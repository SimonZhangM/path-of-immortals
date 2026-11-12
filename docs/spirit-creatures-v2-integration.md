# 灵物V2战斗接入

日期：2026-11-10。状态：七套灵物已接入，叠翠峰12处遭遇已开放并完成定向验证。

来源为 `output/imagegen/战斗用图/资料来源/叠翠峰与青岚山道_灵物V2_20261109` 内原始Excel与用户完整说明；原件保持不变。后续改名、抽芽／回春芽分离、灵猿两骨材与4×4布局，以20261110制作清单和用户确认覆盖旧方案。

用户确认：五种普通灵物炼气初期、护果及守穴灵猿炼气中期；身体材料统一凡品，各独立25%掉1份，无首胜保底。山灵果未吃掉才25%掉1份。叠翠峰12处普通／首领均20游戏日刷新。

## 实施边界

- 注册七套敌人，复用六套头像／阵盘及33种物品画稿、七张战场。叠翠峰12处接真实战斗与定稿插图；青岚山道三套数据备齐，不新造地图节点。
- 器官和掉落材料分开，回春芽及两骨材放敌盘但没有战斗效果。玩家材料不继承敌人的招式。
- 保留Data → Registry → Simulation → State → UI。普通内容用JSON，共用调度支持周期恢复、冷却后条件等待、限次使用、低血量一次增伤、多段攻击；不增加逐怪脚本或逐帧轮询。
- 装备资源上限由物品提供，V2总表不重复相加；新敌人仅初始满资源／护甲，重新装入不补满、不重置本战次数与恢复时钟。
- 恢复与多段命中使用模拟微秒事件队列；先确认存活再触发被动及恢复。山灵果消耗后继续完成三次恢复，掉落读取最终敌盘。

## 配置与素材

七套敌人位于`data/enemies`，六套阵盘位于`data/boards`；35个器官定义共用33张物品图，护果／守穴猿的护岩与猿皮分别配置。21种可掉落材料位于`data/maps/enemy_materials.json`，头像／框／战场绑定位于`data/ui/enemy_art.json`。12事件位于`data/map_events/diecuifeng_encounter_n*.json`。

| 灵物 | 气血 | 体力 | 灵力 | 护甲 | 修为／历练 |
| --- | ---: | ---: | ---: | --- | --- |
| 碧叶藤灵 | 144 | 42 | 28 | 18轻 | 20／10 |
| 溪纹灵螈 | 160 | 40 | 24 | 16灵 | 22／12 |
| 苔背石灵 | 184 | 64 | 56 | 56重 | 24／12 |
| 岚翎灵隼 | 136 | 24 | 60 | 11轻 | 26／14 |
| 青锋灵螳 | 136 | 84 | 48 | 14轻 | 28／16 |
| 岩臂灵猿·护果 | 208 | 110 | 72 | 92重 | 50／28 |
| 岩臂灵猿·守穴 | 240 | 126 | 80 | 106重 | 60／34 |

普通阵盘4×3，每格245×245；灵猿4×4，每格224×224。源PNG保留，游戏使用WebP及mipmap。素材对应与哈希见[接入归档](../output/imagegen/战斗用图/制作批次/灵物游戏接入_20261110/README.md)。六组旧末尾已改：zhuoxi→sunhui、luefeng→luefengfeiyu、guixiyu→guixiweiyu、shuanglian→qingfenglianzhi、baojia→qingtangjiake、yanfu→yanwenyuanpi；assets运行引用与Downloads根目录12份PNG／WebP同步。Downloads仅改名，尺寸及内容哈希不变。

## 已完成验证与边界

全部使用隔离APPDATA／LOCALAPPDATA和测试存档，未改真实存档。

| 专项 | 通过项 | 日志（本地artifacts） |
| --- | ---: | --- |
| spirit_creatures_tests | 209 | final-spirit_creatures_tests.log |
| spirit_encounter_tests | 155 | final-spirit_encounter_tests.log |
| diecuifeng_tests | 63 | spirit-map-run.log |
| wumingjiuci_combat_tests | 113 | spirit-wumingjiuci_combat_tests.log |
| cslz_items_tests | 107 | spirit-cslz_items_tests.log |
| armor_start_tests | 168 | spirit-armor_start_tests.log |

各专项均0失败。覆盖七套数值、资源上限、格位、周期恢复、门槛等待、次数与重装、护境死亡边界、果实三次双资源恢复及消耗后不掉落；12处对应图片、20日刷新、迎战及胜败撤退返回、奖励保存重载。实际击杀用隔离测试武器验证；战后返回测试另注入结果，不代表正式装备的难度或平衡验证。旧测试仅修复过时夹具，不修改正式开局赠品。

已运行遭遇专项渲染并目视藤灵弹窗、灵螈战场、护果猿4×4及骨材行。重启加载项目后生效。运行命令为`tests/run_t01.ps1 -Script res://tests/spirit_creatures_tests.gd`和`tests/run_t01.ps1 -Script res://tests/spirit_encounter_tests.gd`（需要渲染时加`-Render`），须先隔离APPDATA／LOCALAPPDATA。

未做全项目回归或正式难度平衡；未新增威压玩法。青岚山道的灵隼、灵螳、守穴猿已具备数据及美术，具体地图节点留待用户安排。叠翠峰5处非遭遇插图、北／东出口、音乐及世界地图位置属于其他待办，本轮未扩展。
