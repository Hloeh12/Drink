# 打卡助手（iOS）

SwiftUI iOS 15+ 个人健康记录 App，支持喝水打卡、饮食记录（含热量与照片）、体重趋势、CSV 导出、Supabase 多人云同步（Sign in with Apple + RLS 隔离）。

## 功能

| 功能 | 说明 |
|---|---|
| 💧 喝水打卡 | 杯量 150/200/250/300ml，目标可调 800–3000ml，7 日柱状图 |
| 🍽 饮食记录 | 早/午/晚/加餐文本 + 每餐热量（kcal）+ 餐食照片 |
| ⚖️ 体重趋势 | 独立体重存储，7 日折线图（iOS 16+ Charts）/柱状图（iOS 15），统计摘要 |
| 🔥 热量统计 | 每日总热量 + 近 7 天热量概览 |
| 📊 CSV 导出 | 一键导出全部数据为 CSV（带 UTF-8 BOM，Excel 兼容） |
| ☁️ 云同步 | Supabase 多人同步，Sign in with Apple 登录，RLS 行级隔离 |
| 🔔 喝水提醒 | UNUserNotificationCenter 本地通知，间隔 15–120 分钟 |

## 环境

- macOS 14+ / Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- iOS 15+（Charts 图表需 iOS 16+，iOS 15 自动降级为柱状图）

## 生成并运行

```bash
brew install xcodegen
cd "打卡助手"
xcodegen generate --spec project.yml
open "打卡助手.xcodeproj"
```

选择「打卡助手」scheme 与模拟器后运行。

## Supabase 云同步配置

### 1. 创建 Supabase 项目

前往 [supabase.com](https://supabase.com) 创建新项目。

### 2. 运行数据库迁移

在 Supabase Dashboard → **SQL Editor** 中，粘贴并运行：

```
supabase/migrations/0001_initial_schema.sql
```

这会创建以下表（均启用 RLS）：
- `profiles` — 用户资料（注册自动创建）
- `water_intake` — 喝水记录
- `weights` — 体重记录
- `meals` — 餐食记录（含热量、照片 URL）
- `user_settings` — 设置同步
- `meals` 存储桶 — 餐食照片

### 3. 配置 Sign in with Apple

**在 Supabase Dashboard：**
1. Authentication → Providers → **Apple** → 启用
2. 填入：
   - Apple Services ID（如 `com.yoursignin.service`）
   - Secret Key（OAuth Client Secret）
   - Key ID
   - Team ID
3. 将 **Redirect URL** 设为：
   ```
   https://<your-project>.supabase.co/auth/v1/callback
   ```

**在 Apple Developer：**
1. [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles
2. **Sign In with Apple** → 配置 Service ID
3. Return URLs 填入上面的 Redirect URL

### 4. 填入 iOS 代码

打开 `打卡助手/SupabaseClient.swift`，修改：

```swift
enum SupabaseConfig {
    static let url = "https://<your-project>.supabase.co"
    static let anonKey = "<your-anon-key>"
}
```

> 项目 URL 和 anon key 在 Supabase Dashboard → Settings → API 中获取。
> `anonKey` 是公开密钥（safe for client），**不要**用 `service_role` key。

### 5. 运行

填入正确配置后，App 顶部会出现云同步入口，点击头像图标即可用 Sign in with Apple 登录。

## 本地无签名构建与 IPA

```bash
xcodegen generate --spec project.yml
DERIVED_DATA="$PWD/.derivedData"
xcodebuild -project "$PWD/打卡助手.xcodeproj" -scheme "打卡助手" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build
mkdir -p "$PWD/package/Payload"
ditto "$DERIVED_DATA/Build/Products/Release-iphoneos/打卡助手.app" "$PWD/package/Payload/打卡助手.app"
(cd "$PWD/package" && zip -qry "$OLDPWD/打卡助手-unsigned.ipa" Payload)
```

GitHub Actions 的 `build.yml` 会在 `macos-latest` 上执行相同步骤并上传 artifact。

## 真机签名/分发

1. 在 Xcode 的 Signing & Capabilities 中选择自己的 Team
2. 把 `PRODUCT_BUNDLE_IDENTIFIER` 改为团队内唯一值
3. 开启自动签名后连接注册设备运行
4. Ad Hoc/TestFlight/App Store 分发请在 Xcode Archive 后导出

> Sign in with Apple 需要在 Apple Developer Account 中配置 Capability，真机调试时需有效的 Apple Developer 账号。

## 数据与隐私

- **本地存储**：UserDefaults（`water_record_v1`、`meal_record_v1`、`weights_record_v1`）
- **云同步**：Supabase，所有表启用 RLS，用户只能访问自己的数据
- **照片**：上传到 Supabase Storage `meals` 桶，同样受 RLS 保护
- **登录**：仅使用 Sign in with Apple，App 不接触用户密码
- 日期键采用本地时区 `yyyy-MM-dd`

## 已知限制

- iOS 只有在用户允许通知后才会显示提醒
- Sign in with Apple 需要有效的 Apple Developer 账号
- Supabase 云同步需手动配置（见上方步骤）
- Charts 框架需 iOS 16+，iOS 15 自动降级为柱状图
- CSV 导出为本地文件，通过系统分享面板保存或发送
