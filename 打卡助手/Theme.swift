import SwiftUI

// MARK: - 设计系统
// 参考健康记录类 App 的视觉语言：浅灰底 + 纯白圆角卡片 + 绿色主色 + 多彩功能色

enum Palette {
    static let bg        = Color(hex: 0xF4F6F8)
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
    static let ink2      = Color(hex: 0x8A96A3)
    static let ink3      = Color(hex: 0xB9C3CD)
    static let line      = Color(hex: 0xEEF1F4)
}

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - 通用卡片

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
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.045), radius: 12, x: 0, y: 4)
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
            Circle().fill(bg)
            Image(systemName: system)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(fg)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 细进度条

struct SlimBar: View {
    var value: Double          // 0...1
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
