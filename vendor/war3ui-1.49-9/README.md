# 上游原始快照

来源为用户本机 `D:/War3/内置JAPI/2026年/war3UI1.49-9/war3UI/package`，保存于 2026 年 11 月 12 日。`package` 中 78 个文件保持原样，总计 13,511,572 字节；`manifest.json` 记录逐文件 SHA256。

这里用于复现、比较和后续提取适配层，不是当前运行入口。原包同步解码、热更、定时 GC、全局 math 改写等行为没有直接修改；本项目的新入口不加载它们。详见项目研究报告。

插件运行库三个资源与 War3Lib 固定版本一致：

```text
7249284a0f0b0f73104fa152e2a63294c631435ac7a1bca3b9676e2d34804a13  callback
a2751180ad76f8257984311b06d9cd41c20cab508fa2584a7aa09f85356eee9c  (key)
617662229027c27b1482d800d5047b6ff21f1afabca2f7dc203b1f3f8c8fa96e  wenhao_plugin.tga
```

来源文档：[内置 JAPI](https://japi.war3rpg.top/)。本项目没有替上游代码、插件二进制或字体授予新的许可证；如果以后对外发布模板，应核对各上游资源的再分发条件。
