# 储物袋筛选标签 Design QA

## 对比目标

- Source visual truth: `E:/games/path-of-immortals/artifacts/storage_filter_reference.png`
- Implementation full screenshot: `E:/games/path-of-immortals/artifacts/map_inventory_six_columns.png`
- Implementation focused crop: `E:/games/path-of-immortals/artifacts/storage_filter_implementation.png`
- Combined comparison evidence: `E:/games/path-of-immortals/artifacts/storage_filter_qa_comparison.png`
- Viewport: 1920×1080，Godot固定1920×1080逻辑画布，device scale 1。
- Pixels: source 729×99；implementation full 1920×1080；focused crop 890×99。源图和实现裁图均以原始像素密度展示，没有二次缩放；组合图上下排列。
- State: 地图I键储物袋打开，完整库存“储物袋 6”和类别“全部”同时处于选中态。

## Findings

没有剩余P0／P1／P2问题。

- Fonts and typography: 实现沿用项目Microsoft YaHei／Noto Sans CJK SC栈；第一排选中项为暖金文字，第二排选中项为冷白文字，层级与参考一致。补充的项目分类保持同字号、同基线，无截断。
- Spacing and layout rhythm: 两排标签在906px储物袋面板内保持单行；第一排五项、第二排十四项不重叠，分隔线与第三排排序控件位置稳定。1280×720、1280×800、1920×1080及2560×1080布局检查均通过。
- Colors and visual tokens: 第一排选中态采用深金底、2px金边和柔和金光；第二排采用深蓝底、2px亮蓝边和蓝光。未选类别使用细蓝灰框；悬停光效弱于选中态。
- Image quality and asset fidelity: 本次目标不新增图像资产；储物袋标题原有mipmap图标、背景与物品图保持原样，没有以代码图形替代参考中的图片资产。
- Copy and content: 第一排补齐收藏／常用／灵材／配方／储物袋；第二排补齐法器／问答／材料／招式，同时保留项目需要的武器／防具／投掷物／道具。参考图中的示例数量没有伪造，界面继续显示实际库存数量。
- States and interactions: 默认两排选中态、集合与类别点击、配方布尔标签筛选、空结果反馈、排序及重置均由真实控件驱动。map_inventory_smoke无窗口179项、真实渲染189项通过；成功渲染过程无引擎错误。

## Comparison history

1. 首轮对比发现第二排选中文字使用暖金色，比参考图的蓝白高光偏暖（P2）。
2. 将第二排pressed／hover_pressed文字调整为冷白，并保留蓝色描边与外发光。
3. 重新渲染并生成`storage_filter_qa_comparison.png`；选中态色温、边框层级、单行密度与参考意图一致，P2关闭。

## Open Questions

- 无阻塞问题。新增的配方及四个类别当前没有正式物品，因此计数或结果为空属于真实数据状态。

## Implementation Checklist

- [x] 第一排金色选中态及悬停态
- [x] 第二排蓝色选中态、冷白文字及未选细框
- [x] 缺失集合与类别补齐为可交互筛选
- [x] 保留项目现有分类与排序／物品区
- [x] 多尺寸、无窗口和真实渲染验证

## Follow-up Polish

- P3：第一排未选项比参考图多一圈极淡边框，这是为提高可点击性而保留的项目化处理，可按后续实机感受再减弱。

final result: passed
