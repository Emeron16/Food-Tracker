//
//  OnboardingView.swift
//  FreshTrack
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var mealSettings = MealTimeSettings.shared
    @StateObject private var notificationService = ExpirationNotificationService.shared
    @State private var currentStep = 0

    var body: some View {
        TabView(selection: $currentStep) {
            WelcomeStep(onNext: { currentStep = 1 })
                .tag(0)
            MealTimesStep(onNext: { currentStep = 2 })
                .tag(1)
            PermissionsStep(onComplete: completeOnboarding)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: currentStep)
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        MealTimeSettings.shared.onboardingComplete = true
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("Welcome to FreshTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Track your groceries, reduce food waste, and discover recipes using what you already have.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                featureRow(icon: "barcode.viewfinder", color: .blue, title: "Scan barcodes", subtitle: "Quickly add items with your camera")
                featureRow(icon: "brain", color: .purple, title: "Smart predictions", subtitle: "ML-powered expiration date estimates")
                featureRow(icon: "fork.knife", color: .orange, title: "Recipe suggestions", subtitle: "Cook with what's expiring soon")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Step 2: Meal Times

private struct MealTimesStep: View {
    @StateObject private var mealSettings = MealTimeSettings.shared
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Meal Reminders")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Set your meal times and FreshTrack will remind you about expiring items at the right moment.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 0) {
                mealRow(
                    icon: "sunrise.fill",
                    color: .orange,
                    label: "Breakfast",
                    enabled: $mealSettings.breakfastEnabled,
                    time: $mealSettings.breakfastTime
                )
                Divider().padding(.leading, 56)
                mealRow(
                    icon: "sun.max.fill",
                    color: .yellow,
                    label: "Lunch",
                    enabled: $mealSettings.lunchEnabled,
                    time: $mealSettings.lunchTime
                )
                Divider().padding(.leading, 56)
                mealRow(
                    icon: "moon.stars.fill",
                    color: .indigo,
                    label: "Dinner",
                    enabled: $mealSettings.dinnerEnabled,
                    time: $mealSettings.dinnerTime
                )
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onNext) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func mealRow(icon: String, color: Color, label: String, enabled: Binding<Bool>, time: Binding<Date>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            Toggle(label, isOn: enabled)
                .tint(color)

            if enabled.wrappedValue {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Step 3: Permissions

private struct PermissionsStep: View {
    @StateObject private var notificationService = ExpirationNotificationService.shared
    let onComplete: () -> Void
    @State private var didRequestNotifications = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text("Almost Done")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("FreshTrack needs a couple of permissions to work its best.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                permissionRow(
                    icon: "bell.badge",
                    color: .orange,
                    title: "Notifications",
                    subtitle: "Get meal-time reminders about expiring items",
                    granted: notificationService.isAuthorized,
                    action: {
                        Task {
                            await notificationService.requestAuthorization()
                            didRequestNotifications = true
                        }
                    }
                )

                permissionRow(
                    icon: "camera",
                    color: .blue,
                    title: "Camera",
                    subtitle: "Scan barcodes to quickly add groceries",
                    granted: nil,   // camera permission requested when scanner opens
                    action: nil
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onComplete) {
                Text("Start Tracking")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .task {
            await notificationService.checkAuthorizationStatus()
        }
    }

    private func permissionRow(icon: String, color: Color, title: String, subtitle: String, granted: Bool?, action: (() -> Void)?) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if let granted = granted {
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if let action = action {
                    Button("Allow", action: action)
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            } else {
                Text("On Demand")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    OnboardingView()
}
