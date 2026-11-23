import SwiftUI

// MARK: - 历史某天卡片（点击日期条后显示）

struct HistoryCard: View {
    @EnvironmentObject private var store: HealthStore
    let day: Date

    private var amount: Int { store.waterFor(day) }
    private var percent: Int { store.percentFor(day) }
    private var meal: DayMeal { store.mealFor(day) }

    var body: some View {
        SurfaceCard(padding: 20) {
            VStack(spacing: 14) {
                HStack {
                    Text(day, format: .dateTime.month().day().weekday())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text(amount >= store.goal ? "已达标" : "完成 \(percent)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(amount >= store.goal ? Palette.green : Palette.ink2)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(amount >= store.goal ? Palette.greenSoft : Palette.line))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(amount)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.ink)
                    Text("ml").font(.system(size: 15, weight: .medium)).foregroundColor(Palette.ink2)
                    Spacer()
                    WaterCupView(progress: Double(amount) / Double(max(store.goal, 1)))
                        .frame(width: 60, height: 92)
                }
                SlimBar(value: Double(percent) / 100, color: amount >= store.goal ? Palette.green : Palette.blue, height: 8)
                Rectangle().fill(Palette.line).frame(height: 1)
                HStack(spacing: 0) {
                    historyMetric(title: "热量", value: "\(meal.totalCalories)", unit: "千卡")
                    historyDivider
                    historyMetric(title: "体重",
                                  value: meal.weight.isEmpty ? "--" : meal.weight,
                                  unit: "斤")
                    historyDivider
                    let count = [meal.breakfast, meal.lunch, meal.dinner, meal.snack]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                    historyMetric(title: "餐次", value: "\(count)", unit: "/4")
                }
                Text("历史记录仅供查看，要修改请点今天切回")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.ink3)
            }
        }
    }

    private var historyDivider: some View {
        Rectangle().fill(Palette.line).frame(width: 1, height: 38).padding(.horizontal, 6)
    }

    private func historyMetric(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11)).foregroundColor(Palette.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundColor(Palette.ink)
                Text(unit).font(.system(size: 10)).foregroundColor(Palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 历史某天餐食（只读）

struct HistoryMeals: View {
    @EnvironmentObject private var store: HealthStore
    let day: Date

    private var meal: DayMeal { store.mealFor(day) }

    var body: some View {
        SurfaceCard(padding: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("当天饮食")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text("\(meal.totalCalories) 千卡")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.orange)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Palette.orangeSoft))
                }
                .padding(.bottom, 12)

                historyRow("早餐", text: meal.breakfast, cal: meal.breakfastCalories)
                historyRow("午餐", text: meal.lunch, cal: meal.lunchCalories)
                historyRow("晚餐", text: meal.dinner, cal: meal.dinnerCalories)
                historyRow("加餐", text: meal.snack, cal: meal.snackCalories)
            }
        }
    }

    private func historyRow(_ title: String, text: String, cal: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.ink)
                Spacer()
                if let cal, cal > 0 {
                    Text("\(cal) 千卡").font(.system(size: 12)).foregroundColor(Palette.ink2)
                }
            }
            Text(text.isEmpty ? "未记录" : text)
                .font(.system(size: 12))
                .foregroundColor(text.isEmpty ? Palette.ink3 : Palette.ink2)
        }
        .padding(.vertical, 7)
    }
}
