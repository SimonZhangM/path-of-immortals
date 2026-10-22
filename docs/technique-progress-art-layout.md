# 功法中栏图文与技能树定位基准（2026-10-17）

## 风系八重底图更新（2026-10-21）

重新导入用户更新的`UI-wind-middown-8.webp`，源尺寸仍1605×567、裁切仍[14,79,1576,456]；青冥破空诀／听风无影诀共用此新图，既有图标、数字与文字坐标保持。当前SHA-256为`aab82414eb0338fbce63b1f5b3c110df722e90536e9e8197fea6783ae1fe6f46`，两书baseline同步。七系八重右栏现已全部接齐，见[法术右栏](technique-spell-detail-layout.md)与[强化右栏](technique-enhancement-detail-layout.md)。

## 圆环两侧连接遮罩收窄（2026-10-20最新）

共用rank_glow shader的纵向完全抑制区由圆心±8源图px收为y=-4～+3：上端下收4、下端上收5，高度7；上下5px渐变分别为-9～-4及+3～+8，总高17。横向ring_radius-1～ring_radius+2的过渡保持，原图横线不改，七系五重／八重均生效。123项静态渲染与连接线核心像素检查通过，未运行鼠标／键盘检查。

## 右栏玄冰枪首例（2026-10-20最新）

《寒月凝冰诀》第3重已接新法术右栏，其余页面仍为空。新底图完整画布与三个勾／黄色按钮的固定坐标独立记录于[右栏定位说明](technique-spell-detail-layout.md)，不混用中栏源图坐标。顶部进度读实际状态，黄色按钮暂为展示，覆盖下方右栏全部清空的历史描述。

## 七系选中主题与装饰覆盖修正（2026-10-19最新）

选中／悬停光复用technique_categories.json各元素color，亮部由该主题向白色混合，不再固定青蓝。标题文字保护框以栏中心定位，五重宽164、八重奇数100、偶数148源图px，高28、顶为card.y+11；两端金色装饰在保护框之外，完整参加光效。圆环半径分别为五重48、八重奇数44、八重偶数39，去掉额外横向beam，并屏蔽圆环外连接线附近的叠加光，保持原连接线像素和粗细。原按钮命中／图文坐标保持。

右栏清除旧学习详情、强化按钮和对应确认回调，只剩原背景与外框；左侧重数标签继续读取learning_state。此前右栏概念稿尚未接入。以上覆盖下方旧“统一青蓝／短连接光／右栏沿旧实现”记录。

视觉检查使用TECHNIQUE_RANK_VISUAL_ONLY=1运行technique_rank_selection_tests.gd -Render，仅静态切换／渲染，不执行鼠标键盘输入；123项含35本主题与右栏空态，以及水系四种框架标题两端有高亮、连接线两侧像素不变。图例artifacts/technique-rank-revised-water_03-detail.png、technique-rank-theme-fire-detail.png，完整结果见PROJECT_PROGRESS顶部。

## 重数按钮与青蓝选中框（2026-10-19）

map_technique_progress_art的RankSelection层使用独立原生Button，圆环为圆形命中、下方整栏为矩形命中；互斥选择，首次第1重，各书浏览重数仅存当前组件内存。按钮点击或键盘激活发送rank_selected(level)，不调用学习或分支确认。悬停／焦点亮度0.35，选中1.0；聚焦重数按钮时允许ui_accept及原生导航键，G／Esc沿用退出行为。

四份布局新增selection_frames：8的spell_card=[55,244,132,219]、choice_card=[200,243,224,210]（加现有column_offsets、group_pitch与source_origin_offset后取得源图实际坐标）；52a／52b的first_card=[73,192,260,262]，53为[18,193,308,269]（按column_offsets平移）。圆心直接沿现有数字模板与rank_offsets，不重新测一套圆心；布局缩放统一跟随display_crop。

map_technique_rank_glow.gdshader采样当前功法原底图，对圆环和栏框的彩色／金色轮廓叠加青蓝亮边、外光、短横向光及顶端亮点；排除标题文字，保留暗部雕纹。不生成或覆盖美术素材，无动画时间／每帧脚本轮询，技能文字与独立图片位置保持。新增tests/technique_rank_selection_tests.gd为直接输入与渲染专项；图例artifacts/technique-rank-water-third-1920-detail.png及-2560-detail.png。右侧详情仍沿现有实现，概念稿未在此步骤接入。

## 七系八重黄色圆环新版（2026-10-19最新）

七张UI-{element}-middown-8.webp新版只调整第2／4／6／8栏的黄色圆环，14本共用的rank_offsets已对应同步。相对2026-10-18基准，四项偏移分别增加(-1,+1)、(-1,+2)、(0,+2)、(-1,+2)源图px；最终四项rank_offsets分别为[3,2]、[-1,2]、[0,2]、[-1,2]。模板下数字中心为(289,142)、(679,142)、(1074,142)、(1467,142)。不改变column_offsets、奇数重数、source_origin_offset、裁切、技能／名称／说明模板及显示比例。

新版wood SHA-256为88f85c7f6c25eecd48a8f20c0b8260e5d9fc74637eb282d209da1a539ed8d73c；其他六系实际基准存technique_progress_books.json各自layout_overrides。7图导入缓存已同步、源图字节保持。14本三分辨率隔离实际组件静态渲染1680项通过，七系数字目视通过；artifacts/eight-rings-review-20261019.jpg为圆环合图。此节覆盖下方八重旧偶数圆心／哈希记录。

## 全部book右移10px／书名投影（2026-10-19最新）

七系35本中栏book共用BOOK_OFFSET_SCREEN_X=10，_fit_book在原水平定位基础上加10／全局X缩放，实现所有分辨率均向右10屏幕px；变换变化时同步重新布局。图案尺寸、可见边界裁切和原垂直中心保持，覆盖下方旧“水平位置不变”说明。左栏BookName新增Color.BLACK投影、shadow_offset_x=1、shadow_offset_y=1，书名原字号／字体及布局保持；不移动booksimple。金系五本三分辨率466项必要静态渲染通过，完整页面和左栏局部目视通过。

## 六系状态小图与共用底框（2026-10-19最新）

六本{element}_03内容的90项choices现均有status_icons：第1／2／4／5重各单图，第三重各双图，共108图、90框。沿木系53全部几何：单图32；双图各28.8、间距0；单框70×69、双框100×69，以圆心居中整组，底框上移2屏幕px。各系直接共用现有金色UI-wood-middown-53-button.webp，原有reserve_status_space保持，名称不会再额外下移。木系蚀骨／紧缚／固根的1px微调仅属于木系，未复制到新内容。通用状态图来自combat_status_keywords，灵盾例外沿map_buffs的icon_path；不新增悬浮或玩法。

| 系 | 第1／2／4／5重依次 | 第三重第1项 | 第三重第2项 | 第三重第3项 |
| --- | --- | --- | --- | --- |
| 金 | 反锋、锋痕、流血 | 反锋＋锋痕 | 锋痕＋流血 | 流血＋反锋 |
| 水 | 润脉、枯脉、寒霜 | 润脉＋灵盾 | 枯脉＋寒霜 | 寒霜＋润脉 |
| 火 | 附炎、灼烧、破甲 | 附炎＋灼烧 | 灼烧＋附炎 | 破甲＋灼烧 |
| 土 | 坚韧、疲惫、重伤 | 坚韧＋疲惫 | 疲惫＋重伤 | 重伤＋坚韧 |
| 风 | 轻灵、失衡、驱散 | 轻灵＋失衡 | 失衡＋轻灵 | 驱散＋失衡 |
| 雷 | 雷蕴、雷印、连环 | 雷蕴＋雷印 | 雷印＋连环 | 连环＋雷蕴 |

雷蕴图覆盖其凝成的雷盾相关分支，与通用关键词related_keywords一致；水系盈护的灵盾使用当前player-status-sheild.webp。上述左右顺序按效果来源→作用对象／产物排列。

tests/technique_six_elements_progress_preview.gd支持TECHNIQUE_PROGRESS_STATUS_ONLY=1，仅检查每系第3本；本次六批各3974项、共23844项三分辨率静态渲染通过，六张artifacts/technique-progress-{element}-03.png逐本目视通过。覆盖下方状态图待接说明，技能图与布局原基准保持。

## 六系354张效果图与文件名同步（2026-10-19最新）

30份technique_progress_{element}_{slug}.json的spell／choices已补齐icon，分别使用各自assets/UI-{element}-{slug}-effect-{NN}-{skill}.webp。每系10＋10＋15＋12＋12＝59张，六系354张；木系59张保持，七系共413张。五重顺stages→choices，八重每组spell在先、choices随后，对应两位序号01起。现有slot几何、52a／52b下移5屏幕px、名称／重数／描述不变；1px金边、3px圆角、376×376源图mipmap沿既有组件，未修改生产脚本或原图片像素。

六系状态书仍reserve_status_space=true，不借木系状态图或圆框；仅具体技能大图接齐。本节覆盖下方“省略icon”历史状态。六系静态预览更新为有图核验，每系7021项、三分辨率总42126项通过，包含每图所属系／书／序号、纹理／mipmap、样式、槽位与不遮文字；30本渲染逐本目视通过。截图仍在artifacts/progress-review-{element}.jpg，源与缓存均已核验。

金、水31张assets游戏素材根据现行branch_display_names从旧拼音名改名，表中新文件名只替换最后的技能拼音，其余前缀／序号保持；对应JSON及Godot导入均同步。output中的历史源图、生成计划及其原文件名保留，追溯时以元素／书／序号和下表对应。

| 游戏素材旧文件名（省略.webp） | 新文件名末尾 | 当前显示名 |
| --- | --- | --- |
| UI-metal-gengjinzhenjie-effect-01-ruijin | gengjinningfeng | 庚金凝锋 |
| UI-metal-gengjinzhenjie-effect-02-bingxin | baibingtongxin | 百兵通心 |
| UI-metal-gengjinzhenjie-effect-03-chengke | chengkezengwei | 乘克增威 |
| UI-metal-gengjinzhenjie-effect-04-nike | nikehushen | 逆克护身 |
| UI-metal-gengjinzhenjie-effect-05-neiming | fanfengneiming | 反锋内鸣 |
| UI-metal-gengjinzhenjie-effect-06-waiming | henxuewaiming | 痕血外鸣 |
| UI-metal-gengjinzhenjie-effect-07-qishi | gengjinqishi | 庚金启式 |
| UI-metal-gengjinzhenjie-effect-08-chengshi | gengjinchengshi | 庚金承式 |
| UI-metal-jinshacangfengjing-effect-07-fanfengshenghen | shenghen | 生痕 |
| UI-metal-jinshacangfengjing-effect-08-fenghenjianxue | jianxue | 见血 |
| UI-metal-jinshacangfengjing-effect-09-xueyangfengshi | yangfeng | 养锋 |
| UI-metal-jinshacangfengjing-effect-13-fanfengzhenbing | zhenbing | 镇兵 |
| UI-metal-jinshacangfengjing-effect-14-fenghenrugu | tougu | 透骨 |
| UI-metal-jinshacangfengjing-effect-15-xueshibujue | xuxue | 续血 |
| UI-metal-xuanjinbailianlu-effect-10-huafanweijian | jianlian | 简炼 |
| UI-water-hanmailiuzhuanjing-effect-07-yingliuchenghu | yinghu | 盈护 |
| UI-water-hanmailiuzhuanjing-effect-08-kujishenghan | shenghan | 生寒 |
| UI-water-hanmailiuzhuanjing-effect-09-shuanghuihuoshui | huirun | 回润 |
| UI-water-hanmailiuzhuanjing-effect-13-zhouliubuxi | zhouliu | 周流 |
| UI-water-hanmailiuzhuanjing-effect-14-kuhaiduanliu | duanliu | 断流 |
| UI-water-hanmailiuzhuanjing-effect-15-hanchaoliushuang | liushuang | 留霜 |
| UI-water-lingmoxuanfulu-effect-09-yifurushen | shenzhuan | 神篆 |
| UI-water-lingmoxuanfulu-effect-10-baifuchengshu | baifu | 百符 |
| UI-water-xuanshuizhenjie-effect-01-shuifeng | xuanshuiningfeng | 玄水凝锋 |
| UI-water-xuanshuizhenjie-effect-02-liuxi | xuanshuiyangxi | 玄水养息 |
| UI-water-xuanshuizhenjie-effect-03-chengke | chengkezengwei | 乘克增威 |
| UI-water-xuanshuizhenjie-effect-04-nike | nikehushen | 逆克护身 |
| UI-water-xuanshuizhenjie-effect-05-neiming | runmaineiming | 润脉内鸣 |
| UI-water-xuanshuizhenjie-effect-06-waiming | kushuangwaiming | 枯霜外鸣 |
| UI-water-xuanshuizhenjie-effect-07-qishi | xuanshuiqishi | 玄水启式 |
| UI-water-xuanshuizhenjie-effect-08-chengshi | xuanshuichengshi | 玄水承式 |

## 六系30本框架与文字（2026-10-18最新）

technique_progress_books.json现登记七系35本。新增六系按各书ID尾号01→52a、02→52b、03→53、04／05→8；每本layout复用木系对应几何JSON，layout_overrides.texture指向assets/UI-{metal|water|fire|earth|wind|thunder}-middown-{52a|52b|53|8}.webp，baseline_sha256记录该实际源图。24张均1605×567、mipmap开启，维持共同display_crop、placement_crop及下部中心，不改素材像素或借用木系配色。

每书内容为data/ui/technique_progress_{element}_{slug}.json。354个名称取《七系功法简明介绍》现行定稿，与docs版本逐项一致；战斗96条effect短语取output/imagegen版本现有括号短语。description保留对应完整效果及原数值供后续展示用，本轮不增加悬浮行为。重数按stages.level绘1～5／1～8，与木系同样式。五字法术名在原中心拆2＋3两行（当前仅玄庚归一剑），其余名称沿原排版。

本次按用户要求不接具体技能／状态图片：记录省略icon，_add_icon允许跳过；icon_rect／choice_icon_rect仍返回完整预留位置，未来只需补icon路径。状态书reserve_status_space=true，名称保持木系状态栏底部高度，为状态小图预留中间一行；不显示木系状态小图或圆框。已有木系记录与素材不变。

静态预览tests/technique_six_elements_progress_preview.gd，环境变量TECHNIQUE_PROGRESS_ELEMENT可选metal／water／fire／earth／wind／thunder，默认metal。六系各2128项、三分辨率合计12768项通过；artifacts/technique-progress-{element}-{01..05}.png为下部截图，progress-review-{element}.jpg为五书合图，逐本目视通过。展示未接学习或分支确认操作。

## 八重新版与52／53统一中心（2026-10-18最新）

UI-wood-middown-8.webp仍供青萝化生诀wood_05和万木生杀诀wood_04共用。新版完整画布1605×567；display_crop=(14,79,1576,456)，placement_crop=(54,138,1554,414)，center_in_lower_panel=true。与52a／52b／53相同倍率、显示尺寸及中心，标准中栏局部中心(601.75,697.5)，源裁切中心(802,307)。源图不缩放修改，运行展示仍等比适配；本节覆盖下方旧1645×630与八重旧定位记录。

新源图相对原模板统一平移(-27,-51)，由source_origin_offset保存，source_column_offset对图标／名称／说明及独立圆环偏移共同加此量。保留原group_pitch=394、column_offsets与rank_offsets，图标尺寸、字体、说明额外下移2屏幕px均不变。JSON内icon_templates／icon_inner_rects与脚本caption模板仍为历史模板坐标，应用统一偏移后才是新源图坐标，后续换图应沿这一映射。

新源图实测圆环中心从左到右：(94,140)、(290,141)、(485,141)、(680,140)、(878,140)、(1074,140)、(1269,140)、(1468,140)。首组图标外框：法术(45,243,98,97)、强化左(197,250,84,84)、强化右(297,250,84,84)；后续三组法术X=436／829／1221，强化左右X=587／687、982／1082、1375／1475，Y及尺寸保持。法术名源模板Y=362，强化名Y=343，括号说明Y=367，名称各自与图标同中心X。

新基准SHA-256：9f9ee197255e5ae37da3921b97a7c11e167497befa40efcd0edb53157c45f574；原字节快照artifacts/wood-middown-8-centered-baseline-20261018-9f9ee197.webp。旧原图快照仍保留；artifacts不入Git，JSON与本节为持久定位说明。

八重静态预览1428项、共享框架预览5931项三分辨率通过；两书下部截图为artifacts/technique-progress-middown.png／technique-progress-middown-wanmu.png，逐张目视确认。透明外缘留白以可见图案顶边判定与进度标题的间距。无鼠标行为或玩法变更。

## 七系35本上部齐套（2026-10-18最新）

新增water／fire／earth／wind／thunder各01～05共25条记录，沿technique_book_art.json的稳定书目与拼音前缀绑定对应title／label／book／calligraphy.webp。100图开启mipmap，源字节保持且缓存同步。诗意配词与完整来历逐本取《七系功法_35本四栏文案.md》，诗句分两行、来历测宽取首20字符。共用木系Overview全部布局与字体、曲线衬底、书体居中和书法处理，不增加按系分支；已有木金10条记录保持。上部现在35本齐全，下部仍由独立登记表管理，仅木系已有技能树。

静态预览tests/technique_five_elements_overview_preview.gd继承金系预览，通过环境变量TECHNIQUE_PREVIEW_ELEMENT选择water／fire／earth／wind／thunder，默认water。每批五书三分辨率466项，共2330项通过；artifacts/technique-overview-{slug}.png为上部、technique-{element}-{slug}.png为全页，overview-review-{element}.jpg为五书审阅合图。五组渲染逐本目视无溢出或重叠，无鼠标行为检查。

## 金系五本上部图文（2026-10-18最新）

metal_01～05依次玄金百炼录、庚金真解、金煞藏锋经、玄庚剑诀、百兵御灵诀，现与木系五本共同登记technique_overviews.json。各书使用对应UI-metal-{slug}-title／label／book／calligraphy.webp；20图mipmap开启。诗句与完整来历来自《七系功法_35本四栏文案.md》，诗句按两行排布，来历宽度取首20字符测量。复用现有Overview全部布局及文字／书图／书法处理，无金系专用脚本；下部仍独立登记且尚未接金系。

专项tests/technique_metal_overview_preview.gd -Render，五书三分辨率466项通过。artifacts/technique-overview-{slug}.png为上部局部，technique-metal-{slug}.png为全页，五本逐张目视通过；木系原数据保持。

## 三处状态小图微调（2026-10-18最新）

technique_progress_kurong.json中，第2栏蚀骨／紧缚、第4栏固根的status_icons单项screen_offset_x=-1，按屏幕像素仅左移小图；其他状态图默认0。底框、名称和大图位置保持，原source_rect仍保存未微调的几何中心。三分辨率5931项静态检查与2K渲染通过。

## 全部圆框上移与第三栏共用宽框（2026-10-18最新）

status_backplate.columns=[0,1,2,3,4]，screen_offset_y=-2，display_width=70，paired_width=100；每组状态仅建一个底框，共15个。普通底框70×69，第三栏横向拉伸至100×69，素材圆心X由35映射为50，以整组中线左右对称；高度保持原69，所有底框再上移2屏幕px。

第三栏paired_status_icon_scale=0.9、paired_status_icon_gap=0：32×32变28.8×28.8，两图原4间距减为0，组中心维持原位（缩小后垂直居中补偿）。单图栏状态图仍32；底框上移不带动状态图或名称。配置单位除screen_offset_y外沿源图像素／原共同倍率，原素材字节保持。三分辨率5823项检查及渲染通过，覆盖下方第三栏不加框的历史说明。

## 枯荣状态圆框底图（2026-10-18最新）

53布局status_backplate配置：texture=res://assets/UI-wood-middown-53-button.webp，columns=[0,1,3,4]（零基，对应第1、2、4、5栏），circle_center=[35,34]，display_width=70。源图70×69，遵用户实测不额外缩放，整体仍随技能树原倍率；每栏3个，共12个底框。以状态图矩形中心减素材圆心定位，在状态图之前绘制；32px状态图及名称位置不变，第3栏双图不加框。底图mipmap开启，原文件字节保持，仍为静态装饰，不新增鼠标交互。

三分辨率5661项静态检查通过，2K渲染确认圆框完整、圆心一致及文字可见。

## 木系底图通用命名（2026-10-18最新）

三张底图统一去掉书名段，当前资源为assets/UI-wood-middown-52a.webp（百兽）、UI-wood-middown-52b.webp（青木）、UI-wood-middown-53.webp（枯荣）。各自technique_progress_art_52a／52b／53.json引用同步，导入UID与mipmap设置保持；只调整路径，原图片字节、裁切、坐标与显示比例不变。

青萝／万木共用的八重底图同步改为assets/UI-wood-middown-8.webp，由technique_progress_art.json引用；两本继续共用原图，不改变内容布局及技能映射。

## 五重圆环数字（2026-10-18最新）

百兽／青木／枯荣按stages.level逐栏显示1～5。52a／52b的first_rank_rect=(169,99,66,66)，53=(139,99,66,66)，均为源图坐标；后续圆环沿对应column_offsets平移。rank_font_size=36，复用青萝绿色圆环楷体、#f3f0dc与原生像素对齐，不应用overlay_offset_screen_y。保留所有技能图／名称／状态图位置。三分辨率5280项静态检查与三本渲染通过；覆盖历史“无圆环数字”状态。

## 五重内容偏移与枯荣状态行（2026-10-18最新）

52a／52b：overlay_offset_screen_y=5，所有技能图和名称显示时统一下移5屏幕px，三种分辨率均相同；原first_column_icon_rects与choice_icon_rect基准返回值不改。状态图数组独立于原技能icons，切书同时清空。

53：技能大图不动，现行二至三字名称整体下移40源图px，仍沿青萝第一重字体／字号／色彩。状态行在大图底＋18源图px，单图32×32，居中；双图间距4、整组居中。名称顶部＝大图底＋22＋40。JSON字段status_name_offset_y／status_icon_size／status_icon_gap／status_icon_top_gap记录布局，所有新图均忽略鼠标。

状态关联记录于technique_progress_kurong.json，各项使用既有combat_status_keywords.json中的图：第一、二、四、五重依次为生机／毒蚀／缠绕；第三重依次毒蚀＋生机、缠绕＋毒蚀、缠绕＋生机。生机障仍归生机分支。18个状态图裁透明留白、等比显示，未新增效果或学习操作。保留已由名称定稿任务更新的青木／枯荣名称。

三分辨率静态预览4440项通过，枯荣及青木2K渲染确认无交叠。覆盖下方旧“所有图标／名称不动”及“无状态小图”历史描述。

## 木系名称定稿（2026-10-18最新）

青木前四重8项改为四字名称，其中木息为「青木护生」；枯荣后三重9项改为二至三字，其中缠生回息为「缠生」。完整映射见核心01第1.66节。25个名称现均单行显示；下方53四字名2＋2是历史版及通用长名兜底，本版枯荣不再使用。图标、字体、坐标及效果不变。


## 52a／52b分书与53更新（2026-10-18最新）

百兽驭灵录wood_01使用52a（技能二选一），青木真解wood_02使用52b（强化二选一），枯荣wood_03使用新版53。布局分别为technique_progress_art_52a.json／52b.json／53.json；旧52图片及旧52布局已移除。下文52的几何记录同时适用于52a与52b：画布1605×567、共同display_crop=(14,79,1576,456)、同一倍率与下部中心，所有图标矩形／列偏移／名称坐标不调整。

三图最新SHA-256如下（覆盖后文旧哈希），原字节快照路径见各JSON的baseline_snapshot：

- 52a：`06265fb86d9c85d7b20f240445232e118075361d7a41e247706a15c6a99efa44`
- 52b：`6583246db86d67210211afd588bed6384239aa4ab7ea50b8bac4d2ce5b305f9e`
- 53：`92022c5fab5ad33394771045487a46af8f7af74927fb711378c60fd635d6d44e`

三图已启用mipmap且导入缓存与源MD5一致；三分辨率2403项静态检查、三本中栏目视确认通过。

## 木系五本59图与五重名称（2026-10-18最新）

覆盖下方历史frame_only／等待去样例图的状态。wood_01／02／03分别绑定technique_progress_baishou.json、technique_progress_qingmu.json、technique_progress_kurong.json，按简明介绍逐重、同重从左至右排列10／10／15项。wood_04／05原12项绑定保留，全部59张效果图已导入最新版并启用mipmap。底图样例由运行时独立图覆盖，源素材不改；以下共同显示裁切和最新坐标仍有效。

五重名称复用青萝第一重SpellName样式：HarmonyOS Sans SC Regular，#f3f0dc，源字号25并加1原生字号，2K为26px；取消继承缩放后按整数屏幕像素绘字。每个图标中心X对应名称中心X，源矩形Y＝图标底＋22，52名称宽112／高26，53宽94、短名高26／四字名高58；53四字名2＋2换行，保持相同字号。统一1设计px金边、3设计px圆角。仅新增图标和名称，无额外效果文案／圆环数字或学习操作。

静态预览命令仍为tests/technique_choice_frames_preview.gd -Render，三分辨率2403项通过。五本中栏预览artifacts/technique-frame-wood-01.png至05.png，逐张目视确认；59个导入缓存与源图MD5一致。

## 52／53最新共同显示尺寸与图标记录（2026-10-18）

本节覆盖下方旧1645×630画布、52／53各自不同裁切及旧首栏坐标。两张最新版完整源图均1605×567，统一固定display_crop=(14,79,1576,456)，裁切中心为源图(802,307)；仍用共同placement_crop作为倍率参考，两者没有各自的缩放系数。center_in_lower_panel=true，完整显示矩形中心同时对齐下部四边容器中心，宽高／位置完全一致；保留源图内部两类栏框自身的宽度差异，不拉伸图案。

以下为首栏图标外矩形，含细边框，单位源图px，格式x,y,宽,高：

| 模式 | 首栏选项 | 最新矩形 |
| --- | --- | --- |
| 5×2 | 左 | 96,265,98,97 |
| 5×2 | 右 | 210,265,98,97 |
| 5×3 | 左 | 31,265,88,88 |
| 5×3 | 中 | 128,265,88,88 |
| 5×3 | 右 | 225,265,88,88 |

52各栏x偏移仍0／300／600／903／1203，53仍0／315／630／945／1260。`choice_icon_rect`自动按新裁切和共同倍率映射，图标去除后仍使用这些固定值。机器记录见technique_progress_art_52.json／53.json。

52 SHA-256：015c782cefd88b068b94d653de625fdc434b92a6e68ea50a6e51e78b480edaf1；53：f8da79a532502f5aab3978b6c2a455e59252b4c882c6486c9150f95bdd6b92ee。原字节快照分别为artifacts/qingluohuashengjue-middown-52-baseline-20261018-015c782c.webp与53-baseline-20261018-f8da79a5.webp（相同路径前缀）；旧快照保留。441项三分辨率静态检查通过，52与53显示矩形一致，最新渲染仍为technique-frame-wood-01.png／02.png／03.png。

## book视觉中心（2026-10-18最新）

五本木系book中心位于中栏顶边y0与进度线y485的中点y242.5，随栏高／分隔线变化。父页传入book_center_y；Overview._fit_book使用Metrics.visible_rect（alpha>0.02）排除几乎透明的导出杂点，不再让used_rect留白参与中心计算。保留按原book槽与used_rect求得的缩放倍率，裁切后宽高为visible_rect.size×原倍率，X加回可见边界相对原边界的偏移，因此书体实际大小／水平位置不变，仅修正纵向中心。Atlas运行时裁切、不改源像素；其他图片／文字保持。静态专项新增五书三分辨率中心／倍率／X断言，465项通过，五图已查看。

## 五重二选一／三选一定位（旧版基准，最新坐标见文首）

最新居中：两套center_in_lower_panel=true，完整display_crop（含圆环、栏框、题字）的中心均对齐下部四边容器中心。标准中栏内为(601.75,697.5)，随容器尺寸变化；保留原倍率，覆盖初次沿旧middown偏移的定位。新版52的整个内容右移13源图px，以下坐标／裁切／哈希均已更新，53源坐标不变。

枯荣生灭经wood_03使用UI-wood-middown-53；百兽驭灵录wood_01及青木真解wood_02使用middown-52。登记项frame_only=true，只显示原底图及内嵌的首栏样例图标，暂不叠数字、技能名或独立技能图。原青萝／万木内容保持；其他元素同模式可使用这两套布局登记，当前未批量接入。

源画布均1645×630，原点为完整原图左上角，单位为源图px。以下矩形含图标自带细框，格式x,y,宽,高，后续移除自带图标时保持画布和框架位置，直接按矩形叠图：

| 模式 | 首栏选项 | 图标矩形 |
| --- | --- | --- |
| 5×2 | 左 | 118,316,98,97 |
| 5×2 | 右 | 232,316,98,97 |
| 5×3 | 左 | 53,316,88,88 |
| 5×3 | 中 | 150,316,88,88 |
| 5×3 | 右 | 247,316,88,88 |

52后续栏相对首栏x偏移为0／300／600／903／1203；53为0／315／630／945／1260，y不变。后续槽为首栏矩形沿实测栏框偏移投影，当前仅首栏存在样例图标。接口`choice_icon_rect(column_index, option_index)`两索引均从0开始，返回当前显示局部矩形；无效索引返回空矩形，原八重使用的icon_rect接口保持。

机器记录：[5×2百兽](../data/ui/technique_progress_art_52a.json)／[5×2青木](../data/ui/technique_progress_art_52b.json)、[5×3](../data/ui/technique_progress_art_53.json)。52最新源SHA-256为19b80599506d1c7a6e822c430a28780e3f5783e83dde1e605184627d05591e0e；53为9870558a87392c975acd22c26a52a6bb4b17ceaf0f6c92796fff9b7fa576dd68。52新版原字节快照在artifacts/qingluohuashengjue-middown-52-centered-baseline-20261018.webp，旧52快照保留；53快照为artifacts/qingluohuashengjue-middown-53-baseline-20261018.webp；artifacts不入Git，JSON与本文是持久坐标记录。

两套placement_crop固定沿原middown的(54,138,1554,414)仅计算比例，实际display_crop分别为52的(91,132,1468,442)、53的(36,132,1576,442)，避免新框架／题字被旧裁切截断。显示位置＝下部容器中心−显示尺寸÷2；图片等比，切书刷新布局，mipmap开启。换图不要按新透明包围盒重新定位；若再移动栏框需重新测量。

专项`tests/technique_choice_frames_preview.gd -Render`三分辨率426项通过；2K中栏截图artifacts/technique-frame-wood-01.png／02.png／03.png。已目视百兽及枯荣确认完整框架，无玩法／鼠标操作测试。

## 木系五本上部独立展示（2026-10-18最新）

`data/ui/technique_overviews.json`现登记wood_01～05：百兽驭灵录／青木真解／枯荣生灭经／万木生杀诀／青萝化生诀，覆盖下方上部仅青萝或仅两书的历史范围。各自绑定assets中的title／label／book／calligraphy，诗句与完整来历来自`output/imagegen/七系功法_35本四栏文案.md`；青木单句按逗号分成两行，其余保持原诗意配词。新增三本的origin_width_sample按同款约19字测宽，字体／颜色／原生像素／渐隐与书法墨底算法不变，未另建单书脚本或改公共布局。百兽对应baishouyulinglu，不使用另存baishouyulingjue图。

新增12图mipmap，五本book已刷新；左栏booksimple不受影响。上部以自身登记表独立决定显隐，下部仍严格使用原青萝／万木登记表，新三本不显示他书技能树，其他30书不显示木系上部。纯静态专项`tests/technique_wood_overview_preview.gd -Render`覆盖五书三分辨率，2K上部截图为`artifacts/technique-overview-<拼音>.png`、整屏为`technique-wood-<拼音>.png`；本轮420项通过。只接展示，不改变学习、解锁、战斗或存档。

## 下部蒙版最新（2026-10-17）

ProgressShade改为ColorRect，使用map_technique_progress_shade.gdshader。范围仍为中间分隔线下方至栏底内缩2px，位于图文下层；RGB与上部一致(0.015,0.03,0.045)，alpha=0.82×(1−y^2.2)×左右羽化。按最新反馈，左右各5%收窄为0.5%宽度smoothstep渐入／渐出，标准2K画面每侧约8px。由顶部深、先慢后快向下透明，底端alpha=0。公共设置同时应用青萝与万木；覆盖下方旧#15181cad均匀灰蒙版说明，字体／图标／底图不改。最新1308项必要静态检查及渲染通过。

## 万木接入与空框复用（2026-10-17最新）

用户明确允许万木生杀诀复用青萝更新后的空框，覆盖下方底图只供青萝的旧范围；两本的上部图片、诗句／介绍和下部12图标／文案各自独立。`data/ui/technique_progress_books.json`用稳定书ID登记布局与内容：wood_04读取technique_progress_wanmu.json，wood_05读取technique_progress_qingluo.json，均用technique_progress_art.json的当前空框／偏移。切书后清理旧图标／文字并重建，未登记的33本隐藏专用内容；仍未接实际学习或二选一操作。

万木12图按01～12依次对应青木刺／锐刺／毒芽、青藤刃／连刃／缚刃、森罗灵矢／穿林／毒翎、万木森罗／森罗尽发／枯荣夺生。强化短语分别为本体增伤／命中施毒、减耗提速／命中加缠、本体增伤／伤血施毒、本体增伤／伤血生机，来源为简明介绍。延续现有字号／华为Regular名称／楷体说明、1px金边／3px圆角及下方逐栏偏移。

上部绑定表technique_overviews.json新增万木自身title／label／book／calligraphy及四栏文案，诗句按逗号分两行，完整描述自然五行（2K26px），同样原生绘字和米白色。书法使用既有运行时墨底渐隐；16张展示图开启mipmap，源素材未改。两书三分辨率1308项必要静态检查通过；万木完整中栏预览为artifacts/technique-progress-heading-middle-wanmu.png，青萝原预览文件名保持。

## 新版底图逐栏偏移（2026-10-17最新）

更新素材SHA-256为9224c9c7e887c1e27e0589856d9435a711f2dcda2af649b2daaf151c23e3490c。画布1645×630、裁切(54,138,1554,414)保持；下方原始快照与模板仍保留，运行时须叠加以下实测偏移，不再只按394组距计算最终位置。

| 栏位 | 栏框／图标／名称／说明偏移(x,y) | 圆环数字偏移(x,y) |
| --- | --- | --- |
| 1 | 0,0 | 0,0 |
| 2 | 4,0 | 4,1 |
| 3 | -3,0 | -3,1 |
| 4 | 0,0 | 0,0 |
| 5 | -4,0 | -4,0 |
| 6 | 1,0 | 0,0 |
| 7 | -6,0 | -7,0 |
| 8 | 0,0 | 0,0 |

单位为源图px；数据字段column_offsets／rank_offsets分开记录，避免圆环与栏框的细微差异传递错误。文字仍原生像素绘制，所有字号／图标尺寸保持。622项三分辨率静态检查及新版下部渲染确认通过。

## 文字提亮与加速渐隐（2026-10-17最新）

描述字号为round(18×显示缩放)+2（2K26px），诗句字号保持；两段颜色统一#f1ead6米白。origin_width_sample仍按新字号测量，首行保持“……以木”。CopyShade宽min(600,栏宽×0.50)，横向alpha=0.82×(1−x^2.2)，前段变化慢、越往右越快；上下羽化与底层顺序不变。此项覆盖下方25px／旧颜色／520宽smoothstep参数。622项三分辨率静态检查及上部渲染确认通过。

## 指定换行与书法底墨（2026-10-17最新）

介绍绑定表增加origin_width_sample，以实际楷体字宽让首行结束在“以木”，后续行／分隔线对应收窄，覆盖下方365设计px。书法TextureRect使用map_calligraphy_ink.gd生成的512高前景距离纹理及同名shader：保护亮色笔画／朱红印，墨底随距离平滑降透明，ink_density=0.45、feather_width=0.045（相对图高）。只改运行时alpha，不模糊／改色／写回源图；缓存避免每帧分析。其他书法尚未绑定。本次622项静态检查通过，左右对照见artifacts/technique-calligraphy-ink-comparison.png。

## 上部描述与衬底微调（2026-10-17最新）

来历与核心最终原生字号加1（2K24→25px），文案区域宽350→365设计px以避免孤字换行，原左侧／纵向位置和诗句字号保持。左侧图文最底层新增CopyShade，shader为map_technique_copy_shade.gdshader；最高82%深色，从左向右smoothstep渐透明，上下羽化，内缩2px，宽min(520,栏宽×0.43)。同overview跟随青萝显隐，不改图片与中／右素材。622项必要静态检查及渲染通过，覆盖下方无上部阴影／旧描述字号的历史口径。

## 上部介绍与括号说明最新（2026-10-17）

`map_technique_overview.gd`读取`data/ui/technique_overviews.json`，仅wood_05显示指定title／label／book／calligraphy及35本四栏文案中的诗意配词、来历与核心。上部高为分隔线y减8；左侧图与VBox文案、中央完整书籍、右侧竖排书法均在中栏内部。四图等比且mipmap，书法原PNG复制入assets，源像素不变；文案同样按原生像素绘字。后续其他书需独立登记，不复用青萝图文。

下部8个ChoiceEffect在最终原生字号上再加1（2K16→17px），屏幕Y坐标下移2px；仍为楷体，名称／圆环／图标及其他排版保持。622项三分辨率静态检查通过，构图及文字对照见根目录design-qa.md，覆盖下方括号16px／原位置的旧口径。

## 名称字体最新（2026-10-17）

4个SpellName及8个ChoiceName使用项目既有SystemFont配置HarmonyOS Sans SC／鸿蒙简体、font_weight=400（Regular）；括号说明和圆环数字继续楷体。奇数栏名称在原生字号取整后加1，2K为26px；偶数栏名称23px和说明16px保持。下方源坐标／源字号继续用于原位置映射，源字号25并不表示最终屏幕26px。580项必要静态检查与2K渲染通过，覆盖下方所有文本均为楷体的历史描述。

## 文字清晰度（2026-10-17最新）

楷体与ItemTooltip的FlavorDescription相同，均为KaiTi。源坐标／源字号继续按下方基准换算，但28个Label单独抵消父级显示缩放，按最终屏幕整数字号、整数像素位置／尺寸绘制，显式线性过滤并关闭自身随缩放过采样；底图／图标mipmap保持。2K下法术名25px、强化名23px、四字说明16px，未改名义字号、颜色、阴影或排版。文字更新由resized与全局变换通知驱动，字号改变后补一次延迟布局，待Godot字体最小宽度更新后收回边界。三分辨率580项静态检查通过，前后裁图在artifacts/technique-font-before-after.png（上旧下新）。说明字号小于悬浮楷体20px，属于现有尺寸差异。

## 最新文字微调（2026-10-17，覆盖下方旧显示口径）

奇数栏图标下只显示法术名称：保留源矩形(58+394g,413,126,26)，源字号23→25，去掉X重及法术效果说明。偶数栏强化名称矩形y388→394，下移6源图px，四字说明保持(212+394g+100o,418,100,24)；末项统一单行“（火雷连携）”，不再显示暂缓字样。底层deferred状态仍保留，未变更机制。圆环数字及12图标保持，现共28个Label；三分辨率496项静态检查通过并查看2K渲染。

## 最新：独立图标与文字已接入（2026-10-17）

用户更新了middown，旧三个图标已从底图去除；画布／裁切与下方坐标不变。12张更新的376×376 WebP按01～12接入，分别为缚灵藤、盘根、疾藤、蚀脉荆、入骨、蔓生、回春术、急生、长养、青萝天罗、天罗固缚、引火召雷。原图不重绘，每张使用mipmap；`map_technique_icon.gdshader`给独立TextureRect补1设计px金色#D9BB72边与3设计px圆角裁切。定位继续调用icon_rect，后续更换单张图片仍沿此基准。

这套底图、12图标、文字严格绑定`base.cultivation_book.wood_05`。其他34书均隐藏整套内容；切换七系仅过滤左侧，仍按全局当前选书决定显隐。修行进度区域增加深灰#15181C／约68%不透明蒙版，位于图案及标题下层，范围为分隔线以下、内缩侧边2／底边2设计px，12px圆角，不覆盖上半栏或原描边。蒙版及修行进度标题为公共区域设置，专用内容才跟随青萝选书显隐。

图中圆环显示整数1～8，法术列下方显示1／3／5／7重、法术名与简短特点。强化列名称及括号短语读取`data/ui/technique_progress_qingluo.json`，来源为用户指定的`output/imagegen/七系功法简明介绍.md`青萝段：盘根（缠绕增层）、疾藤（减耗提速）、入骨（毒蚀增层）、蔓生（遇毒加缠）、急生（即时强疗）、长养（生机增层）、天罗固缚（缠缚强化）、引火召雷（火雷连携）。引火召雷另标“暂缓”，不把例图中的破甲／持续伤害误写为当前机制。短语为概要，未改完整数值／触发条件／取舍，未实现学习或二选一点击。

新增36个楷体Label，跟随图尺寸从源坐标换算，文本不烘焙入素材。最新专项556项静态检查通过，包括三分辨率、字体容纳／底框留白、12图标位置／边线／mipmap、35书显隐及全局选书规则。原始换图前快照／哈希继续保留；下方“原图保留三个图标、暂无叠图、不随选书替换”的描述是初次基准历史，以本节覆盖。

## 初次接入记录（历史，已由上方最新状态覆盖）

首次接入时仅把`assets/UI-wood-middown-8.webp`（当前文件名）作为功法页中栏下部的静态展示图，不接真实进度／解锁／二选一点击，也不随选书替换。已有修行进度标题、圆角分隔线和栏底图继续沿用。当时保留原图内三个图标，未叠画新图。

## 换图时必须保留的基准

- 原始画布：1645×630；坐标原点为完整原图左上角，单位均为源图像素。
- 固定显示裁切区：`(54,138,1554,414)`。仅排除外围透明留白／极淡导出杂点，图中圆环、八栏及底部题字完整保留。运行时使用AtlasTexture，不修改源图。
- 原图SHA-256：`b31de6057fc818b9a8aefcaeb07f39d1d3fdfa3fba086d74b92eaed36b71a271`。
- 换图前原字节快照：[baseline](../artifacts/qingluohuashengjue-middown-baseline-20261017.webp)。artifacts不入Git；下列坐标及[data/ui/technique_progress_art.json](../data/ui/technique_progress_art.json)是持久定位依据。
- 后续去图标时保持画布、栏框、圆环及题字位置不变，不重新按透明包围区裁图。如果用户另行调整整体画布或栏位，应先重测映射，不能继续套用旧像素坐标。

## 第一组已存在图标的实测区域

矩形格式为`x,y,宽,高`，含小图标自带细边框的外包围区域。内区供未来保留原细框、只替换内部图像时参考；若连细框一起删掉，则新图按外区定位。

| 图标 | 外区 | 内区 |
| --- | --- | --- |
| 第1个法术解锁 | 72,294,98,97 | 74,296,94,93 |
| 第1组强化左选项 | 220,301,84,84 | 222,303,80,80 |
| 第1组强化右选项 | 320,301,84,84 | 322,303,80,80 |

原图小框本身略有像素级不规则，记录外包围矩形，不擅自把98×97拉成更大的正方形。未来新素材若为正方形，优先在目标区域等比居中；是否补细框／裁角按用户当次要求，不预先改图。

## 后续三组的预留定位

原图八栏每组（法术＋二选一）的水平重复间隔为394源图像素。以下第2～4组为按第1组平移得到的未来槽位，当前原图中没有这些图标。

| 组 | 法术解锁外区 | 强化左外区 | 强化右外区 |
| --- | --- | --- | --- |
| 1 | 72,294,98,97 | 220,301,84,84 | 320,301,84,84 |
| 2 | 466,294,98,97 | 614,301,84,84 | 714,301,84,84 |
| 3 | 860,294,98,97 | 1008,301,84,84 | 1108,301,84,84 |
| 4 | 1254,294,98,97 | 1402,301,84,84 | 1502,301,84,84 |

## 页面缩放与后续叠图接口

中栏设计尺寸1203.5×910，分隔线栏内y485。可用矩形左16、顶`分隔线+52`、宽`栏宽−32`、高`栏高−分隔线−80`；图按固定裁切区等比缩至可用矩形内并居中。因此左右至少16、底部至少28设计px，宽屏／分辨率变化仍不拉伸。

`scripts/map/map_technique_progress_art.gd`提供`icon_rect(group_index, option_index)`：组索引0～3；选项索引−1为法术，0／1为左右强化。返回相对于该图节点的显示矩形：

`局部位置 = (原图位置 − 裁切区左上角) × 显示倍率`

`局部尺寸 = 原图尺寸 × 显示倍率`

未来把新TextureRect放到该图节点下，使用此矩形并保持等比，即可和页面一起缩放；不要硬编码截图屏幕坐标。当前只提供矩形计算，不创建可见新图标或鼠标区域。

本轮必要检查：`./tests/run_t01.ps1 -Script res://tests/technique_progress_heading_preview.gd -Render`，三分辨率125项静态通过；中栏预览`artifacts/technique-progress-heading-middle.png`、下部细节`artifacts/technique-progress-middown.png`。未做交互或玩法验证。
