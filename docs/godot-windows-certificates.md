# Godot Windows根证书报错诊断

日期：2026-11-01。引擎：Godot 4.7.2 stable，提交ed1daf0bf。报错为`Failed to read the root certificate store`，来自`platform/windows/os_windows.cpp:2582`。

## 已确认原因

当前受限执行环境内，Windows当前用户／本机ROOT库均可只读枚举，各75张证书。复现引擎调用`CertOpenSystemStoreA(0,"ROOT")`失败，GetLastError为5（拒绝访问）；显式只读的`CertOpenStore`可打开同一证书库。因此不是“Windows没有根证书”，也没有证据表明证书库损坏。没有在用户普通桌面进程环境重复此调用，不能据此判断手工启动Godot也会报错。

当前二进制以`--verbose`运行最小SceneTree探针，实际输出`Loaded builtin CA certificates`，继续执行探针并正常退出。对应版本源码表明，系统库无法读取后会回退内置CA集合；TLS校验仍然存在。用户／企业自行安装、只存在于系统库的私有CA不保证包含在内置集合中。

已查项目scripts和project.godot，未发现HTTPRequest／HTTPClient／HTTPS请求或证书覆盖配置；当前本地绘制、战斗、休息、采集等机制不依赖此证书初始化。此结论不等于联网功能已验收，未来HTTPS服务、企业代理或私有CA须独立验证。

## 本次修复范围

原`tests/run_t01.ps1`把stderr中任何ERROR都判失败，导致功能检查全通过后仍退出失败。本次将日志判定集中到[godot_log_status.ps1](../tests/godot_log_status.ps1)，启动加`--verbose`并保留原始日志：只有stdout明确报告内置CA已加载，且stderr中是精确匹配Windows证书打开失败及其源码栈时，才将这一项作为可见环境警告。Godot非零退出、取不到退出码、其他ERROR／SCRIPT ERROR／FAIL仍失败，同时检查stdout的错误标记。保留进程句柄，避免快速退出时ExitCode不可用。

这修复的是**检查误判**，不是引擎原生证书打开方式。没有改Windows证书库／权限、没有禁用TLS验证、没有添加不可信证书、没有改项目运行设置或替换Godot可执行文件。

彻底消除原始报错应从引擎层修正Windows证书库访问方式：明确只读、打开现有ROOT库，同时保留原有禁用证书过滤逻辑。当前验证说明只读API可行，但未构建／替换引擎，不能称此根因已修复。也可在允许该系统调用的正常执行环境中验证；不需要为当前离线验证扩大系统权限。固定证书包是另一种部署方案，但需维护更新，不应为去掉日志临时改变全项目信任配置。

## 验证

- [日志判定专项](../tests/godot_log_status_tests.ps1)：10种情况通过，包括正常回退、没有回退证据、非零退出、真实TLS握手错误、脚本错误、stdout断言失败、伪装同文案的其他来源和换行差异。
- 最小引擎探针通过修订后的run_t01执行，进程状态可读，脚本返回0，原始证书错误仍保留并输出明确警告。日志在`artifacts/probe.stdout.log`／`probe.stderr.log`；先前诊断日志在`artifacts/certificate-diagnostic/`。
- 未复跑游戏全量测试、网络请求或编辑真实存档，未提交推送。

源码依据：[当前版本Windows证书读取](https://github.com/godotengine/godot/blob/ed1daf0bf/platform/windows/os_windows.cpp)、[mbedTLS内置证书回退](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/mbedtls/crypto_mbedtls.cpp)、[启动时加载证书](https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp)。
