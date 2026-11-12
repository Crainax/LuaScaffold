# 单位生命周期与 handle 复用（第二轮）

范围：本机 Warcraft III 1.27、InnerJAPI 1.49-9、Lua 5.3、handle_level=0。以下是固定场景证据，不是任意插件或地图均不会 OOS 的保证。

## 对象契约

业务入口为 `game.unit.service.new(scheduler)`。服务拥有一个共享原生事件桥和一个单位管理器；`stop()` 先解绑原生事件，再清理单位、事件和任务。不要只关闭管理器而遗留原生桥。

| 状态或操作 | 业务 ID | 生命周期任务 | 原生所有权 |
| --- | --- | --- | --- |
| create | 确定性路径分配，单局不复用 | 可登记 | 服务拥有 |
| adopt / register_placements | 按显式列表顺序分配 | 可登记 | owned 明确指定 |
| 死亡 | 保留 | 取消当前生命周期任务 | 保留尸体/英雄 |
| 复活 | 同一原生对象保留 ID | 新 epoch，旧任务不复活 | 不改变 |
| 类型或所有权变化 | 同一对象保留 ID | 更新 epoch，取消旧任务 | 不改变 |
| remove | 调 native 之前失效 | 立即取消 | 仅允许销毁自有单位 |
| detach | 失效 | 立即取消 | 仅解除登记，不销毁原生对象 |
| stop | 所有登记失效 | 全部取消 | 销毁自有，解除借用 |

`after(id,ticks,fn)` 绑定当前生命周期；`life=false` 才表示跨死亡仍保留的对象级任务。执行前再解析 ID、刷新原生状态和校验 epoch。业务不要保存 handle 后在延迟回调中直接使用。取消 token 即使被外部继续持有，也必须解除 callback 的捕获引用。

死亡、所有权、召唤和玩家退出由共享原生事件桥通知。直接 `ReviveHero` 后显式 refresh；类型变化由 refresh 或延迟任务执行前刷新发现。这里没有宣称能观察任意外部模块在两次刷新之间完成的“变化后又恢复”。需要精确中断的业务应在自己的技能/变身入口主动取消当前动作，不能把属性轮询当成完整的事件历史。

借用地图预放置单位的服务停止后，地图单位仍存在。detach 也可用于明确移交自有单位的管理责任；它不是 RemoveUnit 的别名。调用方必须拥有接续管理者或已经完成外部移除。

## 移除的真实时序

`lifecycle-native-01` 失败于“RemoveUnit 返回后类型立刻为零”的假设。`lifecycle-native-02` 的观测如下：

| 观测点 | 类型 | 生命 | hidden / dead |
| --- | --- | --- | --- |
| RemoveUnit 同一回调内 | H001 | 650 | true / false |
| 下一逻辑 tick | 0 | 0 | false / false |
| 半秒后 | 0 | 0 | false / false |

本场景中 handle_ref 没有让类型长期保持非零；此前这一猜测已被后续观测排除。事实只说明原生查询的失效存在短暂延迟，不推导所有引擎版本的内部实现。

因此框架的 remove 必须先撤销业务 ID、取消任务，再调用原生移除。外部代码直接 RemoveUnit 后，refresh 在原生状态更新后才能发现；需要即时失效时先 detach 或统一使用服务 remove。不要以 IsUnitHidden 代替有效性判断，合法隐藏单位也会返回 true。

参考 MoeHero `scripts/types/unit.lua` 的移除路径，也先标记 removed 并清理技能、Buff、计时器，再 RemoveUnit 和 handle_unref；本项目吸收显式所有权与清理顺序，没有直接引入其全套 ac 对象系统。

## 变身与动态技能

`lifecycle-native-02/03/04` 的自定义变身/变熊命令返回 true，但稍后仍是原类型，动态添加的 A001/A003 已消失。不能将“命令被接受”作为变身成功证据。

`lifecycle-native-05` 原生 AEme/Abrf 对照得到 Edmm/edcm，原生对象与业务 ID 保留，epoch 更新。`lifecycle-native-07` 在自定义技能施放前调用 UnitMakeAbilityPermanent 后，A001/A003 仍保留且两种类型均达到预期。数据和类型读回支持“动态变身技能的保留影响此场景结果”；未反汇编这一具体引擎变身分支，不把推测写成内部实现事实。

项目动态添加且需要跨变身保留的技能应明确标记永久；卸载时仍须显式移除。完整回归应同时断言类型、技能是否保留、业务对象身份和动作是否取消，不能只看 buff 或 IssueImmediateOrder 返回值。

## 真实 handle 复用

- `tests/unit_lifecycle.lua` 强制复用模拟 handle，验证算法；它不是引擎证据。
- `lifecycle-native-05` 在同一回调内创建/移除 2,000 个单位，原生 ID 重复数为 0；该轮之后状态消息没有在断言期限内收到，整轮失败。
- `lifecycle-native-06/07` 固定 100 批，每批 20 个，间隔 10 tick，共 2,000 个，实测各有 1,977 次原生 ID 重复。所有旧业务 ID 失效，取消任务的捕获对象经受控 GC 后全部释放。
- 原生 ID 只写诊断日志，不能决定创建次数、批次数、逻辑 ID 或玩法分支。所有端执行相同固定工作量；允许各端报告不同原生 ID 或复用次数。

同回调批量与分批结果表明，复用实验必须留出引擎处理移除的时间。失败轮说明大批量工作会影响这一测试的完成行为；没有证据将它归因为网络实现错误或 OOS。受控 GC 仅用于实验，不进入正式玩法调度。

## 地图初始化与构建

两个地图各有自己的 placements.json、JASS 初始化、经典版 war3mapUnits.doo 和区域 war3map.w3r。`tools/map_fixtures.py --write` 只重生成显式标记的夹具块与这两份二进制，不替换其他地图初始化。构建检查源清单与夹具一致；一般编辑器地图迁入时应适配登记清单，不能直接用此小型夹具生成器覆盖整图。

构建生成 `world.generated_placements`，按源清单顺序读取 JASS 全局，不用全地图枚举顺序给单位编号。原生测试读取预放置单位类型、所属玩家、坐标、区域边界；最终 MPQ 逐字节回读地形、路径、阴影、预放置和区域资源。

二进制布局交叉参考上游 [unit.ts](https://github.com/flowtsohg/mdx-m3-viewer/blob/master/src/parsers/w3x/unitsdoo/unit.ts) 和 [region.ts](https://github.com/flowtsohg/mdx-m3-viewer/blob/master/src/parsers/w3x/w3r/region.ts)。本生成器只覆盖声明的经典版简单夹具；没有验证编辑器界面显示，也不支持 Reforged skin 或任意随机掉落/背包结构。

## 生命周期阶段的历史证据

| 构建 | 会话 | 结果与覆盖 |
| --- | --- | --- |
| lifecycle-native-06 | 20261112-151023-96bfcd | 单端通过，原生变身、分批真实复用 |
| lifecycle-native-07 | 20261112-151221-5c302c | 单端通过，增加地图预放置/区域、自定义永久变身 |
| lifecycle-three-08 | 20261112-151403-91c884 | 三端通过，摘要纳入单位登记/状态/epoch/批次/召唤 |
| lifecycle-six-slk-09 | 20261112-151814-b823ef | 六端通过，MainMap、SLK、三个英雄名称读回 |
| lifecycle-service-11 | 20261112-152207-21c1c9 | 三端通过，统一服务关闭事件桥与对象、OBJ 字段语义校验 |

以上均不包含下一阶段完整英雄技能、天赋、副本异常及最终 30 分钟验收。新增行为仍需新的构建复验；旧证据只覆盖对应源码。

## 第二轮最终源码的补充验证

最终集合的单端 `round2-expanded-one-03`、三端 `round2-expanded-three-01`、六端 `round2-expanded-six-slk-01` 已通过上述生命周期探针及完整技能/挑战。各构建P1在固定2000单位实验中分别观察1974/1966/1954次原生ID重复。每端都检查旧业务ID失效和旧任务不误操作后续单位；不要求本地原生ID跨端相等。具体会话、源码锁和最终长测见《第二轮实机验证报告》。

本轮进一步发现：已取消的单位任务token虽然清空了callback，其cancel函数仍捕获owner record；调用者长期保留token便会保留已移除对象。`tests/evidence/round2-build/unit-token-retention-before.log` 保存修复前失败，旁边保存当时源码及哈希。修复在取消时清空owner捕获；正常执行只在当前调用栈短暂保存记录作身份/epoch验证。离线及单/三/六端探针均保留8个取消token，并检查弱引用中的原生单位record可回收。这是Lua引用残留修复，不能据此声称解释了全部进程内存或Windows句柄增长。

目标英雄在施法途中经原生Kill/Revive，稳定ID保留，但死亡前的技能事务已取消；原生断言确认复活不能恢复旧延迟伤害。任务的生命周期不是单纯“ID仍存在”。

玩家退出策略由world负责：先撤销该玩家权限，结束其挑战，再按稳定ID顺序清理当前归其控制且服务拥有的单位；借用地图单位和已经转移给其他玩家的对象保留。重复通知幂等。桥接已注册真实 `EVENT_PLAYER_LEAVE`，身份取自引擎；本轮自动探针注入退出通知后验证真实原生资源释放，没有实际断开网络客户端，真实退出与重连仍属于人工/外部环境验证范围。
