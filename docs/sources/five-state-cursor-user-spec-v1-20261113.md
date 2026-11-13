《苍澜界》五态专用鼠标指针：Codex 实施规格 v1.0
目标：在现有 Godot PC 游戏中接入已确认的五态「玉翠＋金边」鼠标。只更换鼠标的视觉形态和状态反馈，不改变任何既有点击、拖动、物品操作、地图节点、弹窗或快捷键的实际规则。

源图：`五态玉石光标图标集.png`。本交付包已提供透明 PNG 的 40px/、`56px/` 两套切分素材及 cursor_hotspots.json。用户最新确定的视觉基线：更明亮的青玉色＋金色边框；1、2、5 为指针；3 为张开的手、4 为握拳；无拖尾、无独立飘散光点。

0. 执行约束
1. 先阅读现有项目代码，确认 Godot 主版本、地图/阵盘/背包拖拽实现、统一 UI 管理器及鼠标悬浮机制。不能假设现有目录结构或强行用新系统替换旧操作逻辑。
2. 沿用原有交互发起、命中检测、物品落点与提示框机制。五态鼠标仅作视觉反馈，不可用光标状态决定是否真的允许操作；操作权限必须由现有业务判断决定。
3. 优先使用 Godot 原生鼠标图片机制 Input.set_custom_mouse_cursor()，而非 Input.MOUSE_MODE_HIDDEN + Sprite2D 逐帧跟随的方式，以避免延迟和命中偏移。
4. 状态只允许由一个统一的 CursorManager（可做成 Autoload）决定，禁止各个场景分别直接改全局鼠标图片。
5. 用户选择「系统鼠标」时恢复 Godot/OS 原本的指针行为；不允许残留半透明图片或第二个软件鼠标。
6. 不添加音效、动画、粒子、拖尾、放大呼吸等新效果。
1. 五个状态的准确含义
内部枚举	素材文件（40/56 两个版本同名）	视觉形态	何时展示	何时不能展示
NORMAL	01_normal.png	青玉金边普通箭头	无可点击目标的静态区域、空白背景、普通只读文字、非拖动状态	有更高优先级交互、拖动或禁止信息时
INTERACT	02_interact.png	较明亮的青玉金边箭头	鼠标悬停于当前确实可以点击/激活的节点、NPC、交互物、功能按钮、任务按钮、可使用道具等	不可操作目标、空白区域、只允许拖动的对象
DRAG_READY	03_drag_ready.png	张开的青玉手	悬停在当前允许拖动的阵盘物品、背包物品、可平移地图区域、可移动对象上，尚未实际开始拖动	不支持拖动的静态对象、已开始拖动时
DRAGGING	04_dragging.png	握拳的青玉手	鼠标按下可拖动对象并真正进入拖动操作之后，且当前位置不是无效落点	未进入拖动状态、拖动落点明确无效时
FORBIDDEN	05_forbidden.png	青玉箭头＋红色禁用标记	悬停明确禁用的按钮/节点，或拖动对象进入明确禁止放置的目标区域	普通空地、单纯无交互的背景、未解锁但不可感知的地图区域


特别注意：`INTERACT` 不等于“鼠标附近有蓝色圆点”，只有该节点当前有实际可执行操作时才亮起；`FORBIDDEN` 不等于“这里无操作”，不可操作的背景仍然是 NORMAL。
2. 场景映射
场景/目标	条件	指针	备注
区域地图：地面和道路	不可拖动画布/当前无可操作目标	NORMAL	地图是浏览背景，不要整图高亮
区域地图：可平移画布的非节点区域	地图当前确实开启鼠标拖动平移	DRAG_READY	开始实际平移后转 DRAGGING；已有不支持平移时保持 NORMAL
区域地图：蓝色路径节点	可选择/行走/进入	INTERACT	不改原有点击范围和寻路规则
区域地图：NPC、宝箱、采集点、休息点、转场标记	当前可互动	INTERACT	悬浮说明正常显示
区域地图：明确被锁定的交互目标	目标展示且状态为禁用，点击不允许	FORBIDDEN	禁止信息由业务接口提供；不要因为没发现动作就推断禁用
顶部 HUD、侧边功能栏、任务栏按钮	启用且可点击	INTERACT	可折叠功能入口同理
模态窗口中的启用按钮、标签、选择项	可点击/切换	INTERACT	弹窗应遮蔽下层地图的悬浮判定
模态窗口中的禁用按钮	禁止操作	FORBIDDEN	保持原有禁止原因 Tooltip
阵盘物品	允许重新摆放/取出且当前不在拖动中	DRAG_READY	仅查看详情的物品显示 INTERACT 或 NORMAL，取决于原有行为
阵盘物品拖动	已触发拖动，落点未判定为无效	DRAGGING	物品图像仍按现有实现跟随鼠标
阵盘物品拖到错误位置	当前落点被现有规则明确拒绝	FORBIDDEN	恢复到合法区域立刻切回 DRAGGING
背包↔仓储物品移动	可拖时 / 正在拖动	DRAG_READY / DRAGGING	存取按钮仍是 INTERACT
地图拖动、滚动条自定义拖动	若项目已经支持这些操作	按拖动三态	不为了指针增添新拖动能力
输入姓名/可编辑文本	获得文本输入焦点	保留 Godot 原生 I-beam 文本光标	文本编辑体验优先，属于五态之外的输入控件原有行为
Tooltip、纯装饰图层、战斗复盘统计叠层	不可点击	透传到底下实际目标	应设置 mouse_filter = MOUSE_FILTER_IGNORE，不得把指针挡成 NORMAL
战斗中非交互动画、无操作的敌方阵盘	无可操作功能	NORMAL	不把怪物当作始终可点击对象


3. 优先级（非常重要）
状态只按最上层、实际接收鼠标事件的有效对象判定。 当多个条件同时存在时：
1. 当前拖动过程优先：已在拖动、指向明确非法落点 → FORBIDDEN；否则 → DRAGGING。
2. 最上层模态弹窗优先：只处理最上层弹窗，禁用目标 → FORBIDDEN，可拖动 → DRAG_READY，可点击 → INTERACT；不能透传到底下地图。
3. 普通可见 UI 优先于地图：顶栏按钮/功能栏/选项列表判断完毕，才允许底层地图目标生效。
4. 同一对象可拖又可点：若主要操作是拖动物品 → DRAG_READY；只有点击功能、不可拖 → INTERACT。
5. 没有命中有效交互上下文 → NORMAL。
光标状态变化应在进入/离开目标、业务权限变化、拖动开始/结束、弹窗打开/关闭时即时更新；不能只靠 mouse_entered，因为目标可能在鼠标不移动时从“可用”变成“禁用”。
4. 拖动状态机
悬浮在可拖对象
    -> DRAG_READY
左键按下
    -> 先记录按下坐标和来源，仍保持 DRAG_READY（防止点击即误拖动）
指针移动距离超过既有工程的拖动阈值
    -> 调用现有拖动逻辑；确认拖动开始后变成 DRAGGING
在有效拖动范围内移动
    -> DRAGGING
移动到明确非法落点
    -> FORBIDDEN（但鼠标释放时仍由原拖动逻辑处理失败/取消）
重新移回合法位置
    -> DRAGGING
释放左键
    -> 实际放置或取消交由原系统处理；结束拖动并重新判定悬浮状态
按 ESC/物品被删除/切换场景/打开强制弹窗
    -> 让原拖动系统取消；清理拖动状态；重新判定悬浮状态
拖动阈值默认建议 6～8 个 UI 逻辑像素，但必须优先沿用项目现有阈值。不要依照是否按下鼠标直接切成握拳，也不能由 CursorManager 替业务逻辑执行物品移动。
5. 状态输出 API 约定
建议建立 CursorManager Autoload，至少提供以下语义接口（Codex 根据现有架构确定函数名，不要求照搬）：
# 语义接口示意，非可直接覆盖项目的最终脚本
request_hover(owner: Object, state: CursorState, priority: int) -> void
release_hover(owner: Object) -> void
begin_drag(owner: Object) -> void
set_drag_drop_allowed(allowed: bool) -> void
end_drag(owner: Object) -> void
cancel_drag() -> void
set_custom_cursor_enabled(enabled: bool) -> void
set_cursor_size(size_name: String) -> void  # "normal"/"large"
refresh_state() -> void
内部必须维护每个悬浮来源（owner）的有效性。不要用不同 UI 节点的 mouse_exited 无条件重置为 NORMAL，否则指针从一个按钮进入相邻按钮或被 Tooltip 遮挡时会闪烁。

可以为每个 UI 控件建立统一 CursorHint/元数据，提供 interactive_enabled / draggable_enabled / explicitly_disabled；地图节点从现有业务状态读取，无需逐个在关卡里硬编码。
6. Godot 4 接入建议
6.1 使用原生硬件光标，不用每帧 Sprite
根据官方 API：
# 演示 Godot 4 API 用法；实际 texture 和热点从素材目录/配置加载
Input.set_custom_mouse_cursor(normal_texture, Input.CURSOR_ARROW, Vector2(10, 3))
Input.set_custom_mouse_cursor(interact_texture, Input.CURSOR_POINTING_HAND, Vector2(10, 3))
Input.set_custom_mouse_cursor(hand_open_texture, Input.CURSOR_CAN_DROP, Vector2(20, 21))
Input.set_custom_mouse_cursor(hand_closed_texture, Input.CURSOR_DRAG, Vector2(20, 21))
Input.set_custom_mouse_cursor(forbidden_texture, Input.CURSOR_FORBIDDEN, Vector2(8, 3))
注意：上例只是预先注册图片，不能单凭这些调用自动满足全部优先级。 Godot 的 Control.mouse_default_cursor_shape 会请求指定形态；若游戏采用统一状态管理，状态切换时应把当前选定的图片同步注册到相关 CursorShape（尤其 CURSOR_ARROW、`CURSOR_POINTING_HAND`、`CURSOR_DRAG`、`CURSOR_CAN_DROP`、`CURSOR_FORBIDDEN`、`CURSOR_MOVE`），让某个 Control 的默认形态不会覆盖当前拖拽／禁止状态；仅在状态实际变化时执行，不要每帧重设。

CURSOR_IBEAM 不参与普通五态映射，保留可编辑文本框的原生文本光标。已有特殊系统光标（例如窗口缩放箭头）同样应按其原用途保留，不强制用五态替代。

屏幕外由操作系统接管光标显示。正常运行时保持 Input.MOUSE_MODE_VISIBLE；已有战斗镜头锁定等特殊鼠标模式需由现有系统优先管理，解除后重获五态状态。
6.2 资源和热点
建议项目中的实际路径（按已有目录规范调整）：
res://assets/ui/cursors/
  40px/
    01_normal.png
    02_interact.png
    03_drag_ready.png
    04_dragging.png
    05_forbidden.png
  56px/
    (同名五张)
  cursor_hotspots.json
- 默认启用 40×40 资源；为高 DPI 或用户设置中的「较大鼠标」提供 56×56 资源；不同分辨率下请以实机可读性为准。
- 五图均为 RGBA 透明 PNG；不要把整个精灵图直接作为鼠标图片。
- 普通箭头、交互箭头、禁用箭头：热点位于左上方实际箭头尖端。
- 张开的手、握拳：热点位于手掌内部的抓取位置，两者保持相同相对位置，防止拖动时视觉跳动。
- 本包 cursor_hotspots.json 已给出按素材计算的初始热点坐标。必须在地图蓝色小节点、阵盘小格与按钮边缘实机核对；发现像素偏差时只修正热点，不移动鼠标的实际坐标。
- PNG 含透明边距，使用时不要添加新光晕、阴影、漂浮粒子，不改变五图的整体造型。
- 对 Godot 4 平台，单张自定义光标不应超过 256×256，官方推荐不超过 128×128；本包 40/56 两档均在建议范围。Web 平台另有更严格的限制。
6.3 设置项
在游戏设置 → 其他（或现有偏好区）加入：
- 鼠标指针：`仙侠指针`（默认）／`系统指针`。
- 指针大小：`标准`（40×40）／`较大`（56×56）。只在仙侠指针启用时有意义。
若目前不希望扩展设置界面，可先只实现仙侠指针，并把设置开关作为独立可选步骤；但应保留关闭接口。

切回系统指针时，对全部已覆盖的 CursorShape 使用 Input.set_custom_mouse_cursor(null, shape) 还原，不得留下原纹理。切回仙侠指针后重建注册并重新判断当前 hover；保持原有输入模式。
7. 在《苍澜界》已有系统的接入点
既有系统	Codex 接入操作	禁止改动
叠翠峰等区域地图	可交互节点、普通空地、地图平移分开标识	原路线、节点数量、行走/转场逻辑
NPC、宝箱、采药、矿点、休息点	从现有可用/禁用判断输出交互／禁止状态	任务条件、采集条件
储物袋／家中仓储	鼠标悬浮可拖物品显示张开的手，正在拖动显示握拳	数量、存取、交换、放置规则
战斗阵盘	可移动物品的 hover、drag、invalid drop 状态接入	阵盘格数、CD、转轮、释放计算
功法界面、任务列表、公告板	可点击标签按钮显示交互；明确不可用选项显示禁止	学习门槛和任务状态
战斗记录和战斗复盘	可点击按钮为交互，纯信息卡片不改变鼠标；悬浮统计不遮挡底层	复盘数据和 Tooltip 内容
模态窗口与关闭按钮	弹窗层级覆盖地图；关闭后刷新底层状态	现有关闭快捷键与输入路由


8. 关键异常与回退规则
- 拖动中鼠标离开游戏窗口：按现有机制保留/取消拖动，窗口重新获得焦点时重新计算当前状态，禁止悬浮状态卡住。
- 拖动来源被删除、背包关闭、区域切换、窗口失焦、Esc 取消：立即清空 drag_owner 与放置合法性标志。
- UI 切换时如果一个目标被销毁，清理其悬浮登记；不要依赖可能不会触发的 mouse_exited。
- Tooltip 和纯展示装饰 Control.mouse_filter = MOUSE_FILTER_IGNORE，确保不会抢走底下目标的悬浮。
- 鼠标离开已禁用按钮到空白处：应立即恢复 NORMAL，不残留红色禁止标记。
- 当前场景不能拖动地图时，不显示张开的手，避免误导。
- 用户在设置中切回系统光标后，任何场景都不能再次偷偷调用自定义光标接口。
9. 验收测试（Codex 必须执行并报告）
- [ ] 正常地图空白处是普通青玉箭头，没有拖尾、光点或重影。
- [ ] 蓝色可走节点／NPC／可采集点悬浮时变亮的交互箭头，鼠标点击仍正确。
- [ ] 不可交互的普通景观仍为普通箭头，不显示禁止。
- [ ] 明确不可用按钮显示带红禁止标记的箭头，点击不会错误触发。
- [ ] 悬浮在可拖动物品上变张开的手，未超过拖动阈值仍允许原有单击行为。
- [ ] 真正开始拖动后变握拳，移动顺滑，拖放位置与实际鼠标一致。
- [ ] 拖动到明确非法落点显示禁止；回到合法位置立即恢复握拳。
- [ ] 拖动释放后，立刻恢复当前指针下方应显示的状态，而不是一律 NORMAL。
- [ ] ESC、弹窗切换、场景切换或目标删除时无卡住的握拳鼠标。
- [ ] 进入/退出模态弹窗后不误显示被遮挡的地图节点交互光标。
- [ ] Tooltips、复盘叠层、图标装饰不会导致光标异常闪烁。
- [ ] 40px 与 56px 的箭头热点都准确指向蓝色小地图节点；手的热点对齐拖动物体。
- [ ] 在明亮草地、深色树林、青蓝 UI 上仍有足够边缘对比。
- [ ] 系统指针切换后五态自定义图片全部还原；重新启用能即时生效。
- [ ] 不改写任何地图逻辑、任务条件、阵盘计算和拖拽业务规则。
10. 交付内容与执行报告
Codex 在项目中完成实现后，应报告：
1. 实际找到并复用的现有脚本、场景和输入事件入口；
2. 新建/修改的文件列表；
3. CursorManager 的状态映射与优先级实现；
4. 设置项是否已接入及保存方式；
5. 地图节点、按钮、储物袋、阵盘各自的验证结果；
6. 不能完整实现的部分和原因，不要声称未经测试的功能已经通过。
官方 API 参考
- https://docs.godotengine.org/en/stable/tutorials/inputs/custom_mouse_cursor.html
- https://docs.godotengine.org/en/stable/classes/class_input.html
- https://docs.godotengine.org/en/stable/classes/class_control.html
可直接粘贴给 Codex 的任务
阅读《苍澜界_鼠标指针使用规则_Codex实施规格_v1.md》及同目录的五态鼠标 PNG / 热点 JSON，根据当前 Godot 项目真实结构实施专用鼠标。先分析现有 UI、地图、阵盘和储物袋的鼠标入口，再建统一 CursorManager，只负责五态视觉切换，不改已有交互。完成每种状态的场景映射、拖拽优先级和 UI 遮挡规则；使用 Godot 自定义硬件鼠标 API 而非逐帧跟随 Sprite；支持正确热点和系统光标回退。按验收清单逐项检查并输出修改文件、验证结果、存在限制。