import Foundation
import SwiftData

/// SwiftData persistent model for user preferences
@Model
final class UserPreferencesEntity {
    @Attribute(.unique) var id: UUID

    // Dietary preferences stored as JSON strings
    var dietaryRestrictionsJSON: String
    var allergiesJSON: String
    var preferredCuisinesJSON: String

    // User profile
    var cookingSkillLevel: Int // 1-5
    var householdSize: Int

    // Notification settings
    var notificationsEnabled: Bool
    var expirationWarningDays: Int
    var morningReminderEnabled: Bool
    var morningReminderTime: Date?
    var eveningReminderEnabled: Bool
    var eveningReminderTime: Date?

    // Meal time preferences stored as JSON
    var preferredMealTimesJSON: String

    // App settings
    var defaultStorageLocation: String
    var defaultCategory: String
    var hasCompletedOnboarding: Bool

    var updatedAt: Date

    // MARK: - Computed Properties

    var dietaryRestrictions: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(dietaryRestrictionsJSON.utf8))) ?? []
        }
        set {
            dietaryRestrictionsJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    var allergies: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(allergiesJSON.utf8))) ?? []
        }
        set {
            allergiesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    var preferredCuisines: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(preferredCuisinesJSON.utf8))) ?? []
        }
        set {
            preferredCuisinesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "[]"
        }
    }

    var preferredMealTimes: [String: String] {
        get {
            (try? JSONDecoder().decode([String: String].self, from: Data(preferredMealTimesJSON.utf8))) ?? [:]
        }
        set {
            preferredMealTimesJSON = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.dietaryRestrictionsJSON = "[]"
        self.allergiesJSON = "[]"
        self.preferredCuisinesJSON = "[]"
        self.cookingSkillLevel = 3
        self.householdSize = 2
        self.notificationsEnabled = true
        self.expirationWarningDays = 3
        self.morningReminderEnabled = false
        self.morningReminderTime = nil
        self.eveningReminderEnabled = false
        self.eveningReminderTime = nil
        self.preferredMealTimesJSON = "{\"breakfast\": \"08:00\", \"lunch\": \"12:00\", \"dinner\": \"18:00\"}"
        self.defaultStorageLocation = StorageLocation.refrigerator.rawValue
        self.defaultCategory = FoodCategory.other.rawValue
        self.hasCompletedOnboarding = false
        self.updatedAt = Date()
    }
}

// MARK: - Dietary Restrictions Options
enum DietaryRestriction: String, CaseIterable, Identifiable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case kosher = "Kosher"
    case halal = "Halal"
    case pescatarian = "Pescatarian"
    case keto = "Keto"
    case paleo = "Paleo"
    case lowCarb = "Low-Carb"

    var id: String { rawValue }
}

// MARK: - Common Allergens
enum CommonAllergen: String, CaseIterable, Identifiable {
    case peanuts = "Peanuts"
    case treeNuts = "Tree Nuts"
    case milk = "Milk"
    case eggs = "Eggs"
    case wheat = "Wheat"
    case soy = "Soy"
    case fish = "Fish"
    case shellfish = "Shellfish"
    case sesame = "Sesame"

    var id: String { rawValue }
}

// MARK: - Cuisine Types
enum CuisineType: String, CaseIterable, Identifiable {
    case american = "American"
    case italian = "Italian"
    case mexican = "Mexican"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case indian = "Indian"
    case thai = "Thai"
    case mediterranean = "Mediterranean"
    case french = "French"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case greek = "Greek"
    case middleEastern = "Middle Eastern"
    case caribbean = "Caribbean"
    case african = "African"

    var id: String { rawValue }
}
