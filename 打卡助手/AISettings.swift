import SwiftUI

// MARK: - AI 识别设置页（粘贴 GitHub Token）

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput: String = FoodAI.token
    @State private var testing = false
    @State private var testResult: String? = nil

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LiquidBackground().allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("什么是 GitHub Token？", systemImage: "key.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text("拍照识别热量用的是 GitHub Copilot 的 AI 接口。只要你有 GitHub 账号（免费版即可），创建一个 Token 粘贴到这里就能用，每月可识别约 50 张照片。")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.ink2)
                            .lineSpacing(4)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.blueSoft))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("获取步骤").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                        step(1, "打开链接 github.com/settings/tokens")
                        step(2, "点 Generate new token (classic)")
                        step(3, "勾选 copilot 权限，生成")
                        step(4, "复制 ghp_ 开头的 Token 粘贴到下面")
                        Link("点此打开 GitHub Token 页面", destination: URL(string: "https://github.com/settings/tokens")!)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Token").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                        SecureField("ghp_xxxxxxxxxxxx", text: $tokenInput)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.8)))
                    }

                    if let result = testResult {
                        Text(result)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(result.contains("成功") ? Palette.green : Palette.red)
                    }

                    HStack(spacing: 10) {
                        Button {
                            testing = true; testResult = nil
                            Task {
                                FoodAI.token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                do {
                                    // 用一张 1x1 图测试连通性（会返回解析错误但能验证 token）
                                    let tiny = UIImage(color: .white, size: CGSize(width: 8, height: 8))!
                                    _ = try await FoodAI.recognizeFood(image: tiny)
                                    testResult = "✅ 测试成功，可以开始拍照识别了"
                                } catch FoodAI.AIError.parseError {
                                    testResult = "✅ Token 有效（连通性正常）"
                                } catch {
                                    testResult = "❌ \(error.localizedDescription)"
                                }
                                testing = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if testing { ProgressView().scaleEffect(0.7).tint(.white) }
                                Text("保存并测试").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(GlassButtonStyle(tint: Palette.green, filled: true))
                        .disabled(testing || tokenInput.count < 10)

                        if FoodAI.isConfigured {
                            Button {
                                FoodAI.token = ""
                                tokenInput = ""
                                testResult = "已清除"
                            } label: {
                                Text("清除")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Palette.red)
                                    .padding(.horizontal, 20).padding(.vertical, 12)
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                    }

                    Text("Token 只保存在你的手机本地，不会上传到任何服务器（除了 GitHub 官方接口本身）。")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.ink3)
                        .lineSpacing(4)
                }
                .padding(16)
            }
            .background(LiquidBackground())
            .navigationTitle("AI 拍照识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Palette.blue))
            Text(text).font(.system(size: 12)).foregroundColor(Palette.ink2)
        }
    }
}

extension UIImage {
    convenience init?(color: UIColor, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
