"""Build a source-located implementation map; never registers unlearned spells."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = 'docs/01_核心定案_七系功法与战斗规则.md'
CATALOG = {
    'metal': ('金', ['玄金百炼录', '庚金真解', '金煞藏锋经', '玄庚剑诀', '百兵御灵诀'], ['庚锋剑', '分光剑雨', '回锋剑幕', '玄庚归一剑', '附灵术', '御兵术', '兵甲化元', '百兵归元']),
    'wood': ('木', ['百兽驭灵录', '青木真解', '枯荣生灭经', '万木生杀诀', '青萝化生诀'], ['青木刺', '青藤刃', '森罗灵矢', '万木森罗', '缚灵藤', '蚀脉荆', '回春术', '青萝天罗']),
    'water': ('水', ['灵墨玄符录', '玄水真解', '寒脉流转经', '寒月凝冰诀', '沧澜燃灵诀'], ['寒月刃', '玄冰枪', '沧澜寒潮', '寒月天河', '燃灵指', '断脉印', '寒潮锁阵', '归墟断流']),
    'fire': ('火', ['赤炉丹经', '离火真解', '炎煞流火经', '赤阳真火诀', '离火燎原诀'], ['赤焰刃', '炎龙枪', '烈阳印', '赤阳天火', '引焰诀', '熔甲炎', '燎原火', '离火真炎']),
    'earth': ('土', ['坤元地脉录', '厚土真解', '镇岳沉元经', '撼岳裂地诀', '不动玄岳诀'], ['岩罡锤', '坠岳印', '地脉震', '山河崩', '守岳式', '破岳式', '镇脉诀', '玄岳反震']),
    'wind': ('风', ['听风寻迹录', '御风真解', '流风无相经', '青冥破空诀', '听风无影诀'], ['风羽矢', '穿云枪', '裂空罡风', '青冥贯日', '听风步', '追风式', '回风引', '清风涤尘']),
    'thunder': ('雷', ['玄枢阵录', '天雷真解', '雷池引霆经', '九霄霆光诀', '雷罡镇狱诀'], ['雷光指', '玄霆枪', '连霆术', '九霄雷落', '雷罡护体', '引雷印', '雷返式', '雷狱锁']),
}
SPECIAL = {
    '回锋剑幕': ['特殊盾替换', '盾阶段返剑'], '附灵术': ['来源独立附伤'],
    '御兵术': ['武器额外发动', '独立支付'], '兵甲化元': ['灵盾来源份额账本'],
    '百兵归元': ['武器合击', '参与者费用'], '回春术': ['法术治疗'],
    '归墟断流': ['资源缺失倍率', '回澜分配'], '地脉震': ['武器定身'],
    '守岳式': ['待发', '暴击拦截'], '破岳式': ['待发', '保证暴击'],
    '镇脉诀': ['待发', '发动申请截断'], '玄岳反震': ['待发', '实际护甲损失反击'],
    '听风步': ['待发', '保证闪避'], '追风式': ['待发', '追击来源优先级'],
    '回风引': ['CD推进或延后', '扫描选目标'], '清风涤尘': ['驱散', '分支CD推进'],
    '连霆术': ['多次连环'], '雷返式': ['待发', '破盾监听'], '雷狱锁': ['麻痹延时'],
}

def export():
    core = (ROOT / CORE).read_text(encoding='utf-8')
    sections = re.split(r'(?=^### )', core, flags=re.M)
    books, spells, sources = [], [], {}
    lines = ['# T01 七系35书／56术实施映射', '',
             '2026-09-29第二批更新。35书／56术已按下列稳定ID注册到运行目录，新增图片均为空；学习账本、境界资格、独立上阵及已定非连携效果已接入。115件实体资产不包含这些书术，未向正式玩家自动授予全部学习。名称与书属核对原方案，规则及初学参数以核心01最新决定为准；原方案旧斩刺身份、蓄势和旧共鸣门槛不导入。', '',
             '当前实现与边界见[第二批清单](t01_书术与控制实施清单_2026-09-29.md)，运行参数在[data/cultivation_library.json](../data/cultivation_library.json)，逐项来源在[映射JSON](sources/t01_spell_implementation.json)。56术基础版与双分支已校验，全部56术经实际入口发动；不代表穷尽全部组合。连携相关分支明确停用，七技艺书仅注册与学习；成长进度、技艺生产、完整界面及跨战流程后续。', '']
    for element, (label, names, techniques) in CATALOG.items():
        path = f'docs/{element}-cultivation-design-2026-09-22.md'
        original = (ROOT / path).read_text(encoding='utf-8')
        sources[path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        def locate(name):
            matches = [i for i, line in enumerate(original.splitlines(), 1) if name in line]
            assert matches, (element, name)
            return {'path': path, 'line': matches[0]}
        def references(name):
            return [s.splitlines()[0].removeprefix('### ') for s in sections if name in s and s.startswith('### 4.')]
        lines += [f'## {label}', '', '| 功法运行ID | 名称 | 作用／接入状态 |', '| --- | --- | --- |']
        for index, name in enumerate(names, 1):
            role = ['技艺', '属性总纲（上阵生效）', '状态专精（习得生效）', '战斗功法', '战斗功法'][index-1]
            status = ['已注册与学习；技艺功能后续', '已接非连携收益；连携分支暂缓', '已接已定状态专精', '已接学习、分支与独立法术', '已接学习、分支与独立法术'][index-1]
            record = dict(id=f'base.cultivation_book.{element}_{index:02}', name=name, element=element,
                          source=locate(name), core_references=references(name), role=role,
                          status=status, dependencies=['学习账本/境界资格', '分支效果注册', '正式修炼进度/获取后续'])
            books.append(record)
            lines.append(f'| `{record["id"]}` | {name} | {role}；{status} |')
        lines += ['', '| 法术运行ID | 法术／原书／习得重数 | 已接共享及专属能力 |', '| --- | --- | --- |']
        for index, name in enumerate(techniques):
            book_index = 3 + index // 4
            dependencies = ['独立法术上阵/唯一', '双资源支付/独立CD', f'{label}系状态/共鸣'] + SPECIAL.get(name, ['法术本体/已定分支'])
            record = dict(id=f'base.spell.{element}_{index+1:02}', name=name, element=element,
                          book_id=f'base.cultivation_book.{element}_{book_index+1:02}',
                          learned_at_book_level=1 + index % 4 * 2,
                          cells=2 if index % 4 == 3 else 1, source=locate(name),
                          core_references=references(name), status='已接本体与已定非连携分支；实际入口已发动' + ('；引火召雷暂缓' if name == '青萝天罗' else ''), dependencies=dependencies)
            spells.append(record)
            note = '；引火召雷连携分支暂缓' if name == '青萝天罗' else ''
            lines.append(f'| `{record["id"]}` | {name}／{names[book_index]}／{record["learned_at_book_level"]}重 | {"、".join(dependencies)}{note} |')
        lines += ['', f'名称出处：[{label}系原方案]({element}-cultivation-design-2026-09-22.md)。逐术核心章节与来源行号见JSON。', '']
    assert len(books) == 35 and len(spells) == 56
    assert len({r['id'] for r in books + spells}) == 91
    result = dict(core=CORE, runtime_catalog='data/cultivation_library.json', implementation_record='docs/t01_书术与控制实施清单_2026-09-29.md', sources=sources, books=books, spells=spells)
    (ROOT/'docs/sources/t01_spell_implementation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (ROOT/'docs/t01_书术映射_2026-09-29.md').write_text('\n'.join(lines),encoding='utf8')
    print('Mapped 35 books / 56 spells with current implementation status; no inventory or learning grants.')

if __name__ == '__main__': export()
