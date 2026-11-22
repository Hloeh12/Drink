# 打卡助手（iOS）

SwiftUI iOS 15+ 本地健康记录 App，支持喝水、餐食、体重、近 7 日回顾及本地喝水通知。无账号、无网络请求、无第三方运行时依赖。

## 环境

- macOS 14 / Xcode 15
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 生成并运行

```bash
brew install xcodegen
cd "打卡助手"
xcodegen generate --spec project.yml
open "打卡助手.xcodeproj"
```

选择“打卡助手”scheme 与模拟器后运行。`.xcodeproj` 是生成物，不提交；修改 `project.yml` 后重新生成。

## 本地无签名构建与 IPA

```bash
xcodegen generate --spec project.yml
DERIVED_DATA="$PWD/.derivedData"
xcodebuild -project "$PWD/打卡助手.xcodeproj" -scheme "打卡助手" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build
mkdir -p "$PWD/package/Payload"
ditto "$DERIVED_DATA/Build/Products/Release-iphoneos/打卡助手.app" "$PWD/package/Payload/打卡助手.app"
        (cd "$PWD/package" && /usr/bin/zip -qry "$OLDPWD/打卡助手-unsigned.ipa" Payload)
```

生成的 unsigned IPA 仅是未签名归档，不能直接安装到普通真机。GitHub Actions 的 `build.yml` 会在 `macos-14` 上执行相同步骤，并上传 artifact。

## 真机签名/分发

1. 在 Xcode 的 Signing & Capabilities 中选择自己的 Team，并把 `PRODUCT_BUNDLE_IDENTIFIER` 改为团队内唯一值。
2. 开启自动签名后连接注册设备运行；若需 Ad Hoc/TestFlight/App Store 分发，请在 Xcode Archive 后按 Apple Developer 账号权限导出签名 IPA。
3. 本工程无需 Push Notifications capability；提醒由 `UNUserNotificationCenter` 本地通知提供。

## 数据与隐私

- 饮水字典保存于 UserDefaults 键 `water_record_v1`。
- 饮食/体重以 Codable JSON Data 保存于 UserDefaults 键 `meal_record_v1`。
- 设置键为 `water_goal`、`remind_on`、`remind_interval`，日期键采用本地时区 `yyyy-MM-dd`。
- 所有数据仅在本机，卸载 App 通常会清除数据；无云同步和备份/导出功能。

## 已知限制

- iOS 只有在用户允许通知后才会显示提醒；关闭系统通知权限时，App 会把提醒开关恢复为关闭。
- 重复本地通知由系统调度，实际送达时间可能因专注模式、低电量或系统策略延迟；本版本不提供服务端推送，也不承诺后台精确定时。
- 单条重复通知按当前间隔调度；修改间隔会替换旧请求。
- 杯量选择只在当前运行期保留，其他记录与设置持久化。
- 体重输入仅做一位小数的轻量格式过滤，不提供医疗判断或减重建议。
