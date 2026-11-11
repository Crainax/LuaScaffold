# InnerJAPI Lua 项目脚手架

基于 InnerJAPI **1.49-9** 的经典 Warcraft III Lua 模板。玩法、UI 和测试使用 Lua 5.3；构建工具生成必要的 JASS 引导外壳，日常业务开发不需要写 JASS。官方 UI 渲染层已接入，原包快照保持原样。

实测支持范围及证据见 [实机验证报告](docs/实机验证报告.md)。这是可复用的基础模板，不包含完整 RPG、伤害、技能、平台存档或登录框架。新玩法仍须做自己的同步验证。

## 从模板创建项目

在本目录执行，目标目录必须不存在：

```powershell
python tools/new_project.py D:/War3/MyLuaGame --id MyLuaGame --title 我的Lua地图
cd D:/War3/MyLuaGame
python tools/check.py
python tools/build.py --name first-build
```

地图输出为 `build/first-build.w3x`。每次使用新的构建名，避免覆盖旧地图和混用测试日志。`project.json` 设置项目 ID、标题及版本；ID 使用 ASCII 字母、数字、下划线或连字符。复制工具不复制 `.git` 和 `build`，新项目可自行初始化 Git。

开发入口为 `src/app/main.lua`；默认 UI 在 `src/app/view.lua`。`src/app/runtime_test.lua` 只进入带 `--test` 的测试包，发行包不包含它。

## 本机工具与构建

需要 Python 3、Lua 5.3 的 `lua`/`luac`，以及提供 StormLib 和经典 JASS 校验器的编辑器运行库。本机默认路径：

- `D:/WE/YDWE1.32.13正式版`：MPQ 打包/回读运行库。
- `D:/WE/KKWE_Plugin`：`pjass-classic`、common.j、blizzard.j。
- `D:/War3/tools/LanTest`：可选的自动局域网测试工具；不随模板复制。

构建时可以用 `--runtime`、`--we` 覆盖前两项。构建会验证 78 个原包文件的 SHA256，检查生成的 JASS，并逐文件回读最终 MPQ。`build/*-build.json` 保存地图哈希及实际打包文件哈希。

只生成待导入文件树：

```powershell
python tools/stage.py --name payload-001
```

`build/payload-001` 对应 MPQ 根目录，已包含官方 UI、字体和运行载体。整合已有地图时，把 `integration/loader.j` 纳入正常地图初始化，并全端调用一次。与已有 War3Lib InnerJAPI 入口二选一，不能重复启动。完整地图构建器目前生成六个静态玩家槽位及最小测试地形；实际地图需自行接入地形、对象数据和初始化顺序。

## 自动验证

```powershell
python tools/check.py
python tools/build.py --name verify-six --test --clients 6 --ticks 12000
./tools/test.ps1 -Name verify-six -Clients 6 -TimeoutSeconds 360
python tools/collect_evidence.py
```

测试客户端数须与构建参数一致；同一游戏环境只运行一场。工具以每端断言、完成标记和房主 OOS 检测验收，结束后按记录的 PID/创建时间清理本次进程。默认测试脚本依赖本机已安装的自动测试启动器和清理计划任务。

OOS 检测对照用例会**故意制造不同步并返回失败**，只能用于测试：

```powershell
python tools/build.py --name verify-control --test --clients 3 --ticks 4000 --oos-control
./tools/test.ps1 -Name verify-control -Clients 3 -TimeoutSeconds 180
```

预期结果是房主记录 `desync detected`，不能把这种构建拿来发布。测试证据在 `tests/evidence`；详细覆盖及未覆盖项见 [验证计划](docs/验证计划.md)。

## 开发规则

- 同步逻辑使用 `entity_registry` 分配的单局稳定 ID。登记必须发生在全端一致的顺序中；不能根据 handle、frame ID、对象地址或未排序枚举选择目标。
- UI 事件是本地回调，只提交 `bridge:send(...)` 意图；业务在同步接收器中校验身份、对象、权限和状态后执行。默认 `ping` 仅演示，不提供通用奖励接口。
- `handle_level=0`，原生资源显式销毁。GC 负责 Lua 对象，不替代单位、组、计时器、触发器和 frame 的生命周期管理。
- 匿名函数可以正常使用；长期回调必须能取消。控件优先用 `control:wait/loop`，销毁父控件会取消所属任务并先销毁子控件。同步任务使用 `bridge.scheduler`。
- UI 定时单位是毫秒，逻辑 scheduler 单位是 tick；统一原生计时器请求间隔 0.01 秒，实际调度精度由引擎决定。
- 禁用原包的隐式 `sync_key`、`load` 解码、热更新、周期全量 GC 和全局 math 改写。标准三角函数使用弧度。
- `Context` 是开发期调用边界检查，不能拦截你直接调用原生 API。不要在本地 UI/GC 回调里创建、销毁或修改同步游戏对象。

## 目录与文档

| 路径 | 用途 |
| --- | --- |
| `src/scaffold` | 生命周期、稳定 ID、任务队列、命令协议、引擎/UI 适配 |
| `src/ui/base` | 官方渲染层的独立适配副本 |
| `src/app` | 新项目业务入口、默认界面及测试 harness |
| `vendor/war3ui-1.49-9` | 原包、来源记录、完整文件哈希 |
| `assets/map` | 最小地图地形及元数据来源文件 |
| `integration` | 固定 JASS 加载外壳 |
| `tests` | 离线测试、原包问题复现和实机证据 |
| `tools` | 校验、复制模板、打包、测试、采集证据 |

- [UI 适配记录及使用方式](docs/UI适配记录.md)
- [原包研究、handle/OOS 与 GC 说明](docs/InnerJAPI研究报告.md)
- [实机验证报告](docs/实机验证报告.md)
- [验证覆盖与后续验收](docs/验证计划.md)

更换 InnerJAPI 二进制、Warcraft 版本或平台后需要重新验证。
