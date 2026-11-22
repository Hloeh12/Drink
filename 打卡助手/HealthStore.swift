import Foundation
import UserNotifications
import SwiftUI

struct DayMeal: Codable {
    var breakfast = ""
    var lunch = ""
    var dinner = ""
    var snack = ""
    var weight = ""
}

@MainActor
final class HealthStore: ObservableObject {
    @Published private(set) var water: [String: Int] = [:]
    @Published private(set) var meals: [String: DayMeal] = [:]
    @Published var goal: Int = 1500 {
        didSet {
            let clamped = min(3000, max(800, goal))
            if goal != clamped { goal = clamped }
            defaults.set(clamped, forKey: "water_goal")
        }
    }
    @Published var remindOn = false { didSet { defaults.set(remindOn, forKey: "remind_on") } }
    @Published var remindInterval = 40 {
        didSet {
            let clamped = min(120, max(15, remindInterval))
            if remindInterval != clamped { remindInterval = clamped }
            defaults.set(clamped, forKey: "remind_interval")
            if remindOn { updateNotifications() }
        }
    }
    @Published var selectedCup = 200 { didSet { defaults.set(selectedCup, forKey: "water_cup") } }

    private let defaults = UserDefaults.standard
    private let waterKey = "water_record_v1"
    private let mealKey = "meal_record_v1"
    private let center = UNUserNotificationCenter.current()

    init() {
        water = defaults.dictionary(forKey: waterKey) as? [String: Int] ?? [:]
        if let raw = defaults.data(forKey: mealKey), let decoded = try? JSONDecoder().decode([String: DayMeal].self, from: raw) { meals = decoded }
        goal = min(3000, max(800, defaults.object(forKey: "water_goal") as? Int ?? 1500))
        remindOn = defaults.bool(forKey: "remind_on")
        remindInterval = min(120, max(15, defaults.object(forKey: "remind_interval") as? Int ?? 40))
        let savedCup = defaults.object(forKey: "water_cup") as? Int ?? 200
        selectedCup = [150, 200, 250, 300].contains(savedCup) ? savedCup : 200
        if remindOn { updateNotifications() }
    }

    var todayKey: String { Self.key(for: Date()) }
    var todayWater: Int { water[todayKey, default: 0] }
    var todayMeal: DayMeal { meals[todayKey] ?? DayMeal() }
    var percent: Int { min(100, Int((Double(todayWater) / Double(max(goal, 1)) * 100).rounded())) }

    static func key(for date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func setWater(_ amount: Int) {
        water[todayKey] = max(0, amount); defaults.set(water, forKey: waterKey); objectWillChange.send()
    }
    func updateMeal(_ field: WritableKeyPath<DayMeal, String>, value: String) {
        var meal = todayMeal; meal[keyPath: field] = value; meals[todayKey] = meal
        if let data = try? JSONEncoder().encode(meals) { defaults.set(data, forKey: mealKey) }
        objectWillChange.send()
    }
    func dates() -> [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 6, to: Calendar.current.startOfDay(for: Date())) } }
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
}
