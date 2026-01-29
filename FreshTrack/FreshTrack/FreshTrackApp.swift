//
//  FreshTrackApp.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FreshTrackApp: App {
    private var notificationService: ExpirationNotificationService { ExpirationNotificationService.shared }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Grocery.self,
            SavedRecipe.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await setupNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: .groceriesDidChange)) { _ in
                    Task {
                        await refreshNotifications()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func setupNotifications() async {
        // Setup notification categories
        notificationService.setupNotificationCategories()

        // Check current authorization
        await notificationService.checkAuthorizationStatus()

        // Request authorization if not determined
        if notificationService.authorizationStatus == .notDetermined {
            _ = await notificationService.requestAuthorization()
        }

        // Schedule notifications for existing groceries
        await refreshNotifications()
    }

    @MainActor
    private func refreshNotifications() async {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Grocery>(
            predicate: #Predicate<Grocery> { !$0.isConsumed }
        )

        do {
            let groceries = try context.fetch(descriptor)
            await notificationService.scheduleExpirationNotifications(for: groceries)
        } catch {
            print("Failed to fetch groceries for notifications: \(error)")
        }
    }
}

// MARK: - Notification for Grocery Changes

extension Notification.Name {
    static let groceriesDidChange = Notification.Name("groceriesDidChange")
}
