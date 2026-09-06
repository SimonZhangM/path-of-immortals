# 修仙之路 · Path of Immortals

Godot 4.7.2 / GDScript / Mobile Renderer 的修仙构筑原型。当前版本 **V0.2：战前背包布阵与左右对阵界面**。

接手开发先读 [项目开发进度](PROJECT_PROGRESS.md) 和 [工程规则](AGENTS.md)。最新成果、验证与限制统一维护在进度文档中。

## 运行与操作

Godot 打开 `project.godot`，按 **F5**。主场景是 `scenes/main/main.tscn`。

1. 启动进入布阵阶段，游戏时间为零。左侧玩家有 **4×4** 背包，右侧是测试木桩。
2. 玄火剑固定占 **1×2** 格，铁甲占 **2×2** 格。鼠标左键拖动，绿色表示可放，红色表示越界或重叠；非法落点保留原位置。不旋转、不交换或丢弃装备。
3. 也可点击装备选中，再点击空格，以该空格为装备左上角放置。
4. 点击 **开始战斗** 后锁定背包，玄火剑每 3 游戏秒造成 10 伤害；木桩初始 100 HP，30 游戏秒被击破。
5. **空格**暂停/恢复；**F1** = 0.5×，**F2** = 1×，**F3** = 2×。默认 1×，1 真实秒 = 1 游戏秒。半速每 6 真实秒攻击，正常每 3 秒攻击，2× 每 1.5 秒攻击。
6. 暂停时仍不能移动装备。**重新布阵**保留当前布局，重置生命、时间、战斗记录及速度（1×），等待再次开战。

结束时冻结在实际击破时刻。铁甲本轮只实现占格和摆放，没有新增防御数值；木桩不会反击。当前玩家生命显示为 100，无角色成长系统。

## 目录与架构

```text
assets/images/             原创 SVG 占位图：角色、木桩、剑、甲
data/items/                道具 JSON（尺寸、图标、效果）
data/enemies/              敌人 JSON
scenes/main/main.tscn      入口场景：Manager + UI
scripts/core/             游戏状态、背包状态、管理入口、日志
scripts/data/             道具静态定义
scripts/registries/       内容读取、校验、稳定 ID 查询
scripts/simulation/       时钟、稳定事件队列、战斗模拟
scripts/systems/          通用 damage 效果接口
scripts/ui/               布局、原生背包拖放、背景绘制
scripts/presentation/     有长度上限的战斗记录
tests/                    逻辑、输入联动与渲染检查
docs/                     设计审查和历史验证记录
artifacts/                本地测试日志与截图（忽略，不上传）
```

`JSON → ContentRegistry → BattleSimulation / InventoryState → GameState → UI`

- 模拟与背包状态继承 `RefCounted`，不依赖场景或 UI。`GameManager` 负责时间桥接、战斗阶段和操作命令。
- 背包保存实例 ID、内容 ID、左上角格坐标；尺寸从 Registry 读取。`InventoryView` 不持有权威布局，只负责坐标换算、预览和命令转发。
- `PREPARATION / BATTLE / FINISHED` 明确区分布阵、战斗和完成；开始战斗才排入首个攻击事件。
- 时钟使用整数微秒并保留换算余数，速度为浮点数，支持 0.5×。不改变 `Engine.time_scale`。
- 最小堆按到期微秒、插入顺序排程；循环从上一次到期时间续排，长帧补算不丢事件。
- UI 读取状态并批量消费表现事件；血量和统计按 revision 更新。图标从内容路径加载并缓存。

设计取舍见 [V0.2 设计审查](docs/v0.2-design-review.md)，历史基础设计见 [V0.1 审查](docs/v0.1-design-review.md)。

## 数据约定

- 玄火剑稳定 ID：`base.test.fire_sword`，原有 ID 保持不变。
- 铁甲稳定 ID：`base.armor.iron_armor`。
- 木桩稳定 ID：`base.test.dummy`。
- 道具 `size: [宽, 高]` 两维均为 1–4 的整数；`icon` 为资源路径；`tags` 为字符串数组。
- 主动道具：`effects` 非空，冷却范围 0.001–86400 秒，当前只支持 `on_activate / damage`，伤害为正整数。
- 无主动效果装备：`effects: []`、`cooldown: 0`，不进入攻击队列。
- 修改 JSON 后重新运行生效。未知效果、重复 ID、非法尺寸和数值会在启动时被拒绝。

## 验证

在项目根目录的 PowerShell 执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -Render
# 本机引擎路径不同时指定：
powershell -ExecutionPolicy Bypass -File .\tests\run.ps1 -GodotPath 'D:\Godot\Godot.exe'
```

目前通过 **484 项逻辑检查、34 项无窗口 UI 检查、39 项真实渲染场景检查**。原生鼠标拖放通过无窗口 Godot 的 `Input.parse_input_event` 路径验证，快捷键经 Viewport 输入分发验证；渲染模式检验拖放回调、键盘和画面，不操纵用户的系统鼠标。详情见 [V0.2 验证记录](docs/v0.2-validation.md)。

设计及默认窗口分辨率为 **2560×1440**，最小 1280×720，使用容器布局与 `canvas_items` 缩放。已检查 2K、720p、16:10、超宽屏和战斗暂停画面。中文使用系统字体，尚未打包可分发字体。当前使用自制矢量占位图，没有正式美术、音效或动画。

## 版本管理与后续范围

仓库：[SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals)，主分支 `main`。忽略 `.godot/`、测试产物和构建目录。

尚未实现敌方反击、铁甲防御效果、多主动法器战斗、旋转、相邻触发、成长、存档、MOD 或 Steam。下一步可讨论最小攻防规则，让铁甲参与战斗；新增规则与数值需用户确定。

尚未导出发行包。未来导出时需显式包含 `data/**/*.json`，并在导出产物中验证加载。
