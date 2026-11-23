import Foundation
import UserNotifications
import SwiftUI
import AuthenticationServices

// MARK: - 数据模型

struct DayMeal: Codable {
    var breakfast = ""
    var lunch = ""
    var dinner = ""
    var snack = ""
    var weight = ""
    var breakfastCalories: Int? = nil
    var lunchCalories: Int? = nil
    var dinnerCalories: Int? = nil
    var snackCalories: Int? = nil
    var breakfastPhoto: String? = nil  // Supabase Storage URL
    var lunchPhoto: String? = nil
    var dinnerPhoto: String? = nil
    var snackPhoto: String? = nil

    var totalCalories: Int {
        (breakfastCalories ?? 0) + (lunchCalories ?? 0) + (dinnerCalories ?? 0) + (snackCalories ?? 0)
    }
}

// MARK: - 体重记录（独立于餐食，支持多条趋势）

struct WeightRecord: Codable, Identifiable {
    var id = UUID()
    var date: String  // yyyy-MM-dd
    var weight: Double  // 斤
}

@MainActor
final class HealthStore: ObservableObject {
    // 水量记录
    @Published private(set) var water: [String: Int] = [:]
    // 餐食记录
    @Published private(set) var meals: [String: DayMeal] = [:]
    // 体重记录（独立存储，支持历史趋势）
    @Published private(set) var weights: [WeightRecord] = []

    @Published var goal: Int = 1500 {
        didSet {
            let clamped = min(3000, max(800, goal))
            if goal != clamped { goal = clamped }
            defaults.set(clamped, forKey: "water_goal")
            syncSetting("water_goal", value: String(clamped))
        }
    }
    @Published var remindOn = false {
        didSet {
            defaults.set(remindOn, forKey: "remind_on")
            syncSetting("remind_on", value: String(remindOn))
        }
    }
    @Published var remindInterval = 40 {
        didSet {
            let clamped = min(120, max(15, remindInterval))
            if remindInterval != clamped { remindInterval = clamped }
            defaults.set(clamped, forKey: "remind_interval")
            syncSetting("remind_interval", value: String(clamped))
            if remindOn { updateNotifications() }
        }
    }
    @Published var selectedCup = 200 { didSet { defaults.set(selectedCup, forKey: "water_cup") } }

    // 云同步状态
    @Published var cloudSyncEnabled = false
    @Published var lastSyncTime: Date?

    private let defaults = UserDefaults.standard
    private let waterKey = "water_record_v1"
    private let mealKey = "meal_record_v1"
    private let weightsKey = "weights_record_v1"
    private let center = UNUserNotificationCenter.current()

    init() {
        loadFromLocal()
        if remindOn { updateNotifications() }
    }

    // MARK: - 本地加载

    private func loadFromLocal() {
        water = defaults.dictionary(forKey: waterKey) as? [String: Int] ?? [:]
        if let raw = defaults.data(forKey: mealKey), let decoded = try? JSONDecoder().decode([String: DayMeal].self, from: raw) {
            meals = decoded
        }
        if let raw = defaults.data(forKey: weightsKey), let decoded = try? JSONDecoder().decode([WeightRecord].self, from: raw) {
            weights = decoded
        }
        goal = min(3000, max(800, defaults.object(forKey: "water_goal") as? Int ?? 1500))
        remindOn = defaults.bool(forKey: "remind_on")
        remindInterval = min(120, max(15, defaults.object(forKey: "remind_interval") as? Int ?? 40))
        let savedCup = defaults.object(forKey: "water_cup") as? Int ?? 200
        selectedCup = [150, 200, 250, 300].contains(savedCup) ? savedCup : 200
    }

    // MARK: - 便捷属性

    var todayKey: String { Self.key(for: Date()) }
    var todayWater: Int { water[todayKey, default: 0] }

    /// 指定日期的饮水量
    func waterFor(_ date: Date) -> Int {
        water[Self.key(for: date), default: 0]
    }

    /// 指定日期是否有任何记录
    func hasRecord(_ date: Date) -> Bool {
        let key = Self.key(for: date)
        if water[key, default: 0] > 0 { return true }
        if let meal = meals[key] {
            let texts = [meal.breakfast, meal.lunch, meal.dinner, meal.snack]
            if texts.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return true }
            if !meal.weight.isEmpty { return true }
        }
        return false
    }
    func mealFor(_ date: Date) -> DayMeal { meals[Self.key(for: date)] ?? DayMeal() }

    /// 指定日期相对目标的完成百分比
    func percentFor(_ date: Date) -> Int {
        let w = waterFor(date)
        return min(100, Int((Double(w) / Double(max(goal, 1)) * 100).rounded()))
    }

    var todayMeal: DayMeal { meals[todayKey] ?? DayMeal() }
    var todayWeight: Double? {
        weights.last(where: { $0.date == todayKey })?.weight
    }
    var todayCalories: Int { todayMeal.totalCalories }
    var percent: Int { min(100, Int((Double(todayWater) / Double(max(goal, 1)) * 100).rounded())) }

    static func key(for date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - 喝水操作

    func setWater(_ amount: Int) {
        water[todayKey] = max(0, amount)
        defaults.set(water, forKey: waterKey)
        objectWillChange.send()
        syncWater(amount)
    }

    // MARK: - 餐食操作

    func updateMeal(_ field: WritableKeyPath<DayMeal, String>, value: String) {
        var meal = todayMeal; meal[keyPath: field] = value; meals[todayKey] = meal
        saveMeals()
        syncMeal(meal)
    }

    func updateMealCalories(_ field: WritableKeyPath<DayMeal, Int?>, value: Int?) {
        var meal = todayMeal; meal[keyPath: field] = value; meals[todayKey] = meal
        saveMeals()
        syncMeal(meal)
    }

    func updateMealPhoto(_ field: WritableKeyPath<DayMeal, String?>, value: String?) {
        var meal = todayMeal; meal[keyPath: field] = value; meals[todayKey] = meal
        saveMeals()
        syncMeal(meal)
    }

    private func saveMeals() {
        if let data = try? JSONEncoder().encode(meals) { defaults.set(data, forKey: mealKey) }
        objectWillChange.send()
    }

    // MARK: - 体重操作

    func setWeight(_ value: Double) {
        let key = todayKey
        if let idx = weights.firstIndex(where: { $0.date == key }) {
            weights[idx].weight = value
        } else {
            weights.append(WeightRecord(date: key, weight: value))
        }
        weights.sort { $0.date < $1.date }
        saveWeights()
        // 同步到餐食记录（保持兼容）
        var meal = todayMeal; meal.weight = String(format: "%.1f", value); meals[todayKey] = meal
        saveMeals()
        syncWeight(value)
    }

    func weightForDate(_ date: Date) -> Double? {
        let key = Self.key(for: date)
        return weights.last(where: { $0.date == key })?.weight
    }

    /// 近 N 天体重趋势
    func weightTrend(days: Int = 7) -> [(Date, Double?)] {
        (0..<days).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            return (date, weightForDate(date))
        }
    }

    /// 体重变化（最新 vs 最早，在有记录的范围内）
    var weightChange: Double? {
        let recent = weights.suffix(7)
        guard let first = recent.first, let last = recent.last, first.date != last.date else { return nil }
        return last.weight - first.weight
    }

    private func saveWeights() {
        if let data = try? JSONEncoder().encode(weights) { defaults.set(data, forKey: weightsKey) }
        objectWillChange.send()
    }

    // MARK: - 热量统计

    func caloriesForDate(_ date: Date) -> Int {
        let key = Self.key(for: date)
        return meals[key]?.totalCalories ?? 0
    }

    /// 近 N 天热量趋势
    func calorieTrend(days: Int = 7) -> [(Date, Int)] {
        (0..<days).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            return (date, caloriesForDate(date))
        }
    }

    // MARK: - CSV 导出

    /// 导出全部数据为 CSV 字符串
    func exportCSV() -> String {
        var csv = ""

        // 喝水记录
        csv += "类型,日期,数值\n"
        for (date, amount) in water.sorted(by: { $0.key < $1.key }) {
            csv += "饮水,\(date),\(amount)ml\n"
        }

        // 体重记录
        csv += "\n类型,日期,数值\n"
        for w in weights {
            csv += "体重,\(w.date),\(String(format: "%.1f", w.weight))斤\n"
        }

        // 餐食记录
        csv += "\n日期,早餐,早餐热量,午餐,午餐热量,晚餐,晚餐热量,加餐,加餐热量,体重,总热量\n"
        for (date, meal) in meals.sorted(by: { $0.key < $1.key }) {
            csv += "\(date),\(meal.breakfast),\(meal.breakfastCalories ?? 0),\(meal.lunch),\(meal.lunchCalories ?? 0),\(meal.dinner),\(meal.dinnerCalories ?? 0),\(meal.snack),\(meal.snackCalories ?? 0),\(meal.weight),\(meal.totalCalories)\n"
        }

        return csv
    }

    /// 导出 CSV 并返回文件 URL（用于分享）
    func exportCSVFile() -> URL? {
        let csv = exportCSV()
        let fileName = "打卡助手_数据导出_\(Self.key(for: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // 写入 UTF-8 BOM 以便 Excel 正确识别中文
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(csv.utf8))

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - 日期工具

    func dates() -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 6, to: Calendar.current.startOfDay(for: Date())) }
    }

    // MARK: - 提醒

    func setReminder(_ enabled: Bool) {
        remindOn = enabled
        guard enabled else { center.removePendingNotificationRequests(withIdentifiers: ["water-reminder"]); return }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async { if granted { self?.scheduleReminder() } else { self?.remindOn = false } }
        }
    }
    private func updateNotifications() { if remindOn { scheduleReminder() } }
    private func scheduleReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["water-reminder"])
        let content = UNMutableNotificationContent(); content.title = "打卡助手"; content.body = "该喝一杯水啦，少量多次，慢慢喝。"; content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(15, remindInterval) * 60), repeats: true)
        center.add(UNNotificationRequest(identifier: "water-reminder", content: content, trigger: trigger))
    }

    // MARK: - Supabase 云同步

    /// 触发全量同步（上传本地数据到云端）
    func syncAll() async {
        guard SupabaseConfig.enabled, SupabaseClient.shared.isAuthenticated else { return }
        cloudSyncEnabled = true

        // 同步水量
        for (date, amount) in water {
            try? await SupabaseClient.shared.upsert(table: "water_intake", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": date,
                "amount_ml": amount
            ])
        }

        // 同步体重
        for w in weights {
            try? await SupabaseClient.shared.upsert(table: "weights", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": w.date,
                "weight": w.weight
            ])
        }

        // 同步餐食
        for (date, meal) in meals {
            try? await SupabaseClient.shared.upsert(table: "meals", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": date,
                "breakfast": meal.breakfast,
                "lunch": meal.lunch,
                "dinner": meal.dinner,
                "snack": meal.snack,
                "calories": meal.totalCalories,
                "photo_url": meal.breakfastPhoto ?? meal.lunchPhoto ?? meal.dinnerPhoto ?? meal.snackPhoto ?? ""
            ])
        }

        lastSyncTime = Date()
        objectWillChange.send()
    }

    private func syncWater(_ amount: Int) {
        guard SupabaseConfig.enabled, SupabaseClient.shared.isAuthenticated else { return }
        Task {
            try? await SupabaseClient.shared.upsert(table: "water_intake", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": todayKey,
                "amount_ml": amount
            ])
        }
    }

    private func syncMeal(_ meal: DayMeal) {
        guard SupabaseConfig.enabled, SupabaseClient.shared.isAuthenticated else { return }
        Task {
            try? await SupabaseClient.shared.upsert(table: "meals", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": todayKey,
                "breakfast": meal.breakfast,
                "lunch": meal.lunch,
                "dinner": meal.dinner,
                "snack": meal.snack,
                "calories": meal.totalCalories,
                "photo_url": meal.breakfastPhoto ?? meal.lunchPhoto ?? meal.dinnerPhoto ?? meal.snackPhoto ?? ""
            ])
        }
    }

    private func syncWeight(_ value: Double) {
        guard SupabaseConfig.enabled, SupabaseClient.shared.isAuthenticated else { return }
        Task {
            try? await SupabaseClient.shared.upsert(table: "weights", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "date": todayKey,
                "weight": value
            ])
        }
    }

    private func syncSetting(_ key: String, value: String) {
        guard SupabaseConfig.enabled, SupabaseClient.shared.isAuthenticated else { return }
        Task {
            try? await SupabaseClient.shared.upsert(table: "user_settings", record: [
                "user_id": SupabaseClient.shared.userId ?? "",
                "key": key,
                "value": value
            ])
        }
    }
}
