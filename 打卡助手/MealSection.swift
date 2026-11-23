import SwiftUI

// MARK: - 今日餐次区（图标圆圈 + 小计 + 展开编辑）

struct MealSection: View {
    @EnvironmentObject private var store: HealthStore
    @State private var expanded: Set<String> = []

    private struct MealKind {
        let key: String
        let title: String
        let icon: String
        let fg: Color
        let bg: Color
        let textPath: WritableKeyPath<DayMeal, String>
        let calPath: WritableKeyPath<DayMeal, Int?>
        let photoPath: WritableKeyPath<DayMeal, String?>
        let placeholder: String
    }

    private var kinds: [MealKind] {
        [
            MealKind(key: "breakfast", title: "早餐", icon: "takeoutbag.and.cup.and.straw.fill",
                     fg: Palette.orange, bg: Palette.orangeSoft,
                     textPath: \.breakfast, calPath: \.breakfastCalories, photoPath: \.breakfastPhoto,
                     placeholder: "吃了什么…"),
            MealKind(key: "lunch", title: "午餐", icon: "sun.max.fill",
                     fg: Palette.blue, bg: Palette.blueSoft,
                     textPath: \.lunch, calPath: \.lunchCalories, photoPath: \.lunchPhoto,
                     placeholder: "吃了什么…"),
            MealKind(key: "dinner", title: "晚餐", icon: "moon.stars.fill",
                     fg: Palette.purple, bg: Palette.purpleSoft,
                     textPath: \.dinner, calPath: \.dinnerCalories, photoPath: \.dinnerPhoto,
                     placeholder: "吃了什么…"),
            MealKind(key: "snack", title: "加餐", icon: "leaf.fill",
                     fg: Palette.green, bg: Palette.greenSoft,
                     textPath: \.snack, calPath: \.snackCalories, photoPath: \.snackPhoto,
                     placeholder: "水果、零食、饮料…")
        ]
    }

    private var isExpanded: Bool { !expanded.isEmpty }

    var body: some View {
        SurfaceCard(padding: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("今日记录")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text("\(store.todayCalories) 千卡")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Palette.orangeSoft))
                }
                .padding(.bottom, 12)

                ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                    mealRow(kind)
                    if index < kinds.count - 1 {
                        Rectangle().fill(Palette.line).frame(height: 1)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func mealRow(_ kind: MealKind) -> some View {
        let meal = store.todayMeal
        let text = meal[keyPath: kind.textPath]
        let calories = meal[keyPath: kind.calPath] ?? 0
        let opened = expanded.contains(kind.key)
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1

        return VStack(spacing: 10) {
            Button {
                if opened { expanded.remove(kind.key) } else { expanded.insert(kind.key) }
            } label: {
                HStack(spacing: 11) {
                    IconBadge(system: kind.icon, fg: kind.fg, bg: kind.bg, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(kind.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Palette.ink)
                            Text("(\(count))")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.ink3)
                        }
                        if count > 0 {
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundColor(Palette.ink2)
                                .lineLimit(1)
                        } else {
                            Text("还没有记录")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.ink3)
                        }
                    }
                    Spacer()
                    if calories > 0 {
                        Text("\(calories) 千卡")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Palette.ink2)
                    }
                    Image(systemName: opened ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.ink3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if opened {
                VStack(spacing: 9) {
                    TextField(kind.placeholder, text: Binding(
                        get: { store.todayMeal[keyPath: kind.textPath] },
                        set: { store.updateMeal(kind.textPath, value: $0) }
                    ))
                    .font(.system(size: 14))
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.bg))

                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.orange)
                            TextField("热量", value: Binding(
                                get: { store.todayMeal[keyPath: kind.calPath] },
                                set: { store.updateMealCalories(kind.calPath, value: $0) }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 14))
                            Text("千卡").font(.system(size: 11)).foregroundColor(Palette.ink2)
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.bg))

                        Button {
                            // 占位：照片功能依赖 Supabase Storage，本地版暂不启用
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Palette.ink2)
                                .frame(width: 42, height: 42)
                                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.bg))
                        }
                    }
                }
                .padding(.leading, 47)
            }
        }
    }
}

// MARK: - 饮食回顾（记录页用）

struct MealHistoryList: View {
    @EnvironmentObject private var store: HealthStore
    @State private var expanded: Set<String> = []

    private let fields: [(String, WritableKeyPath<DayMeal, String>)] = [
        ("早", \.breakfast), ("午", \.lunch), ("晚", \.dinner), ("加", \.snack)
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(store.dates().reversed(), id: \.self) { date in
                let key = HealthStore.key(for: date)
                let meal = store.meals[key] ?? DayMeal()
                let hasData = fields.contains {
                    !meal[keyPath: $0.1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                let opened = expanded.contains(key)

                SurfaceCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            if opened { expanded.remove(key) } else { expanded.insert(key) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(title(date))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Palette.ink)
                                    if hasData {
                                        Text(summary(meal))
                                            .font(.system(size: 12))
                                            .foregroundColor(Palette.ink2)
                                            .lineLimit(1)
                                    } else {
                                        Text("当天无记录")
                                            .font(.system(size: 12))
                                            .foregroundColor(Palette.ink3)
                                    }
                                }
                                Spacer()
                                if meal.totalCalories > 0 {
                                    Text("\(meal.totalCalories) 千卡")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Palette.orange)
                                }
                                Image(systemName: opened ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Palette.ink3)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if opened && hasData {
                            Rectangle().fill(Palette.line).frame(height: 1)
                            ForEach(fields, id: \.0) { label, path in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Palette.ink2)
                                        .frame(width: 16, alignment: .leading)
                                    Text(meal[keyPath: path].isEmpty ? "—" : meal[keyPath: path])
                                        .font(.system(size: 13))
                                        .foregroundColor(meal[keyPath: path].isEmpty ? Palette.ink3 : Palette.ink)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func summary(_ meal: DayMeal) -> String {
        for (_, path) in fields {
            let v = meal[keyPath: path].trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }
        return ""
    }

    private func title(_ date: Date) -> String {
        let base = date.formatted(.dateTime.month(.defaultDigits).day())
        return Calendar.current.isDateInToday(date) ? "\(base) · 今天" : base
    }
}
