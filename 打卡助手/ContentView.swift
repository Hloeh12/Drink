import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HealthStore
    @State private var resetAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0xEEF6FB).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        waterCard
                        mealCard
                        reminderCard
                        HistoryChart(title: "最近 7 天喝水", kind: .water)
                        HistoryChart(title: "最近 7 天体重", kind: .weight)
                        MealReview()
                        Text("提示：少量多次饮用，喝到不口渴即可；饮食记录仅用于自我观察，注意均衡摄入，不要过度节食。如持续头晕、心慌、乏力，请及时进食休息，必要时就医。")
                            .font(.caption).foregroundColor(.secondary).lineSpacing(5).padding(.horizontal, 4)
                    }.padding()
                }
            }.navigationBarHidden(true)
        }.navigationViewStyle(.stack)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 12).fill(Color.blue); Image(systemName: "drop.fill").foregroundColor(.white).font(.title2) }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) { Text("打卡助手").font(.title2.bold()); Text("喝水 · 饮食 · 体重记录").font(.subheadline).foregroundColor(.secondary) }
            Spacer()
        }
    }

    private var waterCard: some View {
        Card {
            VStack(spacing: 16) {
                Text("\(store.todayWater) ").font(.system(size: 40, weight: .bold)).foregroundColor(Color(hex: 0x1B7CB8)) + Text("ml").font(.body).foregroundColor(.secondary)
                Text("目标 \(store.goal) ml · 已完成 \(store.percent)%").font(.subheadline).foregroundColor(.secondary)
                ProgressView(value: Double(store.todayWater), total: Double(store.goal)).tint(Color(hex: 0x2F9BE0))
                Picker("杯量", selection: $store.selectedCup) { ForEach([150, 200, 250, 300], id: \.self) { Text("\($0)ml").tag($0) } }.pickerStyle(.segmented)
                Button { store.setWater(store.todayWater + store.selectedCup) } label: { Label("喝一杯", systemImage: "drop.fill").frame(maxWidth: .infinity).padding(.vertical, 6) }.buttonStyle(.borderedProminent).tint(Color(hex: 0x2F9BE0))
                HStack {
                    Button { store.setWater(store.todayWater - store.selectedCup) } label: { Label("撤销一杯", systemImage: "arrow.uturn.backward") }.buttonStyle(.bordered)
                    Spacer(); Button(role: .destructive) { resetAlert = true } label: { Label("重置今日", systemImage: "trash") }.buttonStyle(.bordered)
                }
                Stepper("每日目标  \(store.goal) ml", value: $store.goal, in: 800...3000, step: 100)
            }
        }.alert("重置今日", isPresented: $resetAlert) { Button("取消", role: .cancel) {}; Button("清空", role: .destructive) { store.setWater(0) } } message: { Text("确定清空今日喝水记录吗？") }
    }

    private var mealCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("今日饮食记录", systemImage: "fork.knife").font(.headline)
                MealField("早餐", "吃了什么…", value: Binding(get: { store.todayMeal.breakfast }, set: { store.updateMeal(\.breakfast, value: $0) }))
                MealField("午餐", "吃了什么…", value: Binding(get: { store.todayMeal.lunch }, set: { store.updateMeal(\.lunch, value: $0) }))
                MealField("晚餐", "吃了什么…", value: Binding(get: { store.todayMeal.dinner }, set: { store.updateMeal(\.dinner, value: $0) }))
                MealField("加餐", "水果、零食、饮料…", value: Binding(get: { store.todayMeal.snack }, set: { store.updateMeal(\.snack, value: $0) }))
                HStack { Text("晨起体重").font(.subheadline).foregroundColor(.secondary); TextField("如 96.1", text: Binding(get: { store.todayMeal.weight }, set: { store.updateMeal(\.weight, value: normalizedWeight($0)) })).keyboardType(.decimalPad).textFieldStyle(.roundedBorder); Text("斤").foregroundColor(.secondary) }
            }
        }
    }

    private var reminderCard: some View {
        Card { VStack(spacing: 14) { Toggle(isOn: Binding(get: { store.remindOn }, set: { store.setReminder($0) })) { Label("定时提醒", systemImage: "bell") }; Divider(); Stepper("每 \(store.remindInterval) 分钟", value: $store.remindInterval, in: 15...120) } }
    }

    private func normalizedWeight(_ text: String) -> String {
        let valid = text.filter { $0.isNumber || $0 == "." }; let parts = valid.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return valid }
        return String(parts[0]) + "." + String(parts[1].prefix(1))
    }
}

private struct MealField: View {
    let label: String, placeholder: String; @Binding var value: String
    init(_ label: String, _ placeholder: String, value: Binding<String>) { self.label = label; self.placeholder = placeholder; _value = value }
    var body: some View { HStack(alignment: .top) { Text(label).font(.subheadline).foregroundColor(.secondary).frame(width: 38, alignment: .leading); TextField(placeholder, text: $value).textFieldStyle(.roundedBorder) } }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(18).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.blue.opacity(0.08), radius: 10, y: 4) }
}

extension Color { init(hex: UInt) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) } }
