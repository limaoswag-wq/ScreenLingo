# 屏译（ScreenLingo）

个人用的实时屏幕翻译。功能形态参考常见录屏翻译 App（识别区域、多 OCR、多翻译源、画中画字幕），代码和资源都是新写的，不是 iTranscreen 的改包。

## 它做什么

1. 点「开始翻译会话」，再点「开始屏幕直播」。
2. 系统直播列表里选 **屏译**（扩展显示名和 App 一样）。
3. 瘦 Broadcast 扩展只抓帧，写入 App Group。
4. 主 App 用 Apple Vision OCR，再按你选的引擎翻译。
5. 译文显示在本页，并用画中画小窗挂在其他 App 上面。

翻译源可切换：

- 自定义 AI（任意兼容 `/v1/chat/completions` 的地址，推荐）
- DeepL
- Google Translate
- 百度翻译
- Apple 翻译（当前版本若系统接口不可用会提示你换别的源）

OCR：Vision 精确 / 快速。  
识别范围：智能字幕带、自定义框、全屏。

## 和商店 App 的差别

- 没有会员、没有写死的腾讯/百度线路。
- 密钥只存在本机 App Group。
- 无开发者证书时，扩展**不一定**会出现在直播列表里。那是系统登记问题，不是翻译逻辑坏了。列表没有时，仍可用「相册图片试一次」验证 OCR 和 AI。

## 用 Codemagic 出包（无证书）

1. 把本目录推到 GitHub。
2. Codemagic 接这个仓库，选 workflow `screenlingo-unsigned-ipa`。
3. 构建产物是 `ScreenLingo.ipa`。
4. 用巨魔安装。若提示签名/权限问题，解压 IPA 后用 `ldid` 写入 entitlements 再打包：

```bash
ldid -SApp/ScreenLingo.entitlements Payload/ScreenLingo.app/ScreenLingo
ldid -SBroadcast/Broadcast.entitlements Payload/ScreenLingo.app/PlugIns/Broadcast.appex/Broadcast
```

本地有 Mac 时：

```bash
xcodebuild -project ScreenLingo.xcodeproj -scheme ScreenLingo \
  -configuration Release -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
./scripts/package_ipa.sh
```

## 第一次使用

1. 打开右上角设置，翻译源选「自定义 AI」，填 API 地址、Key、模型。
2. 原文选自动或日语，译文选简体中文。
3. 识别范围先用智能区域；游戏菜单再改自定义框。
4. 开始会话 → 开始直播 → 列表选屏译 → 切到目标 App。
5. 取帧间隔默认 0.7 秒，发热就调到 1.0～1.5 秒。

## 目录

- `App/` 主界面、OCR、翻译、画中画
- `Broadcast/` 直播扩展，只抓帧
- `Shared/` App Group、设置、模型
- `codemagic.yaml` 云端编未签名 IPA
