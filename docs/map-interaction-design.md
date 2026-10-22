# 地图节点互动与桥头对话（2026-09-15）

## 事件图片与对话新框（2026-10-22更新）

河湾两段剧情共用map-event-chatframe.webp，对话内容按新头像窗口、姓名牌和正文区域排版；主角名读当前MapPlayerStatus.display_name，外门弟子显示“青岚宗弟子”。主角头像继续读当前境界，NPC头像不变。右侧提示三角使用map-event-chatframe-next.webp，作为原整框点击推进的装饰，不额外引入点击逻辑；参考图的回顾／自动／跳过功能未新增。

受伤弟子的事件图框换map-event-picframe.webp，插画保持map-event-1-1.webp；2026-10-22新图框体在源画布内下移14px，取图区域同步改为[101,17,1471,907]，裁切尺寸不变，保证游戏中框体布局位置与大小不变且底角完整。内嵌窗口相对裁切微调为[62,91,1349,758]，等比覆盖并裁切溢出，边缘少量压入金线下避免漏缝。聊天框有效裁切[27,126,2113,437]，头像按椭圆窗口覆盖，姓名按楷体可用宽度适配。三张新图开启mipmap。图片框和聊天框共用屏幕水平中心；布局计算完成后两者一起下移20设计px（1080p为20、2K约26.67），不以位移反算图片尺寸。纯插画阶段隐藏姓名／三角／正文，桥头无插画时只显示聊天框。字段与来源保留于两个事件JSON，实测入口tests/event_dialogue_frames_preview.gd。本条覆盖下方旧map-dialogue／map-event-frame及旧内容坐标说明。

## 剧情领取小号底图（2026-10-21）

剧情“获得物品”领取框单独使用UI-jiaohu-size-s.webp，按有效可见区域等比缩放，与UI-jiaohu-size-m同为363设计px高（2K为484px）。MapScreen对reward_dialog调用use_small_reward_art；原540设计画布内的物品卡、标题、按钮沿用，整体显示乘363/540，标题按新分割线居中。新图开启mipmap，领取与音效逻辑不变。战利品／采集结果继承框未启用此替换，仍保留size1及原尺寸。此条覆盖下方剧情领取框的旧size1／540px显示说明，不改变其他弹窗。静态渲染入口为tests/story_reward_small_art_preview.gd，不包含鼠标或领取行为测试。

## 恢复弹窗素材命名统一（2026-10-21）

当前三个恢复地点按下表加载，覆盖下方历史路径；仅文件名与引用变更，原图内容、UID、mipmap、裁切、文案与休息规则保持。

| 地点 | 弹窗底图 | 内部场景图 |
|---|---|---|
| 林间篝火 | `tanchuang-huifu-linjiangouhuo1.webp` | `tanchuang-huifu-linjiangouhuo2.webp` |
| 山道歇舍 | `tanchuang-huifu-shandaoxieshe1.webp` | `tanchuang-huifu-shandaoxieshe2.webp` |
| 自己家 | `tanchuang-qingshizhen-shineizijia1.webp` | `tanchuang-qingshizhen-shineizijia2.webp` |

## 店铺人物插画命名统一（2026-10-21）

当前六处店铺人物插画统一为 `tanchuang-qingshizhen-{地点}-boss.webp`，地点分别为liandanfang、shangpu、tiejiangpu、yaocaipu、yiguan、zongmenshangpu；仅去掉旧前缀中的jiaoyi，保留当前在用图像字节、UID及mipmap设置。六份事件配置、钱万顺对话头像和相关测试引用同步迁移；客栈原命名已符合规则，无需修改。医馆目标名称原有的停用旧图已清理，现同名文件是迁移后的当前在用插画。此条覆盖下方历史插画路径及旧图保留说明，背景、裁切、位置、对白与交易规则保持。

## 修炼节点累计提升显示规则（2026-10-19，已确认待实现）

所有修炼节点阶段2的两条进度行右端，改为本次累计获得的人物修为／对应功法修炼度，例“＋18.3”“＋42.6”，不再使用百分比。功法按本书分别计数、书名明确归属，多本不能求和后显示为一本的进度；跨层／跨重不清本次累计。进度条仍显示目标完成比例。

后台修炼数值以两位小数记账，界面四舍五入到一位；尚无收益显示＋0.0，未选功法显示—。每修炼日实际运行阵盘60模拟秒，持续结算体灵消耗／恢复，暂停冻结，跨日保留CD与余额。凡人引气成功率100%。完整规则与候选参数见核心01第1.74及[第四版策划](cultivation-growth-proposal-2026-10-19.md)。

本条是最新确认的目标，并非运行完成记录。当前MapCultivationSession仍只有会话／显示接口，MapCultivationProgressDialog仍读比例；本轮未启用未定产出表或虚构收益。正式接入须以实际事件累计增量替换百分比，不直接用修炼天数乘估算值。

## 重进地图时恢复路牌状态（2026-10-17）

初始化先无动画同步存档中的日历／节点期限，再统一隐藏已完成路牌，在首个可绘制帧之前完成。初始化不能把历史完成状态当成新完成事件播放0.3秒淡出；立即隐藏操作可以收尾已经开始的淡出。运行中完成事件仍沿用0.3秒淡出，路径圆点和路线不变；遭遇击败后20天、宝箱领取后40天恢复路牌，按当前轮次领取记录判断，含第二轮及后续宝箱。上述持久化冷却覆盖下方早期“重启恢复怪物”的历史说明；采集的重启恢复测试规则保持。

针对性验证：tests/map_sign_restore_tests.gd使用隔离存档，清空会话标记模拟新进程，检查首帧之前和连续启动帧、同进程重进、11遭遇／5宝箱、冷却到期与过期存档、正常可用节点、淡出及立即隐藏；headless和OpenGL各148项通过。tests/map_sign_motion_tests.gd明确预先探索全部节点用于动画检查，766项通过。

## 瀑下静台修炼第二阶段：界面与进度接口（2026-10-15）

### 新版底图适配：信息框下移／按钮文字居中（2026-10-15最新）

同日最新用户微调覆盖下文初版文字位置：状态说明整体上移5源图px，最终(850,189,562,79)，实际底图边界仍194～273，使用STATUS_DESCRIPTION_OFFSET_Y=-5作视觉偏移。底部三个主标题各右移6源图px，最终(844,708,197,41)、(1048,708,197,41)、(1252,708,197,41)，中心相对按钮右偏共11px；暂停／继续共用该位置。其余图标、细框、按钮命中、字体及底部小字不动。必要静态Render53项通过，未改交互。

用户已替换puxiajingtai2底图，原图仍1536×901，外框／按钮总体大小不变。修炼信息外框顶边从y260下移到y273（+13），其标题区y242→255、三图标随底图下移，三个内框已从新底图删除。现以独立透明Panel补回三个1px灰色细框（#899296），不覆盖原图标；位置为(863,306,175,61)、(1047,306,175,61)、(1231,306,176,61)，保持下方历史基准的尺寸／水平间距与相对偏移。三段文字区域y298→311，x／宽／高／字体不变。三框由INFO_FRAME_RECTS集中管理，不依赖旧图快照运行。

单行状态说明区域变为(850,194,562,79)，按标题横线y194和新版信息框上边y273重新居中（中心233.5），文字／楷体21／左对齐保留。底图内按钮小图标已由用户缩小，本轮不再缩放／重画原图。三项主文字区域分别为(838,708,197,41)、(1042,708,197,41)、(1246,708,197,41)，共同使用楷体25、水平／垂直居中，文字中心仅比按钮中心右偏5源图px用于避让左侧小图标，较旧版明显向左靠中，y710→708对齐新图标中心。底部小字、按钮命中区域、交互／暂停逻辑不变。

本轮重新导入该底图，mipmap保留；只运行cultivation_stage_two_tests -Render，53项静态检查通过，查看2K空态面板，无重叠或截字；未跑鼠标／玩法／完整回归。下方是换图前的保留基准，不是当前绝对y位置。

### 换图前历史：修炼信息三框定位基准（2026-10-15）

用户即将更换阶段2底图，要求保留三个内部小框的相对设置。当前三框及山峰／太极／沙漏图标均烘焙在底图中，并非独立代码边框；本轮未移动三框／其文字。原图1536×901，可见弹窗区(32,32,1474,840)，所有下列坐标为原图坐标，不是屏幕px。当前底图已复制至不入Git的`artifacts/cultivation-phase2-layout-baseline-20261015.webp`供下一次替换时对照；坐标记录为持久依据。

修炼信息外框上边约y260、左边约x845，三框共用上沿y293、底沿y354，中心线约y323.5；小框边线约1源图px，颜色／内底仍由原图决定。三个小框可见尺寸约175×61（末框约176宽），左右净隙约9～10px、中心间距184px。外框左上角作为相对基准时，小框位置约如下：

| 内容 | 小框原图区域（约x,y,w,h） | 相对外框左上角（约x,y） | 当前叠加文字区域（精确x,y,w,h） |
| --- | --- | --- | --- |
| 地点 | 863,293,175,61 | 18,33 | 912,298,122,50 |
| 方式 | 1047,293,175,61 | 202,33 | 1100,298,119,50 |
| 时长 | 1231,293,176,61 | 386,33 | 1284,298,120,50 |

三段文字水平／垂直居中，楷体21源图字号、沿用INK颜色；图标仍在各框左侧，不把文字居中点误改成整框中心。整体缩放为min(视口宽/1920,视口高/1080)×0.9，当前2K为1.2，故重排要使用上述源图坐标。

状态说明本轮合并为一行“凝神静坐，调息凝气。暂离尘嚣，专注眼前的修行。”，左对齐与楷体21不变；区域从(850,198,562,46)改为(850,194,562,66)，在标题分割线y194与信息外框上边y260间垂直居中，中心y227。代码`STATUS_DESCRIPTION_BAND`集中记录这两条边。**换新底图后须重新量这两条边并微调状态说明的垂直位置；当前坐标不是对新版底图的锁死值。**若新图去掉三内部框，以上基准可用于恢复独立边框，但本轮不提前叠画，避免双框。

N32阶段1的进入按钮现打开MapCultivationProgressDialog，不再提示待接入；方式ID不变，balanced显示名改“兼修并进”。使用tanchuang-qingshizhen-xiulian-puxiajingtai2及场景-2，两图开启mipmap，源素材未改。背景可见区仍为(32,32,1474,840)，整体按min(视口宽/1920,视口高/1080)×0.9缩放；左侧huifu-picframe仍693×694、中心(460,451)、内缩4并等比覆盖裁切，和阶段1一致。

修炼中标题／结束入口沿现有黑体与楷体；状态描述位于标题分割线下，最新单行居中区域见上节。修炼信息／修炼进度标题用HarmonyOS Sans SC Regular 400。信息三格只写地名、方式名、持续XX天，无“地点／方式／时间：”前缀，读取阶段1实际选择。天数条绿色，修为黄色，功法蓝色；三个CultivationProgressBar原生控件在源图x1050、宽284高17，y470／534／617，填充两端颜色固定并随已填宽度拉伸、由深至浅。修为为首行数值、次行进度条及比例、第三行状态，当前首行刻意留空且比例“—”；功法首行未选择功法、比例“—”，不伪造正式成长值。

左图中心槽(404,400.5,112,112)为金色虚线／大加号，点击打开MapTechniqueChoiceDialog，复用UI-jiaohu-size-m与菜品选择排版，标题功法选择、最多五列居中滚动，按钮沿菜品选择当前下移14px的位置。正式列表为空时显示“当前没有功法可选”，确定禁用并压暗；取消／Esc／右键只关闭选书层。未来由set_available_techniques提供标准物品卡记录，choose_technique选中后把图标／名称／progress_current与progress_target送入场景槽及功法行；不自动装入旧测试书、不将场景画里的基础吐纳法当成道具。

MapCultivationSession是无场景树／无墙钟的会话模型：begin记下游戏日；MapScreen._sync_calendar通过已有日期更新信号调用sync_calendar，累计正向日期差、重复日／倒退不重复计，天数封顶所选时长。set_paused、suspend(inventory／choice)期间不计天数，返回保留原手动暂停状态。两栏各四条文案放事件stage_two配置，以已修炼游戏日整除5循环；未选对应方式、没选功法、暂停、时段已满分别显示真实状态。set_cultivation_progress(current,target,caption)只接受有限非负current及正target，比例限制0～1。

底部阵盘调整打开真实储物袋，修炼页隐藏、会话暂挂，关闭后回到修炼页；不误返回大地图，嵌套阵盘确认优先处理。暂停修炼／继续修炼切换状态；结束修炼（含右上、Esc／右键）结束本会话、恢复地图操作、节点仍可重入。按钮沿全局click.ogg。结束仅结束界面会话，未结算未来修炼收益。

**边界：**用户确认按游戏日期计时，本轮只接读日历／进度接口；既有日期靠耗时行为推进，停留本弹窗不会自动流逝。本轮未添加任何现实秒→游戏日换算、修炼推进日期动作、实际修为／功法收益或会话存档。已有功法资格／多书并修规则不因当前单槽UI改变。正式数值、目录和日期推进方式待后续，不借此扩展T03。

必要专项tests/cultivation_stage_two_tests.gd：headless55项、Render32项通过；阶段1接续检查headless108项／Render113项通过。仅测试注入6/15天、修为50/100、测试功法42/100检查比例与渐变，不进入正式页面／真实存档。Render只静态渲染，鼠标链路仅在本次确有交互变化的headless检查中执行。截图与对照详见design-qa及最新进度，下文阶段1旧“待接入”状态已被本节覆盖。

## 瀑下静台修炼第一阶段（2026-10-15）

青石河湾N32（原西瀑下支路）正式命名瀑下静台，稳定节点ID／路线不变；新事件base.map_event.qingshihewan.cultivation_n32到达自动打开、站定可点击重开。配置位于data/map_events/qingshihewan_cultivation_n32.json，事件类型cultivation；MapEventRegistry在加载时校验三种方式、三档时长、默认项、图片与必需文案，不借用休息恢复／对话完成流程。

MapCultivationDialog第一阶段：底图tanchuang-qingshizhen-xiulian-puxiajingtai，左侧-1场景及huifu-picframe的尺寸、中心、裁切与林间篝火一致，整体90%。地名同休息弹窗；描述从参考图取文，置于标题分割线下(850,200,562,70)、左对齐并垂直居中（2026-10-15最新调整）；右上稍后再说，整块背景含箭头均可点击离开，另支持右键／Esc。

方式三栏按底图预留位置，用水蓝实线框／金色选中框取代细虚框，分别专注修为／专注功法／兼修；图片UI-xiulian-zzxw／zzgf／jx的1、2号随选中切换，独立互斥。时间三档5／10／15天使用同款状态容器；默认专注修为／10天，按参考图。8张实际使用图均开启mipmap，-2阶段场景尚未引用。底部进入修炼状态使用baoxiang-dakai1白字／dakai2黑字、楷体居中，按钮点击沿用全局click.ogg。

同日后续：底图刷新，进入按钮／文字源图矩形改(984,700,300,96)，中线y748对齐飞云线。六个选择框所有状态边宽1px，选中5px柔光不改。六张方式图按可见本体高84源图px、中心y379等比布局，以原选中专注修为为基准；复用MapTextureMetrics的0.02透明度边界忽略导出杂点，仅用于尺寸定位、不裁改原图。修炼方式与修炼时间两标题改HarmonyOS Sans SC Regular（400），原26号／颜色／区域保持。

同日最新方式图切换修正：zzxw蓝黄两态共用当前蓝图中心y378、可见高84；zzgf蓝黄两态共用中心y380，等比缩小5%后可见高79.8。覆盖此前仅蓝图偏移的实现，避免选中后返回y379造成跳动；方式图使用浮点位置／尺寸与已等比计算的直接绘制，消除透明边距不同导致的独立取整误差。兼修两态仍84高／中心y379，其他控件取整不变。

阶段1初版仅选择UI，曾由cultivation_requested(mode_id,duration_days)提示“第二阶段尚未开放，本次未消耗时间。”；该提示已由上节阶段2入口替代。当前仍不自行推进日历、不扣资源、不改修为／功法／住宿加成、不写真实存档、不标记事件完成。专项tests/cultivation_stage_one_tests.gd已更新为验证进入阶段2；headless仅相关输入／状态／无副作用，-Render仅布局及三张2K预览，详见最新PROJECT_PROGRESS。

## 林间篝火进食／清石客栈菜品（2026-10-15）

同日食品效果后续（按用户方向更正）：选中食品图相对原位向右10px（x879），效果第二行向右5px（x960），上行标题保持x955。第二行通过MapFood.meal_summary显示所有真实额外恢复与辅助效果，采用“进食效果：额外恢复 气血+…%、体力+…%，额外增加 命中／闪避+2%”，无辅助时省略后半段；400源图px范围内文字按宽度适配，单行避开箭头。食品悬浮及商品效果中辅助加成显示+2%，不改内部百分点计算与持续时间；闪避复用命中浅青色。提示两行整体依实际行高调整，使首行中线对齐底图感叹号中心y703。

同日菜品选择按钮微调：确定／取消在原基础上再下移8设计px，累计相对通用弹窗下移14px；内部文字随按钮，卡片及滚动区域保持不变。覆盖下方初版下移6px的位置说明，不改通用离开弹窗。

同日休息排版最新：选菜版林间篝火与山道歇舍统一使用描述区域(850,199,562,123)，含5源图px字形补偿，以标题横线与室内／外休息点可见文字之间的视觉中心为准；两页“耗时”标题均y503，数值／单位不动；休息按钮及文字共用(1142,699,270,91)，即篝火在上次y694基础上再下移5px，山舍同步最终位置。尺寸、自己家及休息机制不变，覆盖下述旧按钮位置。

青石河湾N05林间篝火换用tanchuang-qingshizhen-xiuxi-linjiangouhuo，原左景框及90%整体尺寸不变；恢复框文案上移30源图px、室外休息点居中新横线。2026-10-15后续：底部改左右结构，左侧提示“状态不满也可以休息，\n但恢复不会超过各上限值。”固定从“但”换行，源图区域(902,687,236,74)；右侧休息按钮上移到(1142,684,270,91)。N13山道歇舍换用tanchuang-qingshizhen-xiuxi-shandaoxieshe，复用相同恢复框／选菜／底部布局，保留室内描述、50%恢复及1天；两个事件均allow_food=true。新版底图已有离开箭头，不再叠画旧箭头。自己家／客栈住宿不自动增加进食入口。

新增MapFoodChoiceDialog复用UI-jiaohu-size-m，标题菜品选择、确认／取消按钮下移6设计px；仅列随身储物袋实际食品，一行至多5张，不足一行居中，超过5张滚动；物品卡轻亮悬浮与现有完整物品说明共用。选中并确定只更新预览，不耗菜品；取消／Esc／右键仅退回休息弹窗。确认休息才消耗1份，整次休息失败或保存失败不消耗、不恢复、不推进日期。未选食品仍沿原30%三资源恢复、1天。

[九种食品](../data/maps/foods.json)为独立稳定base.food.*记录，大类food／食物，细类酒水、主食、菜品、热汤；使用UI-caipu九图并开启mipmap，下品、不自动赠送、不能放阵盘，占格提示隐藏，随身及仓储继续按同类堆叠。恢复／辅助数值按用户本次截图落实，商品介绍暂用简短说明；完整数值由同一food配置生成物品悬浮及商店效果文本。

清石客栈吃食页接[专属目录](../data/shops/qingshizhen_inn.json)，四个分类按酒水／主食／菜品／热汤排列，无全部。MapInnFoodView复用MapShopDialog的商品框、详情、数量及购买结算，保留客栈自己的背景、场景与三大页签。售价2／3／3／7／9／4／5／5／9为最终买价，以fixed_buy_price显式标注，不再乘普通商店150%；其他店定价与出售不变，本次未指定食品回售价。购买后入袋、灵石与库存一次持久保存；容量仍遵守测试期允许超额规则。

MapFood负责校验、食品恢复预览和辅助效果解析，MapTimeActions先推进候选日历、消耗具体随身单位并记录food_bonus，再保存并发布三资源；按状态上限增加表内额外百分比且封顶。用户明确清神命中+2个百分点、轻身闪避+2个百分点从休息结束后起算1游戏日，日期不推进不扣时间，次日到期，随存档保存；每次休息1天，故上次食品辅助已到期，不累叠。战斗入口传入已解析的accuracy／evasion比例，CultivationCombat原命中流水线计算并限制0～1，不让模拟依赖日历、UI或现实时间。食品恢复本身继续既有地图资源运行期生命周期，未扩展完整角色资源磁盘存档。

必要专项tests/food_rest_tests.gd：默认校验九品数值／买价、消费／封顶／存档与失败、实际战斗命中计算、购买与选菜输入；-Render仅静态预览客栈／篝火／选择框，不跑鼠标。均隔离存档，具体结果见最新进度。覆盖下方“吃食空页”历史；人物对话及住宿不改。

## 清石客栈／佟晚棠对话接入（2026-10-14）

N13的qingshizhen_inn事件新增dialogue指向data/dialogues/tongwantang.json，NPC ID为base.npc.tongwantang。19段207条基础台词、5个条件分支、6日常及6一次欢迎；人物与两稿取舍见[佟晚棠设计](tongwantang-dialogue-design.md)，本轮不把人物记录写入核心01。标题清石客栈／城镇青石镇，用户已确认保留现行两房型恢复100%及修为收益加成；此次未改lodging／presentation或结算，吃食保持空页。

MapInnDialog已经继承MapClinicDialog，map_screen已有visit／select／advance及继续输入路由，本轮直接绑定数据，不增加共享引擎分支。欢迎末句后点击开启，三话题独立推进；切页保持状态，再入店重新欢迎。普通chat按90日2段，news的隐私段独立90日1段，事件不借日期解锁；保存仍经NpcDialogueActions候选事务，仅保存成功发布，人物进度独立，无需重置既有六人日志。

钱掌柜救援须rescue_completed与tongwantang.qian_told_rescue；河湾情境欢迎须真实遇险及辰宇告知；road_news_ready须主线允许且佟亲见旅客行为。回镇两欢迎分别处理已知／未知入宗，未知时辰宇先告知，完成后set_facts记录knows_joined／return_greeted防止两版连续重播；“回来办事”还需town_business_ready。全部完整事实名及未来写入责任见人物设计；这些主线接口当前尚未由正式剧情落地，不从测试修为、赠玉或单次击杀推断。

news.01依玩家是否实际认识谢云舒、是否同门和她的后期阶段选择固定分支；听到名字不设置xieyunshu.name_known。后续行路变化发生后新读news.02使用旧闻回顾，不强迫补听假装当前的消息；已开始分支保持原文。来源模板／溪水调查不注册。专项tests/tongwantang_dialogue_tests.gd含模型、N13点击开启／切页和隔离存档，Render只静态预览；inn_tabs_tests旧空对话断言已同步，具体结果见最新进度。

## 客栈客房标签视觉补充（2026-10-14）

两房型标签默认都显示金色细边框，悬浮不改变字体或边框样式；选中态使用交互大类同款金色填充、亮边及柔光。右侧房型标题改为Rect2(1049,323.5,344,40)，与左侧标签Rect2(644,326,348,35)共用源图中心线y343.5。仅视觉调整；必要静态预览入口tests/inn_room_style_preview.gd，检查两房型并生成inn-room-style-0／1.png，不执行鼠标或住宿事务。

## 客栈住宿正式接入（2026-10-14）

覆盖下方住宿空页状态：N13“清石客栈”住宿页由MapInnLodgingView展示，数据在qingshizhen_inn.lodging。普通／高级客房左框顶部选择，内图Rect2(651,378,336,265)等比覆盖并clip，边框保持可见。右中框显示全状态恢复及图标后的1天／20或50灵石；其下是+10%／10天或+20%／15天，dakai1白字／dakai2黑字按钮。共用医馆字体／标题结构，参考图地点文案原样接入；未按示例180定价，未开放吃食或人物正文。

MapInnLodging.stay执行候选扣费、advance_days(1)、替换lodging_bonus、save后发布，再恢复气血／体力／灵力；已满也可住，资金不足／保存失败不生效。新住宿完全覆盖旧加成（高级转普通也降为10%），期限从住宿后次日起计，采用游戏日而非现实时间。MapLoadoutState持久保存四字段source_id／percent／start_day／expires_day，旧档默认{}、非法记录拒绝、加载整数归一化；有效区间start_day≤当前日<expires_day。到期getter返回0，不依赖每帧轮询。

地图_sync_calendar同步MapPlayerStatus收益率；储物袋侧栏读取实际百分比。战斗胜利在掉落成功持久结算后从durable_loadout取有效加成，只增修为、不增历练或物品，重复结算不重复发放。修为现为一位小数，cultivation_gain提供同口径计算入口，未来正式修炼再调用；未扩展功法书经验、离线收益或完整角色进度存档。三资源／实际修为仍沿既有运行期生命周期，加成与日历／币已经存档。

必要专项inn_lodging_tests（-Render两档与左栏）、inn_battle_bonus_tests（实际战斗结算），最终结果见最新进度。无真实存档操作。

## 客栈三页框架（2026-10-14）

青石镇N13原酒馆由用户确认改为客栈，节点／路线／原路牌图案不动。data/map_events/qingshizhen_inn.json使用独立inn类型，click触发；MapInnDialog继承现有MapClinicDialog的场景框／对话画布，隐藏医馆诊治控件，提供交谈／吃食／住宿三页。presentation.background、food_background、lodging_background分别引用tanchuang-qingshizhen-kezhan1／2／3；illustration用kezhan-boss，conversation_portrait预绑定ui-portrait-tongwantang，全部mipmap。共享底图区域Rect2(32,32,1474,840)，页签沿原三框位置，场景不随切页移动。

现默认交谈，尚无dialogue词库；吃食和住宿内容容器为空，底图自带资源条不代表真实状态。标题暂为“客栈”、介绍留空，后续逐页提供内容再接入，不自行填菜单、住宿费用／时间／恢复量或人物台词。未来对话可沿event.dialogue与已有NpcDialogueActions接口接入。离开／右键／Esc关闭且不标记完成，下次可重开；当前所有切页均不改变任何玩法状态。检查入口tests/inn_tabs_tests.gd，Render仅三页静态画面，结果见最新进度。

## 苏清禾场景／头像美术更新（2026-10-14）

医馆事件的illustration更新为tanchuang-jiaoyi-qingshizhen-yiguan-boss.webp，交谈／诊治共用既有场景框与尺寸；聊天头像仍为UI-portrait-suqinghe.webp，重新导入用户更新图，两素材mipmap开启。旧场景文件保留，人物正文与诊疗不变。必要静态检查tests/clinic_art_refresh_preview.gd -Render，结果见最新进度。

## 苏清禾成长定位与出发分支（2026-10-14）

原story.depart增加medical_path固定分支15句，门槛仍为base.story.qinglan.departure_ready，主角joined后退休；该事实仍待正式主线写入，不由测试境界或90日日期触发。初次阅读由现有_reveal选中并保存；旧已读／中断无variant记录的继续取原11句base，全部其他base和旧variants保持。无句数迁移、无新增回访轨道，content_revision仍3，不改共用引擎或真实存档。

用户最终时序为清禾炼气篇中段入宗、后段医药任务正式同行；前段决定及宗门重逢正文保存在[人物设计](suqinghe-dialogue-design.md)，未注册到医馆三话题。未来正式章节须先实现人物实际在场、代诊与轮诊交接，区分医馆营业／清禾本人／随队辅助；不能仅设置入宗标记就让医馆与远行队伍同时出现她。正文完成也不授予新队友、技能、恋爱或服务。

直接验证tests/suqinghe_positioning_tests.gd：相关原纯模型、旧出发11个读数、新分支中断存取／失败保存／过时段、静态换行与实际启动；Render只输出两张静态2K预览，不注入鼠标操作。结果见[最新进度](../PROJECT_PROGRESS.md)。

## 六人关系补充与新回访计时（2026-10-14）

已按用户授权接入五段：清禾medical后续两段作为90日一批、chat末尾两段；云舒chat末尾一段，末批不足两段只开放剩余正文。叶伯与清禾chat改90日2段，已开放旧段保留，读完现有批次后再计下一周期。其他四人节奏与所有交易保持，医馆说明已适配两行。

清禾与陆的合作、清禾与云舒相熟采用附件提供的既有生活背景，不由玩家替她们建立关系；跨NPC已读只影响辰宇接话，不作为关系发生开关。行商图明确现在为熟悉地点草稿，完整路线留将来。替换正文以新固定variant接入，原base lines供既有已读／中断记录使用；不改旧ID或将未读伪装成历史。

清禾content_revision=3，仅新增医馆回访计时需要迁移：topic.revisit_added_revision=3，在旧版本该初始话题已读完且没有回访计时的情况下，从首次更新访问日志的游戏日开始90日；原chat计时保持。旧1→2句数映射继续先执行，再补3版计时；原v2不会重复映射。NpcDialogueActions、DialogueJournal.visit及MapClinicTreatment都向upgrade_journal传实际日历日，候选仍先存盘再发布。新版本缺失既有计时仍拒绝，不普遍修补损坏存档。

直接专项tests/npc_relations_tests.gd（含更新后的原清禾纯模型与旧版本迁移），Render仅静态新增内容，未增加鼠标操作验证。原npc_dialogue／yesongnian／xieyunshu专项的回访或段数断言已同步；后两整套未追加运行。实际结果与五图核对见[最新进度](../PROJECT_PROGRESS.md)。

## 谢云舒对话与姓氏称呼（2026-10-14）

N01 qingshizhen_sect.dialogue绑定data/dialogues/xieyunshu.json，覆盖下方空交谈状态，沿用三页和ui-portrait-xieyunshu。23段278基础句（含较高阶段回顾）、2正文分支、12欢迎组，复用独立日志、条件／历史、候选保存与欢迎后点击门槛。DialogueJournal.render_text新增{player.surname}，谢云舒“师弟”称呼读取玩家姓氏，兼容复姓及其他已有姓名模板。

原欢迎入宗后retire，once初识补同门自我介绍并记录姓名／入宗知情，不伪造原欢迎完成。调查按说明差事→真实可见对照→已核实且已告知结果分层，正文分支固定；具体材料与结论待正式主线，条件接口见[合并设计](xieyunshu-dialogue-design.md)。普通90日2段／货市独立90日，当前无自动排班或替班商人。专项tests/xieyunshu_dialogue_tests.gd；共享欢迎npc_greeting_tests、三页sect_three_tabs_tests，本轮实际结果见PROJECT_PROGRESS。

## 韩铁山对话与熟悉后状态欢迎（2026-10-14）

N23 qingshizhen_blacksmith.dialogue绑定data/dialogues/hantieshan.json，覆盖下方空交谈状态，沿用四页及ui-portrait-hantieshan专用头像。三话题和欢迎保持base.npc.hantieshan独立日志，现有欢迎后点击门槛／续读／历史／候选保存逻辑不变。DialogueGreetings.arrive在受伤／疲惫资源阈值匹配前检查该欢迎entry的DialogueConditions，支持韩铁山初始闲聊两段完成后才使用低气血问候；无附加条件的旧角色保持原行为。

18段181基础句、4正文分支，5日常＋1状态＋5事件欢迎。军旅旧话题引用、已去王畿／长墙的分支在开始时固定；实际经历和NPC知情分开，重要揭露另需剧情就绪。普通闲聊90日2段、材料后续90日1段。完整字段来源与未实现主线接口见[合并设计](hantieshan-dialogue-design.md)，不重复维护规则。专项tests/hantieshan_dialogue_tests.gd；共享欢迎npc_greeting_tests、页签blacksmith_four_tabs_tests。实际验证范围见PROJECT_PROGRESS，家事与后期收束稿不注册、打造仍预留。

## 宗门铺三页与谢云舒头像（2026-10-14）

qingshizhen_sect事件N01的background=tanchuang-qingshizhen-zongmenpu.webp，conversation_background=tanchuang-qingshizhen-zongmenpu2.webp，conversation_portrait=ui-portrait-xieyunshu.webp，均mipmap。复用三页与默认交谈逻辑，原boss图／框、商品目录与价格不变；没有dialogue时交谈留空，后续接谢云舒词库会沿用已绑定头像。专项tests/sect_three_tabs_tests.gd，Render仅交谈／购买静态预览，结果见最新进度。

## 铁匠铺四页与专用人物头像（2026-10-14）

N23 qingshizhen_blacksmith配置新background=tanchuang-qingshizhen-tiejiangpu，conversation_background／crafting_background=tiejiangpu2；直接复用四页及默认交谈，打造仍空容器、买卖原样。conversation_portrait=ui-portrait-hantieshan是后续词库头像绑定：注册表校验图片，MapClinicDialog载入有效library后应用专用头像并清除portrait_region，无词库时不显示虚构气泡。陆怀真正式词库已直接改ui-portrait-luhuaizhen并移除旧场景区域，其他台词／条件／存档不变。两背景和两头像均mipmap。直接检查tests/blacksmith_four_tabs_tests.gd，Render生成交谈／购买／打造及隔离陆头像气泡预览；结果见进度。

## 陆怀真独立对话与多来源线索（2026-10-14）

N12的qingshizhen_alchemy.dialogue绑定data/dialogues/luhuaizhen.json，复用现有四页与MapClinicDialog；欢迎末句点击开启话题，读档／续读／归档沿用NpcDialogueActions的候选保存发布。头像复用现有liandanfang-boss图的portrait_region=[327,344,252,252]，源图不改。其他NPC日志保持独立。

DialogueConditions增加可选any_of数组：至少一支满足，其他外层条件仍须全部满足，配置逐支校验。陆异常段按叶伯clue／清禾clue／河湾water_observed任一实际来源开放；variants固定已读开场，默认河湾分支只用N37真实信息。普通chat配置90／2，alchemy珍材回访90／1；正式剧情走story，不受时间及旧话题阻挡。入门段retire_flags=正式修炼／入宗，回顾段只在原段未读完时开放，已读句不丢失。无需改存档版本或清档。

知情使用set_facts，不推动story_revision。修士救助单设cultivator_rescued，与钱掌柜使用的rescue_completed分开；正式主线未实现时维持条件入口。完整映射见[陆怀真设计](luhuaizhen-dialogue-design.md)。原炼丹交谈空页现被本次正文替换，购买／出售功能和炼丹空页保留。直接专项luhuaizhen_dialogue_tests、alchemy_four_tabs_tests；共享条件旧行为用qianwanshun_dialogue_tests，实际验证见最新进度。

## 炼丹房四页框架（2026-10-14）

qingshizhen_alchemy的background改tanchuang-qingshizhen-liandanfang.webp，conversation_background与crafting_background都为tanchuang-qingshizhen-liandanfang2.webp，均开启mipmap。同时有交谈底图与crafting_tab时，MapShopDialog从左交谈／购买／出售／生产，生产按钮源图Rect2(1227,233,192,49)，余额源图(1224,194,192,28)避开第四框；其他店仍用既有布局。交谈页也提供ShopCraftTab，生产切换隐藏交谈画布并还原交易画布、使用空页底图／隐藏交易内容；回交谈清理生产模式以允许反复进入。生产底图可选，未配置的铁匠铺不改。现炼丹为预留空页，陆怀真对话尚无配置，后续接正式dialogue即可，不提前生成NPC进度或生产机制。直接专项tests/alchemy_four_tabs_tests.gd，Render仅三页静态预览；验证见最新进度。

## 钱万顺独立日志与条件内容（2026-10-14）

N16事件dialogue指向data/dialogues/qianwanshun.json，复用原MapShopDialog → MapClinicDialog，普通商铺交谈空页现已有正式内容，买卖与底图不改。头像用原商铺人物图的portrait_region=[305,294,215,215]运行时AtlasTexture，不修改或生成素材；NpcDialogueLibrary校验区域边界，其他NPC无区域仍沿原图。

DialogueJournal补可选revisit_interval_days／revisit_batch_size，钱掌柜chat=90／2，其他话题／人物默认1日1段或重要剧情变化。定周期话题不因story_revision提早更新；一批未完不继续解锁，整批完成刷新计时基准，避免晚读后当天再补发。revisits现在也检查各段条件，钱掌柜后两段需救援。retire_flags可停止过时段的未读部分，next_segment与advance／view都过滤，原seen／done／order不重写；welcome_finished同时支持已完成或已过时首次欢迎，救后首次来店不伪造旧欢迎历史。

可选address_rules按实际事实选择称呼，每条正文揭示时存入该NPC addresses[segment_id]，同段后续句可采用新关系、过去句保留当时称呼。候选恢复验证数组与已读句数一致。set_facts只保存对话知情、不推进story_revision，保持主线set_flags语义。调查／引荐和归来均使用JSON条件及固定分支，不另写人物专属业务逻辑。

DialogueGreetings允许npc／player双向台词，once条目可用archive_topic归档已读句、followup在新一次继续操作接下一组一次欢迎，仍先保存候选再发布。钱掌柜姓名补段完成记录knows_name，再接正式道谢；已知姓名则跳过。已完成欢迎不重复，末句沿原点击开启话题。普通欢迎按救前／救后条件筛选，不会随三个月轮换回救前态度。

剧情事实表及未接主线边界见[钱万顺设计](qianwanshun-dialogue-design.md)；未改现有赠玉、战斗结算、价格或奖励。专项qianwanshun_dialogue_tests覆盖三月边界、退休历史、姓名／道谢、首章跳读、保存失败与重载；-Render仅实际页面必要流程及4张2K，结果以最新进度为准。general_shop_conversation_tests和叶伯跨店断言已更新为钱掌柜独立对话。

## 学徒买药／诊治收费条件闲聊（2026-10-14）

两人的JSON在chat.story末尾各追加稳定段ID，叶伯chat.apprentice_price共10句、清禾chat.treatment_fee共11句；各需独立base.story.yesongnian.apprentice_discount_seen／base.story.suqinghe.treatment_used。沿用条件段优先、单次读完归档、中断续读与三话题呈现，不增加第四话题或自动播放；重要主线排在费用闲聊前，原首次／每日闲聊进度保留。

药材铺purchase_discount.dialogue_unlock_flag配置解锁事实。ObservedTooltipPanel仅替换学徒标签的脚本，仍由Godot原生悬浮延时／退出控制，以TooltipLabel主题显示原文；工具提示节点实际可见且所属弹窗可见后才发tooltip_shown，WeakRef及可见／文本校验防止延迟回调误报。MapScreen检查当前商铺状态并调用NpcDialogueActions.record_dialogue_fact，候选保存成功再发布，失败显示错误且下次悬浮重试；成功清除该次失败提示，重复已知事实不写档。

医馆treatment.dialogue_unlock_flag在MapClinicTreatment同一个候选事务内记录，与支付／诊治问候一起保存，保存成功后才恢复气血。预览、满血、余额不足、失败均不记录；没有配置的其他医馆不解锁这段。两处配置提前校验命名空间标记。小事实直接设置narrative.flags而不递增story_revision，避免误作重要剧情而放出额外每日闲聊；原set_story_flags接口语义不变。新增段不改content_revision与原计数映射，旧档缺标记按未触发处理，不从临时欢迎状态追认历史。

直接专项`./tests/run_t01.ps1 -Script res://tests/npc_fee_chat_tests.gd`；本专项`-Render`也验证本次真实悬浮／按钮链路，并输出学徒提示和两人新闲聊三张2K图。结果见最新进度。不扩展货架、免费领药、好感、任务或治疗动作。

## 青石商铺交谈空页与新底图（2026-10-14）

N16事件qingshizhen_shop的presentation.background为tanchuang-qingshizhen-shangpu.webp，conversation_background为tanchuang-qingshizhen-shangpu2.webp，两图均mipmap。MapShopDialog依conversation_background存在开启三页，默认交谈；无需先配dialogue，缺少台词时MapClinicDialog保留空白内容，隐藏继续／话题，不创建NPC日志。页签沿现有624／828／1025源图x坐标，标题、原boss图／场景框、离开和商品详情复用；买卖报价／结算不改。后续钱万顺只需添加正式dialogue配置与内容，复用现有对话入口，当前不虚构台词。其他商铺按原配置，药材铺已有对话照常。直接专项tests/general_shop_conversation_tests.gd，-Render只输出交谈／购买静态2K；结果见进度。

## 药材铺学徒8折与共用余额栏（2026-10-14）

同日后续（优先于下方初版视觉参数）：货架显示正常原价，优惠只在右侧结算展示，实际8折独立整单取整不变。学徒字号18、容器源图Rect2(1308.75,226.725,104.5,27.55)，原中心缩小5%后下移5px；提示首句为“正在叶伯铺中帮忙学药”。余额灵石槽位SIZE_SHRINK_CENTER以对齐右侧数字。五店及药材铺交谈页离开文字共用_style_leave_button，悬浮fffbea、按下e5c985，不加框或缩放；字号／布局不改，医馆不受影响。专项tests/shop_visual_refinement_tests.gd -Render仅静态预览与断言，结果见最新进度。

qingshizhen_herbalist新增purchase_discount：factor_bps=8000、标签／提示文案及四种草药item_ids白名单。配置校验倍率、非空文案、有效且不重复ID；允许未来另行指定丹药ID，不自动扩张经营范围或货架。其他四店不配置此优惠，出售沿用原价。MapShop.buy_quote(item_id,quantity)统一返回original_unit／original_total／unit_price／total／discounted；先读现行正常单价，再以整数基点分别向上取整单件和整单，purchase实际扣款直接用total。buy_unit_price只作为单件显示，禁止再用于折后整单相乘。原6×10打八折实付48，缺价仍拒绝、余额不足／保存失败保持原子性。

共用交易详情单价／总价HBox内添加OriginalPrice与1px横线，优惠时显灰色划线原价、右侧86e79a实际价，和19号学徒标签同色；无优惠、空分类及出售隐藏旧价。商品格显示折后单件价。学徒PanelContainer位于源图(1306,221,110,29)，复用医馆133429底／绿色细边及simple_tooltip.apply，切其他店清空隐藏，交谈页随交易画布隐藏。文案为“曾在叶伯铺中帮忙学药，购入常规药材与常用丹药时，可享八折学徒优惠。”，实际范围以白名单为准。

五店余额统一ShopBalance HBox(1224,260,192,28)，内容依次持有灵石、18×22槽位灵石图（沿用80%面积）、真实数量；楷体19号、字底对齐页签底边，超长余额缩字避开第三页签。必要专项tests/shop_apprentice_discount_tests.gd，无界面只测本次报价／结算／新增标签命中及实际购买，-Render仅学徒十件／普通店余额2K预览。结果见最新进度；原shop_trade_rules_tests／blacksmith_shop_tests旧断言已同步但本次未整套运行。

## 医馆分项费用／紧凑诊疗布局（2026-10-14）

同日视觉后续：医馆说明改ClinicNoteContent VBoxContainer，在原(700,533,650,99)区域内将标题／图标／两行正文作为一组垂直居中，字体不变。费用区所有常驻文字字号减1（标题／实际支付24、标签19、问诊原价／免收／两费用名称21、耗材数字23、总价26）；问诊费与药材及耗材均楷体。灵石图宽高乘0.9、原中心保持；题句改居中，与确认按钮中心x1230对齐，按钮宽高300×92→285×87.4，以原中心缩小5%，内部29号文字不缩小且继续水平／垂直居中。收费、状态提示与简易悬浮内容不变。

qingshizhen_clinic.treatment由单一fee改为consultation_hp_per_stone=20、supplies_fee=5、waive_consultation=true；MapClinicTreatment.preview统一返回consultation_fee=ceil((气血上限−当前气血)/20)、waived_fee、supplies_fee和fee=问诊费−免收费＋耗材费。苏清禾“熟识照顾”全免问诊费，实际每次有效诊治只收5灵石；此免收属于该医馆配置，非全局规则，其他医馆可独立配置比例、耗材费和是否免收。满气血仍禁止支付，页面保留5灵石报价；不耗时、只回满气血、余额不足／保存失败不扣费及成功诊治问候保持。

新版yiguan-2底图保留mipmap。费用移至源图(672,651)附近的360×132窄框，依次为标题＋绿色熟识照顾、划线原问诊费＋免收、药材及耗材、灵石图＋实际支付；字段读取同一个权威预览。熟识照顾PanelContainer复用simple_tooltip.apply，鼠标可命中、标签文字穿透，原生简易悬浮显示“与清禾自幼相识，诊治时免收问诊费，只需支付实际所需的药材及耗材费用。”，不常驻侧边大框。诊疗状态／正常支付说明移至预计恢复下方(1136,468,208,37)，医馆说明整体上移76源图px、字体／内容不变；原题句移至确认按钮上方留白，确认按钮原位不动。

必要专项tests/clinic_fee_layout_tests.gd：无界面只检查分项取整／免收／可配置收费／失败与重复请求及新增标签命中；-Render仅受伤／满气血静态布局。具体结果见最新进度，原clinic_treatment_tests的配置字段断言同步。

## 所有人物欢迎结束后点击开启话题（2026-10-13）

MapClinicDialog（含药材铺复用视图）在欢迎最后一句时保持三个话题按钮及其框／图标／新标记隐藏，将原继续按钮文案切为“点击开启话题”；再点击提示、弹窗非按钮区域或按一次空格，仅展开三话题，欢迎末句保留。界面本地记录本次欢迎的展开状态，不改DialogueJournal权威读数、不额外保存、不自动开始话题；切诊治／买卖保持状态，真正重入或开始不同欢迎重置。继续输入保持按钮排除、长按过滤及拖拽保护。叶伯medicine.01首句由“来得正好，考你个简单的。”改为“来，考你个简单的。”，其他同词句不改。

直接专项tests/npc_topic_gate_tests.gd验证两人的首次／单句日常／受伤欢迎、苏清禾诊治欢迎、切页保持与额外点击无玩法状态变化；-Render仅两人开启前／后静态2K。原clinic_continue_input_tests及npc_dialogue_tests／yesongnian_dialogue_tests的对应步骤已适配；本次实际执行范围见最新进度。下方历史“欢迎结束即出现话题”说明由此覆盖。

## 苏清禾小修与旧档阅读迁移（2026-10-13）

本次接续此前已写入但未收尾的修改。suqinghe.json为21段159条基础正文，回访欢迎16组30条；指定段落替换见[设计正文](suqinghe-dialogue-design.md)文首。医馆03仍独立于叶伯话题，医馆04完成后的原名／历史行为沿既有实现，未创建“河湾有新发现吗？”后续按钮。

content_revision=2配合legacy_seen_maps与legacy_greeting_seen_maps，只迁移六段正文与三组欢迎的已显示句数；已完成／中断、cursor、order、visits与线索不变。NpcDialogueLibrary先验证映射、在候选日志上迁移及复核，再由NpcDialogueActions正常保存发布；诊治入口也先迁移验证，失败不收费。DialogueJournal初建记录时把JSON版本号规范为整数，保证内存与存档重载一致。无版本的旧记录视为1，叶伯仍使用原版本。

DialogueGreetings日常池按每条excludes_flags筛选，保留原池索引及4次亲近轮次；苏清禾daily.05排除joined。一次性欢迎可配置low_resource和excludes_seen：return_injured需要joined／first_town_return、低气血且story.return未开始，先于普通受伤／疲倦问候。once_seen保留中断位置，once_done仅完成欢迎本身；不进入正式seen／done／order，不自动诊治。后续story.return通过requires_greetings选中after_injured_greeting，省略已替换的普通开头两句，保留12条正文；开始后沿既有variants机制固定，普通版14条仍可供健康回镇及已开始旧档使用。

专项`./tests/run_t01.ps1 -Script res://tests/suqinghe_revision_tests.gd`覆盖迁移各中断点、已读历史、条件边界、一次欢迎、显式诊治、隔离保存重载及失败回滚；`-Render`仅静态2K欢迎／信任末段／受伤回镇。具体本次结果见PROJECT_PROGRESS；下方旧数量及“无需迁移”说明属于先前版本。

## 药材铺叶松年交谈接入（2026-10-13）

N14的qingshizhen_herbalist.json新增dialogue路径及presentation.conversation_background，原shop类型、目录和交易保留。MapShopDialog有对话配置时默认第一交谈，其后买卖；持有一个MapClinicDialog共用视图，交谈显示其画布／遮罩、交易显示原画布／遮罩，任何时刻只显示一份。共用标题／说明／离开／左图保持，话题／头像／气泡沿用医馆规则；新底图yaocaipu-2及头像ui-portrait-yesongnian已开启mipmap，源图保留。没有对话的其他店仍用原买卖／打造配置。

MapScreen只在实际打开店铺时发visit，页签切换只换展示、刷新，不重播欢迎或推进正文。shop模态将空格和对话区点击转给共用视图，按钮仍走自身原生输入；交谈期间拒绝交易命令。原销售价格、商品范围、成交事务和退出操作不变。

data/dialogues/yesongnian.json含20段208条基础台词、药理02的11条完整替代版本、9短欢迎。首次欢迎／3药铺／3药理／2首次闲聊／6回访／2入宗剧情／2药铺后续／1救助补充；三固定话题shop／medicine／chat独立历史。姓名模板、六次闲聊的日历／剧情变化解锁、完成后历史等沿用通用日志。DialogueGreetings增加可选一次性组once／once_done、可选状态词和close_interval=0（关闭亲近池），苏清禾配置／已有存档兼容。

DialogueConditions校验并计算requires_flags／excludes_flags／requires_clues／requires_done／requires_dialogues；最后一项明确引用NPC与段落，避免把玩家获知当NPC获知。segment.variants可按事实选择台词与set_flags，第一次阅读记录在npc.variants，基础版由seen锁定；以后读取有效版本核对进度、还原历史。set_flags只在全段读完后设置，新事实才增加story_revision；NpcDialogueActions沿用候选保存成功再发布。

事实与绑定：

- base.story.qingshihewan.rescue_completed：按用户答复，仅留NpcDialogueActions.set_story_flag接口；当前赠玉、到达节点、结束受伤修士现有段落均不设置。
- base.story.yesongnian.knows_rescue：药理02救助后分支或同话题补充汇报全部读完时设置；救助完成本身不设置。知情且救助完成才用对应特殊欢迎。
- base.story.qingshihewan.water_observed：qingshihewan_bridge_dialogue的story_flags_on_complete绑定；MapScreen在最后一次继续结束事件前保存批量事实，失败保留末句显示错误，重试成功才结束。只访问N37不算，旧档不凭到访回填。
- shop.water须water_observed及shop.03完成；shop.merge须叶伯shop.03与苏清禾medical.02完成，由辰宇首先转述，保留未定因果。
- 入宗继续既有base.story.qinglan.departure_ready／joined／first_town_return；测试境界不解锁，已加入不会新播“即将离镇”。

专项tests/yesongnian_dialogue_tests.gd使用隔离内存／artifacts存档，覆盖分支冻结／失败回滚、NPC知情、两NPC独立记录、回访耗尽、原生页签／继续／买卖／重入与桥头事实。-Render只出静态yesongnian-welcome／topics／buy／sell.png；结果见最新进度。原稿与修订边界见[设计正文](yesongnian-dialogue-design.md)，规则见核心01第1.55。

## 苏清禾回访问候接入（2026-10-13）

data/dialogues/suqinghe.json在原21段146条正式正文外新增greetings配置：10日常、3状态／诊治、2阶段，共15组24条；表情统一Emoji，首次欢迎与回镇开头保持原条数，旧seen／done／cursor无需迁移。具体确认规则见核心01第1.54，提供稿与来源见[苏清禾对话设计](suqinghe-dialogue-design.md)。

DialogueGreetings为纯状态模块，NpcDialogueLibrary在加载前校验词库／条件／轮换参数。NPC可选greeting记录保存当前问候、读数、轮换位置、阶段交替与同次诊治标记；不放进正式seen／done／order。NpcDialogueActions在实际visit后选择问候，view覆盖当前显示但保留原选中话题，select清除已读问候并恢复话题；欢迎未读完暂不显示三话题。旧档缺字段兼容，欢迎轮换经候选存档保存后发布，重启保留上次选词与循环位置。纯DialogueJournal.visit仍只负责正式话题回访解锁，实际医馆通过NpcDialogueActions.command进入。

优先级：未读首次欢迎→低气血（低于50%）→低体力（低于50%）→符合条件的阶段／通用交替。阶段先匹配已完成story.return，再匹配药材异常线索；日常每4次用一条06／08／10，其余七条轮换。状态问候不消耗阶段／日常轮次，阶段问候不消耗日常轮次。特定状态持续时可再次说同一状态问候；日常及阶段交替避免连续相同。主线未绑定的入宗长对话仍不会因测试境界自动开放。

MapClinicTreatment.treat可接收当前NPC词库，在收费候选中原子写pending_treatment，保存失败不产生标记；MapClinicDialog返回交谈只发送after_treatment命令消费标记，不自行判定已治疗。同次成功治疗只播一次，此后切页签保留读数；首次欢迎未完则先读完，下一次继续才播诊治欢迎。实际重新打开医馆清除上次未消费的诊治标记，选择新到访问候。

专项：./tests/run_t01.ps1 -Script res://tests/npc_greeting_tests.gd，-Render输出artifacts/suqinghe-daily-greeting.png、suqinghe-injured-greeting.png及suqinghe-emoji-dialogue.png。已验证范围与结果见最新进度；下方首次接入段落中的“已读欢迎不重复”仅指首次固定欢迎，现普通回访已启用新词库。

## 医馆诊治页与5灵石治疗（2026-10-13）

最新排版：诊金右侧说明区Rect2(978,527,371,51)，较原上移4设计px；正常两行由VBox整体垂直居中，满气血／错误提示原位替换，不再放在按钮上方。满气血按钮文字“无需诊治”，disabled使用普通底图、白字及箭头光标，悬浮不切换且不可扣费；受伤后重新按余额决定能否诊治。按钮及其文字上移12设计px，箴言左移54／上移13设计px。治疗仍只回气血。Render同时输出clinic-treatment.png和clinic-treatment-full.png。

qingshizhen_clinic.json新增treatment及presentation.treatment_background，诊治使用tanchuang-qingshizhen-yiguan-2，交谈维持原图，左侧场景／标题／介绍／离开及交谈第一、诊治第二的页签共用。MapClinicTreatmentView按新底图原生框和心形图示覆盖实时气血数字、诊后上限、恢复差值及诊金；诊治预览／诊金／医馆说明为黑体，说明左侧使用tanchuang-baoxiang-alaet，诊金左侧无图标，右侧灵石单位图沿用交易素材。确认按钮为dakai1／dakai2，鸿蒙简体标准400字重，平时白字／悬浮黑字。

MapClinicTreatment负责配置校验、预览及治疗结算：固定5灵石，仅将气血补满，不恢复体力／灵力、不推进日历、不处理复杂病症。满气血、余额不足时禁用确认；服务层再次校验，保存失败不扣费／不恢复。使用候选库存先保存扣费，再发布状态并调用MapPlayerStatus.set_resource；气血沿用现有地图资源生命周期（跨地图携带，未扩展完整资源存档），货币沿用库存存档。UI只发送treatment_requested，MapScreen确认clinic模态及诊治页再执行，治疗完成留在原页实时更新。

专项tests/clinic_treatment_tests.gd：实际资源预览、按钮材质／鼠标悬浮、诊金不足、失败回滚、原生点击治疗、恰好5灵石、只回气血／无时间／无其他进度变化、持久扣款、满状态防重复和配置校验；-Render静态输出artifacts/clinic-treatment.png。旧clinic_dialog_tests已更新空页假设，仍验证单纯查看不改变资源及既有退出机制。

## NPC分话题对话实施设计（2026-10-13）

独立话题框已接入（2026-10-13）：交谈底图已换为用户去掉内嵌三框的新版本，各话题Button下新增TopicFrame TextureRect，使用UI-dialo-topic.webp（mipmap开启），全矩形锚定原槽位、绘制于按钮样式／文字后，不接收鼠标。框随各自按钮显隐，欢迎词未全部读完时三框／三个话题均隐藏；欢迎完成由DialogueJournal同一次返回三个话题，同步显示。切诊治隐藏，返回交谈按既有进度恢复，已读欢迎不重复播放。

未读话题标记：白色楷体“新”15号，放在气泡图标左上角，相对按钮左上角(26,4)；在上一版(26,2)基础上再下移2设计px，保持原有未读判定且不接收鼠标。

换底图前的话题框位置基线（2026-10-13）：用户将更新交谈底图并去掉其中三个话题框，后续沿用当前布局。MapClinicDialog已固定TOPIC_ROW_RECT=(624,745,806,44)、TOPIC_SEPARATION=29；均为原底图设计坐标，canvas坐标需减FRAME原点(32,32)。从左至右医馆／叶伯／闲聊三槽等宽(806−29×2)÷3≈249.333，高44，理论左边界624／902.333／1180.667，顶部745；实际像素余数由HBoxContainer分配。整体缩放仍为min(视口宽/1920,视口高/1080)×0.9并居中。气泡图标目前仍在底图内，各图标右缘相对槽位为62／63／62；标题留半个汉字间距，新标记用上段偏移。此次只记录位置，不提前更换背景或重建框素材；新底图到位后按此基线接入独立框。

阶段继续提示：_refresh_continue_hint统一更新原继续按钮和同位置的纯Label；can_continue为false且当前topic.history为false时显示“点击话题继续”，段内仍显示原继续按钮，整话题完成／诊治页隐藏。提示本身不新增点击操作，下一段仍由话题按钮选择。

姓名位置最新微调：双方姓名在上次视觉校准基础上再上移1设计px，当前offset_top／bottom均为1，字号仍17。

话题按钮最新：当前话题且can_continue时发送advance，其他话题发送select；段末仍发送select进入已解锁的下一段或查看历史。按钮保持原生输入路径，每次点击只分派一个命令，跨话题不额外跳句。

字号／顺序最新：交谈位于第一项、诊治第二项；正文楷体23号，姓名17号，姓名上下锚点同偏移2设计px达到底框内视觉居中，长姓名继续自适应。下述气泡补偿值已按23号重新静态复核可沿用。

视觉居中校准：在Label整段居中后，按22号楷体实际笔画与内纸面补偿六种素材差异，TEXT_OPTICAL_OFFSET_Y中NPC一／二／三行下移2／2.5／3设计px，主角为5／0.5／-0.5设计px。避免只用字体行框／素材含阴影的外框判断居中；更换字体、字号或气泡素材需复核这些光学校准值。

继续输入：MapScreen在clinic模态输入分支调用MapClinicDialog.handle_continue_input，弹窗canvas内左键按下／释放且位移≤6px时继续，递归排除BaseButton，保留滚轮浏览及原生按钮路径；空格兼容keycode／physical_keycode并过滤echo。request_continue统一检查交谈页、可见及can_continue，段末／历史不继续。提示移到闲聊下方，欢迎结束不再显示“请选择想聊的话题”。专项tests/clinic_continue_input_tests.gd使用隔离内存状态验证。

排版最新微调：气泡台词保持楷体，以可见气泡全高度整体垂直居中，两／三行line_spacing为7；三个话题使用SystemFont的HarmonyOS Sans SC标准400字重，左对齐到各自底图气泡图标右缘＋半个汉字宽度。长标题用同一字体测宽缩字，各按钮状态共用边距，源图／箭头／头像坐标不变。

已接入，覆盖下方医馆空话题框的早期状态。运行内容21段／146条台词，原第二轮反馈保存在[sources/suqinghe-feedback-2026-10-13.txt](sources/suqinghe-feedback-2026-10-13.txt)。NpcDialogueLibrary负责配置校验，DialogueJournal纯数据推进，NpcDialogueActions负责候选保存与发布，DialogueBubble负责实际楷体测宽／换行／三行拆泡／头像遮罩。MapClinicDialog通过dialogue_requested发命令，控制器保存成功才刷新；常规历史操作不重复推进。

数据接口：事件dialogue指向NPC文件；topics内initial／revisits／story引用稳定段落ID，段落支持requires_flags（全部满足）与requires_points（已探索地点），clues只记一次。主线可调用NpcDialogueActions.set_story_flag(state,flag,save_path)：base.story.qinglan.departure_ready解锁离镇段；base.story.qinglan.joined与base.story.qinglan.first_town_return共同解锁回镇段。这些事实尚未自动绑定未实现主线，不把当前化神测试境界当入宗。新段加入相应topic.story即可按条件优先显示；河湾调查结果的具体分支台词仍待提供。

姓名入口NpcDialogueActions.set_player_name(state,surname,given_name,save_path)，narrative.identity持久保存，地图名称及战斗快照来源同步；文本支持{player.full_name}／{player.given_name}／{player.familiar_name}，兼容旧字面量张辰宇／辰宇。创建角色页面本轮不新建。narrative缺省自动兼容旧档；JSON数值恢复时规范为整数，损坏记录拒绝发布，读取历史不重新执行clues。专项tests/npc_dialogue_tests.gd验证全部日程／中断／条件／姓名／隔离存档与UI点击滚动；Render仅静态欢迎、左右会话、剧情示例及三行压力布局（压力文案不进入游戏数据）。

本轮按用户正文与附件接入苏清禾：内容以data/dialogues/suqinghe.json记录稳定NPC／话题／段落ID、自由顺序台词、条件及线索；通用对话模型负责逐句进度、完成归档、三话题互不丢失、每日回访与剧情优先。医馆UI只读取模型并发送选择／继续命令。已完成内容只供查看，不再执行线索；欢迎词仅首轮推进。首次闲聊三段不设日间隔，完成后每日有效回访最多新增一段普通闲聊，未读保留、不累计多天份额；重要剧情标记变化也可构成回访。剧情条件未接到现有主线时保持锁定。

沿用现有库存原子保存通道，新增可选narrative字段保存姓名（姓／名）、剧情标记／线索及NPC日志，旧档缺省无对话进度；每次命令先保存候选后发布，失败不前进。完整名字与亲昵称呼用模板解析，单字名加“阿”，多字名取名字。诊治机制仍留空。气泡按实际换行使用左右1／2／3行素材，过长发言拆连续气泡；头像圆形遮罩、框后绘制，箭头对齐头像上三分之一。历史可滚动，自动滚到新消息，查看旧记录不推进。

## 青石医馆框架（2026-10-13最新）

qingshizhen.json新增qingshizhen_clinic事件，稳定ID base.map_event.qingshizhen.clinic，N19／click／独立clinic类型，不加入五店目录。MapEventRegistry校验标题、介绍、退出文案及三张展示素材，可选treatment_background覆盖诊治底图；缺省使用background。MapEventState保持可重复打开，advance不推进为普通剧情，close_clinic只结束本次交互；MapScreen负责点击呈现、输入隔离与离开／右键／Esc退出。

MapClinicDialog参照商铺FRAME(32,32,1474,840)及居中缩放，左侧-boss与通用场景框，title_center_y=134.5；52号黑体标题、28号黑体页签、楷体单行介绍按长度适配。两新素材mipmap开启，源图不改。默认conversation，另一模式treatment；ConversationContent／ConversationOptions／TreatmentContent为空容器，供后续接正文、话题与诊治UI。源图三个话题框未绑定指令，不生成未定内容或玩法。配置不含商品、收费、治疗或耗时；覆盖旧N19仅地点状态。

专项tests/clinic_dialog_tests.gd：headless验证入口、切页、退出／重开与状态不变，Render仅输出artifacts/clinic-conversation.png及clinic-treatment-empty.png。城镇触发共用检查shop_quantity_town_tests同步新增clinic关闭分支；验证结果见最新进度。

2026-10-13草药／矿石与铺名最新：herbalist目录上架zhixuecao／qingtenggen／kuaiye／xilutai四草药，blacksmith新增cutiekuang／chitongkuang两矿石，原两暗器保持。已有plant→herb、mineral→ore映射正确，缺失的是products上架条目，本次保留物品“草木／药材”及矿石分类、原收购和价目。各事件presentation.title_center_y记录原图logo垂直中心（普通135.5、药材133.5、宗门132.5、铁匠／炼丹133源px），注册校验100～165有限数值，共用弹窗只调整标题y并补偿黑体可见字形中心1px；字号52、横坐标704、logo／原图不变。专项tests/shop_material_stock_preview.gd，Render仅五店静态图shop-material-*.png；分类范围检查shop_trade_rules_tests。覆盖下方空货架和原标题位置。

2026-10-13地点更正：炼丹房迁至原仓库N12，qingshizhen_alchemy只改point_id为n12，目录／ID／click及炼丹空页不变；N19恢复医馆、移除炼丹事件绑定，医馆功能待后续。N14—N19新增r41，N19—N23新增r42，两条Curve2D按参考红线弯曲并复用双向行走，无新运行时分支。31节点／42路线，原道路保留。路牌N12暂用现有药用葫芦，N19原医馆葫芦不改；家中仓储入口不受影响。坐标见地图编辑文首，专项tests/town_clinic_routes_tests.gd，覆盖以下旧N19炼丹房位置。

## 药材铺拆分与炼丹房（2026-10-13最新）

红框N14药材铺保留药材／诱饵，蓝框原医馆N19(2489,1141)改炼丹房；alchemy事件以click绑定N19并加入地图event_files，使用liandanfang底图及-boss左图，两图mipmap启用，源图不改。节点／路线／路牌图案不改。旧herbalist目录3丹药原样迁至alchemy，药材铺购买目录暂空、仍收购药材且不再收丹药，炼丹房买卖丹药／丹方，现无丹方定义。五店分类与作用见核心01第1.51，覆盖下方四店／药材铺四类旧状态。

MapShop允许1～4个分类，继续校验非空、唯一ID和库存映射；两类店只生成两个可点标签，原底图后两格留白，未改用户素材。目录可选crafting_label，默认“打造”，炼丹房配置为“炼丹”；共用CraftingContent空容器和交易禁用保护，跨店present时重设标签文字，铁匠铺不受影响。炼丹配方／实际制作及丹药细分留后续。

专项tests/alchemy_shop_tests.gd检查实际入口、买卖、隔离保存重载、炼丹空页禁交易、药材铺拒收丹药、切店恢复打造；Render仅静态截图alchemy-buy／alchemy-sell／alchemy-empty／herbalist-two-categories。shop_trade_rules_tests覆盖五店唯一经营映射与统一价目，验证结果见最新进度。

## 药材铺／宗门商铺入口与节点换位（2026-10-13最新）

qingshizhen.json注册qingshizhen_herbalist／qingshizhen_sect两事件，分别绑定N14／N01，trigger=click，沿用MapScreen自动加载目录、MapShop原子结算和MapShopDialog共用布局，无新脚本分支。底图分别为tanchuang-jiaoyi-qingshizhen-yaocaipu／zongmenshangpu，左侧为各自-boss，四张原图均保留并启用mipmap，场景边框继续用通用框。药材铺退出文字为“离开药材铺”，宗门商铺为“离开商铺”。

经营分类沿用核心01第1.51，购买保留已有3丹药／3法器，其他未配置货架为空；出售展示范围内随身可售物品，包含药材和未使用阵盘，收藏／上阵／仓庫／关键任务保护及统一价目沿用。没有新增投放、购买资格、补货或打造规则。到达不弹，站在节点点击打开，离开／右键／Esc关闭，不耗天数。

按截图蓝框N01(1323,148)改宗门商铺，红框N05(1057,405)改修炼所，LocationIcon图案及各自原缩放互换，节点／路牌外框／路线不变。N14原“草药铺”显示名统一为“药材铺”。N05没有商铺事件，修炼功能留后续；稳定节点ID不变，无需迁移行走或探索存档。四店入口现全部完成，覆盖下方历史待接记录。

专项tests/herbalist_sect_shop_tests.gd：两节点手动入口、分类、专属图片、实际买卖及隔离磁盘重载；Render仅静态，输出artifacts/herbalist-buy.png、herbalist-sell.png、sect-buy.png、sect-sell.png、town-sect-training-swap.png。具体结果见最新PROJECT_PROGRESS。

2026-10-13最新：普通城镇地点改手动交互。qingshizhen_shop／blacksmith／home_rest三事件trigger统一click，路过／到达不打开也不暂停；站在该点点击后沿原流程打开。沿用MapEventState逐事件trigger及缺省click，不加全局屏蔽，特定剧情仍可显式arrival；野外事件与出口确认不改。共用商品卡单件无角标，多件用HBoxContainer分开17号乘号和19号数字，右对齐范围104→101，数字右边缘左移3设计px。右侧可售数量与结算不变。规则核心01第1.52，覆盖下方城镇自动触发的旧描述。专项tests/shop_quantity_town_tests.gd：headless仅检查城镇到达／点击和剧情例外；Render仅数量静态检查并输出artifacts/shop-quantity-refined.png，无商品点击／交易。

## 青石镇铁匠铺交易与打造空页（2026-10-13）

N23绑定base.map_event.qingshizhen.blacksmith，事件文件data/map_events/qingshizhen_blacksmith.json已加入地图event_files。共用MapShopDialog与MapShop实际买卖，底图用tanchuang-jiaoyi-qingshizhen-tiejiangpu，左图用同前缀-boss，边框／裁切／缩放沿用普通商铺；两新图开启mipmap、源图未改。到达自动打开、原地可点击重开，离开铁匠铺／Esc／右键关闭，不完成事件、不耗日历时间。

目录qingshizhen_blacksmith.json新增可选crafting_tab=true及leave_label；MapShop校验字段类型，普通商铺缺省保持两个模式。新增第三页签“打造”，源图槽位Rect2(1025,233,191,49)，文字及选中高亮沿用28号黑体。灵石余额移至右侧Rect2(1224,240,192,37)，重开普通商铺恢复原位置。打造仅显示空CraftingContent容器，隐藏动态分类／商品／详情／分页和交易控件；UI信号与地图命令都阻止该模式买卖。切回购买／出售恢复原分类交易，重新进入默认购买首分类，普通商铺不显示打造。

交易范围仍为矿石／材料／暗器／器方，购买沿用既有飞针／柳叶镖两件目录，未擅增材料现货或补货规则；出售可收购实际随身矿石、兽材、暗器，沿用统一价格、数量保护、收藏／装备保护及原子保存。器方与打造内容暂空，药材铺／宗门商铺入口仍待接。本节覆盖下方旧“只有N16／其他三店入口未接”记录。

直接检查`./tests/run_t01.ps1 -Script res://tests/blacksmith_shop_tests.gd`：真实N23到达、三模式切换、矿石／兽材出售、暗器购买及持久化、打造禁交易、右键／Esc／离开与跨店重开。加-Render只做静态2K，输出artifacts/blacksmith-buy.png、blacksmith-sell.png、blacksmith-craft-empty.png。共用普通商铺回归shop_transactions_tests；实际计数与验证边界见PROJECT_PROGRESS。

2026-10-13商铺底图局部更新：重导入tanchuang-jiaoyi-qingshizhen-shangpu、保留mipmap。上方购买／出售按缩小后的源图边框分别标定Rect2(624,233,192,49)与Rect2(828,233,185,49)，文字及选中／悬浮高亮随槽位居中；28号黑体、配色不变。其他布局、商品格和实际买卖逻辑不改。必要静态两模式预览tests/shop_mode_frame_preview.gd -Render。

2026-10-12地图切换确认框换图：仅MapScreen创建的出口弹窗调用MapExitDialog.use_map_exit_art，使用UI-jiaohu-size-m，按有效Alpha区域Rect2(20,23,974,585)等比显示约604.38×363设计px，与旧图高度363一致、中心不变；mipmap开启。标题移入新图顶部内框至y185分隔线之间的标题带，字体及正文不变。左确定／右取消继续原button-queren／button-quxiao，位置、160×57.6大小、间距与确认／取消回调不改；地图／战斗阵盘更换框仍用size0。截图里的预计耗时及不同按钮不属于本次要求，未新增耗时或交易逻辑。必要静态专项tests/map_exit_art_preview.gd -Render，截图artifacts/map-exit-medium.png；覆盖下方旧出口底图描述。

## 青石镇商铺实际买卖与价格基线（2026-10-12）

2026-10-12已接入：用户批准首轮价格基线及13项微调，普通商铺可实际买卖；四店经营配置与价目共用，其他三店的场景入口保持待接。出售以权威随身单位重新校验范围／收藏／关键任务／当前装备保护、数量、单价与灵石上限，候选快照扣物加钱一次保存后发布。售空后不自动选中另一种商品，避免连续点击误售。自动／手动用药机制不改。

**最新货架与出售范围（2026-10-15）：**武器9件（6下品＋3凡品）、防具10件（6下品＋4凡品），每页8格；食物／杂货空，不借用其他库存大类填充。原16件保持，追加现有雷纹弓、木纹冠、水纹衣，配合原清风印保障连环／生机／润脉／驱散的早期购买来源；映射及验证见[书术清单文首](t01_书术与控制实施清单_2026-09-29.md)，规则01第1.64。19件均读取批准基准价，匕首／长枪买入45／108灵石不变；未新增定价或直接赠送。出售按商铺经营类别收购，不受当前上架池限制。

**出售列表：**MapShop.sale_items读取state.storage中的松散随身单位，按经营范围筛选并统计真实数量；不依赖上架池、不以缺少价格为由隐藏物品，排除favorite、key_item、quest_item／关键类别、当前使用阵盘；盘内及仓库单位天然不计入。共用弹窗切换购买／出售保留当前主分类，重置页码／数量，出售每页8种、按获得时间降序和ID稳定排序。卡片及右详情显示可售数量、实际分类／效果；加减限制在可售数量和单次999保护内。库存changed即时刷新、删除末页物品后页码回退；空栏清空详情及单价／总价。

**出售按钮与结算：**出售模式用cangku1／2，沿用原200×58设计槽位、按Alpha本体校准两态大小／位置，切换前重置几何防止累计缩小；白楷字、悬浮黑楷字。按下发sale_requested，MapScreen校验实际活动商铺／出售模式／忙碌状态后调用MapShop.sell；服务重新查价格与具体单位，成功扣物加钱、重置数量1并显示成交结果，失败保留原状态并显示原因。售空后清空选择、禁用按钮；购买模式用原dakai图及独立purchase命令。无回购、限量补货或新确认框。

**最新正式基线：**核心01第1.51。普通商铺武器／防具／食物／杂货，药材铺药材／丹药／丹方／诱饵，宗门商铺法器／符箓／阵盘／功法，铁匠铺矿石／材料／暗器／器方；四分类固定顺序、无“全部”。共用UI直接读经营配置，不改储物袋分类。当前只有N16有实际交易入口，另外三店目录已准备但未绑定地图节点；专属场景与打造／交易入口后续接入，未把普通商铺插图冒作另三店正式素材。

**配置分层：**`data/shops/trade_rules.json`维护四个profile及默认价格因数，分类内的inventory_categories仅为现有储物分类到经营分类的映射；没有实物的栏目映射为空，之后随实际内容扩展。`qingshizhen_shop / qingshizhen_herbalist / qingshizhen_sect / qingshizhen_blacksmith.json`分别维护四店上架池，经营范围判断MapShop.category_for独立于是否上架，不代表已获得出售权限。当前材料映射兽材，未来加工金属应纳入该经营栏；未新增库存大类或假物品。

**逐件价格（2026-10-12）：**142项已写入data/shops/item_base_prices.json，包含核心01第1.51批准的13项调整，其余129项沿用首稿。标记first_economy_test_baseline，表示进入经济测试，不代表已完成平衡。[原审阅工作簿](../output/spreadsheet/现有物品基准价_首版建议_2026-10-12.xlsx)及docs/sources/item-base-price-proposal-2026-10-12.json保留为历史来源，不作为现行报价。

**价格入口：**运行时基准价表prices以稳定物品ID为键。`MapTradePricing`用整数基点表示因数（10000=100%，默认买入15000／卖出5000），`shop.pricing.set_factors(buy_bps,sell_bps)`接收未来系统计算好的最终因数，不自行决定声望／活动等来源的叠加规则。修改后通过changed信号同步商品格、单价和总价；买卖均重新读同一权威单价，不接受UI传入总额。买入向上、卖出向下取整，总价为单价×数量。青石短剑基准60、买90／卖30；止血丹基准9、买14／卖4。

**报价校验：**四店目录已移除preview_buy_price／provisional，实际全部使用统一基准价。历史样例价兼容接口仍在，但当前目录不调用。缺价显示待定并禁交易，不能当作0灵石；非法因数／基准价／分类加载前拒绝，空商品池允许。

同日标题／数量悬浮：商铺标题用采药标题同款SimHei黑体、52设计号、fbf4bf，保留原位置。两数量TextureButton内添加不拦截输入的QuantityHover，复用翻页按钮_selection_box的12%浅金底、1px金边和5px圆角；移入显示、移出隐藏，禁用或刷新后按实际悬停状态同步，不缩放按钮、不改数量逻辑。专项tests/shop_title_quantity_style_preview.gd -Render只做静态样式／渲染，不发送鼠标事件；离开商铺继续无悬浮。

同日按钮后续：离开商铺去掉悬浮框与悬浮／按压字色变化，改为采药“稍后再说”同款黑体、27设计号，原底图边框保留。购买两态以原悬浮态实际绘制范围为准：TextureMetrics.solid_rect缓存Alpha>0.5本体边界，默认图按两态本体的宽高及位置映射Atlas区域，购买控件按原悬浮绘制区域定位；悬浮图、文字中心和原素材不变，默认／禁用及悬浮／按压各自共用纹理。不要只按两个1079×364画布或含光晕的裁边推断本体等大。专项tests/shop_button_art_preview.gd -Render，仅静态样式／几何和两态截图，无鼠标操作。

同日物品本体微调：商铺所有商品格及右侧详情的物品本体，在现有尺寸基础上宽高各乘0.85，仍居中；品级方形背景／边框、商品框、名称及价格不变。MapItemThumbnail.create新增可选artwork_scale，商铺传0.85，默认1保持仓储等其他入口原尺寸。此项不撤销下文此前的方图整体面积90%设置，仅额外调整其中物品本体。必要静态预览tests/shop_item_body_preview.gd -Render。

同日底图更新：新shangpu底图已去除预画商品框，沿用下述八个固定位置，独立shangpinbiankuang只在当前页对应商品存在时显示；空位的框、内容及按钮同步隐藏，筛选和翻页复用。空分类同时清空详情并禁用购买，不保留上一件详情。专项静态预览为tests/shop_updated_art_preview.gd（-Render），包括仓储四小标题更新后的UI-title-cangku-jiantou；箭头保持13×25布局区域、有效Alpha裁边、等比居中及mipmap，不改其他方向箭头。

同日视觉修订：详情ScrollContainer使用SHOW_NEVER隐藏滚动条、保留滚动；购买常态白楷／悬浮黑楷，图文y714→722。加减按钮净距92→73.6、整体中点不变，上下细金线相接。灵石图片面积为原80%，商品格／右侧物品方图面积为原90%，各自中心及文字槽位保留；只影响商铺，不改仓储缩略图。购买／出售与四分类字体改黑体，选中背景、金边和文字加亮。护具分类通过ItemTooltip.classification_caption统一显示护臂／护腿／护肩／护腰，内部部位字段不改。静态预览tests/shop_visual_refinement_preview.gd -Render，覆盖本节下方旧颜色／尺寸口径。

N16普通商铺（非N05仙门商铺）绑定`base.map_event.qingshizhen.shop`，到达弹窗、原地点击可重开；离开商铺／Esc／右键关闭，不删除路牌、不完成事件、不耗时。`data/map_events/qingshizhen_shop.json`指定底图、boss场景与通用场景边框；标题青石商铺及地点描述来自`data/shops/qingshizhen_shop.json`。买卖已启用；没有回购、商铺刷新或完整经济平衡。

四个上架池：普通16（武器／防具各8），药材铺3丹药，宗门3法器，铁匠2暗器。目录存item_id及经营category；名称、品级、图片和效果读取实际道具，价格读取统一基准表。其他三店目录仍待正式投放及入口接入。当前可重复购买，未指定有限库存／补货；单次数量1～999为输入保护上限。未来修改或添加商品只编辑目录products，分页自动变化，不新增独立卡片位置。

共用`MapShopDialog`基于源画布FRAME(32,32,1474,840)，沿用采药／采矿的1920×1080基准0.9倍缩放，文字开启随缩放重绘。左边框按有效Alpha裁外透明边后507×696源px、中心(349,451)，在左内边x80与右横线起点x618之间等距，上下对齐y80／822；内嵌boss图片等比cover、内缩5px，原素材未编辑。

**固定商品位维护：**源坐标首格(634,375)，每格118×166，列距136、行距180，4列×2行；常量`SLOT_ORIGIN / SLOT_SIZE / SLOT_STEP`在map_shop_dialog.gd。框用shangpinbiankuang，上方98px方形缩略图复用`MapItemThumbnail`（由仓储同款实现抽出，原仓储尺寸不变），下方白色宋体名称及player-status-coin价格。按店读取的四分类和前后页按钮共用这8格，选中描边不覆盖文字颜色。

右侧展示实际图片／名称／品级及全部分类标签，`ItemTooltip.classification_tags / effect_text / _colored`共享分类和真实效果，不另写假数值；含原描述、关键词配色、资源图标，长内容在详情容器中滚动，不侵入结算框。结算单价／数量／总价，价格用jiaoyi-coin、加减用jiaoyi-zengjia／jianshao，购买用baoxiang-dakai1／2、黑色楷体→悬浮白色楷体。原生按钮自动复用全局click.ogg。

`MapShop`校验目录与经营范围，通过MapTradePricing读取统一单价计算总价，拒绝未知商品、无效数量、锁定状态和余额不足。现有库存快照新增spirit_stones及purchase_serial；旧档余额缺省读取原status_header配置0，不自动赠币。购买构建候选快照，灵石扣除、唯一purchase单位入袋及流水一次保存，成功后才发布；失败两者均不变。地图顶部余额从库存权威值同步，既有跨图／战斗保存链路保留此字段，不扩展气血等完整玩家存档。储物袋继续测试99／允许超额的既定规则。

直接检查：`./tests/run_t01.ps1 -Script res://tests/shop_transactions_tests.gd`验证142项价格、13项调整、买卖原子性、失败回滚、保护／数量、原生切换／分页／选卡／成交及售空禁误售；加`-Render`仅静态2K，输出artifacts/shop-sale-enabled.png、shop-priced-stock.png。shop_trade_rules_tests验证四店分类和价格因数；旧shop_sale_preview_tests入口转调新交易专项。仅用隔离内存／artifacts存档，实际结果见PROJECT_PROGRESS。

## 遭遇与宝箱刷新统一修订（2026-10-12）

全部11处遭遇配置respawn_days=20、5处宝箱=40，共用现有游戏日历；击败／领取当日开始，到第20／40天恢复，跨图及重启不重置。怪物不轮换，宝箱到期清除旧选项并开启新领取周期。此节覆盖下方历史15／30天、无日历或测试重启重生说明；草药／矿点周期不变。

data/world/respawn_rules.json定义刷新版本1及旧记录映射，MapRespawnRules在MapLoadoutState.restore通过输入验证后迁移候选副本，MapLoadoutStore.load将升级一次保存。旧仍在等待的六处15天记录到期日加5天，宝箱按原领取时点延至40天；已到期开放的轮次保持开放。不猜测没有记录的击败日期，规则版本防止重复延长。非法版本／越界日期拒绝，失败不发布状态。

专项`./tests/run_t01.ps1 -Script res://tests/economy_respawn_tests.gd`验证所有节点配置、19／20与39／40边界、真实战斗胜利返回／重载、宝箱第二轮及旧档迁移幂等性；仅用隔离存档，无墙上时钟计时。

2026-10-11月份显示：data/world/calendar.json新增month_names，按月序为正月、杏月、桃月、槐月、榴月、荷月、兰月、桂月、菊月、良月、冬月、腊月。WorldCalendar.month_day统一用于日期横幅及完整日期提示；仅名称变化，不改变月日数值、耗时、生日、刷新或存档。专项calendar_month_names_tests检查十二月各初一／初十／二十／三十，无需界面或完整日历回归。

2026-10-11仓库后续：自家“进入仓储”已打开独立仓库＋随身储物袋，两栏同布局、右键／拖拽整叠双向存取。仓库测试99且允许超额、初始空，实际种类数及单位独立持久保存；原空白框架说明由此覆盖。容量／存取数据边界与专项见[储物袋设计](map-inventory-design.md)文首和核心01第1.49，休息与时间机制不变。

## 青石镇自己家：休息与仓储（2026-10-11）

同日布局后续：中间统一称“仓储栏”，左边界不动、右边界向左收缩至与右侧储物栏等宽；储物栏位置和宽度不变，中间多出的空隙预留。普通库存阵盘栏保持原宽，覆盖下文初版“沿用三栏尺寸”中的仓储中栏宽度口径。

右上N03（2591,317，原“家”）绑定base.map_event.qingshizhen.home_rest，配置data/map_events/qingshizhen_home_rest.json，地图event_files正式加载。到达自动弹、原地可再开、休息后路牌保留。地点“自己家”及用户两句描述（“筒朴”修为“简朴”），配tanchuang-huifu-shineizijia底图、huifu-zijia场景图与原huifu-picframe。气血／体力／灵力上限100%恢复并封顶、耗时1天；复用MapTimeActions及原子日历事务，满状态仍能休息，取消／保存失败无恢复或耗时。

MapRestDialog增加可选warehouse_id，存在时下方为两枚270×91源图px按钮：左“进入仓储”cangku1→cangku2，右“开始休息”kaishi1→kaishi2，沿用34号加粗仿宋、白字→悬浮黑字。新增4图mipmap、原图不改；100%沿用原比例样式，自家提示行上移避免底框覆盖。河湾两处不配置warehouse_id，仍使用原376×127单按钮。

仓储ID为base.warehouse.qingshizhen.home，打开后MapInventoryScreen切换展示模式，沿用三栏尺寸、各栏底图／边框与右侧同一实际储物袋、筛选、排序、容量、卡片及共用说明；左属性与中间阵盘／标题／容量隐藏，保留返回操作。此阶段为空仓储界面框架，未创建独立仓库物品账本／存取事务；右侧仍可浏览／选中／看说明，关闭装备／换盘／装备拖拽，防止物品转入隐藏阵盘。模式退出还原普通储物袋功能，不改库存。返回游历／Esc／I关闭仓储并回到当前地图节点；稍后再说／右键／Esc仍可关闭自家弹窗。仓储不耗时，内部日历及地图日期隐藏设置保留。

专项tests/home_rest_warehouse_tests.gd：headless验证实际节点到达、取消、双按钮悬浮／忙碌、仓储进入退出、数据不变、100%与满状态恢复／耗时、失败重试以及普通库存模式还原；-Render只检查静态布局，输出artifacts/home-rest.png、home-warehouse.png。全部使用artifacts独立存档，结果见PROJECT_PROGRESS。

## 统一日历（2026-10-11，已接入）

用户要求系统接入统一时间日历；起始月日读取未来角色创建的生日，当前缺省一月初一。已确认十二灵兽年、十二年为一纪，主界面隐藏纪次、完整日期补纪次；一年十二个月、每月三十天，共三百六十天，不设闰月。灵兽名称仍为可调整候选，尚未作为最终设定锁定。

WorldCalendar是独立于场景树、墙钟与战斗秒数的纯计算模块，配置data/world/calendar.json。MapLoadoutState保存calendar（birthday、start_day、elapsed_days及最近耗时记录），显示层由连续日转换为灵兽年／传统月日。WorldCalendar.initial([月,日])为角色创建预留生日入口，目前默认[1,1]；初始第一纪／青鹿年均是可调整的暂定配置。候选顺序：青鹿、玄狐、灵鹤、苍熊、金隼、玄龟、锦鲤、玉蟾、银蝶、鸣蝉、云鲸、鲲鹏。年龄按开局年龄加已经完整度过的360天年数，不按灵兽年切换提前加岁，未接寿元耗尽。

用户已确认只按耗时行为推进：MapTimeActions.rest保存候选日历成功后才发布三资源恢复，休息固定1天；全满仍可休息，恢复0。MapGatheringRewards.prepare将选定方式的1／2／3天与随机待领结果一次存档；取消选择不扣天，已出结果后退出不退还耗时，重开／领取不重复扣天；旧待领结果不追扣。移动、闲置、UI操作、战斗／倍速、跨地图和离线均不自动推进日期。旧档首次读取迁入默认日期，不追算历史休息或现实时间。

刷新采用绝对到期日，无每帧扣天：全部11处遭遇胜利掉落与encounter_cooldowns中的20天重生日期一起原子保存；到期恢复原种类路牌和遭遇，失败／撤退不新建计时。五宝箱领取时记录40天ready_day和cycle；到期下一轮使用原奖励ID加.cycle.N，新选项与领取凭证相互独立，旧物品／凭证保留。旧等待记录按文首刷新版本迁移，跨图与重启不清零。草药／矿点刷新周期未定，仍测试重启恢复。

2026-10-11最新澄清：两张地图游历时MapCalendarReadout隐藏；打开全屏储物袋或仓储时，在顶部状态栏下方右侧显示UI-title-time横幅，仅年月日、去掉苍澜界前缀，按两山脚间及横幅内部居中；悬浮可看完整纪次，关闭全屏界面返回地图隐藏。由inventory_screen.visibility_changed统一控制，不依赖某个打开按钮。内部历法、耗时行为、年龄和到期刷新逻辑保留；日期／刷新记录仍接入现有原子库存存档。三资源本身仍只有原有的同运行期跨地图／跨战保留，未实现完整资源磁盘存档。

日历检查入口：./tests/run_t01.ps1 -Script res://tests/world_calendar_tests.gd，覆盖历法、生日、跨纪、保存失败／重复操作、休息和两类采集、40天宝箱复开、实际战斗20天重生、重启／跨图及年龄；隔离存档，不碰正式测试档。本轮直接刷新检查用文首economy_respawn_tests，旧入口仅同步周期断言，未额外整套重跑。加-Render仅静态日期检查和2K截图artifacts/calendar-map.png，无鼠标输入或实际结算。以下历史“日历后续／全满禁用／重启即重生”由文首最新状态覆盖。

## 两处休息交互已接入（2026-10-10）

2026-10-11重新导入用户更新的tanchuang-huifu-shandaoxieshe.webp，N13沿用原引用、内嵌边框及等比裁切，mipmap保持开启。tests/map_header_refinement_preview.gd -Render只检查新版图片、两图日期隐藏和容量同字号，不执行输入或休息结算。

云横线中的“室内休息点／室外休息点”现用24号黑体（原22号楷体），保留原容器和水平／垂直居中。

最新文字微调：共用“状态恢复”标题改黑体；30%／50%为38号加粗楷体、左对齐、x1287，靠近“的”。耗时数字x1121、“天”x1142，间距缩短；情况说明框x1246，较原右移2源图px、左对齐，字号／宽高不变。室内外同步，行为不变。

用户指定N05为室外“林间篝火”，N13为室内“山道歇舍”；地点描述及情况说明记录在两份qingshihewan_rest_nXX.json。共用MapRestDialog，室内／室外对应huifu-shinei／shiwai底图、huifu-picframe与各自场景图；沿用宝箱观察的90%整体尺寸、原生像素文字和左侧等比裁切。云横线中填室内／室外休息点，中部“状态恢复”、放大的50%／30%及1天；提示为“状态不满可以休息，但恢复不会超过各上限值。”。按钮huifu-kaishi1→悬浮kaishi2，加粗仿宋34号、白字→黑字；室内“入内休息”、室外“稍作歇脚”，按上下文校正用户后一处重复“室内”。

两事件已注册到qingshihewan.json，原节点坐标／路线／路牌不动，仅更新地点名称；N32既有水边休息标记不在本次范围。到达自动暂停行走并弹窗，原地点击可重开。MapEventRegistry校验类型、比例、耗时、文案和素材，MapEventState的rest阶段不会被对话推进或标为完成；成功休息与取消均留在当前节点，恢复后不删除路牌。

用户已确认仅恢复气血／体力／灵力，并先记录1天、立即恢复，日历后续接入。MapPlayerStatus.rest统一按当前上限增加30%／50%，封顶并一次发出changed；顶部状态栏立即更新，下次战斗读取同一资源快照。任一项不满可休息，全部满时显示“当前状态已满，无需休息。”并禁用按钮。稍后再说／右键／Esc退出不产生资源与时间变化；重复确认不会重复结算，主动再次打开可再次休息。

时间记录为rest_days_spent累计天数和last_rest最近一次来源事件、比例、耗时、三资源前值／后值／实际增量，与地图资源一起在当前运行期跨图／跨战保留。没有推进年龄、采集、怪物或宝箱计时，也没有增加完整磁盘资源存档；统一日历仍待后续。

必要检查：./tests/run_t01.ps1 -Script res://tests/map_rest_tests.gd，使用artifacts独立存档，headless检查两节点到达／取消／悬浮／恢复／封顶／重复及真实战斗衔接；加-Render仅静态检查实际地图注册及两种弹窗，输出artifacts/rest-n05.png、rest-n13.png，不执行输入或恢复。结果见PROJECT_PROGRESS。

2026-10-10共用遭遇框间距：掉落图片／边框／名称整体上移3源图px，三交互卡全部要素整体下移3源图px；包含底图烘焙边框／图标、说明、按钮、点击区、选中框与禁用蒙版。底图通过encounter_action_offset.gdshader仅对交互区取样偏移，原素材及其他区域颜色／位置保持，所有地点复用同一弹窗。专项encounter_spacing_preview仅静态几何／渲染，不执行鼠标检查。

2026-10-10地图路线：N08宝箱左移；N14恢复马路原坐标和三条原路线、改纯通行节点，原宝箱迁至河岸N39，仅支路R44连接N14；chest_n14事件／奖励ID保留，旧选项及领取凭证继续使用。瀑顶增加普通分岔N38，潮湿溪石N36经N38直达临溪石坡N28；保留原石阶路线，现40节点／44段路。事件与敌人不变，坐标及路线ID见[地图编辑说明](map-editing-guide.md)文首。

## 2026-10-09：横向遭遇战新界面

MapEncounterDialog已整体替换旧纵向full弹窗；旧六格器官／四行摘要／凹角战场预览不再显示。data/ui/encounter_options.json统一维护tanchuang-zaoyuzhan、内嵌框、三组操作文案及六按钮图，MapEncounterOptions在构建前校验资源。仍按1920×1080的0.9倍整体缩放，原生像素排版文字；只裁外透明边距FRAME=(32,32,1474,840)。左框463×694、中心(349,451)、4px内缩cover及裁切与采矿一致，源图片不编辑。18张新增素材均mipmap。

11事件presentation只配置illustration，按下方地点编号读取battle-qingheshiwan-01～11（保留原文件拼写）。事件description存用户地点原文，优先于敌人随机池；敌人主档保存四篇介绍、实际rank_label／category_label与最多两个traits。怪物标签复用草药标签的字体、颜色、圆框，不另加关键词颜色。可能掉落直接读实际enemy.loot并以材料ID查询图片／名称／悬浮说明，包含兽心；不展示战斗器官、不虚构参考图里的兽肉。

底部卡片第一行说明、第二行图片按钮；点卡片或首次点按钮只选择，再点该按钮发送命令，2号图仅已选＋悬浮／按下使用。所有按钮沿用全局click.ogg，忙碌时三卡及按钮全部锁定。绕行沿用退出现遭遇、留敌留路牌；迎战保留保存失败重试、实际战场背景及战前暂停。威压已按用户回复暂时禁用：actions.enabled=false，整卡叠加68%不透明深灰蒙版，卡片／按钮均禁用，选择／命令入口再次防护，忙碌解除／重开不解锁；提示显示“暂未开放；威压要求：胜利3次，且至少高一个等级”。条件只记录展示，统计和逼退／胜利／奖励未接入。规则与未决见核心01第1.44。

必要专项：./tests/run_t01.ps1 -Script res://tests/encounter_redesign_tests.gd；headless只测试本次按钮选中／悬浮／忙碌、11实际到达和真实迎战转场，使用artifacts唯一隔离存档。加-Render只静态查看四种敌人、验证全部11处映射，不操作系统鼠标。旧纵向布局测试由本专项取代，部分复合历史测试仅同步直接字段，不默认全跑。

## 2026-10-09：采药底图与左侧场景图更新

采药使用tanchuang-caiyao，结构／90%整体尺寸、原三组按钮和结算不变。细节对齐采矿：地点描述23号、名称上移2源px、双标签上移1px、方式名下移2px；河湾九条方式短句固定两行，逗号后换行，无逗号按语意断行。左侧共用tanchuang-neiqianbiankuang原463×694、中心(349,451)、4px内缩等比嵌图。gathering_options.locations中止血草／苦艾叶／溪露苔分别对应tanchuang-caiyao-zhixuecao1／kuaiye1／xilutai，底图与三图均mipmap。青藤根未配场景图，隐藏图和框并清空旧纹理；无名旧祠节点仍未开启。本节覆盖旧采药底图和25号／零偏移口径；静态检查使用gathering_copy_audio_tests的Render分支，不默认重跑输入或领取。

## 2026-10-09：青石河湾采矿

最新文字微调：仅采矿地点描述24→23源字号；物品名称上移2源图px至中心y429，品级／矿石标签上移1px至中心y465.5，三档方式名y600→602。配置为mining_options的location_font_size及三个*_offset_y，采药保持原25号及零偏移；其他布局与机制不动。覆盖下方旧24号口径，必要验证仅静态Render。

最新左图接入：tanchuang-neiqianbiankuang按原463×694源尺寸，在左内边x80与横线起点x618之间居中，并在上下内边y80／822之间居中，中心(349,451)、左上(117.5,104)，不额外缩放。框内4px内缩放置地点场景图，等比覆盖并限于框内；透明原边框叠上方，不加色。赤铜矿用tanchuang-wakuang-chitongkuang1，粗铁矿用tanchuang-wakuang-cutiekuang1；三图均mipmap，mining_options按地点配置，采药不新增图片。此项覆盖下方首版左侧暂空描述。

N19（2221,1215）为溪湾砂矿／粗铁矿，N22（1847,833）为西崖矿隙／赤铜矿；对应用户蓝框／红框，保留原坐标、矿石路牌及探索显隐。到达自动弹窗、右键／Esc／稍后再说取消，原地可点击重开；三方式和数量见核心01第1.43。材料原文及图片在data/maps/minerals.json，地点描述与六条短句在data/ui/mining_options.json，事件为qingshihewan_mining_n19／n22.json。

MapGatheringOptions按材料类别选择采药／采矿配置，MapGatheringDialog切换底图、方式名称与单位，MapGatheringRewards共用待领与原子收下流程，仍存到库存v2的gathering_offers。校验按材料类别限定方式，不能拿采药方式制造矿石。取消结果后再打开／重启仍领原数量，收下后同运行不可再次采；测试期重启可重新采矿，新的递增凭证不覆盖旧库存。日历未接，不推进怪物重生天数。

采矿使用tanchuang-wakuang1，保留采药90%整体尺寸；地点描述源字号24（采药25不变），六条方式短句固定两行，有逗号的在逗号后换行，无逗号的浅层铜矿说明按“敲取岩壁／外露的铜矿。”断行，原文不改。左侧场景图与框暂空。三按钮已换tanchuang-wakuang-qiancengqiaoqu／xunmaikaicai／shencengkaizao各1／2图：正常用1，选中容器＋悬浮时用2，首点选方式、再点执行，位置保持；自动接全局click.ogg。六按钮图、底图及两矿图均开启mipmap。矿石卡仅一个“矿石”分类标签、下品品级牌，隐藏占格、不能上阵。

必要验证：`./tests/run_t01.ps1 -Script res://tests/map_mining_tests.gd`。使用独立artifacts存档，headless检查两矿点、三档数量／耗时、取消／重开／存档／防重领／写失败，以及采矿切回采药；加`-Render`只生成两张静态预览，不跑鼠标输入。结果记PROJECT_PROGRESS。

2026-10-09采集文字再微调：地点描述26→25源字号，楷体保持；移除预计合计整行及未选择时原合计位置的提示，不改下方三方式卡上的获得数量。简短方式说明16→18号、楷体保留，显示区域改y422～478，中心y450对齐四行数据底边416与容器底484的中间。未选方式时留空；选择时仍读原12条文案。必要Render静态检查通过，未重跑鼠标或音效测试。

2026-10-09采集文案与全局按钮声音：用户确认全游戏按钮统一click.ogg，UiButtonAudio常驻自动连接Button／TextureButton及其子类的pressed，含动态弹窗、复盘和暂停；原战斗按钮手动click调用移除，避免双响。资源不循环，拾取／摆放／命中音效不替换。药材名称27→26、标签15→14，按实际字体最小高度在原分隔带内居中。地点标题与左logo间距52→26源图px；右侧加入26号楷体描述（标题52的一半），较长文字自动换行且不压右侧返回按钮。预计合计下方加16号楷体短说明，未选方式时留空、选择三方式同步更新。四地点标题／描述及十二条短说明维护在data/ui/gathering_options.json的locations，由稳定药材ID／方式ID索引；祠后石隙／青藤根仅准备文案，不新增地图事件或指定节点。必要专项tests/gathering_copy_audio_tests.gd，headless只测音效所需按钮输入，Render仅静态出图。

2026-10-09采集底图再次更新：重新导入tanchuang-caiji1，保持mipmap及90%显示比例，源图不编辑。按新图将药材框标定为Rect2(730,198,267,286)，首／次分隔线y413／449，图片可见中心305.5、名称中心431、标签中心466.5；预计框四行中心y275／316／357／398，合计中心450，方式抬头中心516。抬头／稍后再说及独立箭头随新版标题栏重新对位；三按钮中心取新版耗时框底733与卡底793之间。字体、字号、颜色、选择及悬停规则不变，覆盖前文旧图绝对坐标。只做必要导入、静态断言与2K渲染，不重跑鼠标交互；测试仍为gathering_layout_refinement_preview。

2026-10-09位置续存已接入：现有库存v2存档增加可选map_location，保存稳定地图ID与最后实际到达节点ID；移动中退出恢复最后节点，不保存半路坐标。F5入口改为scenes/maps/session_start.tscn，由map_session_start.gd按data/maps/session_maps.json受控目录选择场景，先核对存档节点存在；无位置旧档走原默认，失效地图／节点回退默认。只在正式落点／转场提交后保存，预载目的地不抢先覆盖来源位置，退场旧地图不覆盖新位置；探索、库存、奖励凭证沿用同一原子存档，不重复建存档系统。读档定位不自动触发离开确认或重开遭遇。进入战斗保留遇敌节点，返图重新激活位置保存；不是战斗中途续战功能。直接检查tests/map_location_resume_tests.gd使用隔离存档，覆盖重启、跨图、转场激活、旧档与备份恢复、失效位置回退及保存失败重试；本轮结果见PROJECT_PROGRESS。

2026-10-09采集楷体／居中后续：三种方式的获得、耗时六行均用KaiTi楷体和18源图字号（原获得18、耗时20），右侧预计四行值改楷体19号，左字段黑体和合计原字体不变。药材名称与双标签各上移3源图px，按分隔空间作视觉居中；图片区域中心调整为上下边223／434的中点328.5，并按图片可见区域校准，名称／标签仍沿用物品卡字体。稍后再说原文字Rect2(1253,118,167,43)不变，右侧独立加“>”，不改变点击范围或交互。

2026-10-09采集按钮／字体后续：三个行动按钮由源图y737上移至732，中心位于耗时框下沿y730与容器底边y793之间；只有“容器已选中＋鼠标在按钮上”显示2号亮图，移出恢复1号，首次点击选择／第二次执行保持。地点抬头、稍后再说、预计收获、四行字段名、选择采集方式及三方式名称统一SimHei黑体；右侧数值／合计与三卡获得／耗时内容不改。药材名称与两个标签均使用物品卡相应的继承主题字体，保留上次位置、字号与圆角框。按钮图内原字不重绘，源图片不改。

2026-10-09采集排版：弹窗以屏幕中心整体缩小10%（DISPLAY_SCALE=0.9，蒙版仍全屏）；“选择采集方式”按下方中间蓝色方式框水平居中，设计字号24→23。药材名称移至原标签行中心，品级与“药材”分为两个物品卡同款圆角标签，放到下方横线以下；图片与采集机制不变。遭遇战弹窗地点名／现场描述／敌人名称均为SimHei黑体（42／18／28设计字号），本次仅核实不修改；敌人介绍及其类别标签为楷体。

2026-10-08最新表现时长（覆盖下方旧值）：胜利图片与50%黑蒙版同步渐显0.5秒、完整停留1.5秒，总计约2秒，保留点击跳过；进战与返图均0.5秒变黑＋0.5秒显现，音乐同步，总计约1秒。地图之间的方向切换保持1秒＋1秒，首次地图音乐渐入仍3秒。资源加载／保存耗时不计入纯转场时长，奖励框／复盘仍等玩家操作。定时专项：tests/battle_presentation_timing_tests.gd。

## 草药采集与领取（2026-10-08）

规则／范围以核心01第1.40为准。`MapGatheringOptions`读取`data/ui/gathering_options.json`，校验三种命名空间ID、数量区间／耗时和按钮素材，再提供预计摘要；`data/maps/herbs.json`保存四药材及用户原文，MapLoadoutStore注册plant分类但不初始赠送。三份gathering事件将N04／N31／N36绑定地点与药材，到达自动触发、停稳可点击重开；青藤根尚无地图事件。

`MapGatheringRewards`处理随机与原子保存，UI只发送method_id，服务重新查配置。v2新增可选gathering_offers，以事件ID保存待领取的药材、数量、方式、天数、唯一奖励ID；旧档缺省空字典。生成结果先写盘，再显示继承MapRewardDialog的获得药材框；收下通过既有claim_reward写库存与凭证，保存失败不发物、允许重试。结果框右键关闭保留待领，重开／读档不重抽。领取完成写MapEventState同运行期completed并淡出路牌；测试重启清空完成状态，下一轮按奖励序号生成新凭证，既有库存和首轮凭证保留。没有墙上时钟或游戏日历推进。

UI继续使用更新tanchuang-caiji1及原三组按钮，原生整数像素文字；预计单位白色，“选择采集方式”24号。药材区实际图／名／下品标签，可悬浮原文。获得药材框显示收下按钮及数量（1株也显示），药材卡不可拖走或上阵。独立F6入口`scenes/maps/gathering_preview.tscn`只看效果，不读写玩家存档。

必要验证：`tests/map_gathering_dialog_tests.gd`验证本次单位文字／既有选择交互；`tests/map_gathering_rewards_tests.gd`使用隔离存档检查实际到达、入袋、取消、保存失败、读档防重抽、防重复、路牌消失及重启再采。2K图为artifacts/gathering-herb-n04／n31／n36.png、gathering-loot-n04／n31／n36.png，最后数量位置微调见gathering-loot-final.png。四种药材图片开启mipmap，源图不编辑。

2026-10-08草药点修订：N36原「西南石阶水岸」先由矿石标记改草药，本轮正式命名「潮湿溪石」；N04／N31分别改林间草坡／山坡荒地。路牌内图复用map-zhiwu，节点位置、路线、外框与探索显隐不变。三个草药点已接上文采集；剩余矿石N22／N19仍未接采矿玩法。

## 青石河湾逐步探索（2026-10-08）

灰白短路线末端表现更新：从可见节点向外保留清晰线芯，逐步减弱线芯、增加柔化扩散并将全部图层（含阴影）淡出至透明，正反方向一致；不再硬切断。短段长度与探索范围不变，完整金色路线绘法不变。必要静态／渲染检查：`./tests/run_t01.ps1 -Script res://tests/map_hint_fade_preview.gd -Render`，不含鼠标或存档操作。

规则见核心01第1.39。仅qingshihewan.json启用exploration，hint_length=72底图px（短路线按22%截断，两端提示不相接）；青石镇配置不动。MapExplorationState从已访问ID和真实邻接图导出可见节点／完整路线；MapRoute只裁绘制区间，不改Curve2D及移动距离。MapRoutePoint仅对节点自身用灰白shader，子路牌不继承材质；父节点隐藏同时隐藏路牌，与既有完成淡出／恢复兼容。

库存v2新增可选map_visited字典（地图ID→已走节点ID数组），旧档缺失为空；校验类型、命名空间、重复ID及数量边界。首次落点及每次到达／途经先记录并保存，再处理宝箱／遭遇／出口；使用原MapLoadoutStore原子写入，不创建第二份进度存档。仅存已走节点，灰白前沿按拓扑重算；库存奖励候选／恢复／战斗持久快照沿用该字段。保存失败保留内存进度、提示日志并在下一次到达／既有保存入口重试，不假报落盘成功。探索数据不触发无关库存界面重建。

隐藏节点排除_node_at，MapTravelState探索模式下拒绝未揭示目标并过滤未完整展开的路线，防止寻路穿过隐藏捷径。首次EastExit仅邻接N15；在N15展开N14、N16、N37，保留EastExit。专项`./tests/run_t01.ps1 -Script res://tests/map_exploration_tests.gd`，`-Render`生成初始／展开截图；只用隔离存档，不运行全量地图交互套件。此前假定全图可点击的旧地图测试如需复跑，应在独立夹具中先提供已探索记录，不为测试关闭正式探索规则。

## 四怪数据与固定遭遇配置（2026-10-09最新）

本次以用户新表覆盖下方旧分布与掉落。敌人主档保存三条随机遭遇文案、基础值、器官布局、奖励和专属展示资料；四怪battle_enabled=true，11事件enabled=true。2026-10-08头像／阵盘／专属战场均已到齐，已验证地图到达自动弹窗和实际开战。Registry／GameManager仍拒绝缺失正式资源的配置，不复用其他怪物背景。

2026-10-09修订：所有战斗地点固定一种敌人，取消后续种类轮换；南湾沙洲改为灰脊山狼，其余保留原首次敌人。原已配置15游戏日的N01／N10／N30／N21／N28／N26保留重生等待，重生仍为同种；其余五处时长仍未定。实际日历尚未接入，测试重启恢复各地点固定敌人，同运行期重进地图保留击败状态。 事件仅用enemy_id指定固定敌人，移除enemy_sequence；每次开启遭遇从该怪物三条文案抽一次，刷新弹窗不重抽。

河鼋开战护甲0、上限7、6.5秒回3（用户已确认）；狼45/42、河鼋51/45、岩雉46/45、猪96/98（气血/体力），灵力均0。三小怪每胜修为3／历练1，猪5／2。普通可掉器官各独立25%、命中1件，兽心恢复首胜必掉、之后独立10%；已持有的旧兽心材料与凭证保留。器官均下品，掉落仍为无战斗功能的兽材，不免费入库。其他15张新图所属怪物本次不接入。

## 当前地点与启用方式

| 编号 | 节点 | 地点 | 固定敌人 |
| --- | --- | --- | --- |
| 01 | N01 | 雾松崖径 | 青翎岩雉 |
| 02 | N07 | 河心乱礁 | 青壳河鼋 |
| 03 | N10 | 青溪渡口 | 青壳河鼋 |
| 04 | N12 | 夹壁山径 | 灰脊山狼 |
| 05 | N30 | 落英林径 | 赤鬃獠猪 |
| 06 | N21 | 回水岭径 | 灰脊山狼 |
| 07 | N28 | 临溪石坡 | 青翎岩雉 |
| 08 | N33 | 南湾沙洲 | 灰脊山狼 |
| 09 | N24 | 断阶水口 | 青壳河鼋 |
| 10 | N17 | 翻车商道 | 赤鬃獠猪 |
| 11 | N26 | 南岸深林 | 青翎岩雉 |

器官配置：data/items/shanlang_*、heyuan_*、yanzhi_*及cslz_*；敌人主档data/enemies/对应稳定ID尾段.json。三新盘data/boards/qingshihewan_*.json已由300×300逻辑占位升级为各自1254×1254原图与独立格线。九材料写入enemy_materials.json，grant_on_start=false，旧兽心材料保留以兼容持有与凭证。图片按拼音对应、启用mipmap，物品共用可见区域居中及0.5屏幕px描边。

当前四怪均已配置独立presentation.battle_background并开启敌人及11事件；Registry和GameManager仍校验正式资产。以后新增内容沿用此步骤，不需要为普通器官新增脚本。

MapEventState.resolved_event读取地点固定enemy_id（无轮换表时兼容旧序号）；active_event保存本次文案快照，MapScreen每次打开重建对应预览，战斗与奖励取实际敌人ID。advance_encounter_days正整数入参只推进本MapEventRegistry中的遭遇，每段游戏时间由未来统一日历调用一次；禁止按帧反复调用或用多个重复地图实例重复推进。运行期字典以事件ID隔离，尚不写地图天数存档。未设时长地点手动respawn保留；已有15天配置的地点不能绕过等待，超额日数不跨越尚未发生的下一次击败。

检查：tests/qingshihewan_content_tests.gd验证数据／概率边界／材料兼容／资源缺失拒绝／固定敌人重生与文案；tests/qingshihewan_encounter_roster_tests.gd验证真实地图11处到达及两猪可用。渲染gallery只展示器官素材，不开启新怪物战场。已做／未做结果见PROJECT_PROGRESS最新条目。

## 怪物资料归属与专属战场（2026-10-08）

八套头像／阵盘引用存于data/ui/enemy_art.json；敌人JSON使用art_profile，Registry合并为运行时portrait／portrait_includes_frame／board_layout及可选portrait_frame，保持所有UI统一读取。2026-10-22当前河湾四怪改为无框头像＋独立凡人框，两处共用居中比例，原头像尺寸不变；[几何与验证](enemy-portrait-fit.md)。美术档案可以先于完整怪物数据注册，不产生可战敌人。

敌人主档的presentation统一管理rank_label、category_label、description、battle_background、summary；遭遇事件只保留节点、触发、现场文案、战斗入口与弹窗皮肤。动态摘要行只配stat，显示时从PartyMemberState计算，禁止同时填写value；攻击特点等静态介绍仍配value。EnemyPresentation提供共享校验和展示读取，Registry校验字段与素材引用，地图拒绝展示资料不完整的敌人。旧事件内enemy_rank／enemy_category／enemy_description与presentation.enemy_summary／battle_background已迁移，后续重复配置会被拒绝。

四怪背景统一为battle-qingshihewan-前缀：山狼shanjihuilang、河鼋qingkeheyuan、岩雉qinglingyanzhi、赤猪chisongliaozhu，扩展名.webp。赤猪换用户新图，删除旧battle-qingshihewan-zhu.webp及.import；原test1此前已删除。四图保留原像素，启用mipmap和无损导入。遭遇预览／地图开战／独立战斗都读取敌人主档背景，无全局赤猪贴图兜底；未配置背景的旧测试敌人使用中性底色，其他敌人配置自己的背景。MainUI显式背景属性仅保留场景／预览覆盖用途，正常地图流程不再重复传递背景。原战场蒙版和UI布局保持；预览等比cover，新增可选preview_alignment=[x,y]（每轴0～1，默认0.5居中），岩雉设[0.5,0]顶端取景以免切掉头部，四角内凹保持。每次展示重新设置取景，切回赤猪不继承岩雉偏移。

存活与重生按全局唯一地图事件ID独立记录，同种敌人的两个节点互不影响。保留运行期击败记录／重启重生；固定敌人及已有15游戏日重生配置按本文文首，实际日历尚未接入。器官与掉落材料仍使用不同稳定ID。直接检查：`./tests/run_t01.ps1 -Script res://tests/enemy_presentation_tests.gd`，使用内存定义与artifacts隔离存档，不操作鼠标。

## 宝箱两阶段实现（2026-10-10）

第二阶段后续尺寸微调：左侧物品方框围绕原中心等比缩小10%（132→118.8源图px），物品与浮影同步适配；警告文字17→18号；收取按钮围绕原中心等比缩小10%，文字仍居中并保留原字号及长名称适配。选项整行及第一阶段按钮不改。

2026-10-10选物卡文字微调：物品名称改用地点名称同色#FBF4BF；名称与分类标签各下移2源图px（y10→12、55→57），描述上移2源图px（y91→89），让三层文字视觉间距更接近。两行说明高度、字号及物品图框保持。

规则以核心01第1.36为准。五份qingshihewan_chest_nXX.json经event_files注册，到达／途经先进入`chest_observation`、暂停移动。节点及文案：N34西瀑石台、N06河心乱礁、N08北岸林阶、N39桥东石滩、N27南坡林缘；N08保留chest_n22、N39保留chest_n14事件与奖励ID。五处quality全部下品、respawn_days全部30，取代原按路径颜色分配品级。

`MapChestObservationDialog`共用原生像素字体和90%显示尺寸，第一阶段tanchuang-baoxiang1、693×694的picframe、各地点0号宝匣／1号场景。标题与宝匣名黑体，稍后再说27号黑体＋独立“>”，打开按钮34号加粗仿宋；常态dakai1白字、悬浮dakai2黑字。新底图首阶段抬头／稍后再说下移14源图px，宝匣原中心缩小10%；左侧场景等比裁切、素材像素不改、mipmap保持。

`MapChestDialog`继承同一壳，第二阶段改tanchuang-baoxiang2与`presentation.result_illustration`的各地点2号图；显示`observation.result_description`完整寻宝结果。顶部按第二阶段底图装饰对齐，字体与稍后再说形式不变。两个562×156源图px的`MapChestChoiceCard`单选栏，淡金底／亮边与右上圆圈勾；方形图片框与浮影读取MapItemQuality颜色，共享MapItemArtwork取景／朝向，浮影单独固定在框中心。标签读实际分类、子类、甲型／伤害类型、品级并去重。描述读取可选`flavor_description`；2026-10-10已为武器36、防具36、法器22、丹药16、暗器5共115种下品／凡品主角道具逐件补齐简短叙述，每条含标点不超过30字。文案维护在data/maps/inventory_items.json，按稳定ID区分同名不同品级物品；加载时从目录取文案，旧库存无需迁移，T01导入器保留此字段。阵盘、材料及敌人专用道具不在本次范围；悬浮说明仍提供真实效果，行内不可拖拽／右键上阵。描述固定在原两行区域，限制初始最小高度并先设字号再设尺寸，避免非空文本在卡片尚未取得宽度时把说明撑出边界。

下方警告使用底图已有感叹号，文字为“选择并收取后，另一格的物品将永久无法获得。”。领取按钮使用首阶段素材和加粗仿宋，随选项变为“收取 XX”，悬浮亮图黑字；未选禁用，长名称在按钮范围内适配。两阶段的稍后再说／右键／Esc均退出到当前节点。观察无抽取／领取；点击打开时先`MapChestRewards.ensure_offer`原子保存，成功才`MapEventState.open_chest()`进入第二阶段，失败留观察框可重试。旧无observation定义保留直接选物品的兼容入口，第二阶段缺图／文案时为空，不借用其他地点内容。

池定义在`data/maps/chest_pools.json`：武器A＋防具B权重40，丹药／暗器合并池两件权重40，法器两件权重20。MapChestRewards校验配置和候选充足后，先按权重选池，再按event.quality过滤各栏，等概率抽取且排除已选ID。通用支持下品／凡品，河湾只下品；目前下品无暗器，合并池暂为两种丹药。UI不负责抽奖或推断规则。

库存v2可选`chest_offers`保存`{version:2,pool_id,items:[A,B]}`，校验两件不同、同品级与各栏类别；旧数组格式兼容读入，未领取的旧规则选项在首次打开时原子升级，写失败不替换。新版选项取消／重开／重启不重抽；旧已领取凭证不清除。领取候选把一件物品、granted_rewards凭证及`chest_cooldowns[reward_id]={delay_days:30,remaining_days:30}`一次保存成功后才发布。失败保留选择且不发奖／不加等待；成功关闭路牌，路径点与路线保留，重启仍关闭。等待记录随库存／战斗存档保留；未接日历扣天或重新开放，无现实计时器。以后日历接入还需按每次开放周期管理新选项和领取身份。

必要检查：`./tests/run_t01.ps1 -Script res://tests/map_chest_tests.gd`。headless只用artifacts隔离存档及视口虚拟输入，检查五节点实际到达／观察／打开／互斥选择／悬浮／取消／领取、40/40/20池范围、类别品级与去重、旧档迁移、保存失败原子性和30天等待保留。加`-Render`只静态绘制五处两阶段2K预览，不执行鼠标或领取；截图`artifacts/chest-observation-nXX.png`与`chest-choice-nXX.png`（后缀保留事件ID）。实际验证结果见PROJECT_PROGRESS。

## 胜利展示与物品复盘弹窗（2026-10-07最新）

复盘按钮最新更正（2026-10-07）：REVIEW时开放战斗记录，沿用实际本场日志弹窗及关闭按钮；关闭后留在复盘。仅置换／撤退继续灰置，“离开战场”不变。胜利图／奖励框阶段仍禁止通过此按钮打开记录，覆盖下方旧三按钮全禁用描述。

战前入口补充（2026-10-07）：中央“对阵”图216×216设计px改为复用BattleActionButton的点击入口，仅PREPARATION有效，调用现有start_battle；按下缩小最多3%、松开回弹及音效与底部按钮相同。开战后不可点击但保持原色、原位置／尺寸，暂停和复盘仍使用原底部按钮。battle-start素材开启mipmap，静态展示不自动放大／淡出。

后续音乐／布局：胜利时立即停止原战斗曲，victory-song2.mp3只播放一遍；复盘、重开奖励和刷新不重播，自然播完静音，返回地图沿用原播放器渐隐／停止。六张胜利图已等比放大50%（显示框宽66%、高51%，中心不变）；奖励滚动区现408×244，单／双卡居中，两卡间距16设计px，多排仍最多三列。

胜利时MainUI按BANNER→REWARDS→REVIEW管理展示，模拟状态始终保持FINISHED；战败／撤退继续原失败界面。六档素材映射在data/ui/victory_banners.json，取实际主角cultivation_rank，新增图片均开mipmap。胜利图保持原比例、显示框宽屏幕44%、中心Y43%，黑色全屏蒙版Alpha0.5；Timer用独立表现时间3秒，鼠标左／右／中键可提前结束且消费该次输入，不穿透后续确定按钮。

BattleRewardDialog继承MapRewardDialog赠玉画框及标题，保留原剧情单卡流程；战斗卡宽120设计px（原赠玉152），三列、16px横距／28px行距，底部留24px空间以展示品质角标。滚动区408×224，零掉落明确提示，按钮左复盘／右确定使用现有button-quxiao／button-queren。复盘隐藏两层新增弹窗及蒙版；底部主按钮无图标、文字离开战场，其余置换／撤退／战斗记录全部禁用。离开战场只重开物品框，确定才调用既有地图返回与音乐转场。

MapBattleReturn仍先原子保存掉落及首胜凭证，成功后将物品ID发布给界面；不从摘要文字解析物品、不在打开或关闭弹窗时发奖。返回失败在原物品框显示错误并恢复按钮供重试；旧概率、存档格式与玩法结算不变。F6独立入口没有原地图返回地址，继续既有退出程序行为，不虚构地图位置。专项`./tests/run_t01.ps1 -Script res://tests/battle_victory_flow_tests.gd`，加`-Render`生成胜利／奖励／滚动／复盘截图；明确规则见核心01第1.35节。

## 入战先等待开始、阵盘同步显示（2026-10-06）

地图进入战斗后停留PREPARATION战前准备，不自动start_battle，不推进计时或CD；主按钮显示“战斗开始”，点击后才开始模拟，后续“战斗暂停／战斗继续”保持。独立F6入口同样显示“战斗开始”。入场1秒渐隐＋1秒渐显及音乐不变。

InventoryView在绑定与尺寸变更时立即建立／布局底图和物品，不依赖首个_process；转场禁用场景处理时也能随背景一起渐显。仅改变初始化时序，不改占格或拖拽规则。

## 战斗返回保留资源（2026-10-06）

战前使用地图最新三资源，战后返回使用结束时实际气血／体力／灵力；实际气血归零战败为例外：地图气血恢复1点，体力和灵力保留战败瞬间值。战斗界面保留0气血并显示战败画面，存活撤退不会触发恢复。地图之间切换共享当前MapPlayerStatus，避免重新configure补满；修为等非战斗字段沿用。已接同运行期资源衔接，不新增成长奖励或磁盘资源存档；具体入口与验证见地图顶部状态栏设计最新记录。


## 出口到达即确认与转场提速（2026-10-05最新）

角色步行／跑步到达或途经已配置出口节点时，停止于该节点并自动打开离开确认框；不再要求停稳后再点一次。右键（包括在确定按钮上）或Escape、取消按钮均可取消，停在原节点且不立即重弹；随后可继续行走或再次点击出口重开。初始出生与跨图落点只初始化位置，不自动询问返程；确认后忙碌期间不能右键打断切图。其他剧情与遭遇触发保持。

进出战斗的画面与音乐统一1秒渐隐、全黑切场、1秒渐显，总计2秒。地图之间的方向擦除也改为1秒旧图渐隐＋1秒新图渐显，总计2秒，音乐与画面共用真实表现时钟、同步到达终点，不将预载上一帧耗时算进新转场；方向判定、暂停地图BGM并在返回续播、输入锁与模拟冻结保持。普通首次进入地图的音乐仍为3秒渐入。此节覆盖下方旧1.5秒战斗／5秒跨图及到达后再点击要求。

## 遭遇说明20号字与特点独立续行（2026-10-05最新）

右侧统一20号楷体，四条单行分别为“气血 96”“攻击 穿刺主，钝击辅”“甲型 轻甲”“特点 高气血·蓄势爆发”；四行整体垂直居中，特点不再另起一行。标签与值间距7。左侧渐隐竖线#aeada8，透明度与宽度保持。五件器官、攻击／恢复／强化及材料掉落已接入，左侧六槽放五件图标并复用效果提示，第六槽空；详见[五件器官接入](chisong-liaozhu-items-2026-10-05.md)。本条覆盖下方早期“空槽／旧爪子／未有奖励／天生护甲上限6”等历史描述；现在容量6来自厚鬃皮，首胜掉落凭证写入库存存档，敌人测试重生仍按运行期处理。

## 遭遇弹窗四行说明与按钮微调（2026-10-05）

右侧说明改为四条单行：气血 / 体力 96 / 98；攻击 穿刺主，钝击辅；甲型 轻甲；特点 高气血·蓄势爆发。取消硬换行与自动换行，楷体字号15→17，原图标／配色保留。气血／体力和甲型仍读取实际状态，但不再显示开场护甲与上限，也不显示“回体”；真实战斗属性及行为不因删展示字改变。标签“一级中阶”改“凡人级·首领”，旁边“野兽类”保持。“夹壁山径”标题y48→52，下移4设计px。

开战／撤退按钮含文字整体缩小20%，围绕原按钮组中心收缩，两个按钮的边缘空隙也缩小20%。内部显示尺寸200×72→160×57.6、间隔120→96，水平中心200／520→232／488，纵向中心942保持。只改本遭遇弹窗，不改变离图或领取按钮。以下旧文字与按钮尺寸属于之前版本，以本节为准。

## 地图音乐、方向转场与遭遇数值同步（2026-10-05）

地图定义的music数组维护BGM：河湾bgm-qingshihewan-1单曲循环，青石镇bgm-qingshizhen-1／2按顺序循环。MapPresentation常驻表现节点独立于战斗模拟，进入地图3秒线性音量渐入至-6dB；跨图离开3秒渐出并停止，新图从第一首开始。进入战斗时地图画面与音乐同步1.5秒渐隐，全黑后切换，战斗画面与battle.mp3同步1.5秒渐显；返回地图采用同样时序，地图音乐从暂停位置续播。总画面转场3秒，用表现层统一时钟同步音量与遮罩；冻结源／目标处理及输入，战斗直到渐显完成才推进。资源校验与预载在转场前完成，失败保留原场景。播放列表自然结束切下一首，期间发生淡入淡出不会重置音量包络；储物袋、剧情及遭遇预览不暂停BGM。未来地图可以配置自己的列表，无列表则保持静音。

仅地图之间使用全屏柔边黑色方向转场：旧图3秒逐步变黑、完全黑时切图、新图2秒逐步展现，总计5秒。音乐在转场开始时渐出、全黑切图时开始新曲渐入（新曲最后1秒渐入可与恢复操作并行）。按节点在源图中的归一化位置选最近的左／右／上／下边：离开时朝出口边推进，进入时从入口边向内展现，与镜头平移缩放无关。河湾EastExit去青石镇N25两段均左→右；反向均右→左。先预载隐藏目标并验证场景、落点、存档、音乐；失败保留原图和音乐，允许重试。转场期间冻结两图处理并拦截输入，不穿透、不重复切图。地图与战斗之间使用上方3秒均匀全屏渐隐渐显，不使用此5秒方向动效。

赤鬃獠猪实际气血／体力由80／100改为96／98；新增数据驱动的天生轻甲、护甲上限6、开场护甲0，重算装备后仍保留天生属性；其他敌人／玩家原开场规则不变。遭遇框气血／体力与甲型数值从PartyMemberState生成，不再单独依赖展示字符串。此处仅同步用户本次要求的数值／甲型：攻击仍沿用原爪子；“穿刺为主，钝击为辅”“蓄势爆发·回体”的器官与行为接入不在本次数值同步内，保留为展示目标。历史序幕试算虽有器官参数，不自动当作已获授权的新机制实施。

验证入口：tests/map_presentation_tests.gd（headless或-Render），覆盖实际战斗数值、双向转场时序、上下边方向、无效目的地、自然轮播、战斗暂停／续播。旧map_exit_dialog_tests和map_encounter_tests改为等待异步转场；battle_map_ui_tests覆盖3秒战斗画面／音乐、当前玩家与空队友、单人居中及地图版置换适配。音频检查使用静音总线验证播放状态、时间位置及音量，并非人工试听。

## 遭遇弹窗full底图与敌人道具展示（2026-10-05）

底图换为battle-tanchuang-full.webp，Atlas区域(64,56,992,1288)，沿用720×1008设计画布及0.8显示系数，原生2K仍为768×1075.2并居中。顶部描述改放(48,140,624,60)以避开新框抬头；敌人头像移至(94.875,264,153,153)，名称／等级分类／介绍沿用字体与整组垂直居中方式。战场预览迁到(45.75,714,630,178)，继续共享battle-qingshihewan-zhu、等比cover及18px四角内凹遮罩。按钮保留尺寸、字样与左右中心，底距改30px，避开新预览；错误提示位于最下方。

中部敌人道具内容区为(45.75,494,630,166)，在宽度60%位置放1.5px金色竖线，两端透明渐隐，左／右为3∶2。左侧居中放3列×2行72px正方形空边框，间隔9px，无物品和交互。右侧15px楷体说明依序使用icon-enemy-health／attack／defense／chara，长值独立一行；内容来自事件presentation.enemy_summary：气血／体力96／98、穿刺为主钝击为辅、轻甲开场护甲0／上限6、高气血·蓄势爆发·回体。新底图和四图标均生成mipmap，显示端继承线性mipmap过滤。

本节记录前一轮纯展示迁移；后续实际数值同步、音乐与转场以文首同日更新为准。六个道具槽仍为空，未添加敌方新装备。下方旧底图坐标与布局说明保留为历史，以本节为准。

## N12节点纠正与遭遇生命周期（2026-09-30，已实施）

用户两次截图实际均为东北林道N12（2575,319），先前将其认作N30属于绑定错误。本轮将原cliff_encounter稳定ID移至N12，不复制另一只猪到N30。敌人默认存活，到达／途经自动弹框；站定点击仍可重开。

本轮采用轻量地图战斗返回协调节点，不把场景依赖加入战斗模拟：地图带入来源场景、节点、事件ID、朝向及库存路径；协调节点监听GameManager发出的真实finished事件，只有victory写入MapEventState运行期完成记录。结果界面提供返回地图，回到原节点；失败／平局／战中撤退保留敌人，返回时不立刻再次弹出。胜利后隐藏路牌但保留路径点，再次经过不触发；同次运行切图重进仍保留。测试阶段不写击败磁盘记录，重启进程恢复存活。预留显式respawn_encounter命令清除该敌人的完成状态并恢复当前路牌，未来刷新机制调用该接口；本轮不增加生成周期或掉落奖励。

## N12夹壁山径遭遇战（2026-09-30）

青石河湾N12（2575,319）接入arrival型encounter：敌人存活时，到达或路线途经会自动暂停在该节点，显示“夹壁山径”遭遇弹窗。这一条明确覆盖下文普通非剧情事件默认click的规则，其他未配置的战斗路标不自动获得遭遇内容。远处点击仍只规划行走，弹框打开时不能通过空格、I键、外围点击继续移动或跳过。

弹窗使用battle-tanchuang.webp，Atlas取Rect2(64,56,960,1344)，排除外围无关留白。内部仍按720×1008设计px排布；用户后续要求整体缩小20%，显示乘0.8，等效576×806.4设计px、原生2K为768×1075.2且保持屏幕居中。标题、头像及正文随整体同比缩小；情况描述额外从20调为18设计px。原先“宽度为离图框4/3”是缩小前基准，当前实际为其16/15。两个按钮最新单独补偿1/0.8缩放，沿用离图／领取框的160×57.6基础尺寸、26px白色黑体，原生2K实际均为213⅓×76.8，与离图按钮及文字一致；左开战button-queren，右撤退button-quxiao，内部中心x200／520、底距64.2保持。

敌人信息最新排版：头像enemy-qshw-chisongliaozhu自带金边，不重复描框；内部Rect2(94.875,298,153,153)，中心对齐底图“敌人信息”的“息”字（源图x292.5），在原y295基础上下移3设计px。文字组x256、宽397，名称／标签／介绍整个VBox按实际内容高度与头像垂直居中（当前高155、顶部y297，中心y374.5），文字重排时同步收缩容器并重新居中，不保留首次换行前的临时高度。第一层28px黑体名称；第二层18px楷体“一级中阶”“野兽类”灰色圆角标签，较上一版20px缩小一档，圆框高度32→28、圆角16→14、水平内边距12→10、竖向内边距3→2，标签间距12；第三层20px楷体介绍、左对齐自动换行、行距5。按用户确认去掉气血行及原等级／气血图标，并移除旧横竖分割线，右侧短句合并到名称下方介绍。分类来自事件enemy_category，仅作展示；猪的实际气血80不变。

赤鬃獠猪介绍为：“常出没于山脚疏林，獠牙粗硬，赤鬃如针。平日拱土觅食，受惊便低头猛冲，踏得枯枝碎石四散。”文本来自事件enemy_description，不作为新增攻击／行为机制。

战场预览和本遭遇的实际战斗背景均读取presentation.battle_background，当前为battle-qingshihewan-zhu.webp，开启mipmap。预览放在内部Rect2(45.75,511.5,630,291)，贴合“战场预览”标题下方金边；按原图比例居中cover，裁去超出区域，不拉伸。concave_image_mask着色器按面板坐标裁掉四角半径18设计px的四分之一圆，形成向内凹的角，使用导数抗锯齿；覆盖框内云纹，保留外侧金线与抬头，不修改源图。主战斗使用同图等比cover；由地图在实例初始化前传给MainUI，默认独立F6仍使用原测试背景。

遭遇框的“撤退”或Esc关闭弹框、取消剩余路线并停在N12，不完成事件、不移除路牌；站在原点再次点击可重开，离开再到达也可触发。“开战”先保存当前库存，成功后载入scenes/main/main.tscn并直接开始战斗，失败保留弹窗供重试，连点只创建一次场景。战斗读取相同库存／阵型与学习存档路径。

事件数据位于data/map_events/qingshihewan_cliff_encounter.json；敌方稳定ID为base.enemy.chisong_liaozhu，注册数据位于data/enemies/chisong_liaozhu.json。最新要求移除野狗阵盘加成，赤鬃獠猪改用通用base.board.enemy_3x3，保留同款3×3几何及贴图、不含资源或buff加成。基础max_hp从75改80，实际气血80、体力100、灵力0；不再采用“基础75＋阵盘5”。弹窗仍从PartyMemberState读取最终上限。攻击继续沿用dog_claw的3秒冷却／5体力／5伤害；普通行囊与野狗自身配置不改，独立F6默认仍为野狗。GameManager使用可配置enemy_id，不为本怪物创建专属战斗脚本。

战斗结果现已回传：只有真实胜利标记该敌人被击败，结果框点击“返回地图”回到N12，路牌隐藏但圆点与道路保留；重走不弹框，重新实例化地图也不复活。战中撤退／失败／平局可返回地图，但敌人保持存在，返回瞬间不自动再战。MapBattleReturn负责场景衔接，MapEventState负责运行期完成与respawn_encounter，MapSignMotion.restore恢复重生路牌。测试阶段重启进程恢复敌人，不写磁盘击败记录；定时／条件生成、奖励及正式跨战资源规则未扩展。直接检查入口：tests/map_encounter_tests.gd，使用隔离存档，覆盖真实按钮／实际模拟胜利／返回重走／地图重建／重生／战中撤退，可在headless及D3D12运行。

## 青石镇复用河湾路标动效（2026-09-30）

青石镇定义新增sign_motion，直接引用同一份data/ui/map_sign_motion.json，不复制参数或新增动画脚本。20块既有路牌按底框类型接入：16块地点方框（11处设施＋5个出口）仅底框78%～100%明暗呼吸、周期7秒，内部图标保持；许愿树N11／植物N22／土地祠N27三块机缘牌整组上下±1.2最终屏幕px、周期4.8秒；家N03圆牌仅内部图标78%～100%呼吸、周期5.5秒。四处内部节点名改为对应EventIcon／RestIcon以匹配共用配置，源贴图、裁切、图标相对位置与路牌尺寸保留。

镇内路牌和图标资源已具备mipmap，显示端沿用河湾的线性mipmap过滤；节奏按point_id错开，显示计时与战斗倍速独立，储物袋遮盖时复用原暂停规则。路径圆点／路线／节点坐标不参与动画。青石镇目前没有战斗或剧情类路牌，不新增这两类标记和事件。此前“青石镇保持原状／暂不启用”由本节覆盖。

## 跨地图弹窗适配更新后的size0（2026-09-30）

用户同名替换UI-jiaohu-size0.webp为940×940高清素材后，MapExitDialog裁切改为Rect2(25,12,894,601)，只取上方完整路框，排除下方透明画布及孤立残余像素。映射到原540×363设计画布，2K下仍为720×484，屏幕中心与领取框相同。标题、七字居中提示语及左移3px、两个160×57.6按钮和53⅓px按钮空隙全部保留。两向跨图共用此适配，mipmap保持开启，原图像素不修改。

## 领取框更换高清size1底图（2026-09-30）

MapRewardDialog底图改用UI-jiaohu-size1.webp。新素材940×940，原UI-jiaohu-xiao为910×700，透明留白不同；按原可见边框位置重新标定Atlas裁切Rect2(25,12,894,894)，替代旧Rect2(200,88,512,512)。核心画布保持540×540设计px，2K下720×720且中心不变。标题、152px宽道具卡、160×57.6收下按钮及其字号／位置保持；只替换底图与裁切，领取和音效逻辑不改。新图开启mipmap，保留原素材；跨地图弹窗继续使用size0。

## 青石河湾路标动效（2026-09-30，第二版）

青石河湾与青石镇均通过地图定义的sign_motion引用data/ui/map_sign_motion.json启用；下表数量为河湾，青石镇分类与数量见文首。实际结构为MapRoutePoint路径圆点→Sign底框Sprite2D→内部图标Sprite2D；Sign本身即可作为整牌显示组，不需重制图片。金边与黑底同属一张图，地点明暗同时作用于两者，其他类别不改变底框明暗。

| 类别／数量 | 当前参数 | 固定部分 |
| --- | --- | --- |
| 战斗菱形／11 | 整牌以中心等比缩放100%～110%，3.6秒一轮 | 牌中心、颜色、路径点 |
| 机缘六边形／10 | 整牌上下±1.2最终屏幕像素，4.8秒一轮 | 路径点、框与图标相对位置 |
| 剧情八边形／4 | 感叹号上半部绕下方金色圆点左右±10°摇摆，每6秒中摇1.4秒 | 金色圆点、底框、路径点 |
| 地点方形／2 | 仅底框RGB倍率0.78～1.00，7秒一轮 | 内部图标、位置、大小 |
| 休息圆形／3 | 内部图标RGB倍率0.78～1.00，5.5秒一轮 | 底框、位置、大小 |

明暗呼吸采用self_modulate，RGB三通道乘同一倍率、Alpha保留，明度不超过原色；地点底框不连带修改子图标。剧情沿map-juqing原图y=215分区，绕原图坐标(150,253)的金色圆点中心转动上半部；下半部圆点位置、朝向保持。两分区在初始化时各裁取到内存纹理并生成独立mipmap、共用缓存，避免相邻分区在缩小时混色；原图文件不修改，静止时还原原图排布。

修正首版机缘浮动时的细线波浪观感：原底框／多数图标未开启mipmap，缩小纹理经过小数像素时会产生时间采样闪烁。当前两张地图的路牌底框／内部图标均有mipmap，运行时Sign及其子图标使用线性mipmap过滤；保留平滑浮动，不使用整数像素跳步。相关导入设置不改原图像素。

参数继续按实机反馈微调。不同路牌以稳定point_id播种局部随机源，各取一次固定相位；不改游戏随机源，不逐帧随机。统一MapSignMotion更新可见牌的表现，运行时不反复加载素材、不创建Tween、不扫描事件逻辑。机缘位移通过父级完整屏幕变换的仿射逆换算，包含地图缩放、节点缩放和窗口伸缩；不改变MapRoutePoint／曲线／人物位置或点击范围。

待机使用独立UI时间，不跟随战斗倍速或Engine.time_scale；完全打开储物袋时暂停，地图隐藏时停止推进，镜头外路牌跳过绘制参数更新。路径圆点无待机动画，保留既有点击与手势。

完成时先由MapEventState登记completed、关闭事件触发，再冻结该牌待机姿态并让整牌在0.3秒内淡出。路径圆点和路线保留；镜头外、被储物袋覆盖或重进地图恢复完成状态时直接隐藏。仍沿用现有本次运行共享完成记录，跨地图重进不恢复，重启游戏重置；不改变当前温玉佩重启重看测试规则，不新增磁盘剧情存档。其他未实现的战斗／机缘／休息玩法不在本轮接入，未来完成可复用同一显示接口。

验证入口：tests/map_sign_motion_tests.gd（headless或OpenGL），不含鼠标套件。旧剧情鼠标套件仅将最终隐藏断言更新为推进0.3秒后检查，本轮未重新运行。

## 青石河湾与青石镇双向出口（2026-09-30）

最右侧EastExit（base.map.qingshihewan.point.east_exit）新增出口配置：远处点击只发起行走，到达／经过不自动弹窗；人物已经停稳在该节点后再次点击才打开“前往 青石镇”。青石镇N25采用同样规则，标题为“前往 青石河湾”，确认返回河湾EastExit。初始人物已位于对应节点时，点击一次即可打开；到达后不自动弹出。剧情／奖励、储物袋或出口弹窗活动时不重复打开。

UI-jiaohu-size0.webp裁取Rect2(25,12,894,601)（2026-09-30适配940×940新素材），显示为540×363设计px，中心与540×540温玉佩奖励弹窗同为屏幕中心，随固定16:9画布等比缩放。标题“前往 青石镇”最新下移7设计px，矩形y54→61，文字按抬头上下金线之间的可见区域垂直居中；正文“确定离开这里吗？”在此前下移10px后再下移3px，矩形y159。提示语只以“确定离开这里吗”七个汉字计算居中，在此基础上提示语和两个完整按钮统一左移3设计px，第四字“开”最终位于弹窗中心左侧3px，尾部问号跟随在右侧而不参与居中宽度计算；共用同一Label和字体度量保留连续文字。左确定用button-queren，右取消用button-quxiao；两按钮均共用奖励框的160×57.6尺寸、26px白色黑体居中文字与64.2px底部距离。内框x30、宽480；最新在原四分点位置基础上将按钮空隙80px减少三分之一至53⅓px，两侧各内移13⅓px，整体左移后中心x160⅓／373⅔，按钮尺寸与高度不变。新底图与取消按钮开启mipmap。所有切图确认弹窗统一复用MapExitDialog，双向及未来出口保持同一格式，只替换标题，不为各地图另设排版。

取消或Esc关闭并留在原地；外围点击、空格、I键不确认或穿透地图，地图行走／拖图／缩放暂停。确定先保存当前库存，失败保留弹框并允许重试；成功后打开现有qingshizhen.tscn，从用户指定的西南桥头、行商旁N25（187,1469）入口出现。青石镇N25的反向确认则回到河湾EastExit。沿用当前inventory_save_path并读取同一库存／阵型／领取账本，不增加剧情前置。

地图元信息改用exits数组，每条明确配置point_id（本地图节点）、title、scene（目标地图场景）、target_point（目标落点）；可选target_facing只接受left／right，在目标玩家初始化前覆盖本次初始朝向，省略时沿用玩家默认。河湾前往青石镇配置right，到达N25后站立朝右；当前仅配置这对双向出口。一个地图可声明多条独立出口，相同本地节点重复配置会被拒绝；每条必须提供非空字段及存在的源节点／目标场景。点击时按当前节点选择并固定该条配置，切图前确认目标节点存在；错误时保留当前地图与可重试弹框。arrival_point_id在目标地图初始化前传入，覆盖该次进入的默认起点，不修改地图自身start_point，后续多个河湾跨图节点不会互相抢用默认落点。

## 当前规则：剧情到达自动触发、普通事件点击触发与温玉佩领取（2026-09-21）

### 领取框视觉微调（2026-09-29）

540×540弹框及原素材保持。标题矩形y54→62，下移8设计px，使文字在抬头区域垂直居中；物品卡宽152，保持3:4及水平居中，顶部最新由y163再下移8px至171。收下按钮中心由(270,455)上移8px至(270,447)，宽度按截图蓝框对应的内侧480px三等分设为160，高度保持57.6px；图片采用非等比填充，仅横向收窄。白色黑体仍26px，标签随按钮铺满并双向居中；错误提示槽调整至y395、高22px，避开下移后的卡片标签。仅改奖励弹框局部布局，储物袋卡片及领取逻辑不变。

### 测试阶段覆盖：温玉佩每次重启可重看领取框（2026-09-29）

受伤弟子事件reward开启`test_replay_on_restart: true`、`test_storage_limit: 2`。每次重新运行仍先完成N37再到N20，第15句后无论旧领取凭据是否存在都显示领取框；同次运行已完成剧情不重复。保留持久化领取记录，不再每次手动清存档。关闭测试开关即可恢复下文原有的一次性奖励表现，其他事件未自动启用。

点击“收下”才统计储物袋实际存放数量（不含阵盘上的物品）：温玉佩为0或1件时新增1件，2件及以上不增加、不削减现有物品，仍关闭弹框继续下一句。即使旧奖励单位已上阵，新发放也使用未占用的单位ID，不覆盖旧物品。候选库存仍先保存再应用，保存失败可重试；弹框出现本身不修改库存。测试配置由事件加载器校验。

对话框或插画剧情层可见时，按一次空格与完成一次鼠标左键点击相同：插画阶段进入首句，对话阶段推进一段，末段后完成剧情。只响应首次按下，系统按键重复不连续跳段。奖励领取层不属于对话推进，空格不能领取或跳过，仍须点击“收下”。

本节覆盖下方针对当前N37／N20主线的旧版“停稳再次点击”和“法器仅为台词”描述，但不把自动触发扩大到所有地图事件。事件JSON可选trigger字段只接受arrival或click，缺省为click。只有明确标记`trigger: "arrival"`的剧情推进事件在到达时自动触发，经过中间节点也生效：每到一个节点立即检查，暂停在该节点，避免大时间步跨过剧情。完成后恢复原路线；原前置条件和运行期完成记录保留，已完成／未解锁／无剧情配置的节点不弹框。

其他普通探索事件默认click模式：到达或沿路线经过事件点均不自动打开；玩家必须已经停在该点，再次点击该路径节点才触发。尚未到达时点击只发出移动命令，远程点击、移动途中点击和点击别的节点均不能触发该事件。当前没有新增普通事件内容，本规则作为后续非剧情节点的默认入口。

N37桥头独白自动开始；N20仍须先完成N37，到达后自动进入插画阶段，再点击进入对话。在弟子第15句“（想了想，从身上取出小法器）那这个先借你。”展示后，下一次推进先进入奖励阶段，不直接跳到下一句。

领取框使用UI-jiaohu-size1.webp（2026-09-30替换，裁切见文首），裁去外围透明画布后按540×540设计尺寸居中；抬头“获得物品”，中部复用储物袋152px宽温玉佩卡片（品质雾／图片／名称／法器标签／占格），下部160×57.6的button-queren.webp按钮内显示26px白色黑体“收下”。随固定16:9画布等比缩放。点击外围、I键不会领取或关闭；点击收下才发放一件并播放gameplay-bag-pick.ogg，之后接回第16句“这是……法器？”。已有测试库存温玉佩保留，因此未装备时领取后该卡数量为2。领取框、地图储物袋和战斗储物袋均仅在数量大于1时显示数量。

奖励由事件JSON的reward字段指定稳定id、item_id、quantity和after_line（从0起）。存档version仍为1，新增可选granted_rewards字典，未含字段的旧档按未领取处理；奖励物品以reward.<奖励id>.<序号>保持独立身份。先构建候选库存并原子保存，成功后才更新活跃库存／关闭弹框，失败显示错误并允许重试，不发物品。持久化领取凭据防止连点、重进地图或重启重播剧情重复发放；事件剧情完成本身仍按旧规则仅运行期记录。奖励道具支持现有装备、阵型与战斗读取，不改战斗不回写边界。

以下为历史实现说明；与本节冲突处以本节为准。

## 新版圆框适配（2026-09-16）

map-dialogue源图1835×470，可见裁切[10,33,1807,409]。圆孔中心原图约(256,237.5)，最大开口半径约180.1；在裁切后坐标配置portrait_slot=[62,20.5,368,368]，头像半径184略压入金边下，复用portrait_mask.gdshader裁圆，并先画头像、再画对话框，避免缝隙及遮盖金边。每个说话者使用独立居中方形Atlas：player-1-1原图490×490取[22,18,448,448]，npc-qlzdz-1原图715×715取[27,27,664,664]，避开透明边缘并保持图像等比。

文字区改为裁切后[475,95,1250,220]；文字字号仍依原1930×371基准计算，避免背景尺寸更换使31px楷体意外变大。新对话框宽度仍1126.4（1080p），高度随原图比例变为254.95，中心仍屏高75%；事件图自动按新的对话上沿适配，保持间隔。JSON配置负责人物差异，不改稳定说话者ID、剧情数据或源图片。

## N20插画与双人对话扩展

用户指定中央小屋旁的N20。沿用到达后再次点击的互动入口，先同时显示map-event-frame.webp（用户称map-event-pic，工作区实际文件名为frame）和map-event-1-1.webp，再点击才显示首句对话。扩展既有dialogue事件的可选illustration阶段、speakers头像表与逐句line_speakers；保留原N37纯文字事件格式及稳定ID。每次点击推进一个段落，按说话者切换npc-qlzdz-1/player-1-1头像，完整保存20句原文。法器、采集、治疗均为台词，此轮不引入相关玩法或奖励。

用户最新调整：事件框在初次放大三分之一后，再等比放大25%（相对最初基准为5/3），以旧底边中心为锚点向上扩展，底边及水平中心不动；旧版顶部30%仅用作计算原尺寸的基准，当前顶部不再锁定30%；对话框中心为屏高75%，背景及头像尺寸保持；文字改为系统楷体KaiTi，1080p字号32→31，其余窗口按原响应字号减1。插画从首次打开起就预留对话空间，与下方对话框间隔16逻辑像素（随窗口宽度缩放），两阶段不跳变。插画在对话期间保留；所有图片保持源比例，内容居中覆盖内框窗口并由边框遮住边缘。N20要求先完成N37的独白，requires_completed引用稳定事件ID。纯状态增加illustration阶段，下次点击才进入dialogue第0段；20段读完再点击一次完成，隐藏N20路标及图标，运行期不重复、重启重置。与N37共享输入锁定和完成记录，不发放台词中提到的法器或任务奖励。

## 已完成的N37机制

本轮首次加入地图事件：截图指定的大桥西端N37。玩家先通过原有寻路到达节点，停稳后再次左键单击该路径节点才触发；路过、刚到达、点击路标图片或远程点击均不直接打开事件。其他路标保留，未配置内容时不编造互动。

事件采用JSON稳定ID、节点ID及类型。MapEventRegistry负责加载/校验，MapEventState负责触发、逐句进度及完成记录，保持独立于节点、动画和时钟。MapScreen处理地图输入并发出命令，MapDialogue负责图片/头像/文字展示。该入口可供后续事件类型扩展，本轮只支持dialogue。

用户确认完成记录仅保留当前运行期间，重启游戏重置。记录以事件稳定ID保存在纯状态的运行期共享字典；不写磁盘、不引入存档。完成后隐藏该节点的Sign及内部图案，保留路径点和连接，不修改布局源场景。重新实例化地图时按完成记录恢复隐藏状态。

对话使用map-dialogue.webp背景（裁去透明边缘，保留源图宽高比），整体中心在屏幕(x=50%,y=75%)，底板按既有屏宽比例显示，头像各自裁去透明边距并填满左侧圆框，文字改用系统楷体KaiTi，字号在初版响应式计算值上减1（1080p为31px）并在缩小后的右侧区域排版，跟随窗口不跟随地图平移/缩放。player-1-1.webp按独立校准的有效圆形区域等比填满左侧圆框、居中并以圆形蒙版裁切，右侧逐句显示用户原文。用户确认对话为全屏输入模态：暂时锁定地图移动、拖动和缩放，任意位置左键单击推进；第5句再点一次关闭并完成。开启事件的原始点击不同时推进第一句，关闭的点击不穿透到地图；右键、滚轮、拖动、失焦后的抬键均不推进。

验证覆盖：未到达不能触发、到达不自动打开、停稳再次点击触发、逐句显示、完成后不重复及只隐藏目标路标；继续覆盖地图拖动/缩放/改道、所有旧战斗检查，并渲染核对画框位置、头像与中文文本。
