import SwiftUI

// MARK: - 液态玻璃设计系统 v2
// iOS 26 液态玻璃风格：白玻璃卡片 + 发丝描边 + 镜面高光 + 柔和色彩

enum Palette {
    static let bg        = Color(hex: 0xF2F4F8)
    static let green     = Color(hex: 0x2FA36B)
    static let greenSoft = Color(hex: 0xE6F4EC)
    static let orange    = Color(hex: 0xF5A623)
    static let orangeSoft = Color(hex: 0xFEF2DF)
    static let blue      = Color(hex: 0x3E9BE0)
    static let blueSoft  = Color(hex: 0xE7F3FC)
    static let purple    = Color(hex: 0x9B7EDE)
    static let purpleSoft = Color(hex: 0xF1EBFB)
    static let red       = Color(hex: 0xF25C5C)
    static let ink       = Color(hex: 0x1C2733)
    static let ink2      = Color(hex: 0x76828F)
    static let ink3      = Color(hex: 0xAEB9C4)
    static let line      = Color(hex: 0xEEF1F4)
}

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - 触感反馈

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - 液态玻璃卡片

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 18
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // 白玻璃底
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                    // 顶部镜面高光
                    LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.0)],
                                   startPoint: .top, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    // 底部一层极淡的彩虹折射（液态感）
                    LinearGradient(colors: [Palette.blue.opacity(0.05), Palette.purple.opacity(0.04), Palette.green.opacity(0.04)],
                                   startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .blendMode(.plusLighter)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            // 发丝级描边
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.25), Color(hex: 0xD9E0E8).opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color(hex: 0x5B7BA6).opacity(0.10), radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - 页面背景（液态玻璃需要彩色底衬才出效果）

struct LiquidBackground: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            // 三团极淡的彩色雾，营造玻璃下的液态感
            Circle()
                .fill(Palette.blue.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -110, y: -320)
            Circle()
                .fill(Palette.green.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 140, y: -60)
            Circle()
                .fill(Palette.purple.opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -40, y: 300)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 圆形图标徽章

struct IconBadge: View {
    let system: String
    let fg: Color
    let bg: Color
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle().fill(bg.opacity(0.85))
            Circle()
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            Image(systemName: system)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(fg)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 细进度条（玻璃内嵌式）

struct SlimBar: View {
    var value: Double          // 0...1
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.85), color],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .overlay(alignment: .trailing) {
                        // 末端高光珠
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: height * 0.7, height: height * 0.7)
                            .offset(x: -height * 0.2)
                    }
            }
        }
        .frame(height: height)
    }
}

// MARK: - 液态玻璃按钮

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = Palette.blue
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    if filled {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint)
                        LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                                       startPoint: .top, endPoint: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.65))
                        LinearGradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.0)],
                                       startPoint: .top, endPoint: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(filled ? 0.35 : 0.8), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
