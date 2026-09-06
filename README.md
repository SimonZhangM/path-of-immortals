# 修仙之路 · Path of Immortals

Godot 4.7.2 / GDScript / Mobile Renderer 的修仙构筑原型。当前 **V0.4：阵型、双方战斗与体力**。

接手先读 [项目开发进度](PROJECT_PROGRESS.md) 和 [工程规则](AGENTS.md)。每轮遇到新规则歧义先向用户确认再修改。

## 运行与操作

Godot 打开 project.godot 后按 F5。设计及默认窗口1920×1080，最小1280×720。

1. 启动进入布阵。默认辰宇在右侧前排，角色2/3在左侧后排。野狗是单人阵型，头像和背包在敌方区域居中。
2. 辰宇背包固定正常大小，队友固定缩小；所有我方背包都能直接拖放。剑1×2、铁甲2×2，不旋转、不跨人交换；非法落点回到原处。敌方背包只读。
3. 三人布阵时可点击阵型按钮切换“前1后2”和“前2后1”；两人只有前1后1，一人不分前后排。当前没有增减队员的操作入口，代码和测试支持1/2/3人。
4. 空格或开始按钮开战。运行中和暂停中都锁定背包与阵型；点击人物不改变其大小。
5. 空格暂停/恢复；F1/F2/F3分别为0.5/1/2倍速，默认1倍速。计时严格水平居中，速度按钮在右侧。
6. 重新布阵保留装备格位和阵型，恢复双方资源、清空日志、时间归零、速度恢复1倍，再次允许整理背包。

## 战斗规则

| 内容 | 气血 / 体力 / 灵力 | 装备 |
| --- | --- | --- |
| 我方三人 | 各100 / 100 / 100 | 各一把玄火剑及一件铁甲 |
| 野狗 | 100 / 100 / 0 | 一件爪子 |

玄火剑每3游戏秒造成10伤害，爪子每3游戏秒造成5伤害。每次发动扣攻击者5体力；不足5不发动，不自动恢复。铁甲暂时仅占格，无防御效果。

目标优先前排存活者，同排从上到下，前排全灭后打后排。阵亡角色停止发动装备。敌方全灭胜利，我方全灭失败；双方均无法继续发动装备时平局，单方体力耗尽不阻止另一方继续攻击。

同刻事件固定按我方成员/装备顺序、再敌方顺序逐次处理；致死后不会同刻反击。默认配置在第12游戏秒胜利，辰宇剩85气血；我方发动10次，野狗发动3次。

武器轮转时虚线自下而上移动，上方灰色蒙版、下方原图。暂停冻结、发动后重置。体力不足或角色阵亡时停止轮转。

## 架构与内容

`JSON → ContentRegistry → FormationRules / PartyMemberState / InventoryState → BattleSimulation / GameState → UI`

- 模拟、队伍、阵型及背包状态均不依赖UI或系统时间。速度只缩放模拟时钟，不改 Engine.time_scale。
- 按稳定实例ID排程，最小堆以到期时间及插入顺序排序；长帧补算，每次发动重新按阵型选择目标。
- GameState持有双方权威成员引用、阵型、装备运行状态、结果和阵营统计。UI只读取数值和发命令。
- TeamPanel复用双方界面；主角大小固定，成员数量和阵型决定摆放。InventoryView显式绑定阵营/成员，缩小背包也能在布阵时操作。
- 角色/道具/敌人来自 data/ 下的JSON；stamina_cost为非负整数，主动装备有正冷却；体力/灵力上限允许0，气血上限须大于0。

稳定ID：玄火剑 base.test.fire_sword、铁甲 base.armor.iron_armor、爪子 base.weapon.dog_claw、野狗 base.enemy.wild_dog；角色为 base.character.chen_yu / role_2 / role_3。旧木桩 base.test.dummy 留作历史内容。

素材：assets/ 下用户提供的背景、武器、portrait1/2/3.webp和guaiwu.webp；assets/images/items/dog_claw.svg为原创爪子占位图。当前中文依赖系统字体。

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -Render
# 引擎路径不同时添加 -GodotPath 'D:\Godot\Godot.exe'
```

通过1023项纯逻辑、109项无窗口UI、164项真实渲染检查及导入/启动验证。包括伤害/体力、阵型优先、阵亡、胜负/平局、倍速等价、所有我方背包原生拖放、锁定/重开、1/2/3人及两阵型排版。

原生鼠标拖放在无窗口模式使用虚拟指针；隐藏渲染窗口检查回调、键盘和画面，不移动用户系统鼠标。截图和日志位于忽略的 artifacts/；详见 [V0.4验证](docs/v0.4-validation.md)。

## 范围

仓库：[SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals)，main分支。

未做队员增减操作、铁甲防御、体力恢复、技能/法术、范围伤害、相邻触发、成长、存档、MOD、Steam或联网。后续新增规则先确认。未导出发行包；未来导出需包含 data/**/*.json 并验证加载。
