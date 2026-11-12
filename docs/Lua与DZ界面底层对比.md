# Lua InnerJAPI 与 JASS DZAPI 界面底层对比

2026-11-12。承接《UI原生链路与边界》，本次只做磁盘 DLL 静态比较，没有新增游戏运行或视觉验收。

## 结论

常用 BACKDROP/TEXT/BUTTON 等控件，两端建立在 Warcraft 原生 Frame/FDF 体系上。Lua 控件表是包装，不是独立绘图引擎；不能据此把两家插件的全部扩展、模型、事件与销毁语义视为完全一致。

视口能力来自原生扩展 API 与启用状态，不是 Lua/JASS 语言。经用户指出后补查 KKAPI：InnerJAPI 的 FrameSetViewPort 和 KK 的 DzFrameSetClip 都修改传入 frame 地址 +0xC 的 bit 0。此前只核对 BlizzardAPI.j、遗漏 KKAPI.j，因而“DZ 没有对应能力”的宽泛结论不成立。JASS 可以通过已支持的 KK 接口使用该能力，无需为此接入 InnerJAPI。

## 源码链路

- `src/ui/base/controls/panel.lua:111`：以 BACKDROP 类型调用 japi.CreateFrameByTagName，传入原生 parent_id 与模板。
- `src/ui/base/controls/class.lua` 的 set_view_port：调用 japi.FrameSetViewPort(self._id, bool)。
- `src/scaffold/ui.lua`：滚动面板及 clip_children 自动启用视口，另行处理裁剪祖先对输入命中的限制。
- `D:/War3/Library/War3Lib/Jass/ui/components/image/UIImage.j:25`：同样以 BACKDROP 调用 DzCreateFrameByTagName。
- `D:/War3/Library/War3Lib/YDWE/jass/BlizzardAPI.j`：提供创建、父子关系、定位、尺寸等接口，没有 FrameSetViewPort/DzFrameSetViewPort 声明。
- `D:/War3/Library/War3Lib/YDWE/jass/KKAPI.j:38`：有 DzFrameSetClip(integer, boolean)；第 92 行另有 DzFrameEnableClipRect(boolean)。UIImageModule.j:24 的 setClip 已调用前者。
- `D:/War3/Library/War3Lib/Jass/InnerJapi.j:228`：已经有 Zinc/JASS 侧 FrameSetViewPort。函数体只有 GetTriggeringTrigger，是等待插件接管的占位入口，不是独立实现；本次没有验证其构建后绑定状态。

设置原生父控件、设置相对锚点、设置大小、开启裁剪是不同操作。视觉上放在底板内，甚至定位相对于底板，都不能证明已经建立正确的原生父子结构。

## DLL 对比证据

复现：按原报告提取固定载体，运行 `python tools/compare_ui_native.py`。使用已有 build/analysis-deps 中的 pefile/capstone，只解析文件，不 LoadLibrary、不注入、不修改 DLL。

| 样本 | SHA256 |
| --- | --- |
| InnerJAPI 1.49-9 内嵌 pe-60ae0.dll | 5c44196eb2b82a11ccf8754a259193db86dc4c823140887b0442741d48132a8c |
| LAN/KKWE 的 kkapi_local_plugin.dll | 346aa2fa320b7919d95e7cd56792858331f6c224c5459652e166f36c832c8ee3 |

以下是 ImageBase 0x10000000 下的静态 VA。DZ 样本代表本机测试实现，不代表所有线上平台版本。

InnerJAPI CreateFrameByTagName 注册于 0x102527b2，回调 0x10249740，参数解包后进入 0x102492e0。DZ 创建函数通过诊断字符串 JAPI::GUI::DzCreateFrameByTagName 定位于 0x10084690。

| 阶段 | InnerJAPI | 本机 DZ |
| --- | --- | --- |
| 类型描述/工厂 | 类型表 0x106e6158，间接调用 0x106e4ddc | 0x10074c20 → 0x10073c40 |
| 类型相关字段 | 写描述对象 +0x100 | 同样写 +0x100 |
| 模板类型匹配 | 对象 +0x2C 生成位掩码，与模板 +0x48 检查 | 相同偏移与检查形态 |
| 应用模板 | 置描述对象 +0x34=1，再调用适配函数 | 相同形态 |
| 名称登记 | 对象 +0x1C | 对象 +0x1C |
| 创建分支 | 描述对象 +0x48 的 0x2、0x08000000 位 | 相同偏移与位掩码 |
| 临时描述清理 | 虚表首项，参数 1 | 相同形态 |

InnerJAPI 还通过游戏字符串 UI\\FrameDef\\FrameDef.toc 与 Error, frame "%s" already encountered! 定位底层函数。这比 API 同名更有力地支持两者共用 Frame/FDF 基础体系。本次未恢复全部 C++ 类，也未动态证明所有间接调用落到同一地址。

### 视口 setter

注册于 0x10252dbd，回调 0x1024bdd0，签名 (IB)V。有效逻辑：

```asm
mov ecx, [ebp+8]       ; 传入 frame 地址
test ecx, ecx
je return
cmp dword ptr [ebp+0Ch], 0
mov eax, [ecx+0Ch]
je disable
or eax, 1
mov [ecx+0Ch], eax
; disable：and eax, 0FFFFFFFEh，再写回
```

等价于 flags = enable ? flags | 1 : flags & ~1。flags 是按语义给出的描述，不是恢复的原始字段名。函数没有创建 Lua canvas、逐像素绘图或逐个隐藏越界子控件；Lua 只发出状态设置，后续由原生侧绘制。

补查本机 DZ DLL：DzFrameSetClip 的注册三元组按“函数、名称、签名”排列，0x10089f99 写入回调 0x10086900，随后为名称及 (IB)V 签名。该函数同样先判空，再对 [frame+0xC] 执行 or 1 / and 0xFFFFFFFE。与 InnerJAPI 的 setter 在核心状态修改上等价。不能只搜索 ViewPort 名称而漏掉 Clip 同义接口。

DzFrameEnableClipRect 另注册到 0x10084a50，签名 (B)V，是无 frame 参数的独立开关，不应与逐控件 setter 混为一谈。其具体作用及与渲染消费者的关系仍需继续追踪。

## 父子关系为何不自动裁剪

父子关系可以组织布局、显示与生命周期；截掉越界区域还需要绘制路径使用相应裁剪状态。普通定位/尺寸/父子 API 没有替代 InnerJAPI 提供的这个开关。

概念上，允许绘制的区域是子控件区域与祖先视口区域的交集。裁剪可以保留半行文字、半张图片；它不同于隐藏整个控件、缩小控件或用不透明图片盖住外侧。

**最终渲染消费者仍未可靠定位。** 原有 test [reg+0xC],1 候选包含其他对象；本次还复核到 shr reg,3; and reg,1 实际检查的是 bit 3，不能错认成 bit 0。不能仅凭同偏移、矩形运算或接口名字，宣布它采用 D3D scissor、stencil 或 CPU 顶点裁剪；也不能断言完全来自原版 Game.dll、无需插件 hook。

## 对项目的含义与待测边界

1. Lua 新项目继续使用 panel/is_scroll/clip_children，其便利来自 Lua 封装加 InnerJAPI 原生扩展。
2. JASS 老项目不必为这一项能力整体迁移 Lua；已支持 KKAPI 的环境可用 DzFrameSetClip。若效果不符，检查实际运行时支持、调用对象、原生父子关系、Frame 类型及全局开关，不能再归因于“JASS/DZ 没有能力”。
3. 不把反汇编偏移直接变成业务内存写入。setter 只判空，没有足够的类型和存活检查；普通 Frame 与 SimpleFrame 不应混用布局假设。
4. 绘制裁剪和鼠标命中分别验收。脚手架另行补了裁剪祖先交集，setter 本身不证明按钮、滚轮、快捷键正确受限。

最小后续矩阵：同一运行时用 Lua/InnerJAPI 和 JASS/DZ 分别创建父子控件，保持类型、父子关系、坐标相同，关闭/开启同一 viewport setter，对照跨边图片、半行文本、模型、嵌套及被裁掉区域点击。先确认 JASS 绑定，再人工验收像素与真实输入。本次未执行这组新测试；历史测试也没有把裁剪像素和真实输入列为已通过。

依据：[官方视口接口](https://japi.war3rpg.top/1.44/设置控件视口.html)以 JASS 形式描述接口；[更新记录](https://japi.war3rpg.top/)列出 1.44 新增视口、1.45 优化滚动面板。原始反汇编与哈希在 research/evidence/ui-native-comparison.json 和 ui-native-comparison.txt。
