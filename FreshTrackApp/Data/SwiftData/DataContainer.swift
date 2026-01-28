import Foundation
import SwiftData

/// Manages the SwiftData ModelContainer configuration
@MainActor
final class DataContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            GroceryItemEntity.self,
            UserPreferencesEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
            // CloudKit integration can be added later:
            // cloudKitDatabase: .private("iCloud.com.yourcompany.FreshTrack")
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// Creates an in-memory container for previews and testing
    static var preview: ModelContainer = {
        let schema = Schema([
            GroceryItemEntity.self,
            UserPreferencesEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Insert sample data
            let context = container.mainContext

            for item in GroceryItem.sampleItems {
                let entity = GroceryItemEntity.from(item)
                context.insert(entity)
            }

            let preferences = UserPreferencesEntity()
            preferences.hasCompletedOnboarding = true
            context.insert(preferences)

            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()
}
