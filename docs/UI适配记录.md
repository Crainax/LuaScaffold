# 官方 UI 适配记录

来源：`vendor/war3ui-1.49-9/package/plugin/script/ui/base`。工作副本在 `src/ui/base`，统一由 `src/scaffold/ui.lua` 初始化；原始 vendor 文件没有改动。官方文档：[界面事件](https://japi.war3rpg.top/Script/界面/事件管理.html)。具体行为以固定版本源码和本项目实测为准。

## 接入范围

使用官方 panel、button、text、texture、edit、model、model2、progress 和 ui_base 的渲染实现，通过 Lua 调用 InnerJAPI 原生 frame 接口。业务无需编写 JASS Dz UI 调用。没有加载原包 `base`、`ac`、`ui.client`、`ui.server`，也没有再次运行 Lua 版 `InitBlizzard`。

每局在同步初始化中调用一次 `require('scaffold.ui').start()`，随后通过共享时钟推进 `ui.step()`；默认 main 已完成接线。UI 停止后不能同局重新 start，避免重复注册全局原生回调。开发热重载不属于本模板支持范围。

```lua
local ui = require 'scaffold.ui' -- main 已经 start
local panel = ui.class.panel:builder {x=100, y=100, w=300, h=180}
local button = ui.class.button:builder {
    parent=panel, x=20, y=40, w=120, h=36,
}
button.on_button_clicked = function()
    local accepted, reason = bridge:send('ping', 0, 0)
    -- accepted 仅表示进入本地发送队列，不代表业务已执行。
end
button:loop(1000, function() -- 毫秒
    -- 仅更新本地显示。
end)
-- 面板关闭时：
panel:destroy()
```

`bridge` 由 app 持有并传入界面。默认例子见 `src/app/view.lua`；协议新增业务命令时必须同时补同步 handler 和 authorize。收到的发送者来自引擎，不接受字符串自报玩家。

## 与上游的差异

| 范围 | 适配及目的 |
| --- | --- |
| 模块环境 | 每个 UI 模块使用独立 `_ENV`，不把 class/game 等安装到业务 `_G`；仅原生要求的 WindowEventCallBack/FrameEventCallBack 暴露入口 |
| 初始化 | 绕开作者本地搜索路径、base 全局初始化、重复 InitBlizzard、F5 热更新及周期全量 GC |
| 同步 | 禁止 `sync_key` 隐式桥接；不打包上游 `load` 解码器、表序列化器和 UI 注册表同步路由 |
| 时钟 | 重写 detail/timer，使用共享原生时钟下的本地 Lua 队列，不因每端 UI 数量不同创建不同数量的经典 timer |
| 取消 | remove/cancel 立即断开回调引用，支持 pause/resume/get_remaining；外部保留 token 不保留捕获数据；整体 stop 逐一取消任务 |
| 控件所有权 | 控件 wait/loop/set_time 任务绑定控件；按钮 CD、纹理动画、拖动延迟使用所属控件任务 |
| 销毁顺序 | 子控件先于父控件；清理隐藏背景面板、frame 映射、世界投影/鼠标输入引用和 UI 编号；重复 destroy 无效 |
| 事件 | UI 事件在 Context.local_call 内执行；register_event 返回幂等注销函数；事件分发不因前一个回调返回 true 而漏掉后续回调 |
| 指针 | 指针离开所有控件时也更新状态；错误的 native 回调返回不会当作成功拦截事件 |
| 屏幕坐标 | screen_to_world 使用归一化的屏幕坐标，避免错误变量参与投影 |
| 输入框 | set_focus 仅调用 FrameSetFocus，不保留原包的 SendMessage 模拟输入行为 |
| 滚动 | 无溢出时滚动位置为 0，拖动行程为 0 时不做除法；缺失滚动条贴图改用包内资源 |
| 按钮资源 | 缺失 CD/状态图片改为包内 core 资源 |
| 进度条 | 修正模型参数名，替换缺失底图；比例限制 0..1，零分母采用安全显示值 |
| 键盘 | 修正 N 键误记为 L 的表项 |
| 单位头顶 UI | 原 bind_unit_overhead 依赖 ac 单位包装，明确禁用；可用 set_world_position 接入项目自己的本地投影逻辑 |

## 生命周期和同步约束

控件可以在不同客户端创建不同数量。UI 的 `_index`、frame ID 及本地任务 ID 只能用于本端显示管理，不能参与玩法选择，也不能跨端作为实体编号。多人测试特意制造不同数量 UI 和不同 GC 频率验证这一边界。

局部变量离开作用域并不保证立即回收：只要事件表、任务、原生接口或外部对象仍持有闭包，它及捕获数据就还活着。应销毁控件、注销长期事件、取消任务；不需要禁用匿名函数，也不需要每秒强制 collectgarbage。

直接使用 `game.wait/loop` 的任务归 UI 服务所有，关闭单个面板不会自动取消它们。面板相关逻辑优先使用 `panel:wait/loop`。非控件事件用 register_event 返回的注销函数加入自己的 scope。

`bridge:send` 的队列最多 32 项，每 10 个共享 tick 发送一项，消息最多 128 字节；队满返回 false。不要在每帧 hover 或鼠标移动时无条件发送同步命令。高水位去重假设同一发送者消息有序，缺号不阻塞；本模板没有应用层可靠重传协议。新业务需校验命令频率、实体仍有效、控制权、技能冷却、金币等语义。

## 已验证与限制

离线覆盖 100 组嵌套控件销毁及捕获对象释放；实机覆盖文本读回、实际 frame 尺寸、panel/button/text/edit 创建销毁、model/model2、空滚动区、进度条零分母、真实消息通道去重和多客户端差异 UI 压力。具体次数见实机报告。

测试通过 Lua 事件入口模拟按钮点击，没有使用系统鼠标键盘。中文字体、分辨率布局、真实输入法、鼠标拖动、完整键盘交互、长时间原生内存走势尚未人工验收。修正相关源码不等于已实测全部交互。模板保留官方控件 API 风格，但不能承诺上游每个未覆盖方法都已无缺陷。
