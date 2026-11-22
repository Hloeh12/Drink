import SwiftUI
import Charts

/// 体重趋势图：折线图 + 统计摘要
struct WeightTrendView: View {
    @EnvironmentObject private var store: HealthStore
    @Environment(\.dismiss) private var dismiss

    private var trend: [(Date, Double?)] { store.weightTrend(days: 7) }
    private var validWeights: [Double] { trend.compactMap { $0.1 } }
    private var avgWeight: Double? { validWeights.isEmpty ? nil : validWeights.reduce(0, +) / Double(validWeights.count) }
    private var minWeight: Double? { validWeights.min() }
    private var maxWeight: Double? { validWeights.max() }
    private var change: Double? { store.weightChange }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 统计摘要
                    HStack(spacing: 12) {
                        StatBlock(title: "最新", value: validWeights.last.map { String(format: "%.1f", $0) } ?? "--", unit: "斤", color: Color(hex: 0x38B27A))
                        StatBlock(title: "平均", value: avgWeight.map { String(format: "%.1f", $0) } ?? "--", unit: "斤", color: Color(hex: 0x2F9BE0))
                        StatBlock(title: "变化", value: change.map { String(format: "%+.1f", $0) } ?? "--", unit: "斤", color: change.map { $0 >= 0 ? Color(hex: 0xE8730C) : Color(hex: 0x38B27A) } ?? .gray)
                    }
                    .padding(.horizontal)

                    // 折线图
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("体重趋势 · 近 7 天").font(.headline)
                            chartContent
                        }
                    }
                    .padding(.horizontal)

                    // 历史明细
                    Card {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("历史明细").font(.headline).padding(.bottom, 10)
                            ForEach(trend.reversed(), id: \.0) { date, weight in
                                HStack {
                                    Text(dateLabel(date))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let weight = weight {
                                        Text(String(format: "%.1f 斤", weight))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(Color(hex: 0x38B27A))
                                    } else {
                                        Text("--")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }.padding(.vertical, 8)
                                if date != trend.first?.0 { Divider() }
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical)
            }
            .background(Color(hex: 0xEEF6FB).ignoresSafeArea())
            .navigationTitle("体重趋势")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("关闭") { dismiss() } }
        }.navigationViewStyle(.stack)
    }

    // MARK: - 图表内容

    @ViewBuilder
    private var chartContent: some View {
        if #available(iOS 16, *) {
            Chart(trend, id: \.0) { date, weight in
                if let weight = weight {
                    LineMark(
                        x: .value("日期", date, unit: .day),
                        y: .value("体重", weight)
                    )
                    .foregroundStyle(Color(hex: 0x38B27A))
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("日期", date, unit: .day),
                        y: .value("体重", weight)
                    )
                    .foregroundStyle(Color(hex: 0x258456))
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .frame(height: 200)
        } else {
            // iOS 15 fallback：柱状图
            legacyChart
        }
    }

    // MARK: - iOS 15 兼容柱状图

    private var legacyChart: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(trend, id: \.0) { date, weight in
                VStack(spacing: 4) {
                    if let weight = weight {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text("--").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        VStack { Spacer()
                            RoundedRectangle(cornerRadius: 5)
                                .fill(barColor(for: weight, date: date))
                                .frame(height: barHeight(weight, available: geo.size.height))
                        }
                    }.frame(height: 100)
                    Text(date, format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity)
            }
        }
    }

    private var yDomain: ClosedRange<Double> {
        let lo = minWeight ?? 0
        let hi = maxWeight ?? 100
        let padding = Swift.max((hi - lo) * 0.15, 1)
        return (lo - padding)...(hi + padding)
    }

    private func barColor(for weight: Double?, date: Date) -> Color {
        guard weight != nil else { return Color.gray.opacity(0.2) }
        return Calendar.current.isDateInToday(date) ? Color(hex: 0x258456) : Color(hex: 0x70C99D)
    }

    private func barHeight(_ weight: Double?, available: CGFloat) -> CGFloat {
        guard let weight = weight, let lo = minWeight, let hi = maxWeight, hi > lo else { return 4 }
        let ratio = CGFloat((weight - lo) / (hi - lo))
        return Swift.max(8, available * (0.25 + 0.75 * ratio))
    }

    private func dateLabel(_ date: Date) -> String {
        let base = date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
        return Calendar.current.isDateInToday(date) ? "\(base) · 今天" : base
    }
}

// MARK: - 统计块

private struct StatBlock: View {
    let title: String, value: String, unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title3.bold()).foregroundColor(color)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }
        }.frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}
