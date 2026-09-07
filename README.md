# 修仙之路 · Path of Immortals

Godot 4.7.2 / GDScript / Mobile Renderer。当前 **V0.5：共享储物袋、暂停调整与丹药**。

接手先读 [项目开发进度](PROJECT_PROGRESS.md) 和 [工程规则](AGENTS.md)。新玩法有歧义先与用户确认，再修改。

## 运行

Godot打开project.godot，F5运行。1920×1080，最小1280×720。默认辰宇在右侧前排，角色2/3在左侧后排；野狗单人居中。

1. 战前或战斗暂停时，点中列底部“背包调整”，打开右侧共享储物袋。
2. 点击我方角色/阵盘选择目标；右键储物袋物品随机放入合法位置，或拖动到具体格位。同种丹药自动叠放。
3. 阵盘内拖动可换位置，右键物品或拖回储物袋可收回。主角大阵盘、队友小阵盘大小固定。
4. 空格开始/暂停/恢复。开战或恢复自动关闭储物袋并锁定编辑；战斗进行时调整按钮置灰。
5. F1/F2/F3对应0.5/1/2倍速。状态在居中计时下方；底部“战斗记录”查看隐藏日志。
6. 阵型规则保留供未来大地图设置，当前战斗界面没有切换或重新布阵按钮。战斗结束后重新运行项目可开始新测试。

## 物品与CD

- 原装备：每人玄火剑1×2、铁甲2×2。新增库存：青锋剑、赤霄剑各1；玄铁甲、青鳞甲各1。
- 回春丹回复气血、蕴灵丹回复灵力、益气丹回复体力，各10瓶，1×1；每瓶2次，每次3秒内回复5对应资源，不超上限。
- 已开瓶完成第二次发动后消耗1瓶；已发动的回复继续完成。满资源不启用下一瓶。数量显示在阵盘物品右下角，部分使用次数转移后保留。
- **冷却CD：**战斗中装入/移动/换角色后的2游戏秒等待，灰色显示2s/1s。战前配置没有冷却。
- **轮转CD：**每次生效前计时，测试武器和丹药均3游戏秒；采用虚线上移揭示。追加同种丹药、同格放置不打断进度。
- 暂停冻结全部计时，倍速只影响模拟时间。例：第1秒暂停装剑，恢复后第3秒冷却结束，第6秒首次攻击。
- 新剑与原剑均轮转3秒、10伤害、消耗5体力；爪子为3秒、5伤害、消耗5体力。防具目前没有防御效果。

前排存活目标优先，同排从上到下；阵亡停止攻击。体力不足等待，丹药恢复后能继续。敌方全灭胜利、我方全灭失败；双方均不能再发动且无待结算回复时平局。默认原装备战斗仍在12秒胜利。

## 架构

JSON → ContentRegistry → SharedStorage / InventoryState / PartyMemberState → BattleSimulation / GameState → UI。

纯模拟以微秒事件堆处理攻击、插入冷却和持续回复。装备调整用版本号拒绝旧激活事件；每瓶以稳定ID与剩余次数保留状态。UI只读状态并发命令，速度不修改Engine.time_scale。阵型和双方排版继续复用FormationRules / TeamPanel。

分类/品质/uses_per_unit及效果来自JSON；普通物品共用脚本。category预留weapon、armor、pill、item、talisman。现有JSON的cooldown字段对应轮转CD，不改名。

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -Render
# 引擎不在默认路径时添加 -GodotPath 'D:\Godot\Godot.exe'
```

2026-09-07：1110项逻辑、95项无窗口UI、153项真实渲染检查全部通过，导入/启动无错误。详见 [V0.5验证](docs/v0.5-validation.md)。原生虚拟鼠标在headless测试，渲染隐藏窗口不移动系统鼠标。截图和日志在忽略的artifacts/。

当前没有存档、大地图、战后流程、招募、法术、MOD、Steam、联网或导出包。退出后恢复默认库存；防具效果待指定。进一步范围和交接信息见PROJECT_PROGRESS.md。

仓库：[SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals)。
