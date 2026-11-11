# InnerJAPI Lua 脚手架研究报告

研究基线日期为 2026 年 11 月 12 日。目标是让以后新 Warcraft 项目的玩法和 UI 都由 Lua 开发，并把同步及生命周期风险限制在清晰的基础层中。

**可行，值得采用；但应以当前包的引擎与 UI 实现为基础重新组织入口，不能直接复制整个示例入口就宣布多人安全。** 原包的 `script` 目录包含 60 个 Lua 文件、22,125 行，其中相当一部分是 common/Blizzard 的 Lua 移植，不等于已经实现完整的 RPG 玩法框架。

这里把结论分为三类：源码确认的事实、离线可复现的行为，以及需要游戏实测的边界。文档中的风险等级是本项目的工程判断，不代表官方公告。后续实现已接入官方 UI，并完成固定环境的单人、三人、六人及故意 OOS 对照验证；最新范围与证据见 [实机验证报告](实机验证报告.md)，适配差异见 [UI 适配记录](UI适配记录.md)。

## 能否以后全程使用 Lua

玩法、技能、事件、数据结构、业务状态、UI 组件可以使用 Lua，通过 `require 'jass.common'` 和 `require 'jass.japi'` 调用引擎。名字里有 `jass` 只是桥接模块名，不表示必须写 JASS 业务代码。

经典 Warcraft 的地图初始化、地形、预放置对象、地图配置和插件加载仍有底层格式要求。当前原包在 `embedded.j` 尾部通过 `StartCampaignAI(..., "callback")` 加载插件，再执行 `AbilityId("exec-lua:plugin_main")`。War3Lib 的 `Jass/YDLua.j` 在 `WAR3_INNER_JAPI` 分支使用同一顺序。可以把这一小段固定外壳交给构建工具维护，让日常开发只接触 Lua。

这不同于把地图切换为 Reforged 的原生 Lua 脚本模式。不要为了“全 Lua”误改地图脚本语言并丢掉经典版本兼容性。也不要只复制 `.lua` 文件，却漏掉 `callback`、`(key)` 和 `wenhao_plugin.tga`。

官方首页给出的通用接口范围是 1.24e、1.26、1.27；这是文档声明，不能直接扩展为所有 Warcraft 版本、所有平台或每个小版本的实测保证。[官方首页](https://japi.war3rpg.top/)

## 原包结构与实际启动链

```text
package/
  insert.j                  编译期遍历导入 plugin，生成 path.lua
  embedded.j                JAPI 声明/桥接与引擎加载
  plugin/
    callback                引擎启动资源
    (key)                   配套资源
    wenhao_plugin.tga        配套运行库载体，不是普通 UI 贴图
    plugin_main.lua         Lua 总入口
    path.lua                本地路径与 MPQ 搜索路径
    core/ fonts.TTF         控件贴图和字体
    script/
      init.lua              ac → base → ui → 界面 → 地图类 → GC → 热更
      ac/                   事件、计时器、数学、坐标、LNI
      base/                 runtime、native、common、Blizzard、日志
      ui/base/              class、控件、鼠标键盘、UI 时钟、FDF
      ui/client/            本地事件整理、序列化、发送队列
      ui/server/            同步事件接收和分发
      ui/tool/              编辑/调试工具，原 ui/init.lua 默认不加载
      界面/ 地图类/          示例与玩家包装
```

`client/server` 是同一个 Warcraft 客户端 Lua 环境里的职责划分，**这里的 server 不是独立权威服务器**。它借助游戏同步消息使各客户端执行相同逻辑，本地变量并不会因此天然可信。

原包有几个需要修改的启动决定：

| 位置 | 源码行为 | 新模板决定 |
| --- | --- | --- |
| `plugin_main.lua:17` | xpcall 的错误处理正文被注释，初始化失败可能静默 | 错误必须留日志并明确失败 |
| `path.lua:2` | 用地图是否带 `war3map.wtg` 推断本地模式，包含作者旧电脑路径 | 构建配置显式选择模式；发行版只用包内路径 |
| `script/init.lua:1` | 先加载 ac，随后才设置 runtime；ac.timer 已经创建原生 timer | handle 策略必须在首次业务句柄访问之前确定 |
| `base/runtime.lua:29` | handle_level=0，sleep=true | 当前候选维持 0，关闭 sleep，统一任务调度 |
| `base/library.lua` 末尾 | 自动调用 Lua 版 InitBlizzard | 不整包加载；避免与地图 JASS 初始化重复创建资源 |
| `ac/math.lua:9` 等 | 把全局三角函数改成角度制 | 保留标准数学库；另建 sin_deg 等命名函数 |
| `script/init.lua:6` | 每 30 秒全量 GC 并打印 | 不把它作为防泄漏方案或同步保证 |
| `script/init.lua:7` | 默认加载 F5 本地热更 | 正式包和多人包禁用 |

原包 UI 并非纯 Lua 无副作用库。加载过程中会创建 timer、hashtable、控件模板并安装全局回调；第一次 require 必须在各端一致的启动位置执行，不能等某一位玩家第一次打开背包时才懒加载整个框架。

当前工作区的目录名 `LuaScaffold` 后还含一个不可见字符 U+200C。本次不重命名工作区，脚本使用相对路径规避命令输入歧义；以后复制成新项目时建议使用纯 ASCII 项目目录名。它与 Lua 逻辑无关，但可能导致旧 Windows 工具的编码输出和路径匹配出错。

## War3Lib 已有研究可以复用到什么程度

检查了当前拥有这些行为的实际文件：

- `D:/War3/Library/War3Lib/Lua/compile/RuntimeProfile.lua`：YD Lua 与 InnerJAPI 分开缓存和打包，InnerJAPI 资源在版本目录中固定。
- `D:/War3/Library/War3Lib/runtime/innerjapi/README.txt`：明确 MPQ 根目录位置、全量构建和游戏内兼容性待测的范围。
- `D:/War3/Library/War3Lib/Jass/YDLua.j`：选择唯一 Lua 引导入口。
- `D:/War3/Library/War3Lib/script/init.lua`：实际使用 handle_level=0、sleep=false，并区分每位玩家的日志。
- `D:/War3/Library/War3Lib/script/experiments/innerjapi`：实验模块有 start/stop，HTTP 回调用 generation 阻止停止或重载后的旧结果继续处理。

本次快照的三个运行库资源 SHA256 与 War3Lib 的 `SHA256SUMS.txt` 相同。因此可以复用现有的引擎来源与加载经验；但已有单人实验和打包测试不能证明这套完整 UI 与新玩法在多人环境安全。

HTTP 是一个具体的版本陷阱。War3Lib 实验说明记录了 1.49-9 的 HTTP 回显与 HTTPS 空结果，及该载体所用 libcurl 缺少 HTTPS 后端的分析。本次没有再次发起网络请求，不把旧实验扩大为全部版本结论。更重要的是官方明确表示 1.50 以上计划取消 `post_message`；新项目不能把它作为长期唯一平台后端。[官方服务器通讯说明](https://japi.war3rpg.top/Lua/服务器交互.html)

## Handle ID 与 OOS

### 先区分四种编号

| 名称 | 实际含义 | 可以怎样使用 |
| --- | --- | --- |
| 原生 handle / GetHandleId | 当前客户端引擎对象身份，可能被回收复用 | 本机对象查表和诊断；必须管理生命周期 |
| UI `_id` / frame ID | 本客户端控件标识 | 渲染、控件事件定位；不能作为玩法对象身份 |
| `class.handle_manager` 的 `_index` | 原包自己的可回收 UI 序号 | UI 内部命名；也不能跨端决定玩法 |
| 自建 entity ID | 在确定的同步创建顺序中分配的业务 ID | 同步命令、排序、存活校验和确定性日志 |

Lua table 的地址、`tostring(table/function/userdata)` 也不是跨端稳定编号。把 handle 换成 table 包装，不会自动使其具有同步身份。

### Xlimon 的证据与边界

现有 [Xlimon OOS 报告](D:/War3/Maps/Xlimon/20260801-OOS报告.md) 记录：同一玩家同一件 `I20v` 在 P2/P3 为 `1052208`，在 P1 为 `1052210`。报告也明确区分了“已观测到 handle 差异”和“大帝目标选择是高度疑似根因，尚缺逐端目标日志”。本次沿用前者作为确切教训，不把后者改写成已完全证实。

危险链条是：

```text
本地创建/释放、不同的引用保留或分配历史
       ↓
handle 数字 / 对象枚举顺序不同
       ↓
按最小 handle 选目标、按枚举第一个处理、随机索引对应不同候选
       ↓
攻击/死亡/触发顺序不同 → RNG 消耗不同 → 玩法状态继续分叉
```

同一个业务对象在各端 handle 不同，不必然立即掉线；**把这种差异用于同步决策才是必须杜绝的行为**。反过来，也不能因为当前没报警就允许本地随意创建经典 timer/trigger/group/unit。

### Handle ID 可以做什么

`by_handle[handle] = record` 用于本地快速找同一对象，且销毁时清理映射，是可接受的模式。各端键值可以不同，但必须都映射到相应的同一个逻辑实体。风险来自陈旧映射、handle 复用，以及通过这些键的顺序决定业务。

以下用途禁止：最小 handle 优先、平局时比较 handle、把 handle 发送给别人后直接 i2h、按 handle 排序给每人发不同奖励、拿 handle 作随机种子、把本地对象地址写入同步状态摘要。

技能找目标时，应明确完整规则，例如“距离平方，再 entity ID”。不能只排序距离后相信稳定排序自动解决相等项；Lua 的 table.sort 不应被当成稳定排序承诺。比较器必须形成有效顺序，不要用 `<=`，也不要用会破坏传递性的随意误差比较。

随机选目标必须先形成**同样成员、同样次序**的候选数组，再做同样次数的同步随机抽取。组枚举结果不能直接按返回顺序分配新 entity ID；否则只是给不稳定顺序重新编号。

预放置单位宜由构建时生成的固定列表登记；动态单位在全端一致的创建路径登记。引擎自动产生的单位、变身替换、召唤及复活，都需要明确登记/撤销规则。当前 `entity_registry.lua` 只实现映射与单局不复用编号，尚未代替完整单位生命周期管理器。

### handle_level 不是同步安全开关

官方 YD Lua 说明区分：0 是数字且不自动保护引用，1 使用 lightuserdata 但也不保护引用，2 使用完整 userdata 并管理引擎引用。更高等级解决部分引用保护问题，不保证跨端身份相同。[handle_level 说明](https://japi.war3rpg.top/lua-engine.html#runtime-handle-level-默认为-0)

| 方案 | 优势 | 必须承担的问题 |
| --- | --- | --- |
| level 0 | 与此原包、当前 War3Lib 一致；数字接口兼容较好 | 遗留数字可能指向复用对象；长期持有需审查 ref/unref |
| level 1 | 不容易把普通整数误当 handle | 没有引用保护；原包的数字判断需适配 |
| level 2 | 桥接层持有时保护引擎引用 | userdata 的回收/引用释放受 Lua 可达性影响；本地 UI 引用差异需要重点联机验证 |

候选基线选择 **level 0，加显式资源所有权与稳定业务 ID**。这是基于现有兼容性的工程选择，不是证明 level 2 必然 OOS。level 2 在多端 GC 和本地引用不一致时可能影响引擎引用释放时机，须对指定二进制实测；也不应一边运行一边切换等级。

`handle_ref` 防止过早复用，`handle_unref` 释放引用，`DestroyTimer/DestroyTrigger/RemoveUnit` 负责对象语义上的销毁，它们不是同一种操作。不能用多加一次 ref 掩盖生命周期问题，也不能对不归自己拥有的借用句柄随意 unref。原包 `base/war3.lua` 对 trigger 的 ref/unref 有配对示例，但不证明所有框架对象都已经覆盖。

## 匿名函数和回收

**匿名函数可以正常使用，不需要因为匿名就禁止。** 命名函数与匿名函数都可能形成闭包；把匿名函数改一个名字，不会解除它对外部对象的引用。

Lua 会回收不可达的函数、table 和循环引用；可达性决定回收资格，函数是否有名字并不决定资格。外部事件注册表或原生桥接若仍持有函数，它就仍然存活。[Lua 5.3 GC](https://www.lua.org/manual/5.3/manual.html#2.5)

典型引用链：

```text
全局事件表 / timer 队列 / C++ 回调注册表
                 ↓
               闭包
                 ↓ 捕获变量
           玩家 / UI / 单位包装 / 缓存
```

把 UI 变量设为 nil 或把原生对象 Destroy 掉，不一定切断上面的整条链。反过来，Lua 包装 table 被回收，也不等于引擎自动调用了所有 Destroy API。

### 本次验证了什么

`tests/run.lua` 用弱引用观察并验证：一个自引用闭包在外部注册表清空后能够回收；注册表仍持有它时不能回收。新调度器取消任务后，即使外部仍保留取消 token，捕获的大对象也可以回收。

`tests/upstream_audit.lua` 则复现了原包 `ac.wait(600000, fn):remove()` 后，队列仍强引用 task，task 仍持有 `on_timer`，因此捕获对象不会马上回收。通常要等到原定到期位置被清掉，或者所有其他引用也释放。这属于可观察的延迟释放；不能一律称为永久泄漏。若外部长期保存 task，其 callback 会继续保留。

### 实际编码约定

- 一次性任务完成、取消和失败时都清理 callback/context；循环任务必须能取消。
- UI 面板关闭时注销事件、取消刷新/动画、清空业务引用，并显式 destroy 控件。
- 模块 start/stop 对称；热重载前 stop；销毁要幂等。
- 异步 HTTP 或延迟回调如果不能真正取消，使用 generation 判断旧回调是否失效；这只能阻止执行，不保证底层立刻释放内存。
- 不在每次局部刷新中重新给原生引擎注册一个新闭包。对原生 timer/trigger 使用少量稳定入口，在 Lua 内分发可取消任务。
- 需要在未来执行的对象操作尽量捕获 entity ID，再查存活注册表，避免捕获已移除的裸数字 handle。
- 不用 `__gc` 实现同步 RemoveUnit、发奖或 DestroyTimer；不要把弱表回收当成死亡/销毁事件。

原生回调桥是单独的验收项：`DestroyTrigger`、`TriggerRemoveAction`、`DestroyTimer` 是否立即释放内置引擎对 Lua closure 的全部引用，必须测 1.49-9 的真实行为。官方确实记录过“注册 Lua 闭包给 JASS 导致掉线”的修复，这说明历史上存在桥接缺陷，但既不能因此禁用全部匿名函数，也不能据此保证任何当前生命周期都安全。[引擎变动](https://japi.war3rpg.top/Lua/引擎变动.html)

## Lua 写法中额外需要注意的事

这套引擎不是未经修改的标准 Lua。官方引擎页面写为“lua 5.34”，通常理解为 5.3.4；运行中仍应记录 `_VERSION`、runtime.version 和实际载体哈希。当前电脑的离线解释器是 Lua 5.3.6，它只用于语义实验与新代码语法检查。

| 项目 | 本项目规则和原因 |
| --- | --- |
| 遍历 | 同步副作用前对明确类型的 key 排序或使用稠密数组；不能依赖 table/userdata 键的 pairs 顺序 |
| 引擎 pairs 修订 | 官方称改善 string/number key 的一致性，但插入历史、键集合、对象键、删除操作仍需一致；不要因此撤销排序约定 |
| 稀疏数组 | `#t` 不是键数；`ipairs` 遇 nil 停止；带洞参数用显式长度，禁止把混合表当数组发包 |
| 真值 | 0 和空字符串都是真；数字 handle 的无效值不能仅用 `if handle then` 判断 |
| 随机 | 业务随机只在同步路径使用；先确认绑定是否消耗 Warcraft RNG。本地 UI 动效使用独立本地随机源，不能随意调用共享 math.random/randomseed |
| 时间 | `os.clock/os.time`、HTTP 到达时间、渲染 delta 仅用于本地用途；同步规则使用逻辑 tick/引擎同步事件 |
| 数字 | jass integer/real 与 Lua integer/float 边界要显式限制；拒绝 NaN/Inf，传输协议使用约定整数范围和量化单位 |
| Rawcode | 原生接口常要四字节整数；集中 FourCC 转换，不把任意中文字符串当四字节 ID |
| 字符串 | UTF-8 的字节长度不等于显示字符数；截断网络数据、姓名、富文本时使用正确单位 |
| 模块 | require 只首次运行；修改文件不会自动更换旧闭包。模块初始化顺序须固定，禁止本地懒加载同步基础设施 |
| 全局变量 | 默认 local，模块返回 table；第三方依赖不能任意覆盖 print/math 或向 _G 注入业务状态 |
| 协程 | yield/resume 不是自动同步；恢复来源若是本地 HTTP/UI，后续逻辑仍是本地。不要用 sleep 等待同步数据 |
| 错误处理 | pcall 成功只说明没有抛异常；catch_crash 不能修复已分叉的游戏状态；不能吞错后继续发奖 |
| 版本语法 | 不使用 Lua 5.4 的 `<close>`、`<const>`；中文变量名是该引擎扩展，通用模块宜使用 ASCII 标识符 |
| 字节码 | 官方引擎修改过字节码；不要把宿主 luac 输出直接当发行包。默认交付源码，确需加密时使用匹配版本工具并做打包回读 |

标准 Lua 的数组、真值和语言边界可查 [Lua 5.3 语言手册](https://www.lua.org/manual/5.3/manual.html#3)。涉及引擎变更、随机绑定和对象哈希时，以固定版本行为为准，不能只套标准 Lua 经验。

尤其要分开“UI 时钟”和“玩法时钟”。原包 `game.wait/loop` 与 `ac.wait/loop` 都用原生周期 timer 驱动，但前者的队列可能由本地鼠标和按键填充；**同样叫 timer 不表示回调天然同步**。本地事件向 ac 队列添加玩法任务，同样会产生分叉。

## UI 是否可以改用网站的模式

**可以。** 官方提供 `class.panel/button/text/edit/model/model2`、builder 和继承机制，适合让日常 UI 开发摆脱 JASS 端手写 DzFrame 调用。底层仍会调用原生 frame/JAPI；迁移的价值是 Lua 层的组件、事件、布局与资源管理。[官方 UI 结构](https://japi.war3rpg.top/Script/界面/前言.html)

其事件约定是：普通 `on_button_clicked` 为本地事件；设置唯一 `sync_key` 后，对应 `on_sync_button_clicked(player)` 可接收同步事件。[官方事件管理](https://japi.war3rpg.top/Script/界面/事件管理.html)

阅读当前源码后的具体判断：

- 内置通道默认走 `SendCustomMessage → RegisterMessageEvent → GetMessagePlayer/GetTriggerMessage`；`ui/server/trigger.lua` 的 DzSyncData 分支被 `if false and ...` 关闭。并不是只有调用 JASS Dz 函数才能同步。
- UI 渲染事件、hover、鼠标坐标、选中单位、窗口大小属于本地状态。显示价格可以本地计算，扣钱和生成物品必须进入同步业务路径。
- `sync_key` 必须是业务定义的稳定字符串，不能由本地控件创建次数、frame ID 或 `_index` 临时拼接。
- 各端接收时都必须有相应控件及处理函数。一个客户端打开面板才创建的控件，不适合作为整个房间的命令路由中心。
- 原包 `ui/server/sync.lua:34` 把收到的 sync_data 写回控件，随后调用控件处理函数。它传递的是数据，不是验证了数据。价格、数量、对象归属、冷却与权限必须由同步状态重新判断。
- 原包采用 150ms 的控件队列和 120ms 的发送队列，并有时钟节流。操作不应承诺点击立即执行。动画和反馈可以先本地显示，成功结果以同步状态为准。
- `world_unit` 路径还要求单位包装提供 is_alive、get_point、get_height、is_visible 等方法；仅复制 UI 目录不等于这些玩法对象方法已经存在。

推荐新项目的接线方式：

```text
本地 UI 控件 → 发送命令名称、逻辑 entity ID、参数、序号
                                  ↓
                   引擎同步消息，提供真实发送者
                                  ↓
                   长期存在的命令路由与业务校验
                                  ↓
                    同步状态变化 → 各端更新本地显示
```

这样玩家 A 没打开商店、玩家 B 已关闭面板时，购买命令的业务处理也不会依赖 UI 是否存在。将来可以保留官方控件系统，但替换同步桥。使用显式命令桥时不再给同一个按钮配置官方 sync_key，避免重复下单。

### 官方 UI 的实际接入方式

原包 UI 与全局 base/InitBlizzard、双时钟、全局 WindowEventCallBack/FrameEventCallBack 以及同步编码器相互关联。现已把渲染部分提取到 `src/ui/base`，通过独立环境加载，替换本地任务队列并接入新命令桥。默认入口启用 UI；不执行原包全局入口或旧同步解码器。

实机验证已覆盖常用控件创建、文本读回、模型、滚动、进度条和销毁；真实鼠标/输入法及视觉效果仍需人工验收。同局重启 UI 不受支持。完整变更与限制见 [UI 适配记录](UI适配记录.md)。

## 原包发现与处理清单

所有行号均相对当前 `vendor/war3ui-1.49-9/package/plugin` 快照。上游文件保持原样，避免掩盖原始证据。

| 优先级 | 发现与源码位置 | 证据和处置 |
| --- | --- | --- |
| P0 | `script/ui/client/util.lua:245` 用 load 解码同步数据，仅过滤括号 | 离线复现：Lua 无括号字符串参数调用仍可执行函数。新通道完全不使用 load；不能把同步载荷当代码 |
| P1 | 同文件 89–115 行首事件编码达到 600 字节时可能不被放进批次 | 700 字节参数复现发送 `{}`。后续队列还可能受该条目阻塞；新基线明确拒绝超长格式，不静默丢包 |
| P1 | 同文件编码器将 `#t>0` 的表按 ipairs 写出 | 离线复现混合表的字符串字段丢失；新通道只接受固定字段 |
| P2 | 同文件编码器不把 end 等关键字键写成方括号形式 | 离线复现生成无效 Lua；再次说明不宜使用 Lua 源码序列化 |
| P1 | `script/ac/timer.lua:143` remove 未清 on_timer，也不立即移出未来队列 | 离线复现长任务捕获对象仍存活；新调度器取消时立即清理 callback 和注册项 |
| P1 | `script/ac/math.lua` 全局角度制替换 | 离线复现 sin(pi/2) 不再为 1；新入口不加载它 |
| P1 | `script/ui/server/sync.lua` 按接收数据和 UI 注册表派发 | 源码确认缺少通用业务 schema/权限验证。新通道只允许白名单命令、引擎发送者和显式验证函数 |
| P1 | `script/热更新.lua` 本地 F5 销毁与重载 UI、事件、计时器 | 源码确认；正式包不加载，不把它视为多人热更方案 |
| P1 | `plugin_main.lua` 静默错误、`path.lua` 作者路径 | 新入口记录错误并使用 MPQ 相对路径 |
| P2 | timer/trigger 移除后仍可能由业务对象保留 callback | 需要逐类清空 owner/event/callback，并测反复打开关闭，不只看 Lua 总内存 |
| P2 | UI 32 位字符串 hash、相同 sync_key 冲突 | hash 碰撞仅打印，重复键不能作为稳定路由保证；新命令直接使用短白名单名称 |
| P1 | 原包父 frame 与子 frame、按钮背景销毁次序 | 新适配层统一子先父后并幂等销毁，已通过实机压力；没有把原包旧顺序可能出错扩大为已证实崩溃 |
| 部分已测 | 原生回调登记、handle 引用、GC 差异 | 原生 TimerStart 闭包探针 0/8 保留，三/六端差异 GC 场景通过；TriggerAddAction 等其余注册类型仍需专项测试 |

这些优先级针对“直接把原包放进正式多人游戏”的风险。新入口已经避开上述旧编码器、示例入口和默认热更，但这不等于快照本身被修好了。

## 当前已经建立的基础

| 模块 | 已实现内容 | 尚不承担的职责 |
| --- | --- | --- |
| `scope.lua` | 逆序清理、幂等 close、某个清理失败后继续其他清理 | 不能自动猜测原生对象所有者或保证 native callback 已释放 |
| `entity_registry.lua` | 显式登记、单局递增 ID、不复用、删除后失效 | 不自动登记所有原生单位，也不代替 RemoveUnit/ref/unref |
| `scheduler.lua` | 整数 tick、同 tick 按登记序号执行、取消释放闭包、暂停/恢复、错误停止调度 | 暂无时间轮优化或大型战斗任务容量保证 |
| `command.lua` | 固定 ASCII 格式、长度/整数校验、真实发送者参数、白名单、重复序号拒绝 | 不是通用 JSON/存档协议；未实现大包分片、应答重试或防作弊服务器 |
| `innerjapi.lua` | 固定两个原生入口、显式引用配对、收到同步消息后才执行业务、发送队列限长与节流、故障停止本端处理 | 不是跨端故障共识；还需实际平台网络验证 |
| `plugin_main.lua` | MPQ 相对路径、先设置运行策略、可见错误、项目独立日志与业务入口 | 不代替真实项目的地图数据与玩法初始化 |

协议形如 `LS1|1|ping|0|0`。序号属于发送者本地发送通道，绝不能与 entity ID 计数器共享。发送者身份来自 `GetMessagePlayer`，不会从字符串中读取。当前高水位去重要求引擎对同一发送者保持顺序；可靠性、乱序及丢包行为仍列为联机验收项。

当前 scheduler 使用遍历加排序实现，逻辑简单但不是高容量战斗调度器。任务规模上去后可以改用时间轮或堆，前提是保持同一 tick 的确定性顺序与取消语义。不要为了复用而声称已经包含完整技能、弹道、伤害、平台存档或对象池系统。

发生同步业务异常时，仅停止本端后续 Lua 处理可以避免继续扩大本端破坏，却不能修复已产生的 OOS，也不能让所有客户端自动同时停止。正式项目需要定义断言失败上报、对局终止/排障策略，不允许把“捕获了异常”作为继续运行的安全凭证。

## 验证结果与采用路线

初期离线研究之后，已完成官方 UI 适配、完整最小地图构建、模板复制流程、10 项纯 Lua 用例、6 项上游复现、bridge/UI mock，以及单人、三人、六人实机测试和故意 OOS 对照。发行 payload 为 43 个文件，完整地图 50 个导入文件；测试构建额外包含 runtime harness。未改动 War3Lib、Xlimon 或原始 InnerJAPI 包。详细结果和早期失败记录见 [实机验证报告](实机验证报告.md)。

新项目采用顺序（其中模板层步骤已实现，项目自己的业务仍需验证）：

1. 以当前目录固定 Lua 规则和运行库来源，开始写纯 Lua 领域逻辑与离线测试。
2. 对接一个最小地图的打包器，验证唯一启动、包内模块读取与退出重进；不从 Xlimon 直接复制大型玩法。
3. 提取官方 UI 渲染层，接入独立命令桥，验证常用按钮/文字/模型/滚动及完整销毁。
4. 验证原生回调释放、句柄复用、稳定实体登记和取消任务压力场景。
5. 用多客户端制造不对称 UI/GC/本地活动，比较逻辑状态与 RNG 消耗，达到明确的 OOS 验收门槛。
6. 在实际目标平台及插件版本组合上验证后，发布固定版本的正式模板。

详见 [验证计划](验证计划.md)。最终方向是 **Lua 业务 + 官方 UI 组件思路 + 自己掌控的同步及生命周期边界**。这能明显改善开发体验，同时把 Xlimon 已经付过代价的问题纳入基础设计。
