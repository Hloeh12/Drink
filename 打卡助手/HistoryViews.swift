import SwiftUI

struct HistoryChart: View {
    enum Kind: Equatable { case water, weight }
    @EnvironmentObject private var store: HealthStore
    let title: String
    let kind: Kind

    private var records: [(Date, Double?)] {
        store.dates().map { date in
            let key = HealthStore.key(for: date)
            if kind == .water { return (date, Double(store.water[key] ?? 0)) }
            guard let value = store.meals[key]?.weight, let number = Double(value), number > 0 else { return (date, nil) }
            return (date, number)
        }
    }
    private var values: [Double] { records.compactMap { $0.1 }.filter { kind == .water ? $0 > 0 : true } }
    private var low: Double { values.min() ?? 0 }
    private var high: Double { values.max() ?? 1 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 5) {
                            Text(labelValue(item.1)).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                            GeometryReader { geo in
                                VStack { Spacer(); RoundedRectangle(cornerRadius: 5).fill(barColor(isToday: index == 6)).frame(height: barHeight(item.1, available: geo.size.height)) }
                            }.frame(height: 84)
                            Text(item.0, format: .dateTime.month(.twoDigits).day(.twoDigits)).font(.system(size: 10)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func labelValue(_ value: Double?) -> String {
        guard let value = value, !(kind == .water && value == 0) else { return kind == .water ? "0" : "--" }
        return kind == .water ? "\(Int(value))" : String(format: "%.1f", value)
    }
    private func barHeight(_ value: Double?, available: CGFloat) -> CGFloat {
        guard let value = value, !(kind == .water && value == 0) else { return 2 }
        if kind == .water { return max(5, available * CGFloat(value / max(values.max() ?? 1, Double(store.goal)))) }
        if high == low { return available * 0.65 }
        return max(8, available * CGFloat(0.25 + 0.75 * ((value - low) / (high - low))))
    }
    private func barColor(isToday: Bool) -> Color {
        if kind == .water { return Color(hex: isToday ? 0x1B7CB8 : 0x70BDE8) }
        return Color(hex: isToday ? 0x258456 : 0x70C99D)
    }
}

struct MealReview: View {
    @EnvironmentObject private var store: HealthStore
    @State private var expanded: Set<String> = []
    private let fields: [(String, WritableKeyPath<DayMeal, String>)] = [("早", \.breakfast), ("午", \.lunch), ("晚", \.dinner), ("加", \.snack)]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("饮食回顾 · 近 7 天").font(.headline).padding(.bottom, 10)
                ForEach(store.dates().reversed(), id: \.self) { date in
                    let key = HealthStore.key(for: date); let meal = store.meals[key] ?? DayMeal()
                    let hasData = fields.contains { !meal[keyPath: $0.1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } || !meal.weight.isEmpty
                    let summary = fields.compactMap { _, path -> String? in let value = meal[keyPath: path].trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value }.first
                    VStack(alignment: .leading, spacing: 8) {
                        Button { if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) } } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dateLabel(date)).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                    if let summary = summary { Text(summary).font(.caption).foregroundColor(.secondary).lineLimit(1) } else if !hasData { Text("当天无记录").font(.caption).foregroundColor(.secondary) }
                                }
                                Spacer()
                                if !meal.weight.isEmpty { Text("\(meal.weight) 斤").font(.caption.weight(.medium)).foregroundColor(Color(hex: 0x258456)) }
                                Image(systemName: expanded.contains(key) ? "chevron.up" : "chevron.down").font(.caption).foregroundColor(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if expanded.contains(key) {
                            if hasData {
                                ForEach(fields, id: \.0) { label, path in HStack(alignment: .top) { Text(label).foregroundColor(.secondary).frame(width: 24, alignment: .leading); Text(meal[keyPath: path].isEmpty ? "—" : meal[keyPath: path]).foregroundColor(.primary) }.font(.caption).padding(.vertical, 2) }
                                if !meal.weight.isEmpty { HStack { Text("体重").foregroundColor(.secondary).frame(width: 24, alignment: .leading); Text("\(meal.weight) 斤") }.font(.caption) }
                            } else { Text("当天无记录").font(.caption).foregroundColor(.secondary) }
                        }
                    }.padding(.vertical, 10)
                    if key != HealthStore.key(for: store.dates().first ?? date) { Divider() }
                }
            }
        }
    }
    private func dateLabel(_ date: Date) -> String {
        let base = date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
        return Calendar.current.isDateInToday(date) ? "\(base) · 今天" : base
    }
}
