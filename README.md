# InnerJAPI Lua 项目脚手架

经典 Warcraft III / InnerJAPI **1.49-9** / 内嵌 Lua **5.3** 开发基线。业务、官方 UI 适配和测试用 Lua；地图保留必要 JASS 初始化和单次加载入口。原包 78 文件保持不可变。

当前包含 **3 个英雄类型**、专属技能与二选一天赋、原生伤害/特效、挑战/Boss、命令 UI、稳定单位 ID 和生命周期管理。它是可运行的样板，未包含完整 RPG、平台存档或装备系统。先读 [正式业务目录与技能样板](docs/正式业务目录与技能样板.md)、[Lua 开发规则](docs/Lua开发规则.md) 和 `.agents/skills/innerjapi-lua/SKILL.md`。

## 从零创建正式项目

### 1. 准备环境与创建副本

在 VS Code 打开本脚手架，使用项目根目录的 PowerShell 终端执行以下命令，**不要在 `C:/Windows/system32` 执行相对路径命令**。本机脚手架文件夹名称末尾含不可见字符，优先使用编辑器的项目终端，不要手打其绝对路径。

需要 Python 3、宿主 `lua/luac`（Lua 5.3）、PowerShell 7（`pwsh`），以及下文列出的 w3x2lni、YDWE/KKWE 工具。自动实机测试还需要 LanTest 和清理计划任务。宿主 Lua 仅用于离线检查，实际游戏运行在 InnerJAPI 内嵌 Lua 中。

目标目录必须尚不存在；以下名称和路径可替换成自己的项目：

```powershell
# 在脚手架根目录执行
python -X utf8 tools/new_project.py D:/War3/MyLuaGame --id MyLuaGame --title "我的Lua地图"

# 此后的开发、构建和测试均在新项目根目录执行
Set-Location -LiteralPath 'D:/War3/MyLuaGame'
python -X utf8 tools/check.py
python -X utf8 tools/build.py --name first-build --map MainMap --format obj
```

分别确认 `NEW PROJECT READY`、`OFFLINE CHECKS PASSED`、`BUILD PASS first-build.w3x`。命令失败时先处理报错，不继续启动残留地图。输出地图为 `build/first-build.w3x`，每次直接调用 build.py 使用新的构建名；日常用 run.ps1 会自动生成带时间戳的名字。

生成器复制的是**带三英雄玩法的可运行样板**，不是空白游戏。它不复制 `.git`、`build`、历史 `tests/evidence`，也不会替你初始化 Git。首次确认可构建后，可在新项目执行：

```powershell
git init
git add .
git commit -m "初始化 InnerJAPI Lua 项目"
```

检查 `project.json` 中的 `id`、`title` 和 `version`。`id` 使用不超过 32 字符的 ASCII 字母、数字、横线或下划线；标题可以中文。可选增加 `log_folder`（单个文件夹名，例如 `我的Lua地图`），不填则日志目录采用项目 ID。

### 2. 理解业务与脚手架的依赖关系

新项目的实际布局如下（与本研发仓库公共层直接放在 src 下不同）：

```text
MyLuaGame/
  project.json                       地图标识、标题、日志目录
  framework.lock.json                公共框架内容哈希和依赖路径
  deps/lua-scaffold/                  创建时复制的固定版本公共框架
    src/scaffold/                    调度、事件、作用域、同步桥、引用统计
    src/game/                        单位、技能生命周期、原生战斗适配
    src/ui/                          官方 UI 适配
    vendor/                          固定 InnerJAPI 原始包
  src/
    app/main.lua                     应用启动、组装和停止
    world/session.lua                会话、命令分发、服务所有权
    world/arenas.lua                  英雄出生点和挑战场地坐标
    content/heroes/catalog.lua       英雄注册顺序
    content/heroes/reimu/            definition.lua、talents.lua、skills/
    content/heroes/marisa/           第二个英雄
    content/heroes/sakuya/           第三个英雄
    content/effects/                 共享特效配置
    content/challenges/training/     训练副本定义、Boss 行为
    systems/heroes/                  英雄实例和队伍管理
    systems/talents/                 天赋选择、权限与规则
    systems/challenges/              副本开始、结束、胜败和清理
    rules/combat.lua                 本地图伤害、天赋等公式
    presentation/                   本地 UI 和命令提交
    probes/                         游戏内测试探针，不进入正式包
    dev/                            开发模式的受控 UI 热更新
  maps/MainMap/                     正式地图 LNI 源
  maps/UnitTestMap/                 单元测试地图 LNI 源
  assets/                          模板资源；具体打包位置以构建器为准
  config/                          固定工具版本与构建策略
  tools/                           构建、启动、依赖升级、证据采集
  tests/                           离线测试及新项目自己的 evidence
  .vscode/tasks.json               编辑器任务
  .agents/skills/innerjapi-lua/      项目配套开发 skill
  build/                           自动生成，不提交 Git
```

业务照常写 `require 'game.skill.service'`，不需要把 deps 路径写进 require。构建器读取 `framework.lock.json` 并合并公共层与业务层；新项目可以独立搬走，不依赖原脚手架目录仍然存在。不要在 `src/scaffold`、`src/game`、`src/ui` 下同名覆盖公共模块，也不要直接修改已锁定的依赖文件。

日常改英雄、技能、副本、UI 时只改自己的业务层。公共框架修复应导出新版本包，再显式升级依赖并回归；旧项目不会随脚手架更新自动变化。工具和文档是创建时复制的，也不会因公共依赖升级自动更新。升级/回退操作见 [固定依赖与 LNI 构建](docs/固定依赖与LNI构建.md)。

### 3. 先从一个英雄技能开始改

先读 [Lua 开发规则](docs/Lua开发规则.md) 和 [正式业务目录与技能样板](docs/正式业务目录与技能样板.md)。推荐第一步只改灵梦技能的数值，完成一次“改代码 → 离线检查 → 游戏中施法 → 多人验证”的闭环，再替换整套英雄。

`src/content/heroes/reimu/definition.lua` 负责关联单位物编、技能和天赋：

```lua
return {
    key = 'reimu', name = '灵梦', rawcode = 'H001',
    skill = require 'content.heroes.reimu.skills.spirit_bolt',
    talents = require 'content.heroes.reimu.talents',
}
```

`src/content/heroes/reimu/skills/spirit_bolt.lua` 是共享技能配置。下面是现有机制可直接接受的示例：

```lua
return {
    key = 'spirit_bolt', name = '灵符',
    cost = 20, cooldown = 200,
    windup = 30, interval = 1, hits = 1,
    damage = 60, range = 700,
    effect = require 'content.effects.cast_aura',
}
```

`cost` 是样板的 Lua 逻辑能量，不是原生 mana；`cooldown/windup/interval` 使用逻辑 tick，调度请求间隔为 0.01 秒，但不是严格墙钟时间保证。伤害、范围、多段次数由公共技能服务执行；不要为同一个技能另建一套裸 CreateTimer/ref/unref。

`talents.lua` 放天赋配置；现有 `rules/combat.lua` 支持 `damage_percent`、`damage_flat`、`range_bonus`、`hit_bonus`。增加其他字段时，必须同时实现对应公式或机制，仅在配置里写字段不会自动生效。

目前每名英雄注册**一个技能、两个天赋选一**。四技能栏、主动/被动组合、弹道、BUFF、复杂召唤等不是现成配置能力，需要扩展技能接口、业务注册、命令/UI 和测试；不能只把 `skill` 改为一个数组。

新增或替换英雄时按以下顺序处理：

1. 在 `content/heroes/<英雄key>/` 创建 `definition.lua`、`talents.lua` 和 `skills/<技能key>.lua`，更新 require 路径和唯一 key。
2. 在 `catalog.lua` 中按明确顺序注册，不能扫描目录或用未排序 pairs 决定创建顺序。
3. 在 **MainMap 和 UnitTestMap** 各自物编中提供 `rawcode` 对应单位；新技能需要原生物编能力时也要配置对应对象。Lua 定义不会自动创建物编。
4. 检查 `world/arenas.lua` 出生点、`systems/heroes/service.lua` 注册方式和 `presentation/challenge_view.lua` 展示。目前样板给每位玩家创建整个 catalog 队伍；如果要选一个英雄，需要另做选人流程。
5. 补离线和实机探针。旧样板测试含三英雄及既定数值假设，改玩法后要同步调整测试设计，不能删除失败断言来制造通过。

定义表由 require 共享，不能往里面写某位玩家的冷却、能量或天赋选择；这些必须是英雄/施法实例状态。新增技能机制应继续沿用“校验 → 准备资源 → 提交消耗 → 执行 → 完成/中断清理”的生命周期。

### 4. 编写副本、战斗和 UI

| 要实现的内容 | 修改位置与责任 |
| --- | --- |
| 一个新副本或 Boss | `content/challenges/<key>/` 定义具体行为，并在会话/挑战服务中显式接入；创建目录不会自动注册 |
| 所有副本共用的开始、超时、胜败、退出 | `systems/challenges/service.lua`，管理实例和资源清理 |
| 护甲、暴击、属性与伤害公式 | `rules/` 和对应地图系统，不把地图专属公式塞进公共框架 |
| 技能按钮、天赋面板、挑战界面 | `presentation/`，参考现有 challenge_view |
| 所有者、施法和任务的通用生命周期 | 公共 game/scaffold；需要修改时走固定依赖升级流程 |

本地 UI 只提交命令，经过同步桥和发送者/目标/权限校验后才修改玩法。本地显示成功、命令入队成功都不等于技能已经执行成功。不要在 UI 回调、文件热更或 os.clock 分支里直接伤害、创建单位或发奖励。

单位延迟动作优先参考 `units:after(unit_id, ticks, callback)`；同步通用任务用框架调度器或便利 ac 接口，并交给资源作用域清理。UI 定时任务留在本地域。通过框架管理的单位、特效和任务不重复手动 ref/unref；裸原生资源仍需明确持有者和销毁责任。使用稳定业务 ID，不能用 handle ID 作同步排序或随机种子。

每个副本结束、技能中断和玩家退出都应取消任务、注销监听、释放自有单位/特效。检查 `scaffold.handle_refs.snapshot()` 的当前 active 是否回到基线；累计 refs/unrefs 随正常施法增长不是泄漏。

### 5. 日常构建与单人调试

下面命令均在**新项目根目录**执行。run.ps1 会先跑离线检查，再构建；每次调用都是一个新构建。

```powershell
# 只检查 Lua 语法、离线逻辑和构建清理边界，不启动游戏
python -X utf8 tools/check.py

# 只编译正式地图 / 只编译带 gameplay 探针的测试地图
pwsh -NoProfile -File tools/run.ps1 -Mode Build -Map MainMap -Format obj
pwsh -NoProfile -File tools/run.ps1 -Mode BuildTest -Map UnitTestMap -Suite gameplay

# 启动正式地图进行人工体验，游戏保留，由你手动关闭
pwsh -NoProfile -File tools/run.ps1 -Mode Play -Map MainMap -Dev

# 自动单人业务测试，完成后按本次进程身份清理游戏
pwsh -NoProfile -File tools/run.ps1 -Mode Test -Suite gameplay -Clients 1
```

也可在 VS Code 的“终端 → 运行任务”中选择编译、开发地图、选择单测或多人验证。运行自动测试前先结束上一场手动 Play；同一游戏环境只跑一场测试。`-Dev` 只启用开发能力，受控热更仅用于 UI view；改同步技能、单位或副本逻辑应重新构建并重开游戏。

新项目默认 Logger 路径为 `D:/Program Files (x86)/Warcraft III Frozen Throne/MyLuaGame/logs`（使用默认 GamePath 且未设置 log_folder 时）。第一次启动会创建目录；自定义 GamePath/log_folder 后按实际值添加到 Logger，不沿用脚手架的“Lua框架研究”目录。

### 6. 多人、异常场景和证据归档

先通过单人测试，再逐条运行多人命令，上一条结束后才能运行下一条：

```powershell
pwsh -NoProfile -File tools/run.ps1 -Mode Test -Suite gameplay -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Test -Suite gameplay -Clients 6

# 专项验证，按本次改动选择
pwsh -NoProfile -File tools/run.ps1 -Mode Test -Suite lifecycle -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Test -Suite ui -Clients 1
pwsh -NoProfile -File tools/run.ps1 -Mode Resource -Suite resource_matrix -Clients 3
pwsh -NoProfile -File tools/run.ps1 -Mode Soak -Clients 3

# 检查 OOS 检测链路：这是故意制造不同步，预期检测到失败
pwsh -NoProfile -File tools/run.ps1 -Mode OOS -Clients 3

# 在各场测试结束后归档本项目的会话记录
python -X utf8 tools/collect_evidence.py
```

普通场景检查每端断言、UT_DONE、状态摘要一致、房主无 OOS，以及清理结果；不能只看游戏启动或未掉线。故意 OOS 对照应有实际报警证据，不能把任意启动失败当成对照通过。Soak 使用 180000 个逻辑 tick，实际持续时间以日志为准。

新技能至少覆盖：正常施法、能量不足、冷却、重复请求、无效/超范围目标、前摇中死亡、目标移除、所有权变化、多段中断和资源回到基线。副本补胜利、失败、超时、主动退出、重复结束、再次开始；多人同时操作时核对各端业务摘要。

业务探针在 `src/probes/`，由应用测试入口接入；宿主离线用例在 `tests/`，新增文件要显式加入 `tools/check.py` 才会执行逻辑断言。测试自己的玩法时需要编写相应断言，模板探针不会自动理解新技能。真实断线、鼠标交互和画面布局另做实机验收。

收集后的证据位于本项目 `tests/evidence/`。保留每端日志、构建身份、预期失败解释和未覆盖范围。`verify_round2.py`、`verify_handle_refs.py` 是脚手架特定历史验收集合的检查器，新项目不能照搬它们宣称通过；应建立自己的验收集合/检查器。继承的研究文档也不是新项目实测结果。

### 7. 正式包、清理与提交

MainMap 和 UnitTestMap 各有独立 LNI 源。两者都会经过 w3x2lni 打包，不是只把 Lua 文件复制进地图；构建检查物编、载荷、初始化资源及最终 JASS。模型/纹理放入对应地图的 `resource/`、音频放入 `sound/`，其他地图内容按现有 LNI 分类维护；不要假设新建任意 assets 子目录就会自动入包。两图要使用的对象和资源必须各自具备，或由明确生成流程同步。

```powershell
# 生成正式 SLK 包，不加 --test 或 --dev
python -X utf8 tools/build.py --name release-0-1-0 --map MainMap --format slk
git diff --check
```

正式包不包含 probes、runtime_test 和 dev。构建通过后仍应对正式 MainMap 做体验验收，例如 `run.ps1 -Mode Play -Map MainMap -Format slk`（会另建同配置的新包），不能仅凭测试地图正常就发布。发布文件为成功构建对应的 `.w3x`，同时保存其 `-build.json`、版本和 Git 提交号。

成功构建后自动清掉 payload 副本和 LNI 工作目录，默认保留最新 **3 份受管理地图，正式与测试合计**；日志和清单继续保留。待发布包应另外保存到发布归档，避免后续构建轮转掉它。调整数量或保留排障现场可直接调用：

```powershell
python -X utf8 tools/build.py --name debug-001 --map UnitTestMap --test --suite gameplay --keep-maps 5 --keep-work
```

`--keep-work` 会固定保留该地图和工作目录，需要人工清理；失败构建、无清单的旧文件也不会被自动删除。源码、Git、证据和研究依赖不参与清理。详见 [构建清理规则](docs/固定依赖与LNI构建.md)。

每个功能完成后，提交业务代码、必要物编/资源、测试、文档和依赖锁；不要提交 build。提交前检查 diff，确保不混入其他工作的修改。推荐日常顺序：**改一个功能 → 离线检查 → 单人 → 多人及异常路径 → 收集证据 → 正式包验证 → 本地提交**。

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
