//
//  FreshTrackApp.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/26/26.
//

import SwiftUI
import SwiftData

@main
struct FreshTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Grocery.self,
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
        }
        .modelContainer(sharedModelContainer)
    }
}
