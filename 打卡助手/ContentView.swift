import SwiftUI

// MARK: - 根视图（底部 Tab 容器）

struct ContentView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var tab = 0
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            Group {
                switch tab {
                case 0: TodayView()
                case 1: TrendTabView()
                case 2: DiaryTabView()
                default: MeTabView()
                }
            }

            BottomBar(tab: $tab, onPlus: { showQuickAdd = true })
        }
        .confirmationDialog("快速添加", isPresented: $showQuickAdd, titleVisibility: .visible) {
            Button("喝一杯 \(store.selectedCup)ml") {
                store.setWater(store.todayWater + store.selectedCup)
            }
            Button("记录今日饮食") { tab = 0 }
            Button("记录体重") { tab = 0 }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - 底部导航栏

struct BottomBar: View {
    @Binding var tab: Int
    var onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(0, "首页", "house.fill")
            item(1, "趋势", "chart.line.uptrend.xyaxis")
            Spacer().frame(width: 68)
            item(2, "记录", "book.fill")
            item(3, "我的", "person.fill")
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .padding(.horizontal, 20)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Button(action: onPlus) {
                ZStack {
                    Circle()
                        .fill(Palette.green)
                        .frame(width: 56, height: 56)
                        .shadow(color: Palette.green.opacity(0.45), radius: 10, x: 0, y: 5)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -26)
        }
    }

    private func item(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(tab == index ? Palette.green : Palette.ink3)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 今日页

struct TodayView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var showReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                topHeader
                DateStrip(days: store.dates())
                HeroCard()
                waterControls
                MealSection()
                weightCard
                tipText
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }

    // 顶部：日期 + 连续天数
    private var topHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date(), format: .dateTime.month(.defaultDigits).day())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text("打卡助手")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.ink2)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").font(.system(size: 12))
                Text("\(streak) 连续天数").font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Palette.orange)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Palette.orangeSoft))
        }
        .padding(.top, 4)
    }

    // 连续打卡天数
    private var streak: Int {
        var count = 0
        for day in store.dates().reversed() {
            if store.waterFor(day) > 0 { count += 1 } else { break }
        }
        return count
    }

    // 喝水操作区
    private var waterControls: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach([150, 200, 250, 300], id: \.self) { ml in
                        Button { store.selectedCup = ml } label: {
                            Text("\(ml)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(store.selectedCup == ml ? .white : Palette.ink2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(store.selectedCup == ml ? Palette.blue : Palette.blueSoft)
                                )
                        }
                    }
                }

                Button {
                    store.setWater(store.todayWater + store.selectedCup)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                        Text("喝一杯").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.blue)
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        store.setWater(store.todayWater - store.selectedCup)
                    } label: {
                        Label("撤销一杯", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.line))
                    }
                    Button { showReset = true } label: {
                        Label("重置", systemImage: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Palette.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.red.opacity(0.09)))
                    }
                }

                HStack {
                    Text("每日目标").font(.system(size: 13)).foregroundColor(Palette.ink2)
                    Spacer()
                    Stepper(value: $store.goal, in: 800...3000, step: 100) {
                        Text("\(store.goal) ml")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                }
            }
        }
        .confirmationDialog("重置今日饮水", isPresented: $showReset, titleVisibility: .visible) {
            Button("清空今日记录", role: .destructive) { store.setWater(0) }
            Button("取消", role: .cancel) {}
        }
    }

    // 体重卡片
    private var weightCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    IconBadge(system: "scalemass.fill", fg: Palette.green, bg: Palette.greenSoft, size: 34)
                    Text("晨起体重").font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    if let change = store.weightChange {
                        Text(String(format: "%+.1f 斤", change))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(change <= 0 ? Palette.green : Palette.orange)
                    }
                }
                HStack(spacing: 8) {
                    TextField("如 96.1", text: Binding(
                        get: { store.todayMeal.weight },
                        set: { store.updateMeal(\.weight, value: filterWeight($0)) }
                    ))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.bg))
                    Text("斤").font(.system(size: 14)).foregroundColor(Palette.ink2)
                }
            }
        }
    }

    private var tipText: some View {
        Text("提示：少量多次饮用，喝到不口渴即可；饮食记录仅用于自我观察，注意均衡摄入，不要过度节食。如持续头晕、心慌、乏力，请及时进食休息，必要时就医。")
            .font(.system(size: 11))
            .foregroundColor(Palette.ink3)
            .lineSpacing(5)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private func filterWeight(_ text: String) -> String {
        let valid = text.filter { $0.isNumber || $0 == "." }
        let parts = valid.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return valid }
        return String(parts[0]) + "." + String(parts[1].prefix(1))
    }
}

// MARK: - 日期条

struct DateStrip: View {
    @EnvironmentObject private var store: HealthStore
    let days: [Date]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(days, id: \.self) { day in
                let amount = store.waterFor(day)
                let ratio = Double(amount) / Double(max(store.goal, 1))
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 5) {
                    Text(isToday ? "今天" : weekday(day))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isToday ? Palette.ink : Palette.ink2)
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Palette.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ratio >= 1 ? Palette.greenSoft : (ratio > 0 ? Palette.orangeSoft : Color(hex: 0xF1F3F5)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isToday ? Palette.ink : Color.clear, lineWidth: 2)
                )
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}

// MARK: - 主数据卡片

struct HeroCard: View {
    @EnvironmentObject private var store: HealthStore

    private var progress: Double {
        Double(store.todayWater) / Double(max(store.goal, 1))
    }
    private var mealCount: Int {
        let m = store.todayMeal
        return [m.breakfast, m.lunch, m.dinner, m.snack]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        SurfaceCard(padding: 20) {
            VStack(spacing: 16) {
                HStack {
                    Text("今日饮水")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.ink2)
                    Spacer()
                    Text("目标 \(store.goal) ml")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.blue)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Palette.blueSoft))
                }

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(store.todayWater)")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundColor(Palette.ink)
                            Text("ml").font(.system(size: 15, weight: .medium)).foregroundColor(Palette.ink2)
                        }
                        SlimBar(value: progress, color: Palette.blue, height: 8)
                        HStack {
                            Text("已完成 \(store.percent)%")
                                .font(.system(size: 12)).foregroundColor(Palette.ink2)
                            Spacer()
                            Text("还差 \(max(0, store.goal - store.todayWater)) ml")
                                .font(.system(size: 12)).foregroundColor(Palette.ink2)
                        }
                    }
                    WaterCupView(progress: progress)
                        .frame(width: 60, height: 92)
                }

                Rectangle().fill(Palette.line).frame(height: 1)

                HStack(spacing: 0) {
                    metric(title: "热量", value: "\(store.todayCalories)", unit: "千卡",
                           color: Palette.orange, ratio: min(1, Double(store.todayCalories) / 1800))
                    metricDivider
                    metric(title: "体重", value: weightText, unit: "斤",
                           color: Palette.green, ratio: store.todayWeight == nil ? 0 : 0.72)
                    metricDivider
                    metric(title: "餐次", value: "\(mealCount)", unit: "/4",
                           color: Palette.purple, ratio: Double(mealCount) / 4)
                }
            }
        }
    }

    private var weightText: String {
        if let w = store.todayWeight { return String(format: "%.1f", w) }
        let raw = store.todayMeal.weight
        if !raw.isEmpty, let w = Double(raw) { return String(format: "%.1f", w) }
        return "--"
    }

    private var metricDivider: some View {
        Rectangle().fill(Palette.line).frame(width: 1, height: 38).padding(.horizontal, 6)
    }

    private func metric(title: String, value: String, unit: String, color: Color, ratio: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11)).foregroundColor(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundColor(Palette.ink)
                Text(unit).font(.system(size: 10)).foregroundColor(Palette.ink2)
            }
            SlimBar(value: ratio, color: color, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 水杯图形

struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topInset = rect.width * 0.05
        let botInset = rect.width * 0.15
        let bottomY = rect.maxY - rect.height * 0.02
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - botInset, y: bottomY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + botInset, y: bottomY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.07))
        p.closeSubpath()
        return p
    }
}

struct WaterCupView: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let clamped = max(0.03, min(1, progress))
            ZStack {
                CupShape().fill(Color(hex: 0xEFF6FC))
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(LinearGradient(colors: [Color(hex: 0x6EC2F0), Palette.blue],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: h * clamped)
                }
            }
            .clipShape(CupShape())
            .overlay(CupShape().stroke(Palette.blue.opacity(0.28), lineWidth: 1.5))
        }
    }
}
