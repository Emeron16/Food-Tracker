//
//  MealTimeSettings.swift
//  FreshTrack
//

import Foundation
import Combine

/// UserDefaults-backed store for the user's meal time preferences.
/// Each meal has a time (stored as hour + minute) and an enabled toggle.
final class MealTimeSettings: ObservableObject {
    static let shared = MealTimeSettings()

    // MARK: - Keys

    private enum Keys {
        static let breakfastEnabled = "mealTime.breakfast.enabled"
        static let breakfastHour    = "mealTime.breakfast.hour"
        static let breakfastMinute  = "mealTime.breakfast.minute"

        static let lunchEnabled     = "mealTime.lunch.enabled"
        static let lunchHour        = "mealTime.lunch.hour"
        static let lunchMinute      = "mealTime.lunch.minute"

        static let dinnerEnabled    = "mealTime.dinner.enabled"
        static let dinnerHour       = "mealTime.dinner.hour"
        static let dinnerMinute     = "mealTime.dinner.minute"

        static let onboardingComplete = "onboarding.complete"
    }

    // MARK: - Published Properties

    @Published var breakfastEnabled: Bool {
        didSet { UserDefaults.standard.set(breakfastEnabled, forKey: Keys.breakfastEnabled) }
    }
    @Published var breakfastTime: Date {
        didSet { saveTime(breakfastTime, hourKey: Keys.breakfastHour, minuteKey: Keys.breakfastMinute) }
    }

    @Published var lunchEnabled: Bool {
        didSet { UserDefaults.standard.set(lunchEnabled, forKey: Keys.lunchEnabled) }
    }
    @Published var lunchTime: Date {
        didSet { saveTime(lunchTime, hourKey: Keys.lunchHour, minuteKey: Keys.lunchMinute) }
    }

    @Published var dinnerEnabled: Bool {
        didSet { UserDefaults.standard.set(dinnerEnabled, forKey: Keys.dinnerEnabled) }
    }
    @Published var dinnerTime: Date {
        didSet { saveTime(dinnerTime, hourKey: Keys.dinnerHour, minuteKey: Keys.dinnerMinute) }
    }

    @Published var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: Keys.onboardingComplete) }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Defaults: breakfast 8am, lunch 12pm, dinner 7pm — all enabled
        self.breakfastEnabled = defaults.object(forKey: Keys.breakfastEnabled) as? Bool ?? true
        self.breakfastTime    = MealTimeSettings.loadTime(hourKey: Keys.breakfastHour, minuteKey: Keys.breakfastMinute, defaultHour: 8, defaultMinute: 0)

        self.lunchEnabled     = defaults.object(forKey: Keys.lunchEnabled) as? Bool ?? true
        self.lunchTime        = MealTimeSettings.loadTime(hourKey: Keys.lunchHour, minuteKey: Keys.lunchMinute, defaultHour: 12, defaultMinute: 0)

        self.dinnerEnabled    = defaults.object(forKey: Keys.dinnerEnabled) as? Bool ?? true
        self.dinnerTime       = MealTimeSettings.loadTime(hourKey: Keys.dinnerHour, minuteKey: Keys.dinnerMinute, defaultHour: 19, defaultMinute: 0)

        self.onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
    }

    // MARK: - Computed: active meal times as (hour, minute) tuples

    var activeMealTimes: [(hour: Int, minute: Int, label: String)] {
        var times: [(hour: Int, minute: Int, label: String)] = []
        let cal = Calendar.current
        if breakfastEnabled {
            times.append((cal.component(.hour, from: breakfastTime),
                          cal.component(.minute, from: breakfastTime), "breakfast"))
        }
        if lunchEnabled {
            times.append((cal.component(.hour, from: lunchTime),
                          cal.component(.minute, from: lunchTime), "lunch"))
        }
        if dinnerEnabled {
            times.append((cal.component(.hour, from: dinnerTime),
                          cal.component(.minute, from: dinnerTime), "dinner"))
        }
        return times
    }

    // MARK: - Helpers

    private func saveTime(_ date: Date, hourKey: String, minuteKey: String) {
        let cal = Calendar.current
        UserDefaults.standard.set(cal.component(.hour, from: date), forKey: hourKey)
        UserDefaults.standard.set(cal.component(.minute, from: date), forKey: minuteKey)
    }

    private static func loadTime(hourKey: String, minuteKey: String, defaultHour: Int, defaultMinute: Int) -> Date {
        let defaults = UserDefaults.standard
        let hour   = defaults.object(forKey: hourKey)   as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? defaultMinute
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour   = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
