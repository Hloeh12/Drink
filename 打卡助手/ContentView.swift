import SwiftUI
import Charts
import AuthenticationServices

struct ContentView: View {
    @EnvironmentObject private var store: HealthStore
    @StateObject private var supabase = SupabaseClient.shared
    @State private var resetAlert = false
    @State private var showWeightTrend = false
    @State private var showCSVShare = false
    @State private var csvFileURL: URL?
    @State private var showLogin = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: 0xEEF6FB).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if SupabaseConfig.enabled {
                            cloudSyncCard
                        }
                        waterCard
                        mealCard
                        reminderCard
                        HistoryChart(title: "最近 7 天喝水", kind: .water)
                        HistoryChart(title: "最近 7 天体重", kind: .weight)
                        calorieSummaryCard
                        MealReview()
                        exportCard
                        Text("提示：少量多次饮用，喝到不口渴即可；饮食记录仅用于自我观察，注意均衡摄入，不要过度节食。如持续头晕、心慌、乏力，请及时进食休息，必要时就医。")
                            .font(.caption).foregroundColor(.secondary).lineSpacing(5).padding(.horizontal, 4)
                    }.padding()
                }
            }.navigationBarHidden(true)
        }.navigationViewStyle(.stack)
        .sheet(isPresented: $showWeightTrend) {
            WeightTrendView()
        }
        .sheet(isPresented: $showCSVShare) {
            if let url = csvFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    // MARK: - 顶部标题

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.blue)
                Image(systemName: "drop.fill").foregroundColor(.white).font(.title2)
            }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text("打卡助手").font(.title2.bold())
                Text("喝水 · 饮食 · 体重记录").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            // 登录状态指示
            if SupabaseConfig.enabled {
                Button { showLogin = true } label: {
                    Image(systemName: supabase.isAuthenticated ? "checkmark.circle.fill" : "person.circle")
                        .foregroundColor(supabase.isAuthenticated ? .green : .secondary)
                        .font(.title3)
                }
            }
        }
    }

    // MARK: - 云同步卡片

    private var cloudSyncCard: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(supabase.isAuthenticated ? .blue : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.isAuthenticated ? "已登录" : "未登录")
                            .font(.headline)
                        if let email = supabase.userEmail {
                            Text(email).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if supabase.isAuthenticated {
                        if let last = store.lastSyncTime {
                            Text("同步于 \(last.formatted(.dateTime.hour().minute()))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                if supabase.isAuthenticated {
                    Button {
                        Task { await store.syncAll() }
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(.borderedProminent).tint(Color(hex: 0x2F9BE0))
                }
            }
        }
    }

    // MARK: - 喝水卡片

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

    // MARK: - 餐食卡片（含热量和照片）

    private var mealCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("今日饮食记录", systemImage: "fork.knife").font(.headline)
                    Spacer()
                    if store.todayCalories > 0 {
                        Text("\(store.todayCalories) kcal").font(.caption.weight(.semibold)).foregroundColor(Color(hex: 0xE8730C))
                    }
                }
                MealField("早餐", "吃了什么…", value: Binding(get: { store.todayMeal.breakfast }, set: { store.updateMeal(\.breakfast, value: $0) }))
                CalorieField("早餐热量", value: Binding(get: { store.todayMeal.breakfastCalories }, set: { store.updateMealCalories(\.breakfastCalories, value: $0) }))
                MealField("午餐", "吃了什么…", value: Binding(get: { store.todayMeal.lunch }, set: { store.updateMeal(\.lunch, value: $0) }))
                CalorieField("午餐热量", value: Binding(get: { store.todayMeal.lunchCalories }, set: { store.updateMealCalories(\.lunchCalories, value: $0) }))
                MealField("晚餐", "吃了什么…", value: Binding(get: { store.todayMeal.dinner }, set: { store.updateMeal(\.dinner, value: $0) }))
                CalorieField("晚餐热量", value: Binding(get: { store.todayMeal.dinnerCalories }, set: { store.updateMealCalories(\.dinnerCalories, value: $0) }))
                MealField("加餐", "水果、零食、饮料…", value: Binding(get: { store.todayMeal.snack }, set: { store.updateMeal(\.snack, value: $0) }))
                CalorieField("加餐热量", value: Binding(get: { store.todayMeal.snackCalories }, set: { store.updateMealCalories(\.snackCalories, value: $0) }))

                Divider()
                HStack { Text("晨起体重").font(.subheadline).foregroundColor(.secondary); TextField("如 96.1", text: Binding(get: { store.todayMeal.weight }, set: { store.updateMeal(\.weight, value: normalizedWeight($0)) })).keyboardType(.decimalPad).textFieldStyle(.roundedBorder); Text("斤").foregroundColor(.secondary) }
            }
        }
    }

    // MARK: - 热量概览卡片

    private var calorieSummaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("近 7 天热量", systemImage: "flame.fill").font(.headline).foregroundColor(Color(hex: 0xE8730C))
                HStack(spacing: 16) {
                    ForEach(store.calorieTrend(), id: \.0) { date, cal in
                        VStack(spacing: 4) {
                            Text(cal > 0 ? "\(cal)" : "--").font(.system(size: 12, weight: .medium)).foregroundColor(cal > 0 ? .primary : .secondary)
                            Text(date, format: .dateTime.month(.twoDigits).day(.twoDigits)).font(.system(size: 9)).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - 提醒卡片

    private var reminderCard: some View {
        Card { VStack(spacing: 14) { Toggle(isOn: Binding(get: { store.remindOn }, set: { store.setReminder($0) })) { Label("定时提醒", systemImage: "bell") }; Divider(); Stepper("每 \(store.remindInterval) 分钟", value: $store.remindInterval, in: 15...120) } }
    }

    // MARK: - 导出卡片

    private var exportCard: some View {
        Card {
            VStack(spacing: 12) {
                Label("数据导出", systemImage: "square.and.arrow.up").font(.headline)
                Text("导出喝水、体重、餐食、热量记录为 CSV 文件")
                    .font(.caption).foregroundColor(.secondary)
                Button {
                    csvFileURL = store.exportCSVFile()
                    if csvFileURL != nil { showCSVShare = true }
                } label: {
                    Label("导出 CSV", systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }.buttonStyle(.borderedProminent).tint(Color(hex: 0x38B27A))
            }
        }
    }

    private func normalizedWeight(_ text: String) -> String {
        let valid = text.filter { $0.isNumber || $0 == "." }; let parts = valid.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return valid }
        return String(parts[0]) + "." + String(parts[1].prefix(1))
    }
}

// MARK: - 餐食输入栏（文本）

private struct MealField: View {
    let label: String, placeholder: String; @Binding var value: String
    init(_ label: String, _ placeholder: String, value: Binding<String>) { self.label = label; self.placeholder = placeholder; _value = value }
    var body: some View { HStack(alignment: .top) { Text(label).font(.subheadline).foregroundColor(.secondary).frame(width: 54, alignment: .leading); TextField(placeholder, text: $value).textFieldStyle(.roundedBorder) } }
}

// MARK: - 热量输入栏

private struct CalorieField: View {
    let label: String; @Binding var value: Int?
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary).frame(width: 54, alignment: .leading)
            TextField("kcal", value: $value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Text("kcal").font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - 分享 Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 登录视图

struct LoginView: View {
    @StateObject private var supabase = SupabaseClient.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "drop.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                Text("打卡助手")
                    .font(.title.bold())
                Text("登录后可在多设备间同步数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                if supabase.isAuthenticated {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        if let email = supabase.userEmail {
                            Text(email).font(.subheadline).foregroundColor(.secondary)
                        }
                        Button(role: .destructive) {
                            supabase.signOut()
                            dismiss()
                        } label: {
                            Label("退出登录", systemImage: "arrow.right.square")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered)
                    }
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                }
                Spacer()
            }.padding()
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("关闭") { dismiss() } }
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let authCode = credential.authorizationCode else { return }
            Task {
                do {
                    try await supabase.signInWithApple(identityToken: identityToken, authorizationCode: authCode)
                    await MainActor.run { dismiss() }
                } catch {
                    // 错误处理：静默失败，用户可重试
                }
            }
        case .failure:
            break
        }
    }
}

// MARK: - 卡片容器和颜色扩展

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(18).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.blue.opacity(0.08), radius: 10, y: 4) }
}

extension Color { init(hex: UInt) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) } }
