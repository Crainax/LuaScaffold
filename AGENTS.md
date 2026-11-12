# LuaScaffold 工作约定

- 开发与审查先读 `docs/Lua开发规则.md`；项目配套 skill 为 `.agents/skills/innerjapi-lua/SKILL.md`，随模板复制。新实验应更新规则中的结论与证据范围。

- 本项目面向经典 Warcraft III 的 InnerJAPI 1.49-9；业务使用 Lua 5.3。不要把宿主 Lua、YDWE Lua、Reforged 原生 Lua 当成同一运行时。
- `vendor/war3ui-1.49-9/package` 是原始快照。不要直接修改；需要修订的上游模块应复制到适配目录并记录差异及来源。
- 禁止默认执行原包 `script/init.lua`、热更新、定期全量 GC、`ui.client/util.lua` 的 load 解码器；不要改写全局标准 math 函数。
- 同步逻辑不可用 handle ID、frame ID、table/function 地址、未排序 pairs/组枚举顺序作决策。逻辑 ID 只能在确定的同步顺序中分配。
- UI/HTTP/鼠标/文件/墙钟数据属于本地输入。经过明确的同步协议和校验后才允许修改玩法。接收玩家身份取自引擎事件，不能相信 payload 自报玩家。
- 不在 GC、弱表回收或本地回调中销毁同步原生句柄。业务对象必须提供显式清理；长期回调使用稳定入口及可取消任务。
- 修改新 Lua 基础层后运行 `python tools/check.py`。通过离线测试不代表地图打包、原生回调释放或多人 OOS 通过。
- 框架显式handle引用经 `scaffold.handle_refs` 配对；新资源路径补active基线/停止归零回归，不能重置账本掩盖残留。该统计不等于引擎全局引用总数。最新增量范围见 `docs/handle引用统计与回归.md` 与 `tools/verify_handle_refs.py`。
- 游戏内测试遵守用户的全局规则及 war3-runtime-test 技能；不要用 Windows 桌面自动化。保存每端日志，使用本次记录的 PID/创建时间清理自动测试游戏。
- 支持声明以实际通过的固定版本、场景及证据为界：新增单位/技能/挑战/依赖/LNI见 `docs/第二轮实机验证报告.md` 和 `tests/evidence/verified-round2.json`；第一轮《扩展实机验证报告》和原《实机验证报告》保留历史。报告中的待测项目不算通过。新平台、原生二进制或业务逻辑不能沿用旧结果直接宣布无 OOS；扩展范围须更新 `docs/验证计划.md`。
