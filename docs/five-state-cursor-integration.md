# 五态玉石鼠标接入

实施日期：2026-11-13。依据[用户实施规格原文](sources/five-state-cursor-user-spec-v1-20261113.md)，以实际 `assets/UI-map-cursor-*.webp` 五张素材为准。素材本体保持200×200透明WebP，运行时生成40×40／56×56两档，不另画图、不覆盖原图。

## 新图与地图按下反馈（2026-11-13追加）

当前五张WebP采用用户替换的「玉石鎏金云纹手势图标组」裁剪版。2026-11-13用户追加要求将normal原图亮度降低10点，assets/UI-map-cursor-normal.webp现已对可见像素sRGB三个通道各减10并截到0，200×200透明无损WebP。原字节备份及核验保存在output/image-adjustments/cursor-normal-rgb-minus10-20261113。其余四图与下载目录同名新版SHA256一致。三种箭头热点根据新尖端位置更新为下表坐标，张手与握手共用抓取位置。

最新修订规定，区域地图空白处默认NORMAL，路径节点悬浮、按下及松开左键均为INTERACT。世界地图弹窗的画布空白、边框与普通信息区同样为NORMAL，地点、选择项及按钮使用INTERACT。普通弹窗的空白和装饰区使用NORMAL，现有按钮及选择控件按自身可用状态提供反馈。可平移画布空白处按住左键仍显示UI-map-cursor-dragging，松开恢复NORMAL。实际开始平移采用原6px阈值。

最新修订专项103项通过，包括地图空白NORMAL、路径节点INTERACT、可拖范围及阈值、真实休息弹窗正文／按钮、世界地图空白／边框／地点／按钮。日志位于artifacts/map-normal-and-brightness-20261113，使用隔离目录和程序输入。

按下反馈由CursorManager读取原生左键状态，沿实际悬浮Control的祖先查询cursor_press_feedback_enabled。区域地图要求实际命中可用画布、可平移且当前位置为空白，世界地图要求实际命中map_window、可平移且未指向地点。悬浮外观与按下资格分别查询。真正进入拖动后使用当前拖动状态。

本次隔离验证93项光标检查、21项原生API及静态渲染检查通过。覆盖按下静止、6px以内移动、画布完全显示时按住、地图释放、世界弹窗边框／按钮／外部遮罩及最大缩放按钮的实际点击。新箭头热点位于可见尖端像素，40／56两档新素材拼图已目视。日志和拼图保存于artifacts/cursor-refresh-20261113。桌面鼠标的实际热点手感及多显示器DPI仍待游玩确认。

## 当前使用方式

2026-11-13遭遇战补充：可用操作按钮及对应卡片在点击后、执行忙碌时保持INTERACT；真正未开放的操作仍使用FORBIDDEN。仅在MapEncounterDialog局部提供悬浮状态，忙碌防重复执行逻辑保留。相关155项输入检查通过，见artifacts/battle-header-cursor-20261113/encounter.log。

重启游戏后默认使用标准仙侠指针。开始菜单或地图系统菜单 → 系统设置 → 其他，选择「仙侠指针／系统指针」「标准／较大」，点击「应用并关闭」生效。「恢复默认」只重置本页草稿；取消不应用。系统指针模式下大小选项灰显。

沿用项目现有设置保存范围：当前游戏进程共享，切场景保留，重新启动恢复默认。未新增跨重启偏好文件，不改玩家存档。

## 状态与入口

| 状态 | 实际入口和行为 |
| --- | --- |
| 普通箭头 NORMAL | 区域地图及世界地图空白、弹窗空白与装饰、普通信息和只读盘面 |
| 明亮箭头 INTERACT | 启用的BaseButton、既有可点击光标控件、实际地图命中节点／世界地点、仅可选择的物品卡 |
| 张手 DRAG_READY | 允许整理的地图／战斗物品、仓储物品及已有滑条 |
| 握手 DRAGGING | 既有代码开始拖动后显示。可平移地图画布空白处，左键按下即显示握手。实际地图平移和方形物品卡采用各自原有门槛 |
| 禁止 FORBIDDEN | 明确disabled的按钮、不可编辑滑条、业务拒绝的已声明拖放目标；合法落点恢复握手 |

实际调用入口包括地图 `_gui_input`、世界地图 `_map_input`／`_slider_input`、物品卡 `_begin_drag`、战斗阵盘 `_get_drag_data` 及储物袋原生拖放转发。地图的 `_node_at`／`location_at`、阵盘 `_can_drop_data`、仓储 `_can_transfer` 和战斗 `can_edit_inventory` 继续决定可执行操作；光标查询不执行装备、存取、寻路或战斗结算。

`CursorManager` 是唯一调用 `Input.set_custom_mouse_cursor` 的运行服务。先检查正在进行的拖动，再读取Viewport实际最上层悬浮Control，沿允许透传的父链查语义提供者／按钮／原有光标提示；STOP控件阻断底层地图。原生PopupMenu单独处理菜单项的启用状态。每帧只刷新实际悬浮目标，保证鼠标不动时权限更新；硬件图片只在状态、尺寸或启用状态变化时注册。

`cursor_hover_state`／`cursor_hover`元数据返回五态；`cursor_drop_state`返回-1未声明、0拒绝、1允许，`cursor_drop_allowed`直接复用既有拖放Callable。弱引用记录拖动来源，来源隐藏／删除／失效、Esc、失焦及设置弹出时取消；地图界面切换沿既有结束入口清理。释放完成后重新读取悬浮目标。

只覆盖ARROW、POINTING_HAND、CAN_DROP、DRAG、FORBIDDEN、MOVE。输入框I-beam及窗口尺寸箭头不覆盖，也不更改现有mouse_mode。关闭自定义时对六种形态全部传null恢复；没有软件跟随鼠标、拖尾或新音效。

纯装饰与复盘信息层沿用现有MOUSE_FILTER_IGNORE。物品说明框已有关键词／详情交互，保留其原本事件接收，不将整框改成透传。

## 热点配置

配置在[data/ui/cursors.json](../data/ui/cursors.json)，源坐标按200px画布记录，生成时同比缩放并取整。箭头尖端分别标定，张手与握手使用相同抓取点。

| 文件后缀 | 源热点 | 40px热点 | 56px热点 |
| --- | --- | --- | --- |
| normal | 53,22 | 11,4 | 15,6 |
| interact | 51,22 | 10,4 | 14,6 |
| drag_ready | 108,110 | 22,22 | 30,31 |
| dragging | 108,110 | 22,22 | 30,31 |
| forbidden | 47,22 | 9,4 | 13,6 |

40／56是完整透明画布尺寸，可见图形较小。高DPI主观可读性及实物鼠标尖端手感仍需实际游玩审阅，不根据截图改变输入坐标。

## 修改文件

| 范围 | 文件 |
| --- | --- |
| 新服务／配置 | `scripts/ui/cursor_manager.gd`、`data/ui/cursors.json`；`project.godot`注册Autoload |
| 设置 | `data/settings/defaults.json`、`scripts/settings/game_settings.gd`、`scripts/settings/settings_panel.gd` |
| 地图 | `scripts/map/map_screen.gd`、`map_world_map.gd` |
| 地图物品与仓储 | `scripts/map/map_inventory_item_card.gd`、`map_inventory_screen.gd`、`map_loadout_board.gd`、`map_breakthrough_board.gd` |
| 战斗物品与储物袋 | `scripts/ui/inventory_view.gd`、`battle_inventory_item_card.gd`、`battle_storage_panel.gd`、`storage_item_card.gd`、`storage_panel.gd` |
| 验证 | `tests/cursor_integration_tests.gd`、`tests/cursor_visual_preview.gd`、`tests/system_settings_tests.gd` |
| 资源 | 五张既有WebP的Godot import元数据；新增脚本uid |

工作区另有地图吊牌、世界地点等已有修改，不能视为本次光标任务内容。

## 验证与限制

运行前将APPDATA／LOCALAPPDATA指向 `artifacts/cursors-20261113/` 下的独立目录：

```powershell
$env:APPDATA = Join-Path (Get-Location) 'artifacts/cursors-20261113/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'artifacts/cursors-20261113/localappdata'
./tests/run_t01.ps1 -Script res://tests/cursor_integration_tests.gd
./tests/run_t01.ps1 -Script res://tests/cursor_visual_preview.gd -Render
```

- headless真实输入派发：81项通过，包括按钮权限原地变化、装饰透传、模态遮挡、文本光标保留、地图／世界图拖动、不可平移画布、物品单击选择、阈值、非法→合法落点、成功放置后恢复、取消时库存不变、仓储双向接收、战斗只读／敌盘、来源隐藏／删除、失焦、设置弹出、系统回退和两档大小。
- Windows原生API及静态渲染：21项通过。实际调用全部十组纹理／热点、恢复系统和重新启用；1080p／2K设置页居中和间距通过，两张截图及三背景五态拼图已目视。
- 现有系统设置套件：77项通过。同步维护新增设置数量、按实际配置读取快捷键数，以及已有独立键位网格的布局断言；空隔离目录使用内存新档夹具。首轮暴露旧测试依赖现有存档／旧页面布局，修正测试后复跑通过，没有修改对应游戏规则。
- 原生硬件鼠标不会进入Godot Viewport截图，因此拼图只是同一纹理的静态展示，不宣称已拍到系统鼠标；未操作桌面鼠标逐一验证节点边缘、手掌实际抓取感或多显示器高DPI。
- 地图与战斗实际场景加载已在专项中覆盖，未做完整玩法回归。日志存在本机已知Windows根证书读取失败并回退内置证书提示；本专项无脚本错误或失败断言。

截图和日志见 `artifacts/cursors-20261113/` 与 `artifacts/cursor_*.*.log`。原图未改，未操作真实玩家存档，未提交／推送Git。
