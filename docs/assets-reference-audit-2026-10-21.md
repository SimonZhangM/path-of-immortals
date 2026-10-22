# assets 引用盘点（2026-10-21）

本报告已在恢复弹窗六张图改名及旧状态图兜底代码清理后重新扫描，仅列当前磁盘仍存在的素材。用户已删除的图片不再列为候选；旧的2026-10-08报告仅供历史追溯。

## 结论

- 源素材 **1186** 个；`.import` **1186** 份，导入配置自引用不计作使用。
- **19** 个未发现当前游戏运行引用，合计 **1.68 MiB**。
- 其中 **18** 个属于无名旧祠四怪的明确待接入器官素材，建议保留；另 **1** 个仍需复核用途。
- 旧状态图动态兜底已移除，护甲／灵盾直接读取配置中的现用图标。
- 无源素材的孤立 `.import`：**0** 份。

## 扫描范围与判断边界

检查scripts、scenes、data、project.godot、tests、tools、文档、工作簿及本地output创作资料；output只作为文档／历史清单证据，不当作游戏运行引用。排除.git、.godot、artifacts、tmp、builds以及所有旧引用审计报告，避免报告自引用。已通过.import将UID映射到源素材，忽略脚本注释中的路径。

运行源码／配置存在引用不等于当前主场景一定可到达：旧演示、暂未开放敌人或已注册但未上架内容也可能在此类。仅测试、工具、文档、工作簿或生成时受保护文件哈希清单出现文件名，均不代表游戏正在使用。未覆盖外部存档、MOD、编辑器手工引用和未落档创作计划；本轮直接检查及验证边界见PROJECT_PROGRESS最新记录，未运行完整游戏回归。

动态引用已经按实参逐族复核：仓储通用`assets/%s.webp`仅认实际调用中的文件名，不能据此保留所有WebP；仓储四按钮、七系选中框、三栏背景、六张对话气泡、七品级底图／标签、四个配角技能及三资源图标均按实际枚举范围识别。

## 分类统计

| 分类 | 文件数 | 体积（MiB） |
|---|---:|---:|
| 运行源码／配置直接引用 | 1128 | 133.31 |
| 已核对的动态运行引用 | 39 | 2.38 |
| 仅文档／工作簿／生成记录提及 | 19 | 1.68 |

## 无当前运行引用：非预留复核清单（1个）

| 文件 | 体积（KiB） | 分类／说明 | 证据 |
|---|---:|---|---|
| `assets/map-shuijing.webp` | 33.4 | 仅文档／工作簿／生成记录提及 | output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:916；output/imagegen/_generation/wood-arts-2026-10-17/protected-baseline.json:975 |

## 明确待接入的旧祠器官素材，建议保留（18个）

| 文件 | 体积（KiB） | 分类／说明 | 证据 |
|---|---:|---|---|
| `assets/item-enemy-heiweicishu-cuweihengsao.webp` | 61.3 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:152；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:676 |
| `assets/item-enemy-heiweicishu-qianzhua.webp` | 73.1 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:125；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:678 |
| `assets/item-enemy-heiweicishu-yingmenchi.webp` | 31.0 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:98；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:680 |
| `assets/item-enemy-huiyifu-fuchi.webp` | 34.5 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:240；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:682 |
| `assets/item-enemy-huiyifu-fuyimo.webp` | 76.3 | 仅文档／工作簿／生成记录提及 | docs/01_核心定案_七系功法与战斗规则.md:563；docs/sources/wuming-jiuci-enemies-2026-10-08.json:324 |
| `assets/item-enemy-huiyifu-huifuyizhua.webp` | 64.7 | 仅文档／工作簿／生成记录提及 | docs/01_核心定案_七系功法与战斗规则.md:563；docs/sources/wuming-jiuci-enemies-2026-10-08.json:267 |
| `assets/item-enemy-huiyifu-zhenmingnang.webp` | 78.9 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:294；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:690 |
| `assets/item-enemy-xuejuhuizhu-huizhijiake.webp` | 145.8 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:410；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:710 |
| `assets/item-enemy-xuejuhuizhu-huizhuaoya.webp` | 76.8 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:436；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:712 |
| `assets/item-enemy-xuejuhuizhu-huizhusi.webp` | 150.0 | 仅文档／工作簿／生成记录提及 | docs/01_核心定案_七系功法与战斗规则.md:563；docs/sources/wuming-jiuci-enemies-2026-10-08.json:520 |
| `assets/item-enemy-xuejuhuizhu-niansinang.webp` | 103.4 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:490；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:716 |
| `assets/item-enemy-xuejuhuizhu-qianzusiche.webp` | 79.2 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:463；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:718 |
| `assets/item-enemy-yanfuduzhu-dazhusinang.webp` | 139.7 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:690；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:720 |
| `assets/item-enemy-yanfuduzhu-fudunang.webp` | 98.5 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:659；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:722 |
| `assets/item-enemy-yanfuduzhu-yanfuaoya.webp` | 76.5 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:632；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:724 |
| `assets/item-enemy-yanfuduzhu-yanfujiake.webp` | 145.9 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:606；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:726 |
| `assets/item-enemy-yanfuduzhu-yanfuxinnang.webp` | 113.4 | 仅文档／工作簿／生成记录提及 | docs/sources/wuming-jiuci-enemies-2026-10-08.json:745；output/imagegen/_generation/fire-earth-effects-2026-10-17/protected-baseline.json:728 |
| `assets/item-enemy-yanfuduzhu-yanfuzhusi.webp` | 140.2 | 仅文档／工作簿／生成记录提及 | docs/01_核心定案_七系功法与战斗规则.md:563；docs/sources/wuming-jiuci-enemies-2026-10-08.json:720 |

上述预留以`docs/sources/wuming-jiuci-enemies-2026-10-08.json`为依据，该记录明确`runtime_registered=false`，不由ContentRegistry加载，不代表应删除。旧蝠齿／翼爪／翼膜的替换关系需要区分原文件名与修订后的当前对应。

## 动态加载已复核

| 位置 | 模式 | 宽泛匹配数 → 已核对文件数 |
|---|---|---:|
| `scripts/dialogue/dialogue_bubble.gd:66` | `res://assets/UI-dialo-%s%d.webp` | 6 → 6 |
| `scripts/map/map_inventory_item_card.gd:263` | `res://assets/levelbq-%d.webp` | 7 → 7 |
| `scripts/map/map_inventory_screen.gd:668` | `res://assets/player-status-%s.webp` | 8 → 3 |
| `scripts/map/map_item_quality.gd:30` | `res://assets/level-%d.webp` | 7 → 7 |
| `scripts/map/map_technique_book_card.gd:20` | `res://assets/UI-gongfa-left-selectbook-%s.webp` | 7 → 7 |
| `scripts/map/map_technique_screen.gd:361` | `res://assets/UI-gongfa-%s-bg.webp` | 3 → 3 |
| `scripts/map/map_warehouse_actions.gd:56` | `res://assets/UI-title-cangku-%s.webp` | 12 → 4 |
| `scripts/map/map_warehouse_sidebar.gd:319` | `res://assets/%s.webp` | 1167 → 10 |
| `scripts/ui/companion_card.gd:28` | `res://assets/skill%02d.webp` | 4 → 4 |
| `scripts/ui/item_tooltip.gd:500` | `res://assets/levelbq-%d.webp` | 7 → 7 |

## 候选中的完全相同文件组

未发现需要单列的同字节重复组。

## 无源素材的导入配置

0份。

## 缺失明确路径的附加检查

这里只列运行源码／配置中的缺失明确路径；测试故意使用的不存在图片不列入当前素材清单。

未发现运行源码／配置中的缺失明确素材路径。

完整1186项和逐条证据见本地`artifacts/assets-reference-audit-20261021.json`及CSV；一次性扫描／实参复核脚本也在artifacts。它们不纳入Git。清理及改名结果见PROJECT_PROGRESS最新记录。
