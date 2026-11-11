# j2b 加载、失败含义与项目隔离

你补充的 2021 年文件确实是关键线索。不过这份 `jass2binary.lua` 的主体是**编译/保护并重建地图**，不是“地图没加密时正常走一次解密”。它在现有测试环境中属于额外加载的工具路径，不是 Lua 业务所必需。

## 已确认的加载源

以下两份文件 SHA256 相同：

- `D:/War3/内置JAPI/2021年/jass2binary.lua`
- `D:/Program Files (x86)/Warcraft III Frozen Throne/jass2binary.lua`

哈希为 `61642441cfeaba50c7d73323162f5dfc3d8112c05fe05305fa6090fb6f204126`。原始文件的第 5 行打开 console，第 7 行打印“j2b加密开始”。脚本检测到 `war3map.bin` 时会提前返回避免重复编译；否则加载 `war3map.j`，补充保护辅助代码，在第 157 行调用 `japi.compile_script`，之后调用 `storm.rebuild` 输出带 bin 与加载外壳的地图。

固定 DLL 的嵌入 PE 中存在对 `require("jass2binary")` 的调用。记录位于 `research/evidence/selected-native-disassembly.txt`，相关函数区域 VA `0x10299150..0x1029943f`。这证明有原生加载入口；不能仅从这段代码推断所有版本、所有启动场景或 Lua VM 的数量。

实机对照中，仅在 plugin_main 设置 `package.loaded.jass2binary=true` 没有阻止全局文件执行；仅在 MPQ 根目录放同名空模块也没有阻止本机全局副本执行。游戏目录下 jass2binary 生成物的更新时间仍变化。项目因此没有把其中任何一种办法单独当成充分隔离。

## 这条输出到底表示什么

`Call jass function crash.<unknown>` 是 compile_script 原生调用失败的诊断，不是 Lua 业务 OOS 的同义词。脚本使用 xpcall 打印异常，然后仍无条件打印“j2b加密结束”，所以“结束”不表示编译成功；也不能因为前后两行都有就把中间异常当作正常解密提示。

本次追到一个可独立复现的输入缺陷：旧最小 JASS 没有 globals/endglobals，而这份工具靠替换 endglobals 插入辅助定义，生成文件便留下对 `EXLoadFileHashKey` 的调用却没有定义。经典 pjass 对该生成文件报告三处未定义函数，原始结果保存在 `research/evidence/j2b-pjass.txt`。模板现在保留空 globals/endglobals，消除这个输入缺陷。

这并不证明该缺陷是所有 `compile_script crash` 的唯一原因，也未将加密流程列为本模板支持能力。之前出现诊断的地图仍完成 Lua 断言和 LAN 测试，说明该次可选工具失败没有阻止业务启动；不能推广成“所有此类错误都可忽略”。

## 隔离方式

`tools/lan/Start-LuaTest.ps1` 是共享 LAN 启动器的项目适配副本。它持有共享会话/环境锁后：

1. 将游戏根目录同名脚本的原始字节、存在状态和哈希写入 `build/runtime-guard-active.json`。
2. 暂时安装关闭 console 的最小模块，每个客户端写出本次构建的 `J2B_SKIPPED` 标记。
3. 等待全部客户端确认加载后，按哈希比较当前文件并逐字节恢复原件；随后继续等待测试完成。
4. 失败路径也执行恢复。若文件被外部改变则拒绝覆盖，保留恢复日志供处理。

标记启动前清除，防止重跑同一构建时误认旧确认。`tests/runtime_guard.ps1` 验证了原文件存在、不存在、以及外部修改时拒绝覆盖三种情况。每次实机的 `runtime-guard.json` 记录恢复结果；它不包含原脚本正文。

正常结束后不会永久修改游戏目录的原脚本。异常断电等导致 journal 留下时，先确认游戏已退出，再运行 `pwsh -NoProfile -File tools/restore-runtime.ps1`；工具仍检查目标路径和当前替代文件哈希。不要直接删除 journal 当作恢复。

正式 MPQ 还带有关闭可选流程的根模块 `jass2binary.lua`。本机启动必须使用项目 tasks/CLI 才具备上述全局文件隔离；通过其他编辑器启动不能沿用这个保证。没有修改原 2021 年脚本，也没有修改共享 LanTest 或 War3Lib 源码。

## 无额外 console 与日志

Lua 入口关闭 `jass.console.enable`/`package.console_enable`，print 转入 `jass.log`。启动器使用隐藏的辅助进程启动配置；j2b 的已知开 console 路径通过上述临时模块避开。没有使用桌面枚举来观察窗口，因此这里确认的是代码、启动配置和各端加载标记，不是假称做过视觉验收。

Logger 添加目录：`D:/Program Files (x86)/Warcraft III Frozen Throne/Lua框架研究/logs`。文件名为 `<build>-P1.log` 到 `-P6.log`，构建名不复用。新模板副本默认使用自己的项目 ID 目录，可以在 project.json 设置 log_folder。
