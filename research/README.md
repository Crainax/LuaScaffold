# 研究来源与复现

这里保存的是可审查的来源、静态证据和分析输出。运行测试的原始日志在 `tests/evidence`，Lua/工具源码在 `src`、`tools`。研究输出不是运行时依赖。

- `upstream-sources.json`：已阅读的 GitHub 固定树及具体文件，不把搜索排序当成框架质量排名。
- `local-sources.json`：MoeHero、魔灵等实际参考文件的路径和 SHA256。本项目不修改它们。
- `evidence/embedded-images.json`：固定载体与嵌入 PE 的偏移、长度、哈希。提取物只放在忽略的 build 目录。
- `evidence/selected-native-disassembly.txt`：viewport、font、j2b loader 的静态指令；地址基于该镜像的首选 ImageBase。
- `evidence/game-font-trace.json`：通过插件的查找规则，在指定 Game.dll 中复现字符串引用及下游字体路径。
- `evidence/*viewport*candidates.json`：检索候选，不是已经确认的 frame 数据流或绘制消费者。
- `evidence/j2b-pjass.txt`：旧无 globals 引导经加密脚本插入后的具体语法缺陷复现，不代表已穷举 native crash 原因。

只读二进制分析可在项目根目录复现：

```powershell
python -m pip install --target build/analysis-deps -r research/requirements.txt
python tools/engine_trace.py
python tools/inspect_engine.py --image build/engine-pe/pe-60ae0.dll --output inner-engine-static.json
python tools/trace_game_font.py
python tools/trace_game_viewport.py
```

这些工具不 LoadLibrary、不执行 DLL、不注入分析组件、不修改游戏文件。Game.dll 路径是本机固定安装目录，脚本会检查哈希；换版本必须重新定位，不能删除断言后继续沿用旧地址。PE 静态地址和磁盘代码不证明运行中没有重定位、hook 或替换；实际行为仍以原生测试及明确的未覆盖项为界。

性能分析：先 `python tools/collect_evidence.py` 保存已结束会话，再 `python tools/analyze_runtime.py --session SESSION`。最终集合由 `tests/evidence/acceptance.json` 指定，`python tools/verify_evidence.py` 核对正常场景、OOS 对照、清理、时长和源码哈希。

资源趋势图使用 `python tools/plot_resources.py --session SESSION`，输出 PNG/SVG。独立分阶段诊断使用 `python tools/build_resource_probe.py --name NAME` 后按普通单端 CLI 启动；它明确替换该构建的 app.main 为此目录下的 resource_probe.lua，不修改 src，也不进入普通发行构建。阶段分别为空闲、单位创建销毁、无输入框 UI、带输入框 UI、停止后的恢复，每阶段 15,000 逻辑 tick。该诊断用于区分资源增长来源，不代替多人同步测试。

同一工具的 `--profile idle --clients 3` 构建只保留共享桥的 75,000 tick 空闲对照；`--profile clock --clients 3` 用独立原生 5 秒 timer 采样共享 tick。诊断快照会随证据复制为 fixture.lua，不能用修改后的文件重解释历史构建。探针必须有真实断言、PASS 标记和 UT_DONE 标记，单独打印“完成”不会通过自动运行器。
