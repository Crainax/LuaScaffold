# 固定依赖与 LNI 构建

本轮已经落地的构建约定。完整业务样板与最终综合验收见《第二轮实机验证报告》，构建通过与多人验证分别记录。

## 新项目和公共依赖

运行 `python tools/new_project.py D:/War3/Maps/MyLuaGame --id MyLuaGame --title 我的Lua地图`。目标必须不存在且在模板外。默认得到独立业务源码、地图源码、工具、规则、skill 和 VS Code tasks；不复制模板 Git、build 或历史 tests/evidence。

公共运行库位于 `deps/lua-scaffold`：scaffold、ui、game 及固定官方 vendor。项目业务仍在 src。framework.lock.json 指向依赖目录和内容版本；包内 package-lock.json 锁定每个文件及完整清单。构建拒绝修改、缺失、额外文件，以及 src 中对 scaffold/ui/game 命名空间的覆盖。不要为了临时修 bug 直接修改 deps；在框架中修复、验证后导出新的版本。

`python tools/framework_package.py <不存在的导出目录>` 导出当前公共运行库。内容 SHA-256 是版本标识，origin_commit 只是来源说明；存在未提交公共修改时 origin_public_dirty=true，不能把快照误称为该 Git 提交的原样内容。

`python tools/framework_dependency.py <项目目录> <快照目录>` 校验现有依赖及新快照，再复制到项目 deps/packages/<版本> 并原子切换锁。旧包保留，回退使用同一命令激活旧包。失败不改锁；当前依赖有私改时拒绝覆盖。`tests/dependency_upgrade.py` 已验证 A→B→A 的真实构建和 Lua 入口、包篡改与额外文件拒绝；新增公共 API 仍需项目回归，不承诺自动迁移业务。

`--copy-framework` 是显式源码副本模式，后续维护完全由项目承担。默认固定依赖更适合长期复用；复制模式不享有依赖锁的防漂移保证。

从旧源码副本迁移：先盘点公共层的本地改动，把必要修复纳入一个已验框架快照；用 new_project 创建新的锁定依赖项目，再迁移业务、资源和两图LNI源。不要把旧 src/scaffold、src/ui、src/game 或 framework.lock.json 混入新项目。合并 project.json、地图引导和构建配置后，跑离线、两图回读及对应原生回归，验收前保留旧项目。无需删除或原地覆盖原项目来完成迁移。

## 两个地图与产物

| 位置 | 用途 |
| --- | --- |
| maps/MainMap | 正式地图自己的地形、物编、预放置、区域及必要 JASS 初始化 |
| maps/UnitTestMap | 单测地图自己的相同类别源文件 |
| src | 项目 Lua；正式构建排除 probes、runtime_test 和开发热更 |
| config/w2l-lock.json | 固定 w3x2lni 完整安装文件哈希 |
| config/w2l-policy.ini | CLI 公开配置的私有策略 |
| config/w2l-core-policy.ini | 私有核心默认配置，只关闭 SLK computed_text |
| build/<名字>-lni | 每次独立复制的 LNI 工作树 |
| build/<名字>.w3x | w3x2lni 生成的最终地图 |
| build/<名字>-build.json | 所有构建校验通过后才生成的清单与哈希 |

开发默认 OBJ，发布可选择 SLK；两者都运行 w3x2lni，并非只在发布时“打包资源”。MainMap 与 UnitTestMap 使用同一固定工具和验证流程。Lua 是业务入口，JASS 只保留地图初始化和单次 InnerJAPI 引导；打包不以最小模板替换源地图初始化。

常用命令：

```powershell
python -X utf8 tools/build.py --name main-dev --map MainMap --format obj
python -X utf8 tools/build.py --name main-release --map MainMap --format slk
python -X utf8 tools/build.py --name unit-life --test --suite lifecycle --map UnitTestMap --clients 3 --ticks 4000
pwsh -NoProfile -File tools/test.ps1 -Name unit-life -Clients 3
```

构建名字不可复用。VS Code 已分别提供 MainMap OBJ、MainMap SLK、UnitTestMap 仅编译、选择单测及多人任务；没有 YDLua/InnerJAPI 切换。hotreload 和旧 soak 套件启用开发模块；Mode Soak 默认改为 campaign_soak 业务长测，不自动启用热更。正式构建默认不启用开发模块。

## 验证内容与实际失败

1. 校验固定依赖、固定工具、私有配置完整性，不改共享工具安装或注册表。
2. 检查显式地图夹具和唯一引导钩子；生成按源清单排序的 Lua 预放置入口。
3. 按工具规则将纹理/模型放 resource、音频放 sound、Lua/载体放 map。目录是 LNI 分类，不是最终 MPQ 路径前缀。
4. 要求工具完成协议且无严重错误。最终回读每个 Lua/载体/资产字节及地形、路径、阴影、单位与区域二进制。
5. 用固定前端分别解析源物编和最终 OBJ/SLK，对源中声明的对象比较全部有效字段。当前 7 个对象、950 个字段。忽略工具内部下划线元数据，允许 TXT 空字符串/缺省表示等价、OBJ 数字字符串及浮点存储误差；整数精确比较。篡改英雄名称的负例已经被拒绝。
6. 校验最终 JASS，并记录源地图、Lua、工具策略和地图哈希。测试入口拒绝清单缺失、地图哈希变化和客户端数不匹配。

SLK 校验发现默认 computed_text 会将说明中的 `<AEme,DataE1>` 等替换为数字。该选项不在公开 config_define 白名单，写入普通全局 ini 无效；因此固定私有核心配置关闭它，并将该文件哈希纳入工具缓存版本和构建清单。原安装、vendor 及其他项目不变。

最初校验假设 OBJ/SLK 都有 war3map.w3u，SLK 实际使用表格式，该假设已删除；现在比较解析后的字段，不依赖特定容器存在。OBJ 解析把部分实数表示为 `0.` 字符串，比较按数值意义处理，不把格式差异当作物编丢失。

一次构建校验失败后，旧独立 test.ps1 仍启动了已经产生的 w3x。该轮主动中止，记为 FAIL，不纳入支持范围；现在入口要求成功清单。中止与运行器 finally 清理曾竞争同一锁，保留 cleanup-first-failure.json，待运行器退出后按记录身份重试，确认全部退出。后续由自动运行器统一负责退出清理。

原生已覆盖 UnitTestMap OBJ 三端、MainMap SLK 六端的预放置、区域和三个英雄名称；完整业务及最终37分钟三端长测已另行验收。编辑器可视检查仍按《人工验收步骤》手动进行，不能用包回读替代界面证明。
