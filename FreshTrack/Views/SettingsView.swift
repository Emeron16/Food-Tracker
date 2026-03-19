//
//  SettingsView.swift
//  FreshTrack
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var mealSettings = MealTimeSettings.shared
    @StateObject private var notificationService = ExpirationNotificationService.shared
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Grocery> { !$0.isConsumed }) private var activeGroceries: [Grocery]

    @State private var showingClearConfirmation = false
    @State private var confirmText = ""
    @State private var showingDeletedBanner = false
    @State private var hasUnsavedChanges = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Notifications
                Section {
                    Toggle(isOn: Binding(
                        get: { notificationService.isAuthorized },
                        set: { enabled in
                            if enabled {
                                Task { await notificationService.requestAuthorization() }
                            } else {
#if os(iOS)
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
#endif
                            }
                        }
                    )) {
                        Label("Notifications", systemImage: "bell.badge.fill")
                    }
                    .tint(.orange)
                } header: {
                    Text("Permissions")
                } footer: {
                    Text(notificationService.isAuthorized ? "Notifications are enabled." : "Enable notifications to get expiration reminders. Tap to open Settings.")
                }

                // MARK: - Meal Times
                Section {
                    Toggle(isOn: $mealSettings.breakfastEnabled) {
                        Label("Breakfast", systemImage: "sunrise.fill")
                    }
                    .tint(.orange)
                    .onChange(of: mealSettings.breakfastEnabled) { hasUnsavedChanges = true }

                    if mealSettings.breakfastEnabled {
                        DatePicker("Time", selection: $mealSettings.breakfastTime, displayedComponents: .hourAndMinute)
                            .padding(.leading, 32)
                            .onChange(of: mealSettings.breakfastTime) { hasUnsavedChanges = true }
                    }

                    Toggle(isOn: $mealSettings.lunchEnabled) {
                        Label("Lunch", systemImage: "sun.max.fill")
                    }
                    .tint(.yellow)
                    .onChange(of: mealSettings.lunchEnabled) { hasUnsavedChanges = true }

                    if mealSettings.lunchEnabled {
                        DatePicker("Time", selection: $mealSettings.lunchTime, displayedComponents: .hourAndMinute)
                            .padding(.leading, 32)
                            .onChange(of: mealSettings.lunchTime) { hasUnsavedChanges = true }
                    }

                    Toggle(isOn: $mealSettings.dinnerEnabled) {
                        Label("Dinner", systemImage: "moon.stars.fill")
                    }
                    .tint(.indigo)
                    .onChange(of: mealSettings.dinnerEnabled) { hasUnsavedChanges = true }

                    if mealSettings.dinnerEnabled {
                        DatePicker("Time", selection: $mealSettings.dinnerTime, displayedComponents: .hourAndMinute)
                            .padding(.leading, 32)
                            .onChange(of: mealSettings.dinnerTime) { hasUnsavedChanges = true }
                    }

                    if hasUnsavedChanges {
                        Button {
                            rescheduleNotifications()
                            hasUnsavedChanges = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Apply & Reschedule Notifications")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Text("Meal Notification Times")
                } footer: {
                    Text("FreshTrack will remind you about expiring items at each enabled meal time.")
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: - Data
                Section {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Permanently deletes all groceries, saved recipes, and interaction history.")
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .overlay(alignment: .bottom) {
                if showingDeletedBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text("All data deleted")
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.red, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingDeletedBanner)
            .sheet(isPresented: $showingClearConfirmation, onDismiss: { confirmText = "" }) {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)

                        VStack(spacing: 6) {
                            Text("Clear All Data")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("This will permanently delete all groceries, saved recipes, and interaction history. This cannot be undone.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Type **confirm** to continue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("confirm", text: $confirmText)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
#endif
                        }

                        HStack(spacing: 12) {
                            Button("Cancel") {
                                showingClearConfirmation = false
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                            Button("Delete Everything") {
                                clearAllData()
                                showingClearConfirmation = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingDeletedBanner = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingDeletedBanner = false
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(confirmText.lowercased() == "confirm" ? Color.red : Color.red.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .disabled(confirmText.lowercased() != "confirm")
                        }
                        .fontWeight(.medium)
                    }
                    .padding(24)
                    .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 32)
                }
                .presentationBackground(.clear)
#if os(iOS)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
#endif
            }
        }
    }

    // MARK: - Helpers

    private func rescheduleNotifications() {
        Task {
            await notificationService.scheduleExpirationNotifications(for: activeGroceries)
        }
    }

    private func clearAllData() {
        try? modelContext.delete(model: Grocery.self)
        try? modelContext.delete(model: SavedRecipe.self)
        try? modelContext.delete(model: RecipeInteraction.self)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Grocery.self, SavedRecipe.self, RecipeInteraction.self, configurations: config)
    return SettingsView()
        .modelContainer(container)
}
