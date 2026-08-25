# 屏译（ScreenLingo）

个人用的实时屏幕翻译。功能形态参考常见录屏翻译 App（识别区域、多 OCR、多翻译源、画中画字幕），代码和资源都是新写的，不是 iTranscreen 的改包。

## 它做什么

1. 选语言、翻译模式、翻译区域，点「开始」。
2. 再点「开始直播」，系统列表里选 **屏译**。
3. 瘦 Broadcast 扩展只抓帧，写入 App Group。
4. 主 App 用 Apple Vision OCR，再按你选的引擎翻译。
5. 译文显示在本页，并用画中画小窗挂在其他 App 上面。

翻译源可切换：

- 自定义 AI（Chat Completions 或 Responses，模型从上游 `/v1/models` 拉取）
- DeepL
- Google Translate
- 百度翻译
- Apple 翻译（当前版本若系统接口不可用会提示你换别的源）

OCR：快速 / 高精度。  
识别范围：智能、自定义、全屏。  
模式：游戏、漫画、视频、阅读（复制即译）。

## 用 Codemagic 出包（无证书）

1. 把本目录推到 GitHub。
2. Codemagic 接这个仓库，选 workflow `screenlingo-unsigned-ipa`。
3. 构建产物是 `ScreenLingo.ipa`。
4. 用巨魔安装。

## 第一次使用

1. 打开右上角设置，翻译源选「自定义 AI」，填 API 地址和 Key。
2. 选 Chat Completions 或 Responses，点「从上游获取模型列表」，再选模型。
3. 原文选自动或日语，译文选简体中文。
4. 翻译区域先用智能；游戏菜单再改自定义。
5. 开始 → 开始直播 → 列表选屏译 → 切到目标 App。
