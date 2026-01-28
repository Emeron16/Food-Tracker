import SwiftUI
import SwiftData

@main
struct FreshTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(DataContainer.shared)
    }
}

/// Root content view with tab navigation
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            PantryView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator.fill")
                }
                .tag(1)

            ScannerPlaceholderView()
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(2)

            RecipesPlaceholderView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }
                .tag(3)

            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
    }
}

// MARK: - Placeholder Views for Future Implementation

struct ScannerPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                Text("Scanner")
                    .font(.title)
                Text("Barcode scanning coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Scan")
        }
    }
}

struct RecipesPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                Text("Recipes")
                    .font(.title)
                Text("Recipe recommendations coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Recipes")
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gear")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.title)
                Text("App settings coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(DataContainer.preview)
}
