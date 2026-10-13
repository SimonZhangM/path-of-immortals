# assets 引用盘点（2026-10-08）

本报告已按同日清理后的当前工作区复查，包含未提交修改；源素材保持用户当前状态。

## 同日授权清理结果

用户授权清理源文件已不存在的.import，并自行删除原“仅测试引用”的4张源素材及对应.import。遍历实际文件系统共找到18个孤立导入配置：此前报告列出16个，另2个旧MP3导入配置被Git忽略而未计入。批量删除命令被工具安全策略拦截，未执行；改为逐个移出assets并归档至忽略目录`artifacts/orphan-imports-cleanup-20261008/`，其中`moved.json`记录原路径，方便恢复。

复查assets中的无源.import为0；4张用户删除的源图及其导入配置均不存在。当前源素材281个，剩余13个无引用候选、9个仅文档提及和2个旧动态兜底保持原样。部分旧测试仍保留对4张旧图的断言引用，列在下方缺失路径中；本次未改测试脚本或运行测试。

## 范围与判定

扫描 scripts／scenes／data、project.godot、tests、tools、文档与工作簿；排除 .godot、.git、artifacts、tmp、builds 及本报告。源素材与 .import 导入配置分开统计；.import 的 source_file 自引用不算使用证据。脚本注释不算运行引用，UID经导入配置映射。

“运行源码／配置引用”仅说明运行文件存在引用，不保证当前主场景能到达；旧演示、全部注册配置与未来内容也可能在此类。“仅测试”“仅工具”“仅文档”均不等于正在游戏中使用。未发现引用是清理候选，不是已授权删除。

已逐项核对动态规则：MapItemQuality支持七品级，level-6仍是仙品底图，levelbq-1～7由品级序号加载，skill01～04由配角索引生成。这12张不可因没有写死文件名而判为闲置。buff-hujia／hudun仍有动态兜底路径，但当前data/ui/map_buffs.json为护甲／灵盾显式配置player-status-armor／sheild，因此当前配置不取旧图；清理旧兜底图时应一起调整或保留兜底策略。

临时预览、外部存档／MOD、文件系统外部应用及尚未写入代码的创作计划不在覆盖范围。未运行游戏／鼠标测试或删除后验证。

## 统计

| 分类 | 文件数 | 体积（MiB） |
|---|---:|---:|
| 运行源码／配置引用 | 245 | 36.16 |
| 全项目未发现引用 | 13 | 1.50 |
| 仅文档／工作簿提及 | 9 | 4.48 |
| 仅动态兜底引用（当前被替代） | 2 | 0.10 |
| 已核对的动态运行引用 | 12 | 0.57 |

## 全项目未发现引用（13个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|
| `assets/UI-jiaohu-xiao.webp` | 56.9 | 本次扫描无匹配 |
| `assets/enemy-qshw-chisongliaozhu-all.webp` | 407.4 | 本次扫描无匹配 |
| `assets/map-duihua.webp` | 104.0 | 本次扫描无匹配 |
| `assets/map-head1.webp` | 185.7 | 本次扫描无匹配 |
| `assets/map-shuijing.webp` | 33.4 | 本次扫描无匹配 |
| `assets/map-teshushijian.webp` | 193.3 | 本次扫描无匹配 |
| `assets/npc-shangren1.webp` | 107.9 | 本次扫描无匹配 |
| `assets/npc-xuetu-qlz.webp` | 100.2 | 本次扫描无匹配 |
| `assets/player-level-2.webp` | 53.6 | 本次扫描无匹配 |
| `assets/player-level-3.webp` | 58.8 | 本次扫描无匹配 |
| `assets/player-level-4.webp` | 70.2 | 本次扫描无匹配 |
| `assets/player-level-5.webp` | 72.7 | 本次扫描无匹配 |
| `assets/player-level-6.webp` | 87.5 | 本次扫描无匹配 |

## 仅文档／工作簿提及（9个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|
| `assets/battle-tanchuang.webp` | 207.5 | docs/map-interaction-design.md:88 |
| `assets/fr-idle.webp` | 347.5 | PROJECT_PROGRESS.md:4660、docs/map-editing-guide.md:49 |
| `assets/fr-run.webp` | 375.5 | PROJECT_PROGRESS.md:4410、PROJECT_PROGRESS.md:4424、docs/map-editing-guide.md:33 |
| `assets/fr-walk.webp` | 246.9 | PROJECT_PROGRESS.md:4474、PROJECT_PROGRESS.md:4478、PROJECT_PROGRESS.md:4622 |
| `assets/inv-zhenpan.webp` | 302.1 | PROJECT_PROGRESS.md:3808、PROJECT_PROGRESS.md:4058、PROJECT_PROGRESS.md:4066 |
| `assets/map-cunzhen.webp` | 32.1 | PROJECT_PROGRESS.md:4572、docs/map-editing-guide.md:82、docs/sources/AGENTS-before-core-index-2026-09-24.txt:988 |
| `assets/map-qingshizhen-route.webp` | 2744.9 | README.md:131 |
| `assets/sword_slashing.mp3` | 251.2 | PROJECT_PROGRESS.md:5153 |
| `assets/zhujue-m1.webp` | 78.4 | PROJECT_PROGRESS.md:4458、docs/sources/AGENTS-before-core-index-2026-09-24.txt:966 |

## 仅工具引用（0个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|

## 仅测试引用（0个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|

## 仅动态兜底引用（当前被替代）（2个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|
| `assets/buff-hudun.webp` | 49.9 | scripts/map/map_inventory_screen.gd:538（动态路径族） |
| `assets/buff-hujia.webp` | 51.5 | scripts/map/map_inventory_screen.gd:538（动态路径族） |

## 已核对的动态运行引用（12个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|
| `assets/level-6.webp` | 94.6 | tests/item_quality_badge_preview.gd:24、tests/board_change_dialog_tests.gd:55（动态路径族）、docs/map-inventory-design.md:269 |
| `assets/levelbq-1.webp` | 47.4 | tests/map_inventory_smoke.gd:109、tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族） |
| `assets/levelbq-2.webp` | 53.8 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/levelbq-3.webp` | 57.4 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/levelbq-4.webp` | 60.6 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/levelbq-5.webp` | 61.1 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/levelbq-6.webp` | 55.5 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/levelbq-7.webp` | 65.7 | tests/item_quality_badge_preview.gd:51（动态路径族）、tests/item_quality_badge_diagnostics.gd:8（动态路径族）、tests/item_quality_badge_diagnostics.gd:48（动态路径族） |
| `assets/skill01.webp` | 28.6 | scripts/ui/companion_card.gd:28（动态路径族）、README.md:192、PROJECT_PROGRESS.md:5042 |
| `assets/skill02.webp` | 15.9 | scripts/ui/companion_card.gd:28（动态路径族）、README.md:192、PROJECT_PROGRESS.md:5042 |
| `assets/skill03.webp` | 23.0 | scripts/ui/companion_card.gd:28（动态路径族）、README.md:192、PROJECT_PROGRESS.md:5042 |
| `assets/skill04.webp` | 19.2 | scripts/ui/companion_card.gd:28（动态路径族）、README.md:192、PROJECT_PROGRESS.md:5042 |

## 动态路径可能使用（保留复核）（0个）

| 文件 | 体积（KiB） | 证据 |
|---|---:|---|

## 动态路径审阅

| 源码位置 | 模式 | 匹配现有素材数 |
|---|---|---:|
| `tests/run_tests.gd:139` | `res://assets/pt0%d.webp` | 2 |
| `tests/map_board_title_preview.gd:36` | `res://assets/player-status-%s.webp` | 8 |
| `tests/item_quality_badge_preview.gd:51` | `res://assets/levelbq-%d.webp` | 7 |
| `tests/item_quality_badge_diagnostics.gd:8` | `res://assets/levelbq-%d.webp` | 7 |
| `tests/item_quality_badge_diagnostics.gd:48` | `res://assets/levelbq-%d.webp` | 7 |
| `tests/board_change_dialog_tests.gd:55` | `res://assets/level-%d.webp` | 7 |
| `tests/battle_status_polish_tests.gd:78` | `res://assets/item-enemy-cslz-%d.webp` | 5 |
| `scripts/ui/companion_card.gd:28` | `res://assets/skill%02d.webp` | 4 |
| `scripts/map/map_inventory_item_card.gd:154` | `res://assets/levelbq-%d.webp` | 7 |
| `scripts/map/map_inventory_screen.gd:525` | `res://assets/player-status-%s.webp` | 8 |
| `scripts/map/map_inventory_screen.gd:538` | `res://assets/buff-%s.webp` | 9 |
| `scripts/map/map_item_quality.gd:23` | `res://assets/level-%d.webp` | 7 |

## 无源图的导入配置（0个）

这些是现存 .import 指向已经不存在的源素材；与未引用源文件分开处理。


## 已缺失的明确资源路径

只列运行／测试／工具中的明确路径；测试断言“文件已删除”也会出现，不能直接当作加载错误。

- `res://assets/does-not-exist.webp`：tests/enemy_presentation_tests.gd:41
- `res://assets/level-fanpin.webp`：tests/map_inventory_smoke.gd:70
- `res://assets/missing-frame.webp`：tests/run_tests.gd:147
- `res://assets/pt-a-1.webp`：data/characters/chen_yu.json:8
- `res://assets/pt04.webp`：tests/ui_smoke.gd:290
- `res://assets/pt05.webp`：tests/ui_smoke.gd:296
- `res://assets/test1.webp`：tests/enemy_presentation_tests.gd:30
- `res://assets/test1.webp.import`：tests/enemy_presentation_tests.gd:30
- `res://assets/title-chuwudai.webp`：tests/map_inventory_smoke.gd:192
- `res://assets/title-zhenpan.webp`：tests/map_inventory_smoke.gd:191
- `res://assets/title-zpsxjc.webp`：tests/map_inventory_smoke.gd:190

机器清单与完整证据：`artifacts/assets-reference-audit-20261008.json`、`artifacts/assets-reference-audit-20261008.csv`（本地产物，不纳入Git）。
