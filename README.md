# 修仙之路 · Path of Immortals

Godot 4.7.2 / GDScript / Mobile Renderer 的 V0.1 最小可玩原型。参考《口袋修仙》的自动触发构筑方向，第一阶段仅验证底层链路，不复刻其资源或完整玩法。

## 运行

用已安装的 Godot 打开本目录 `project.godot`，按 **F5** 运行项目。主场景为 `scenes/main/main.tscn`。

启动即自动战斗：测试玄火剑每 3 游戏秒攻击木桩，造成 10 伤害；木桩初始 100 HP，第 30 游戏秒被击破。支持 1× / 2× / 4× / 8×、暂停/继续、重新开始。重新开始会重置战斗、记录、速度与暂停状态。

4× 下每 0.75 真实秒攻击，8× 下每 0.375 真实秒攻击。胜利后不再攻击，游戏时钟仍可推进，以便观测 60 秒等测试窗口；胜利耗时固定显示实际击破时刻。

## 目录与边界

```text
data/items/                 法器 JSON
data/enemies/               敌人 JSON
scenes/main/main.tscn       入口场景：Manager + UI
scripts/core/              调度入口、权威状态、日志
scripts/data/              法器定义
scripts/registries/        内容读取、校验、稳定 ID 查询
scripts/simulation/        时钟、稳定最小堆事件队列、战斗模拟
scripts/systems/           通用效果执行接口（当前仅 damage）
scripts/ui/                容器布局、状态展示、操作转发
scripts/presentation/      事件转战斗记录（最多保留 12 行）
tests/                     逻辑测试、场景联动及渲染验证
docs/                      第一阶段架构审查与取舍
artifacts/                 本地测试日志和截图（Git 忽略）
```

只创建本阶段实际使用的目录，后续素材、存档和 MOD 目录按需求补充。

## 架构

`JSON → ContentRegistry → BattleSimulation → GameState → MainUI`

- 模拟类均继承 `RefCounted`，不依赖节点树、UI、系统时间或动画。`GameManager` 是现实帧时间到模拟的唯一桥梁。
- `SimulationClock` 将真实 delta 按速度换算成整数微秒，保留不足一微秒的余数。不修改 `Engine.time_scale`。
- `EventQueue` 按「到期微秒 + 插入序号」排序。循环事件从上一次到期时间重排，不从当前帧末尾重排，因此掉帧不会丢失攻击或累积冷却漂移。
- `GameState` 持有生命、次数、累计实际伤害、内容 ID、实例 ID 和到期时间。静态内容从 Registry 读取。
- `EffectSystem` 校验与分发 `on_activate / damage`。今后扩展通用处理器，不为普通法器新建脚本。
- UI 每帧更新时钟/冷却，生命与战斗统计按状态 revision 更新；表现事件每帧批量交付，动画或日志不阻塞模拟。
- JSON 启动时读取一次；拒绝重复 ID、未知效果、非法数值、缺失字段、错误 JSON。加载失败显示原因并停止启动战斗。

详细审查见 `docs/v0.1-design-review.md`。

## 修改测试数据

编辑 `data/items/test_fire_sword.json` 的 `cooldown`、`effects[].value`，或敌人 JSON 的 `max_hp`，重新运行即可生效。不要修改已有稳定 ID。

当前字段约束：ID 是至少三段小写标识符；name 为非空字符串；type 非空；tags 为字符串数组；冷却范围 0.001–86400 秒；伤害与生命为 1–10 亿的整数；effects 非空且只支持 `on_activate` + `damage`。这属于 V0.1 校验契约，还不是对外发布的 MOD SDK。

## 测试

在项目目录的 PowerShell 执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1
# 额外使用实际 Mobile / D3D12 渲染四种窗口尺寸，并保存截图：
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -Render
# 引擎位置不同可以传入：
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -GodotPath 'D:\Godot\Godot.exe'
```

脚本等待 Windows 版 Godot 退出，并同时检查退出码与错误日志。先导入全局类，再运行逻辑测试、场景按钮联动测试、主场景启动检查。无需额外插件或测试框架。

逻辑测试覆盖 1/2/4/8×、30/60/144 FPS、精确事件时刻、同时间事件顺序、60 秒长帧补算、不均匀帧、暂停/切速/恢复、死亡停止、过量伤害截断、数据校验。高血量测试目标在 60 游戏秒内均攻击 20 次、损血 200；正式木桩只攻击 10 次。

界面以 1920×1080 为参考，用 Container 和锚点布局，默认窗口 1280×720，最小 960×540，支持 16:10 和超宽窗口。中文使用系统字体（Windows 微软雅黑优先），未打包商业字体；将来跨平台发行时再选择可分发字体。当前无正式美术、动画、音效。

## 版本管理与下一步

已初始化 Git 并忽略 `.godot/`、测试产物和构建目录。远程仓库为 [SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals)，主分支为 `main`。首个版本提交为 `V0.1 minimal simulation prototype`，使用已连接的 GitHub 身份及 GitHub 隐私邮箱。

下一阶段建议先加入第二件数据驱动法器和多个实例，验证不同冷却、同时触发与实例状态隔离；通过后再设计背包布局和相邻触发。本次未开始第二阶段。
