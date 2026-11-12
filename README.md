# InnerJAPI Lua 项目脚手架

经典 Warcraft III / InnerJAPI **1.49-9** / 内嵌 Lua **5.3** 开发基线。业务、官方 UI 适配和测试用 Lua；地图保留必要 JASS 初始化和单次加载入口。原包 78 文件保持不可变。

当前包含 **3 个英雄类型**、专属技能与二选一天赋、原生伤害/特效、挑战/Boss、命令 UI、稳定单位 ID 和生命周期管理。它是可运行的样板，未包含完整 RPG、平台存档或装备系统。先读 [正式业务目录与技能样板](docs/正式业务目录与技能样板.md)、[Lua 开发规则](docs/Lua开发规则.md) 和 `.agents/skills/innerjapi-lua/SKILL.md`。

## 新项目

目标目录必须不存在：

```powershell
python tools/new_project.py D:/War3/MyLuaGame --id MyLuaGame --title 我的Lua地图
cd D:/War3/MyLuaGame
python tools/check.py
python tools/build.py --name first-build --map MainMap --format obj
```

输出 `build/first-build.w3x`，每次使用新构建名。业务在 `src`；公共 `scaffold/ui/game` 和原包在 `deps/lua-scaffold`，由 `framework.lock.json` 固定内容哈希，新项目不依赖原脚手架目录。复制不带 `.git`、`build`、历史 `tests/evidence`；继承的研究报告不证明新项目已经通过实测。升级/回退见 [固定依赖与 LNI 构建](docs/固定依赖与LNI构建.md)。

## 开发与测试

入口 `src/app/main.lua` 组装 `world/session.lua` 和 `presentation/challenge_view.lua`。每位玩家拥有三个英雄，选择天赋、开始挑战、选择英雄施法。技能使用独立逻辑能量，不等于原生 mana；挑战结束恢复队伍，冷却不重置。

```powershell
pwsh -NoProfile -File tools/run.ps1 -Mode Build -Map MainMap -Format slk
pwsh -NoProfile -File tools/run.ps1 -Mode Play -Dev
pwsh -NoProfile -File tools/run.ps1 -Suite gameplay -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Resource -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Resource -Suite resource_matrix -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Soak -Clients 3
```

VS Code tasks 提供两图编译、套件选择、1/3/6 客户端、OOS 对照、资源对照及长测。没有 YDLua 切换。同环境串行启动；手动 Play 保留游戏，自动测试按本次 PID/创建时间清理。入口验证成功构建清单、地图哈希和人数，失败构建的残留文件不能启动。

`gameplay` 是业务/生命周期测试；`ui/performance/hotreload` 是独立回归；`campaign_soak` 是长期业务压力；`business_resource` 重复两轮相同业务负载；`resource_matrix` 分离单位、事件/任务、UI、技能、组合及恢复。OOS 模式故意分叉，预期被房主检测并返回失败，不可发布。编译、原生断言、多人状态和像素/真实输入验收是不同证据。

Logger 路径：`D:/Program Files (x86)/Warcraft III Frozen Throne/Lua框架研究/logs`，派生项目默认使用自己的 ID 文件夹。启动适配器在共享锁内临时隔离全局 jass2binary，加载完成恢复，见 [j2b 与日志](docs/j2b加载与隔离.md)。构建不加密，不弹额外游戏 console。

## 地图构建

`maps/MainMap` 和 `maps/UnitTestMap` 是独立 LNI 源，含物编、地形、初始化、预放置和区域。构建使用固定 **w3x2lni 2.7.2** 私有缓存，支持 OBJ/SLK，保留地图初始化并插入一次 Lua 引导；不修改共享配置。最终验证包括载荷字节、初始化二进制、物编有效字段及最终 JASS，成功清单最后写出。

本机工具：Python 3、宿主 Lua 5.3、`D:/War3/tools/w3x2lni`、`D:/WE/YDWE1.32.13正式版` 的 MPQ 运行库、`D:/WE/KKWE_Plugin` 经典 JASS 检查器。自动游戏测试另需 `D:/War3/tools/LanTest` 及已安装的精确清理计划任务。路径选项以 `python tools/build.py --help` 为准，内容锁仍生效。

`tools/stage.py` 仅生成待导入载荷。正式包排除 runtime_test、旧测试 UI app/view、probes 和 dev，`--dev` 才包含受控 UI 热更。已有地图集成须保证唯一引导，不能同时执行 War3Lib 的 InnerJAPI 加载流程。

## 证据与边界

新增 [handle引用统计与回归](docs/handle引用统计与回归.md)：`require('scaffold.handle_refs').snapshot()` 查看框架显式持有的单位/特效/触发器/计时器引用。关注分类active是否回到基线，累计refs/unrefs正常增长。最新增量验收使用 `python tools/verify_handle_refs.py`；下面第二轮37分钟记录对应此前提交 `1bf9031`，不冒充新统计版本的长测。

[单位生命周期与 handle 复用](docs/单位生命周期与handle复用.md)、[第二轮实测报告](docs/第二轮实机验证报告.md)、[第一轮扩展实测](docs/扩展实机验证报告.md) 保留通过及失败。原始日志在 `tests/evidence`，第二轮完整检查使用 `python tools/verify_round2.py`，须先收集该轮全部会话。所有结论受固定运行时、平台和场景限制；新项目必须建立自己的验收集合，不能继承历史通过记录。

第二轮最终源码已完成单人、3/6客户端、故意OOS对照、UI/热更回归、11阶段资源矩阵、重复工作对照，以及约37分15秒的三端长测（每端354轮挑战、359轮一致摘要、6200断言）。`verified-round2.json` 核对当前源码与证据；独立项目示例在 `D:/War3/LuaScaffoldExample`，已完成离线及两图构建，未单独运行该副本游戏。

历史长测曾观察到私有内存增长，Lua 清理通过不等于原生零泄漏。Windows 进程句柄数不等于 Warcraft handle ID 数。真实鼠标/输入法、裁剪像素、多分辨率外观仍需[人工验收](docs/人工验收步骤.md)，未使用桌面自动化。玩家退出清理有模拟通知及真实原生资源验证，不等于真实断线/重连已经测试。

其他研究：[框架选型](docs/框架选型与目录研究.md)、[UI 原生链路](docs/UI原生链路与边界.md)、[性能/GC/时钟](docs/性能GC与时钟实验.md)、[受控 UI 热更](docs/计时事件与开发热更新.md)、[验证计划](docs/验证计划.md)。
