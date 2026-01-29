//
//  MainTabView.swift
//  FreshTrack
//
//  Created by Prince Marcelle on 1/27/26.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

#if os(iOS)
            BarcodeScannerView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Scan", systemImage: "barcode.viewfinder")
                }
                .tag(1)
#endif

            PantryView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator.fill")
                }
                .tag(2)

            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
                .tag(3)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, configurations: config)
    
    return MainTabView()
        .modelContainer(container)
}
