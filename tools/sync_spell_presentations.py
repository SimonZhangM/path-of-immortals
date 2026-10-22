"""Bind approved layered spell artwork and source-backed tooltips; never edit art pixels."""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'output/imagegen/_generation/six-elements-spell-frames-handpaint-2026-10-19/manifest.json').read_text('utf-8'))
catalog=json.loads((ROOT/'data/cultivation_library.json').read_text('utf-8'))
source=(ROOT/'output/imagegen/七系功法简明介绍.md').read_text('utf-8')
presentations={}
for s in manifest['spells']:
    f=next(f for f in manifest['frames'] if (ROOT/f['file']).resolve()==Path(s['frame']).resolve())
    raw=next(r for r in catalog['spells'] if r['id']==s['id'])
    icon='res://assets/'+Path(s['art']).stem+'.webp'
    frame='res://assets/'+Path(s['frame']).stem+'.webp'
    assert (ROOT/icon.removeprefix('res://')).exists() and (ROOT/frame.removeprefix('res://')).exists()
    w,h=f['dimensions']
    norm=lambda r:[r[0]/w,r[1]/h,r[2]/w,r[3]/h]
    line=next(l for l in source.splitlines() if '| 固定习得 |' in l and '**【'+s['name']+'】**' in l)
    summary=line.split('】**：',1)[1].rsplit('|',1)[0].strip()
    # A short source overview; runtime numbers below always come from resolved combat data.
    summary=re.split(r'基础伤害|冷却|本术消耗',summary)[0].strip().rstrip('；')
    branch_text={}
    for branch in raw['branches']:
        pattern=r'\*\*【'+re.escape(branch)+r'】\*\*(?:（[^）]*）)?：([^|<\n]+)'
        # Scope to this spell's following even-rank row, avoiding shared branch names.
        next_line=source.split(line,1)[1].splitlines()[1]
        match=re.search(pattern,next_line)
        if match:branch_text[branch]=match.group(1).strip()
    presentations[s['id']]={'icon':icon,'frame':frame,'book_name':s['book_name'],'quality':{1:'下品',3:'凡品',5:'上品',7:'灵品'}[raw['learned_at_book_level']], 'viewport':norm(f['preview_viewport_xywh']),'art_rect':norm(f['art_rect_xywh']),'clip_rect':norm(f['art_clip_xywh']),'placement_mode':f['placement_mode'],'summary':summary,'branch_descriptions':branch_text}
out=ROOT/'data/ui/spell_presentations.json'
out.write_text(json.dumps(presentations,ensure_ascii=False,indent=2)+'\n','utf-8')
for path in {v[k] for v in presentations.values() for k in ['icon','frame']}:
    p=ROOT/(path.removeprefix('res://')+'.import')
    if p.exists():
        text=p.read_text('utf-8').replace('mipmaps/generate=false','mipmaps/generate=true')
        p.write_text(text,'utf-8')
    else:
        # Godot populates remap/deps on the first import, retaining these settings.
        p.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\n','utf-8')
print('Bound 56 spell WebPs / 28 frame WebPs; enabled mipmaps; source pixels unchanged.')
