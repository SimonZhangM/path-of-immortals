"""Build the reviewed runtime catalogue; no workbook edits or inventory grants."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'docs/sources/t01_spell_implementation.json').read_text(encoding='utf-8'))
specs={
'metal': ['回锋 留痕 血沸','蕴锋 刻痕 炼血','反锋生痕 锋痕见血 血养锋势','化锋 深痕 沸血','反锋镇兵 锋痕入骨 血势不绝'],
'wood':['早春 潜毒 盘根','养生 蚀骨 紧缚','以毒养生 缚毒相生 缠生回息','生息绵长 蚀骨渐深 盘根愈固','生生不息 蚀骨难消 盘根不绝'],
'water':['活泉 潜枯 初霜','养脉 蚀脉 凝霜','盈流成护 枯极生寒 霜回活水','长养 深枯 玄霜','周流不息 枯海断流 寒潮留霜'],
'fire':['余焰 复燃 熔痕','蕴火 炽灼 初熔','炎入灼痕 灼势回炎 熔火生灼','炎势炽盛 灼火入骨 深熔','火种不灭 灼骨 熔甲难复'],
'earth':['余韧 疲势难消 催伤','固岳 困乏 沉伤','岳势反镇 乏极成伤 伤深养韧','岳体 疲极 伤元','山岳不倾 疲势崩裂 伤势反噬'],
'wind':['留影 留隙 疾散','轻身 破衡 拂尘','避实成隙 乘隙化影 清风乱势','无影 失势 涤尘','乘风留影 逐影连锋 风过无尘'],
'thunder':['回蕴 留印 连势','凝罡 震印 连霆','盾破留印 雷击成环 连环回蕴','雷罡凝实 雷印震威 连霆增势','雷罡反震 双霆引印 连霆不绝']}
first=['锐金 兵心','木锋 木息','水锋 流息','烈火 蓄炎','坤击 重兵','风锋 灵行','霆威 雷罡']
last=['纯金贯式 兵法合流','万木同息 生杀并济','沧澜同流 玄水两仪','赤阳贯式 炎兵合流','坤岳同势 重器合流','长风同势 风矢合流','万雷同势 雷兵合流']
# Values are from core 01's final replies, not the obsolete proposal tables.
def S(d,cd,fee,a,b,**kw):return dict(damage=d,cooldown=cd,spirit_cost=fee,branches={a[0]:a[1],b[0]:b[1]},**kw)
def B(name,**kw):return name,kw
def H(s,n,gate='hit',target='enemy'):return dict(status=s,count=n,gate=gate,target=target)
D={
'metal':[
S(12,4,4,B('剑锋',damage_pct=.25),B('留痕',statuses=[H('锋痕',3)])),
S(24,6,8,B('骤雨',cd_pct=-.25),B('聚锋',damage_pct=.3)),
S(0,8,8,B('护主',shield=50),B('返剑',counter=15),opcode='sword_screen',shield=30,absorption=.4),
S(60,10,20,B('破军',damage_pct=.4),B('留煞',damage_pct=-.2,statuses=[H('锋痕',6),H('流血',3,'hp_damage')])),
S(0,6,3,B('锐灵',ratio=.75),B('血锋',bleed=2),opcode='enchant',ratio=.5),
S(0,8,6,B('疾御',cd_pct=-.25,cost_pct=-.25),B('重御',weapon_pct=.5),opcode='command_weapon'),
S(0,8,6,B('固元',ratio=1.5),B('返锋',return_edge=True),opcode='weapon_barrier',ratio=1),
S(0,6,12,B('主兵',main_ratio=2),B('群兵',other_ratio=1),opcode='weapon_union',main_ratio=1,other_ratio=.5)],
'wood':[
S(10,4,4,B('锐刺',damage_pct=.25),B('毒芽',statuses=[H('毒蚀',3)])),
S(22,6,7,B('连刃',cd_pct=-.25,cost_pct=-.25),B('缚刃',statuses=[H('缠绕',5)])),
S(36,8,12,B('穿林',damage_pct=.3),B('毒翎',statuses=[H('毒蚀',4,'hp_damage')]),hit_bonus=.15),
S(60,10,20,B('森罗尽发',damage_pct=.4),B('枯荣夺生',life_per_hp=.1)),
S(8,5,5,B('盘根',statuses=[H('缠绕',5)]),B('疾藤',cd_pct=-.25,cost_pct=-.25),statuses=[H('缠绕',3)]),
S(18,6,8,B('入骨',statuses=[H('毒蚀',6)]),B('蔓生',poison_entangle=3),statuses=[H('毒蚀',4)]),
S(0,8,8,B('急生',heal_pct=.5),B('长养',heal_pct=-.25,statuses=[H('生机',6,'always','self')]),opcode='heal',heal=15,statuses=[H('生机',4,'always','self')]),
S(30,10,16,B('天罗固缚',root=1.5,statuses=[H('缠绕',12)]),B('引火召雷',deferred='连携本轮停用'),root=1,statuses=[H('缠绕',8)])],
'water':[
S(12,4,4,B('凝锋',damage_pct=.25,armor_bonus=.1),B('覆霜',statuses=[H('寒霜',3)])),
S(26,6,8,B('贯寒',damage_pct=.3,counter_bonus=.1),B('裂冰',armor_only=.3)),
S(40,8,12,B('叠浪',cd_pct=-.25,cost_pct=-.25),B('凝潮',damage_pct=.3,statuses=[H('寒霜',2)])),
S(60,10,20,B('断江',damage_pct=.4,armor_bonus=.15),B('覆海',damage_pct=-.2,statuses=[H('寒霜',6)])),
S(10,4,4,B('深蚀',drain_spirit=9),B('回流',drain_return=.5),drain_spirit=6),
S(18,6,8,B('封灵',wither_resource='spirit'),B('困体',wither_resource='stamina'),statuses=[H('枯脉',4)]),
S(16,8,12,B('积霜',statuses=[H('寒霜',10)]),B('骤冻',freeze_extra=.2),statuses=[H('寒霜',6)]),
S(60,10,20,B('枯海',missing_scale=1.5),B('回澜',return_resources=True),missing_scale=1)],
'fire':[
S(12,4,4,B('烈锋',damage_pct=.25,armor_bonus=.1),B('蓄焰',statuses=[H('附炎',3,'hit','self')])),
S(26,6,8,B('贯阳',damage_pct=.3),B('熔锋',statuses=[H('破甲',3,'armor_damage')])),
S(40,8,12,B('阳爆',damage_pct=.3),B('焚印',burst_pct=.5),burst_status='灼烧',burst_ratio=1),
S(60,10,20,B('焚灭',damage_pct=.4),B('天火余烬',damage_pct=-.2,statuses=[H('灼烧',6),H('破甲',4,'armor_damage')])),
S(0,6,4,B('聚炎',statuses=[H('附炎',10,'always','self')]),B('疾引',cd_pct=-.25,cost_pct=-.25),opcode='status',statuses=[H('附炎',6,'always','self')]),
S(18,6,8,B('深熔',statuses=[H('破甲',6)]),B('炽裂',burst_pct=.5),statuses=[H('破甲',4)],burst_status='破甲',burst_ratio=.5,burst_armor_only=True),
S(30,8,12,B('续燃',statuses=[H('灼烧',10)]),B('烈灼',damage_pct=.4,statuses=[H('灼烧',3)]),statuses=[H('灼烧',6)]),
S(60,10,20,B('炎尽',layer_ratio=.015,layer_cap=1.5),B('余火',refresh_fire=True,statuses=[H('附炎',6,'hit','self')]),damage_layers=['灼烧','破甲'],layer_ratio=.01,layer_cap=1)],
'earth':[
S(12,4,4,B('重岳',damage_pct=.25),B('震乏',statuses=[H('疲惫',4)])),
S(24,6,8,B('镇山',damage_pct=.3),B('乘乏',burst_pct=.5),burst_status='疲惫',burst_ratio=2),
S(30,8,12,B('裂地',damage_pct=.3),B('沉岳',root=2,statuses=[H('重伤',3)]),root=1),
S(60,10,20,B('倾岳',damage_pct=.4),B('伤崩',burst_pct=.5),burst_status='重伤',burst_ratio=2),
S(0,8,6,B('镇身',reduction=.4),B('蓄岳',tenacity=4),opcode='guard_critical',prepared=True,reduction=.2),
S(0,10,8,B('崩击',blunt_critical=1.75),B('震伤',injury=3),opcode='force_critical',prepared=True,blunt_pct=.2,blunt_critical=1.5),
S(0,10,10,B('沉耗',surcharge=1),B('伤元',surcharge=.25,injury=6),opcode='tax_cast',prepared=True,surcharge=.5,injury=3),
S(0,10,12,B('借力',ratio=1),B('镇敌',ratio=.25,statuses=[H('疲惫',2),H('重伤',2)]),opcode='armor_counter',prepared=True,ratio=.5)],
'wind':[
S(10,4,4,B('疾羽',cd_pct=-.25,cost_pct=-.25),B('透风',damage_pct=.25),hit_bonus=.15),
S(26,6,8,B('贯云',damage_pct=.3),B('破隙',burst_status='失衡',burst_ratio=2)),
S(40,8,12,B('风暴',damage_pct=.3),B('乱流',statuses=[H('失衡',8)]),statuses=[H('失衡',4)]),
S(60,10,20,B('贯日',damage_pct=.4,armor_bonus=.15),B('逐隙',damage_layers=['失衡'],layer_ratio=.01,layer_cap=.5,statuses=[H('失衡',6)])),
S(0,8,6,B('留风',agility=4),B('借势',advance_cd=2),opcode='dodge',prepared=True),
S(0,10,8,B('贯影',followup_bonus=.25,pierce_bonus=.25),B('疾追',followup_hit=.15),opcode='followup',prepared=True),
S(0,8,8,B('顺风',advance_cd=4),B('逆风',delay_cd=2),opcode='change_cd',advance_cd=2),
S(16,8,12,B('洗尘',statuses=[H('驱散',12)],dispel_bonus=.2),B('乘风',advance_cd=2),statuses=[H('驱散',8)])],
'thunder':[
S(10,4,4,B('疾电',cd_pct=-.25,cost_pct=-.25),B('刻雷',statuses=[H('雷印',3)])),
S(26,6,8,B('贯霆',damage_pct=.3),B('引印',statuses=[H('雷印',5)]),statuses=[H('雷印',2)]),
S(30,8,12,B('疾霆',cd_pct=-.25,cost_pct=-.25),B('重链',chain_bonus=.5),extra_chain=True),
S(60,10,20,B('镇邪',race_bonus=.3),B('引劫',strike_bonus=.5)),
S(0,6,4,B('聚罡',statuses=[H('雷蕴',10,'always','self')]),B('疾护',cd_pct=-.25,cost_pct=-.25),opcode='status',statuses=[H('雷蕴',6,'always','self')]),
S(18,6,8,B('深印',statuses=[H('雷印',10)]),B('疾引',cd_pct=-.25,cost_pct=-.25),statuses=[H('雷印',6)]),
S(24,10,8,B('震返',damage_pct=.3),B('连锁',statuses=[H('连环',4)]),opcode='thunder_counter',prepared=True),
S(40,8,12,B('锁狱',paralysis_extension=2),B('雷刑',damage_pct=.3,statuses=[H('雷印',8)]),paralysis_extension=1,statuses=[H('雷印',4)])]}
books=[]; spells=[]
for b in m['books']:
 b={k:v for k,v in b.items() if k not in ['status','dependencies']}
 e=b['element']; index=int(b['id'][-2:]); ei=list(specs).index(e)
 b.update(icon='',max_level=8 if index>=4 else 5,cells=2 if index>=4 else 1,branches={})
 if index==1:b['deferred']='技艺生产／探索功能与成长进度后续专题'
 elif index==2:
  b['branches']={str(i+1):x.split() for i,x in enumerate([first[ei],'乘克 逆克','内鸣 外鸣','启式 承式',last[ei]])}
  b['deferred_branches']={choice:'连携本轮暂缓' for choice in b['branches']['4']+b['branches']['5'] if choice not in ['生杀并济','玄水两仪']}
 elif index==3:b['branches']={str(i+1):x.split() for i,x in enumerate(specs[e])}
 else:
  b['branches']={str(2+2*i):list(D[e][(index-4)*4+i]['branches']) for i in range(4)}
 books.append(b)
for old in m['spells']:
 s={k:v for k,v in old.items() if k not in ['status','dependencies']}
 params=D[s['element']][int(s['id'][-2:])-1].copy()
 s.update(icon='',opcode='attack',prepared=False,**{})
 s.update(params);spells.append(s)
out=root/'data/cultivation_library.json'
out.write_text(json.dumps(dict(version=1,source='docs/01_核心定案_七系功法与战斗规则.md',books=books,spells=spells),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'{len(books)} books / {len(spells)} spells -> {out}')
