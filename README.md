# 修仙之路 · Path of Immortals

Godot 4.7.2 / GDScript / Mobile Renderer 的修仙构筑原型。当前版本 **V0.3：三人队伍、独立背包与轮转揭示**。

接手开发先读 [项目开发进度](PROJECT_PROGRESS.md) 和 [工程规则](AGENTS.md)。最新成果、验证与限制统一维护在进度文档中。

## 运行与操作

Godot 打开 `project.godot`，按 **F5**。主场景是 `scenes/main/main.tscn`。

1. 启动进入布阵阶段，游戏时间为零。左侧为**辰宇（炼气初期）、角色2、角色3**，每人使用独立大头像及气血/体力/灵力组合；选中组合按 100% 显示，其余按 66% 显示。每人有独立 **4×4** 背包。右侧使用怪物头像表示测试木桩。
2. 玄火剑固定占 **1×2** 格，铁甲占 **2×2** 格。鼠标左键拖动，绿色表示可放，红色表示越界或重叠；非法落点保留原位置。不旋转、不交换或丢弃装备。
3. 也可点击装备选中，再点击空格，以该空格为装备左上角放置。
4. 布阵或战斗暂停时，点击角色卡片或小背包切换选中角色。选中者的背包放大，其他角色按原顺序在右上、右下显示；战斗运行中不能切换。
5. 按 **空格**或点击**开始战斗**后锁定三人的背包。三把玄火剑各自每 3 游戏秒造成 10 伤害；100 HP 木桩在第 12 游戏秒被击破。
6. 战斗中再按**空格**暂停/恢复；**F1** = 0.5×，**F2** = 1×，**F3** = 2×。默认 1×，1 真实秒 = 1 游戏秒。每把剑半速每 6 真实秒攻击，正常每 3 秒攻击，2× 每 1.5 秒攻击。
7. 轮转时，武器图标上的虚线从下往上移动，线上方为灰色蒙版，下方为原图；发动后重新轮转，暂停冻结，切换角色不重置进度。
8. 暂停时仍不能移动装备。**重新布阵**保留三人布局和选中角色，重置属性、时间、战斗记录及速度（1×），等待再次开战。

结束时冻结在实际击破时刻。三人先使用相同的剑和甲作为测试配置，气血/体力/灵力均为 100/100，尚无消耗或恢复规则。铁甲仅实现占格和摆放；木桩不会反击。本轮先改我方，敌方三人尚未实现。

## 目录与架构

```text
assets/images/             原创 SVG 占位图：角色、木桩、剑、甲
assets/backgroundtest.png 用户提供的战斗背景
assets/weapontest.webp     用户提供的测试武器图片
assets/portrait1-3.webp    用户提供的三名角色头像
assets/guaiwu.webp         用户提供的敌人头像
data/items/                道具 JSON（尺寸、图标、效果）
data/enemies/              敌人 JSON
data/characters/           角色 JSON（名字、境界、三项资源上限、肖像）
scenes/main/main.tscn      入口场景：Manager + UI
scripts/core/             游戏状态、角色/背包状态、管理入口、日志
scripts/data/             道具静态定义
scripts/registries/       内容读取、校验、稳定 ID 查询
scripts/simulation/       时钟、稳定事件队列、战斗模拟
scripts/systems/          通用 damage 效果接口
scripts/ui/               属性卡片、背包切换/拖放、轮转蒙版、背景贴图
scripts/presentation/     有长度上限的战斗记录
tests/                    逻辑、输入联动与渲染检查
docs/                     设计审查和历史验证记录
artifacts/                本地测试日志与截图（忽略，不上传）
```

`JSON → ContentRegistry → BattleSimulation / PartyMemberState / InventoryState → UI`

- 模拟与背包状态继承 `RefCounted`，不依赖场景或 UI。`GameManager` 负责时间桥接、战斗阶段和操作命令。
- 背包保存实例 ID、内容 ID、左上角格坐标；尺寸从 Registry 读取。`InventoryView` 不持有权威布局，只负责坐标换算、预览和命令转发。
- `PREPARATION / BATTLE / FINISHED` 明确区分布阵、战斗和完成；开始战斗才排入首个攻击事件。
- 时钟使用整数微秒并保留换算余数，速度为浮点数，支持 0.5×。不改变 `Engine.time_scale`。
- 最小堆按到期微秒、插入顺序排程；循环从上一次到期时间续排，长帧补算不丢事件。
- 多个主动装备按稳定实例 ID 分别保存下一次发动时间和次数；日志带所属角色。被选中与否不参与战斗计算。
- UI 读取状态并批量消费表现事件；血量和统计按 revision 更新。图标从内容路径加载并缓存。

设计取舍见 [V0.3 设计审查](docs/v0.3-design-review.md)，旧版设计保留在 docs 中。

## 数据约定

- 玄火剑稳定 ID：`base.test.fire_sword`，原有 ID 保持不变。
- 铁甲稳定 ID：`base.armor.iron_armor`。
- 木桩稳定 ID：`base.test.dummy`。
- 角色稳定 ID：`base.character.chen_yu`、`base.character.role_2`、`base.character.role_3`。`max_hp / max_stamina / max_spirit` 为正整数，`realm / portrait` 为非空字符串。
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

目前通过 **1078 项逻辑检查、79 项无窗口 UI 检查、84 项真实渲染场景检查**。原生鼠标拖放、角色卡片和小背包点击通过无窗口 Godot 的 `Input.parse_input_event` 路径验证，快捷键经 Viewport 输入分发验证。包括头像资源、100%/66% 选中缩放、透明组合、敌人图和计时位置，以及多武器速度等价性、背包隔离和三种排序、运行禁换人、暂停切换及轮转保持。渲染模式检验拖放回调、键盘和画面，不操纵用户的系统鼠标。详情见 [V0.3 验证记录](docs/v0.3-validation.md)。

设计及默认窗口分辨率为 **1920×1080**，最小 1280×720，使用容器布局与 `canvas_items` 缩放。已检查 1080p、720p、16:10、超宽屏和三种选中角色的暂停画面。中文使用系统字体，尚未打包可分发字体。背景、武器、角色和敌人使用用户提供图片；铁甲仍为 SVG 占位图，没有正式动画或音效。测试截图在忽略的 artifacts/ 中。

## 版本管理与后续范围

仓库：[SimonZhangM/path-of-immortals](https://github.com/SimonZhangM/path-of-immortals)，主分支 `main`。忽略 `.godot/`、测试产物和构建目录。

尚未实现敌方三人、反击、目标选择、铁甲防御效果、资源消耗、旋转、相邻触发、成长、存档、MOD 或 Steam。下一步可继续敌方展示并讨论最小攻防规则；新增规则与数值需用户确定。

尚未导出发行包。未来导出时需显式包含 `data/**/*.json`，并在导出产物中验证加载。
