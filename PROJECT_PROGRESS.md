# 项目开发进度 · 修仙之路

> 跨任务交接入口。开始工作先读本文件与 AGENTS.md，再核对实际代码和 Git。完成或中断时更新。建议与用户已批准范围须区分。

最后更新：2026-09-06（Asia/Shanghai）。

## 当前结论

**V0.4「阵型、双方战斗与体力」已完成并通过验证。** 用户确认规则后实施，取代 V0.3 的点击角色放大背包、暂停可编辑、单木桩不反击等行为。

默认我方为后排角色2/3在左、前排辰宇在右，靠中心为前排；三个背包同向排布。只有辰宇背包固定正常大小，队友始终缩小，点击人物不改大小。敌方目前只有野狗，头像+名字+资源组合及背包各自在敌方区域居中，没有角色2/3的空框。

启动进入布阵，所有我方背包都可直接整理；开战后及暂停中均禁止移动装备或更换阵型。重新布阵保留布局和阵型，重置双方资源、时间、日志和速度。敌方背包只读。

三把玄火剑和野狗爪子独立轮转。每次成功攻击扣攻击者5体力，不足5停止发动，不自动恢复。优先攻击前排存活目标，同排按上到下，前排全灭后攻击后排；阵亡者停止攻击。敌方全灭胜利、我方全灭失败，双方均不能继续攻击时平局。

本轮代码、验证和交接已完成，无已知阻塞。Git 提交与远程同步状态以实际命令为准。

## 环境与操作

| 项目 | 信息 |
| --- | --- |
| 目录 | `E:\games\path-of-immortals` |
| 仓库 | [SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals) |
| 分支 | main，跟踪 origin/main，用户已授权持续同步 |
| 引擎 | Godot 4.7.2.stable.official.ed1daf0bf |
| 路径 | `E:\games\Godot_v4.7.2-stable_win64.exe` |
| 技术栈 | GDScript 2.x / 原生2D Control / Mobile D3D12 |
| 入口 | project.godot → scenes/main/main.tscn |
| 分辨率 | 设计/默认1920×1080，最小1280×720，canvas_items缩放 |

Godot 打开项目后 F5。空格开始/暂停/恢复，F1/F2/F3 = 0.5/1/2×，默认1×。布阵阶段点击“前1后2 · 切换”可换到前2后1。暂无增减队员的游戏操作，代码和测试覆盖1/2/3人。

**用户偏好：**以后每轮修改前先思考需求；有新歧义或缺失战斗规则，先问清楚再编辑。已确认的规则不重复询问。持续维护本进度文件并同步到已授权仓库。

## 当前内容与规则

| 内容 | 配置 |
| --- | --- |
| 辰宇 | base.character.chen_yu，炼气初期，气血/体力/灵力100/100/100 |
| 角色2、3 | base.character.role_2 / role_3，同上；默认后排上/下 |
| 野狗 | base.enemy.wild_dog，气血100、体力100、灵力0 |
| 玄火剑 | base.test.fire_sword，垂直1×2，每3游戏秒伤害10，stamina_cost=5 |
| 爪子 | base.weapon.dog_claw，垂直1×2，每3游戏秒伤害5，stamina_cost=5 |
| 铁甲 | base.armor.iron_armor，2×2，被动，无防御效果、无轮转 |

旧稳定ID不改名。base.test.dummy JSON保留为历史内容，不再用于主场景。主角装备实例仍是 run.item.001 / run.item.002；队友为 run.party.1/2.sword/armor；野狗爪子为 run.enemy.0.claw。

三人支持前1后2（辰宇前、两队友后）和前2后1（两队友前、辰宇后）。两人固定辰宇前、队友后；一人无前后排、头像和背包居中。敌方布局镜像，靠中心始终是前排。阵亡时不重新压缩阵型槽位，目标选择跳过阵亡者。

同刻事件按我方成员/装备顺序、然后敌方成员/装备顺序稳定入队，逐次结算。默认战斗第3秒野狗70气血，辰宇95气血，四名攻击者体力均95。第12秒胜利：辰宇气血85/体力80，队友气血100/体力85，野狗气血0/体力85；我方10次攻击、敌方3次。野狗在第12秒被击败后不会在同刻反击。

## 实现入口

| 模块 | 说明 |
| --- | --- |
| scripts/core/formation_rules.gd | 纯数据阵型规则，前后排、目标顺序、阵型名称；UI和模拟共用 |
| scripts/core/party_member_state.gd | 独立角色资源、配置副本与 InventoryState |
| scripts/core/game_state.gd | 双方权威成员引用、阵型、结果、按阵营统计、装备实例轮转 |
| scripts/core/game_manager.gd | 默认双方队伍、布阵编辑命令、阶段切换、倍速与阵型切换 |
| scripts/simulation/battle_simulation.gd | 每实例排程、攻击者存活/体力门槛、逐次选目标、胜负/平局 |
| scripts/systems/effect_system.gd | 双方复用damage结算，扣目标气血，产出表现事件 |
| scripts/registries/content_registry.gd | JSON校验；新增stamina_cost，体力/灵力上限允许0 |
| scripts/ui/team_panel.gd | 双方共用排版，固定身份大小、前后排方向、单人居中、空位不绘制 |
| scripts/ui/party_member_card.gd | 透明头像+姓名/境界+三行资源；画像略放大下移，阵亡变灰，0灵力显示0/0 |
| scripts/ui/inventory_view.gd | 绑定阵营和成员；我方全部背包布阵时可直接拖放，敌方只读 |
| scripts/presentation/battle_log.gd | 记录攻击者/武器/目标、伤害、体力消耗、阵亡和结果 |

重要接口变更：BattleSimulation 现在接收 allies、enemies、registry 和各自阵型，不再接收单物品/单木桩配置。GameState 旧 enemy_hp、单物品兼容字段已移除，用 teams、item_runtime、activation_counts、damage_totals、result、finished_at_usec。角色资源在 PartyMemberState，UI只读，不自行扣血或体力。旧 selected_member / member_selected 已移除；move_item 显式传成员索引，不能跨人物背包移动。

素材：backgroundtest.png、weapontest.webp、portrait1/2/3.webp、guaiwu.webp 为用户原图；dog_claw.svg 为本轮简单爪子占位图，铁甲为旧SVG。计时仍严格水平居中、速度控制在右。气血/体力/灵力色为AF3549/8CD259/5598EB；最后一项为之前7位色值按前6位处理。

## 验证

2026-09-06 执行 `tests/run.ps1 -Render`，全部通过，无脚本错误。

| 项目 | 结果 |
| --- | --- |
| 纯逻辑 | 1023 checks，0 failures |
| 无窗口UI | 109 checks，0 failures |
| 真实渲染UI | 164 checks，0 failures |
| 导入与启动 | 通过 |
| 战斗 | 双方扣血/体力，前排优先和同排顺序，阵亡换目标/停止发动，体力0/4/5，胜利/失败/平局，过量伤害钳制，同刻无尸体反击 |
| 时间 | 0.5/1/2× × 30/60/144 FPS；高气血双方60秒时我方60次/600伤害、敌方20次/100伤害，耗尽体力平局；不同冷却、同人共享体力、长帧补算 |
| UI | 所有我方大/小背包原生拖放、跨包与非法落点拒绝、战斗/暂停锁定、重开保留队友自定义布局、固定大小、两阵型及1/2/3人排版 |
| 画面 | 1080p、720p、16:10、超宽，双方资源变化、零灵力、爪子轮转与锁定、单人居中 |

原生鼠标拖放在无窗口模式用 Input.parse_input_event 测试虚拟指针。隐藏渲染窗口只测拖放回调/键盘/截图，不移动系统鼠标。旧测试中的单木桩/角色选择等接口随架构改动重写，测试数量不可与旧版本直接比较。

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -Render
```

引擎路径不同时传 -GodotPath。截图与日志在忽略的 artifacts/。主要截图：formation_1920x1080.png（默认布阵）、formation_front_two.png、formation_battle_3s.png、formation_paused.png、formation_roster_1/2.png。

## 限制与下一步

- 敌方实际仅一只野狗；已具备通用双方阵型结构，未做敌方多人数值配置与招募/队伍编辑玩法。
- 铁甲没有防御数值，灵力无消耗，体力不恢复。只做确定的普通攻击规则，未新增范围伤害、技能/法术、相邻加成、buff、成长、地图或掉落。
- 背包不可旋转、交换或跨角色转移；移动只影响布局，当前无位置伤害收益。无存档，退出后不保留布阵。
- 未做MOD SDK、Lua、PCK、Steam、联网、正式动画/音效。中文依赖系统字体，尚未导出发行包；导出时须包含 data/**/*.json 并验证加载。
- 同角色多装备共用体力；极端连锁事件预算未实现，ItemData不可变为代码约定。
- **后续建议，未批准：**进一步指定技能/法术对前后排的伤害规则，或增加铁甲防御与资源恢复。新规则先向用户确认。

## 文档与历史

- [工程规则](AGENTS.md)、[运行说明](README.md)、[V0.4设计](docs/v0.4-design-review.md)、[V0.4验证](docs/v0.4-validation.md)。
- V0.1/V0.2/V0.3文档为历史；点击放大、暂停编辑等旧行为已被V0.4取代。
- [基础技术立项说明 + 第一阶段实施规范](<基础技术立项说明 + 第一阶段实施规范.md>)、[口袋修仙-Mod制作与SDK分析总结](口袋修仙-Mod制作与SDK分析总结.md)。用户新确认规则优先于旧范围。
- 2026-09-06：V0.1模拟 → V0.2背包 → V0.3三人及图像/布局 → V0.4阵型、野狗反击、体力与胜负。

同步状态用 git status、git log、git fetch 后核对；不预填本文件未来提交哈希。中断时记录未完成工作与错误，不能只保留在聊天里。
