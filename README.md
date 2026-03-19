# FreshTrack — iOS Grocery Tracking App

FreshTrack helps you track groceries, reduce food waste, and cook smarter. It predicts expiration dates using on-device machine learning, reminds you at your meal times, and recommends recipes from what's already in your pantry.

---

## What's Built

All six phases are complete.

### Phase 1 — Foundation
- Grocery tracking with manual entry and SwiftData persistence
- Category, storage location, quantity, and expiration date fields
- Dashboard (HomeView) with stats, expiring alerts, storage and category breakdowns
- Pantry list with search, swipe-to-delete, swipe-to-mark-consumed
- Cross-platform support (iOS + macOS)

### Phase 2 — Barcode Scanning
- Camera-based barcode scanner using Vision framework (`DataScannerViewController`)
- Open Food Facts API integration for product lookup
- Auto-fills name, category, and product image from scan
- Redis-cached barcode lookups on backend
- Manual entry fallback when barcode not found

### Phase 3 — Recipe Search
- Spoonacular API integration for recipe search
- Search by keyword, by pantry ingredients, or by expiring items
- Ingredient selector — tap to include/exclude specific pantry items from search
- Recipe detail view with ingredients, step-by-step instructions, cook time, health score
- Save/bookmark recipes locally with SwiftData
- Local expiration notifications (category-specific messages)

### Phase 4 — Expiration Prediction (ML)
- On-device Core ML model (Boosted Tree Regressor, trained via Create ML)
- 122 training samples across 11 food categories × 4 storage locations
- Predicts days until expiration based on category + storage location
- Confidence scores displayed in UI
- Fallback to category defaults if model unavailable

### Phase 5 — On-Device Recommendations
- Interaction tracking — every recipe view, save, like, dislike logged to SwiftData
- `RecipeRecommendationService` scores unsaved recipes using:
  - Interaction history (liked > saved > viewed)
  - Time-of-day affinity (what you browse at similar hours)
  - Expiring pantry boost (recipes that use items about to expire)
- "Recommended for You" horizontal scroll in the Recipes → Saved tab
- "Why recommended?" explanation sheet on each card
- Thumbs up / thumbs down feedback
- Auto-prunes interaction history to 500 entries

### Phase 6 — Settings, Notifications & Onboarding
- **Onboarding** — 3-step first-launch flow: Welcome → Meal Times → Permissions
- **Meal-time notifications** — breakfast, lunch, dinner each get their own notification slot per expiring item. Fully configurable, no server required
- **SettingsView** — meal time pickers with enable/disable toggles, notification permission status, app version, clear all data
- **scenePhase rescheduling** — notifications re-evaluated every time app comes to foreground
- **Settings tab** added to main tab bar

---

## Tech Stack

### iOS
| Technology | Purpose |
|---|---|
| SwiftUI | UI framework |
| SwiftData | On-device persistence |
| Core ML + Create ML | On-device expiration prediction |
| Vision / DataScannerViewController | Barcode scanning |
| UserNotifications | Local meal-time notifications |
| AsyncImage | Product images from Open Food Facts |

### Backend (local dev only — not required for core app)
| Technology | Purpose |
|---|---|
| FastAPI (Python) | REST API |
| PostgreSQL | Database |
| Redis | Barcode + recipe caching |
| Docker Compose | Local orchestration |

### External APIs
| Service | Purpose | Required |
|---|---|---|
| Open Food Facts | Barcode product lookup | No (fallback to manual) |
| Spoonacular | Recipe search | Yes (for Recipes tab) |

---

## Project Structure

```
Food-Tracker/
├── FreshTrack/                         # Xcode project
│   ├── FreshTrack/
│   │   └── FreshTrackApp.swift         # App entry point, ModelContainer, scenePhase
│   ├── Models/
│   │   ├── ModelsGrocery.swift         # Grocery @Model, enums (FoodCategory etc.)
│   │   ├── Recipe.swift                # Recipe, RecipeDetail, RecipeByIngredient
│   │   ├── SavedRecipe.swift           # SwiftData model for bookmarked recipes
│   │   ├── ScannedProduct.swift        # Barcode scan result model
│   │   └── RecipeInteraction.swift     # Interaction history for recommendations
│   ├── Views/
│   │   ├── MainTabView.swift           # Tab bar (Home, Scan, Pantry, Recipes, Settings)
│   │   ├── HomeView.swift              # Dashboard
│   │   ├── PantryView.swift            # Grocery list
│   │   ├── RecipeListView.swift        # Saved, Search, My Ingredients, Expiring tabs
│   │   ├── RecipeDetailView.swift      # Full recipe detail
│   │   ├── BarcodeScannerView.swift    # Camera scanner
│   │   ├── ViewsAddGroceryView.swift   # Add grocery form
│   │   ├── EditGroceryView.swift       # Edit grocery form
│   │   ├── OnboardingView.swift        # First-launch onboarding
│   │   └── SettingsView.swift          # Settings + meal time pickers
│   ├── Components/
│   │   ├── ComponentsGroceryRowView.swift  # Grocery list row (with product image)
│   │   ├── RecipeCard.swift            # Recipe grid card
│   │   └── RecommendationCard.swift    # Recommendation card with feedback
│   ├── Services/
│   │   ├── BarcodeAPIService.swift     # Open Food Facts integration
│   │   ├── RecipeAPIService.swift      # Spoonacular integration
│   │   ├── ExpirationPredictionService.swift  # Core ML inference
│   │   ├── ExpirationNotificationService.swift # Meal-time notification scheduling
│   │   ├── InteractionTrackingService.swift    # Recipe interaction logger
│   │   ├── RecipeRecommendationService.swift   # On-device recommendation engine
│   │   └── MealTimeSettings.swift      # UserDefaults meal time store
│   └── Resources/
│       ├── ExpirationTrainingData.json # 122-sample ML training data
│       └── ExpirationPredictor.mlmodel # Trained Core ML model
│
├── backend/                            # FastAPI backend (local dev)
│   ├── app/
│   │   ├── api/v1/endpoints/           # auth, groceries, barcode, recipes
│   │   ├── services/                   # barcode_service, spoonacular_service
│   │   └── db/models/                  # user, grocery
│   ├── docker-compose.yml
│   └── requirements.txt
│
├── IMPLEMENTATION_PHASES.md            # Detailed phase breakdown
├── APP_STORE_DEPLOYMENT.md             # Step-by-step App Store submission guide
└── README.md
```

---

## Getting Started

### Requirements
- Xcode 15.0+
- iOS 17.0+ deployment target
- Apple Developer account (for device testing and App Store)
- Spoonacular API key (free tier available)

### Run on Simulator or Device

1. Open `FreshTrack/FreshTrack.xcodeproj` in Xcode
2. Select your target device or simulator
3. Add your Spoonacular API key in `RecipeAPIService.swift`
4. Build and run (`Cmd+R`)

> Barcode scanning requires a physical device (no camera in simulator).

### Backend (optional — only needed for barcode caching)

```bash
cd backend
cp .env.example .env          # add your SPOONACULAR_API_KEY
docker-compose up -d
# API available at http://localhost:8000
# Docs at http://localhost:8000/docs
```

The iOS app calls Open Food Facts and Spoonacular directly, so the backend is not required for the app to function.

---

## Development Phases

| Phase | Status | Description |
|---|---|---|
| Phase 1 | ✅ Complete | Foundation — grocery tracking, SwiftData, backend |
| Phase 2 | ✅ Complete | Barcode scanning — camera, Open Food Facts |
| Phase 3 | ✅ Complete | Recipe search — Spoonacular, ingredient filter |
| Phase 4 | ✅ Complete | Expiration ML — Core ML, Create ML |
| Phase 5 | ✅ Complete | On-device recommendations — interaction history, time-of-day |
| Phase 6 | ✅ Complete | Settings, meal-time notifications, onboarding |

---

## License

MIT
