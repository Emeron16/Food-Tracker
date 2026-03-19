//
//  ExpirationNotificationService.swift
//  FreshTrack
//
//  Created by Claude on 1/28/26.
//

import Foundation
import UserNotifications
import SwiftData
import Combine

/// Service for scheduling and managing expiration notifications.
class ExpirationNotificationService: ObservableObject {
    @MainActor static let shared = ExpirationNotificationService()

    @MainActor @Published var isAuthorized = false
    @MainActor @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()

    @MainActor private init() {}

    // MARK: - Authorization

    /// Request notification permissions from the user.
    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status.
    @MainActor
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        self.isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Notifications

    /// Schedule notifications for all groceries based on their expiration dates.
    /// Fires at each of the user's enabled meal times (from MealTimeSettings).
    @MainActor
    func scheduleExpirationNotifications(for groceries: [Grocery]) async {
        await removeAllExpirationNotifications()

        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }

        let mealTimes = MealTimeSettings.shared.activeMealTimes

        // Fall back to 9am if user has disabled all meal times
        let effectiveMealTimes = mealTimes.isEmpty
            ? [(hour: 9, minute: 0, label: "morning")]
            : mealTimes

        for grocery in groceries {
            guard !grocery.isConsumed else { continue }
            let expirationDate = grocery.expirationDate ?? grocery.predictedExpirationDate
            guard let expDate = expirationDate else { continue }

            for days in [3, 1, 0] {
                for meal in effectiveMealTimes {
                    await scheduleNotification(
                        for: grocery,
                        daysBeforeExpiration: days,
                        expirationDate: expDate,
                        hour: meal.hour,
                        minute: meal.minute,
                        mealLabel: meal.label
                    )
                }
            }
        }
    }

    /// Schedule a single notification for a grocery item at a specific meal time.
    private func scheduleNotification(
        for grocery: Grocery,
        daysBeforeExpiration: Int,
        expirationDate: Date,
        hour: Int,
        minute: Int,
        mealLabel: String
    ) async {
        let notificationDate = Calendar.current.date(byAdding: .day, value: -daysBeforeExpiration, to: expirationDate)!

        guard notificationDate > Date() else { return }

        let groceryIdentifier = grocery.notificationIdentifier
        let identifier = "\(groceryIdentifier)-\(daysBeforeExpiration)-\(mealLabel)"

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch daysBeforeExpiration {
        case 0:
            content.title = "\(grocery.name) expires today!"
            content.body = getExpirationMessage(for: grocery, urgency: .today)
        case 1:
            content.title = "\(grocery.name) expires tomorrow"
            content.body = getExpirationMessage(for: grocery, urgency: .tomorrow)
        default:
            content.title = "\(grocery.name) expiring soon"
            content.body = getExpirationMessage(for: grocery, urgency: .soon)
        }

        content.categoryIdentifier = "EXPIRATION_REMINDER"
        content.userInfo = [
            "groceryIdentifier": groceryIdentifier,
            "groceryName": grocery.name,
            "category": grocery.category.rawValue
        ]

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour   = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Notification Messages

    private enum Urgency {
        case today, tomorrow, soon
    }

    /// Generate a notification message based on the grocery category and urgency.
    private func getExpirationMessage(for grocery: Grocery, urgency: Urgency) -> String {
        let categoryMessages = getCategoryMessage(for: grocery.category, urgency: urgency)
        return categoryMessages
    }

    private func getCategoryMessage(for category: FoodCategory, urgency: Urgency) -> String {
        switch category {
        case .dairy:
            switch urgency {
            case .today:
                return "Use it in scrambled eggs, smoothies, or baking before it's too late!"
            case .tomorrow:
                return "Perfect time to make a creamy pasta or use in your morning coffee."
            case .soon:
                return "Consider making a quiche, smoothie, or creamy sauce this week."
            }

        case .meat:
            switch urgency {
            case .today:
                return "Cook it today! Try a quick stir-fry or grill it for dinner."
            case .tomorrow:
                return "Plan to cook tomorrow - marinate tonight for extra flavor."
            case .soon:
                return "Time to plan a meal. Consider freezing if you can't use it soon."
            }

        case .seafood:
            switch urgency {
            case .today:
                return "Seafood is best fresh! Make a quick pan-sear or add to pasta."
            case .tomorrow:
                return "Plan a seafood dinner - it's freshest when used quickly."
            case .soon:
                return "Fresh seafood doesn't last long. Cook it or freeze it soon."
            }

        case .produce:
            switch urgency {
            case .today:
                return "Toss into a salad, blend into a smoothie, or roast as a side dish."
            case .tomorrow:
                return "Great for a stir-fry, soup, or fresh salad tomorrow."
            case .soon:
                return "Use in salads, smoothies, or cook into a warm dish this week."
            }

        case .bakery:
            switch urgency {
            case .today:
                return "Make toast, croutons, or breadcrumbs before it goes stale."
            case .tomorrow:
                return "Use for sandwiches or French toast tomorrow morning."
            case .soon:
                return "Freeze what you won't use, or make a bread pudding!"
            }

        case .frozen:
            switch urgency {
            case .today:
                return "Check the quality and use in your next meal."
            case .tomorrow:
                return "Plan to use soon for best taste and texture."
            case .soon:
                return "Still good! But use within the week for best quality."
            }

        case .beverages:
            switch urgency {
            case .today:
                return "Drink up or use in a recipe today!"
            case .tomorrow:
                return "Enjoy it tomorrow - most beverages are best fresh."
            case .soon:
                return "Best enjoyed soon for optimal freshness."
            }

        case .condiments:
            switch urgency {
            case .today:
                return "Add extra flavor to today's meal!"
            case .tomorrow:
                return "Spice up tomorrow's cooking with this."
            case .soon:
                return "Condiments often last longer - check if it still smells and looks good."
            }

        case .snacks:
            switch urgency {
            case .today:
                return "Snack time! Enjoy before they go stale."
            case .tomorrow:
                return "Perfect for a quick bite tomorrow."
            case .soon:
                return "Enjoy as a treat this week."
            }

        case .pantry:
            switch urgency {
            case .today:
                return "Check the quality and use if still good."
            case .tomorrow:
                return "Pantry items often last - verify freshness before using."
            case .soon:
                return "Most pantry items last well, but check the expiration date."
            }

        case .other:
            switch urgency {
            case .today:
                return "Use it today before it expires!"
            case .tomorrow:
                return "Plan to use this tomorrow."
            case .soon:
                return "Remember to use this before it expires."
            }
        }
    }

    // MARK: - Remove Notifications

    /// Remove all expiration-related notifications.
    func removeAllExpirationNotifications() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let expirationIds = pendingRequests
            .filter { $0.content.categoryIdentifier == "EXPIRATION_REMINDER" }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: expirationIds)
    }

    /// Remove notifications for a specific grocery item across all meal times.
    func removeNotifications(for grocery: Grocery) {
        let id = grocery.notificationIdentifier
        let meals = ["breakfast", "lunch", "dinner", "morning"]
        var identifiers: [String] = []
        for days in [0, 1, 3] {
            for meal in meals {
                identifiers.append("\(id)-\(days)-\(meal)")
            }
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Setup Notification Categories

    /// Register notification categories and actions.
    func setupNotificationCategories() {
        let markUsedAction = UNNotificationAction(
            identifier: "MARK_USED",
            title: "Mark as Used",
            options: []
        )

        let viewRecipesAction = UNNotificationAction(
            identifier: "VIEW_RECIPES",
            title: "Find Recipes",
            options: [.foreground]
        )

        let expirationCategory = UNNotificationCategory(
            identifier: "EXPIRATION_REMINDER",
            actions: [markUsedAction, viewRecipesAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([expirationCategory])
    }
}
