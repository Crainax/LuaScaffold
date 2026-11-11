# 最小地图来源

`map/` 的地形、阴影、寻路、元数据和空装饰物来自 `D:/War3/Library/War3Lib/UnitTestMap.w3x`，来源及逐文件哈希见 `war3lib-source.json`。保留的空 wts 是旧最小载体文件，不承担业务逻辑。

不包含 War3Lib 的 war3map.j、单位预放置、对象修改表、触发器或测试业务。构建工具更新 W3I 的标题/作者/描述及六个明确玩家槽/队伍，清除对象覆盖/随机表，重新生成 main/config、空 globals/endglobals 和固定引导 JASS。模板内字体与 core 贴图取自固定 vendor。

这是用于验证和开始开发的最小地图，不是完整地图编辑管线。实际项目可以替换地形和对象数据；更换后应重新验证脚本生成、资源打包和玩家初始化。
