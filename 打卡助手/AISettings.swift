import SwiftUI

// MARK: - AI 设置页（设备登录流程）

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var loggedIn = FoodAI.isConfigured
    @State private var flowState: FlowState = .idle
    @State private var deviceCode = ""
    @State private var userCode = ""
    @State private var verifyURL = "https://github.com/login/device"
    @State private var testResult: String? = nil
    @State private var testing = false

    enum FlowState: Equatable {
        case idle, waiting(code: String, url: String), authorizing, done, failed(String)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statusCard
                    switch flowState {
                    case .idle, .done, .failed:
                        if loggedIn { loggedInCard } else { startCard }
                    case .waiting(let code, let url):
                        codeCard(code: code, url: url)
                    case .authorizing:
                        HStack {
                            ProgressView().scaleEffect(0.9)
                            Text("等待 GitHub 确认授权…").font(.system(size: 14)).foregroundColor(Palette.ink2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    }
                    if let r = testResult { testCard(r) }
                    if loggedIn { logoutRow }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(LiquidBackground())
            .navigationTitle("AI 拍照识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: loggedIn ? "checkmark.seal.fill" : "info.circle.fill")
                .font(.system(size: 17))
                .foregroundColor(loggedIn ? Palette.green : Palette.blue)
            Text(loggedIn ? "已连接 GitHub Copilot" : "未连接 · 按下方步骤授权后即可拍照识别")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Palette.ink)
            Spacer()
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 13).fill(loggedIn ? Palette.greenSoft : Palette.blueSoft))
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("三步完成授权").font(.system(size: 16, weight: .bold)).foregroundColor(Palette.ink)
            step(1, "点下面的按钮获取 6 位代码")
            step(2, "在任意浏览器打开 github.com/login/device")
            step(3, "输入代码并确认授权，回到 App 自动完成")
            Button {
                startFlow()
            } label: {
                Label("开始授权", systemImage: "key.horizontal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Palette.blue))
            }
            if case .failed(let msg) = flowState {
                Text(msg).font(.system(size: 12)).foregroundColor(Palette.red)
            }
        }
        .padding(16)
        .background(glassBg)
    }

    private func codeCard(code: String, url: String) -> some View {
        VStack(spacing: 14) {
            Text("你的 6 位代码").font(.system(size: 13)).foregroundColor(Palette.ink2)
            Text(code)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.ink)
                .kerning(6)
            Button {
                UIPasteboard.general.string = code
                Haptic.light()
            } label: {
                Label("复制代码", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())
            Button {
                UIApplication.shared.open(URL(string: url)!)
            } label: {
                Label("打开 github.com/login/device", systemImage: "safari")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Palette.blue))
            }
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.8)
                Text("正在等待你在浏览器完成授权…").font(.system(size: 12)).foregroundColor(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(glassBg)
    }

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("识别设置").font(.system(size: 16, weight: .bold)).foregroundColor(Palette.ink)
            Text("拍照识别每月免费约 50 次。在任意一餐点相机按钮，选好照片后 AI 会自动算出食物和热量，点「填入」写入记录。")
                .font(.system(size: 12)).foregroundColor(Palette.ink2)
            Button {
                testConnection()
            } label: {
                HStack {
                    if testing { ProgressView().scaleEffect(0.8) }
                    Text(testing ? "测试中…" : "测试连接")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(GlassButtonStyle(tint: Palette.blue, filled: true))
            .disabled(testing)
        }
        .padding(16)
        .background(glassBg)
    }

    private func testCard(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 12))
            .foregroundColor(msg.contains("✅") ? Palette.green : Palette.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 11)
                .fill(msg.contains("✅") ? Palette.greenSoft : Palette.red.opacity(0.08)))
    }

    private var logoutRow: some View {
        Button {
            FoodAI.logout()
            loggedIn = false
            flowState = .idle
            Haptic.light()
        } label: {
            Text("退出登录").font(.system(size: 13, weight: .medium)).foregroundColor(Palette.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(GlassButtonStyle())
    }

    private var glassBg: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Palette.blue))
            Text(text).font(.system(size: 13)).foregroundColor(Palette.ink2)
        }
    }

    private func startFlow() {
        flowState = .authorizing
        Task {
            do {
                let start = try await FoodAI.startDeviceFlow()
                userCode = start.userCode
                verifyURL = start.verifyURI
                flowState = .waiting(code: start.userCode, url: start.verifyURI)
                deviceCode = start.deviceCode
                try await FoodAI.pollDeviceFlow(start)
                await MainActor.run {
                    loggedIn = true
                    flowState = .done
                    Haptic.success()
                }
            } catch {
                await MainActor.run {
                    flowState = .failed(error.localizedDescription)
                    Haptic.medium()
                }
            }
        }
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task {
            do {
                _ = try await FoodAI.copilotTokenForTest()
                await MainActor.run {
                    testing = false
                    testResult = "✅ 连接成功，可以开始拍照识别了"
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testResult = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
