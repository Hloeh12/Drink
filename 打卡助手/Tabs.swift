import SwiftUI
import Charts

// MARK: - 趋势页

struct TrendTabView: View {
    @EnvironmentObject private var store: HealthStore

    private var points: [(Date, Double)] {
        store.weightTrend(days: 7).compactMap { item in
            guard let w = item.1 else { return nil }
            return (item.0, w)
        }
    }
    private var values: [Double] { points.map { $0.1 } }
    private var latest: Double? { values.last }
    private var average: Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    private var yDomain: ClosedRange<Double> {
        let lo = values.min() ?? 0
        let hi = values.max() ?? 100
        let pad = Swift.max((hi - lo) * 0.2, 0.5)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("趋势")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text("近 7 天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.ink2)
                }
                .padding(.top, 6)

                HStack(spacing: 10) {
                    StatTile(title: "最新体重", value: latestText, unit: "斤", color: Palette.green)
                    StatTile(title: "平均", value: avgText, unit: "斤", color: Palette.blue)
                    StatTile(title: "变化", value: changeText, unit: "斤", color: Palette.orange)
                }

                weightChartCard
                waterChartCard
                calorieChartCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }

    private var latestText: String {
        guard let v = latest else { return "--" }
        return String(format: "%.1f", v)
    }
    private var avgText: String {
        guard let v = average else { return "--" }
        return String(format: "%.1f", v)
    }
    private var changeText: String {
        guard let c = store.weightChange else { return "--" }
        return String(format: "%+.1f", c)
    }

    // 体重折线图
    private var weightChartCard: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("体重曲线")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)

                if points.isEmpty {
                    EmptyHint(icon: "scalemass", text: "还没有体重记录\n在首页输入晨起体重")
                } else if #available(iOS 16.0, *) {
                    Chart(points, id: \.0) { item in
                        LineMark(
                            x: .value("日期", item.0, unit: .day),
                            y: .value("体重", item.1)
                        )
                        .foregroundStyle(Palette.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("日期", item.0, unit: .day),
                            y: .value("体重", item.1)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(60)
                        .annotation(position: .overlay) {
                            Circle().fill(Palette.green).frame(width: 7, height: 7)
                        }
                    }
                    .chartYScale(domain: yDomain)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                                .font(.system(size: 9))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Palette.line)
                            AxisValueLabel().font(.system(size: 9)).foregroundStyle(Palette.ink3)
                        }
                    }
                    .frame(height: 190)
                } else {
                    WeightBarFallback(points: points, domain: yDomain)
                }
            }
        }
    }

    // 喝水柱状
    private var waterChartCard: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("饮水").font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text("目标 \(store.goal) ml").font(.system(size: 11)).foregroundColor(Palette.ink2)
                }
                BarRow(
                    items: store.dates().map { day in
                        (day, Double(store.waterFor(day)), Double(store.goal))
                    },
                    color: Palette.blue
                )
            }
        }
    }

    // 热量柱状
    private var calorieChartCard: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("热量").font(.system(size: 15, weight: .semibold)).foregroundColor(Palette.ink)
                    Spacer()
                    Text("千卡").font(.system(size: 11)).foregroundColor(Palette.ink2)
                }
                BarRow(
                    items: store.dates().map { day in
                        (day, Double(store.caloriesForDate(day)), 1800)
                    },
                    color: Palette.orange
                )
            }
        }
    }
}

// MARK: - 记录页

struct DiaryTabView: View {
    @EnvironmentObject private var store: HealthStore

    private var monthDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<35).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("记录")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    HStack(spacing: 10) {
                        legend(Palette.greenSoft, "达标")
                        legend(Palette.orangeSoft, "有记录")
                        legend(Color(hex: 0xF1F3F5), "无")
                    }
                }
                .padding(.top, 6)

                SurfaceCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("近 5 周饮水")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                            ForEach(monthDays, id: \.self) { day in
                                let ratio = Double(store.waterFor(day)) / Double(max(store.goal, 1))
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(ratio >= 1 ? Palette.green : (ratio > 0 ? Palette.orangeSoft : Color(hex: 0xF1F3F5)))
                                    .frame(height: 30)
                                    .overlay(
                                        Text(day, format: .dateTime.day())
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(ratio >= 1 ? .white : Palette.ink2)
                                    )
                            }
                        }
                    }
                }

                HStack {
                    Text("饮食回顾")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                }
                .padding(.top, 4)

                MealHistoryList()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text).font(.system(size: 10)).foregroundColor(Palette.ink2)
        }
    }
}

// MARK: - 我的页

struct MeTabView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var csvURL: URL?
    @State private var showShare = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                profileCard
                settingsCard
                exportCard
                aboutCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $showShare) {
            if let url = csvURL { ShareSheet(items: [url]) }
        }
    }

    private var profileCard: some View {
        SurfaceCard(padding: 18) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x6EC2F0), Palette.blue],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("打卡助手").font(.system(size: 17, weight: .bold)).foregroundColor(Palette.ink)
                    Text("喝水 · 饮食 · 体重记录").font(.system(size: 12)).foregroundColor(Palette.ink2)
                }
                Spacer()
            }
        }
    }

    private var settingsCard: some View {
        SurfaceCard(padding: 18) {
            VStack(spacing: 16) {
                HStack {
                    IconBadge(system: "target", fg: Palette.blue, bg: Palette.blueSoft, size: 34)
                    Text("每日饮水目标").font(.system(size: 14, weight: .medium)).foregroundColor(Palette.ink)
                    Spacer()
                    Stepper(value: $store.goal, in: 800...3000, step: 100) {
                        Text("\(store.goal) ml").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink2)
                    }
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                HStack {
                    IconBadge(system: "bell.fill", fg: Palette.orange, bg: Palette.orangeSoft, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("定时提醒").font(.system(size: 14, weight: .medium)).foregroundColor(Palette.ink)
                        Text("每 \(store.remindInterval) 分钟").font(.system(size: 11)).foregroundColor(Palette.ink2)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.remindOn },
                        set: { store.setReminder($0) }
                    ))
                    .labelsHidden()
                    .tint(Palette.green)
                }
                if store.remindOn {
                    HStack {
                        Text("提醒间隔").font(.system(size: 12)).foregroundColor(Palette.ink2)
                        Spacer()
                        Stepper("", value: $store.remindInterval, in: 15...120, step: 5).labelsHidden()
                        Text("\(store.remindInterval) 分").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.ink)
                    }
                }
            }
        }
    }

    private var exportCard: some View {
        SurfaceCard(padding: 18) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    IconBadge(system: "square.and.arrow.up", fg: Palette.green, bg: Palette.greenSoft, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("数据导出").font(.system(size: 14, weight: .medium)).foregroundColor(Palette.ink)
                        Text("喝水、体重、餐食、热量导出为 CSV").font(.system(size: 11)).foregroundColor(Palette.ink2)
                    }
                    Spacer()
                }
                Button {
                    csvURL = store.exportCSVFile()
                    if csvURL != nil { showShare = true }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text.fill")
                        Text("导出 CSV").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.green))
                }
            }
        }
    }

    private var aboutCard: some View {
        SurfaceCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("关于").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                Text("数据全部保存在本机，不会上传到任何服务器。卸载 App 会清除数据，建议定期导出 CSV 备份。")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.ink2)
                    .lineSpacing(4)
                Text("本工具仅用于自我记录，不提供医疗建议。")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.ink3)
                Text("版本 1.1").font(.system(size: 10)).foregroundColor(Palette.ink3).padding(.top, 2)
            }
        }
    }
}

// MARK: - 小组件

struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10)).foregroundColor(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(color)
                Text(unit).font(.system(size: 9)).foregroundColor(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(Palette.ink3)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Palette.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// 通用柱状行
struct BarRow: View {
    let items: [(Date, Double, Double)]
    let color: Color

    private var peak: Double {
        let maxValue = items.map { $0.1 }.max() ?? 0
        let maxTarget = items.map { $0.2 }.max() ?? 1
        return Swift.max(maxValue, maxTarget, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 5) {
                    Text(item.1 > 0 ? short(item.1) : "--")
                        .font(.system(size: 9))
                        .foregroundColor(Palette.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(item.1 <= 0 ? Color(hex: 0xF1F3F5) : color.opacity(opacity(for: item.1)))
                                .frame(height: Swift.max(3, geo.size.height * CGFloat(item.1 / peak)))
                        }
                    }
                    .frame(height: 70)
                    Text(item.0, format: .dateTime.day())
                        .font(.system(size: 9))
                        .foregroundColor(Calendar.current.isDateInToday(item.0) ? Palette.ink : Palette.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func opacity(for value: Double) -> Double {
        0.45 + 0.55 * Swift.min(1, value / peak)
    }

    private func short(_ value: Double) -> String {
        value >= 1000 ? String(format: "%.1fk", value / 1000) : String(Int(value))
    }
}

// iOS 15 体重柱状回退
struct WeightBarFallback: View {
    let points: [(Date, Double)]
    let domain: ClosedRange<Double>

    private var span: Double { Swift.max(domain.upperBound - domain.lowerBound, 0.1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(points, id: \.0) { item in
                VStack(spacing: 5) {
                    Text(String(format: "%.1f", item.1))
                        .font(.system(size: 9)).foregroundColor(Palette.ink2)
                    GeometryReader { geo in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Palette.green.opacity(0.75))
                                .frame(height: Swift.max(6, geo.size.height * CGFloat((item.1 - domain.lowerBound) / span)))
                        }
                    }
                    .frame(height: 140)
                    Text(item.0, format: .dateTime.day())
                        .font(.system(size: 9)).foregroundColor(Palette.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
