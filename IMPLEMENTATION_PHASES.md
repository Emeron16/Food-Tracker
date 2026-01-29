# FreshTrack Implementation Phases

Detailed breakdown of all implementation phases with specific tasks and files.

---

## Phase 1: Foundation ✅ COMPLETED

**Goal**: Core app structure, basic grocery tracking, local backend

### iOS Tasks
- [x] Set up Xcode project with Models/Views/Components structure
- [x] Create domain models & enums (`FoodCategory`, `StorageLocation`, `MeasurementUnit`, `ExpirationStatus`)
- [x] Create SwiftData `@Model` class (`Grocery`) with ML fields, consumption tracking, computed properties
- [x] Configure `ModelContainer` in `FreshTrackApp`
- [x] Build `PantryView` with search, expiring-soon section, swipe actions (delete/mark consumed)
- [x] Create `AddGroceryView` with category/storage/quantity pickers, date handling, quick-add grid
- [x] Create `GroceryRowView` reusable component with category icons, ML badge, expiration badge
- [x] Build `HomeView` dashboard with stats cards, expiring/expired alerts, storage & category breakdowns
- [x] Set up `MainTabView` with tab navigation (Home + Pantry)
- [x] Cross-platform support (iOS + macOS) with `#if os()` guards

### iOS Files (Actual)
- `FreshTrack/FreshTrack/FreshTrackApp.swift` — App entry point, ModelContainer config
- `FreshTrack/Models/ModelsGrocery.swift` — Grocery @Model, FoodCategory, StorageLocation, MeasurementUnit, ExpirationStatus enums
- `FreshTrack/Models/PantryView.swift` — Grocery list with search, expiring section, swipe actions
- `FreshTrack/Views/ViewsAddGroceryView.swift` — Add grocery form with quick-add
- `FreshTrack/Views/HomeView.swift` — Dashboard with stats, alerts, breakdowns
- `FreshTrack/Views/MainTabView.swift` — TabView (Home + Pantry)
- `FreshTrack/Components/ComponentsGroceryRowView.swift` — Reusable row with category icon, ML badge, expiration status

### Backend Tasks
- [x] Initialize FastAPI project structure
- [x] Set up SQLAlchemy async with PostgreSQL
- [x] Create User model with preferences
- [x] Create GroceryItem and ConsumptionRecord models
- [x] Implement JWT authentication (register, login, refresh)
- [x] Implement Sign in with Apple endpoint
- [x] Create grocery CRUD endpoints
- [x] Create grocery sync endpoint for iOS
- [x] Set up Docker Compose with PostgreSQL and Redis

### Backend Files Created
- `backend/app/main.py`
- `backend/app/config.py`
- `backend/app/db/database.py`
- `backend/app/db/models/user.py`
- `backend/app/db/models/grocery.py`
- `backend/app/core/security.py`
- `backend/app/api/v1/router.py`
- `backend/app/api/v1/endpoints/auth.py`
- `backend/app/api/v1/endpoints/groceries.py`
- `backend/app/api/v1/schemas/user.py`
- `backend/app/api/v1/schemas/grocery.py`
- `backend/docker-compose.yml`
- `backend/Dockerfile`
- `backend/requirements.txt`

---

## Phase 2: Barcode Scanning ✅ COMPLETED

**Goal**: Quick grocery entry via camera

### iOS Tasks
- [x] Implement `BarcodeScannerService` using Vision framework
- [x] Create `ScannerView` with camera preview
- [x] Create `ScannerViewModel` for scan logic
- [x] Add camera overlay with barcode detection frame
- [x] Implement barcode lookup from Open Food Facts
- [x] Add manual entry fallback when barcode not found
- [x] Cache barcode lookups locally
- [x] Handle camera permissions
- [x] Add haptic feedback on successful scan

### iOS Files Created (Actual)
- `FreshTrack/Views/BarcodeScannerView.swift` — Scanner view with DataScannerViewController, camera preview, overlays, and scan logic
- `FreshTrack/Services/BarcodeAPIService.swift` — Open Food Facts API integration with category mapping
- `FreshTrack/Models/ScannedProduct.swift` — Product info model for scanned barcodes

### Backend Tasks
- [x] Create barcode lookup endpoint
- [x] Integrate Open Food Facts API
- [ ] Integrate UPC Database API as backup
- [x] Implement barcode result caching with Redis
- [ ] Store product catalog for offline suggestions

### Backend Files Created (Actual)
- `backend/app/services/barcode_service.py` — Barcode lookup with Redis caching
- `backend/app/api/v1/endpoints/barcode.py` — GET /barcode/{barcode} endpoint
- `backend/app/api/v1/schemas/barcode.py` — BarcodeProductResponse schema

---

## Phase 3: Basic Recipe Search (MVP Complete) ✅ COMPLETED

**Goal**: Recipe search and ingredient-based filtering

### Backend Tasks
- [x] Integrate Spoonacular API
- [x] Create recipe search endpoint
- [x] Implement ingredient-based recipe search
- [x] Create "Use Expiring Items" recipe filter
- [x] Cache popular recipes
- [x] Create recipe detail endpoint
- [ ] Track recipe interactions (views, saves)
- [x] Store user's saved/favorite recipes (iOS local with SwiftData)

### Backend Files Created (Actual)
- `backend/app/services/spoonacular_service.py` — Spoonacular API integration with Redis caching
- `backend/app/api/v1/endpoints/recipes.py` — Search, by-ingredients, expiring, and detail endpoints
- `backend/app/api/v1/schemas/recipe.py` — Recipe response schemas

### iOS Tasks
- [x] Create `Recipe` domain model
- [x] Create `RecipeAPIService` for backend communication
- [x] Build `RecipeListView` with search
- [x] Build `RecipeDetailView` with ingredients and instructions
- [x] Implement recipe filtering (by ingredients, diet, time)
- [x] Build `RecipeCard` component
- [x] Add recipe saving/favoriting
- [ ] Create cooking completion flow (skipped for MVP)

### iOS Files Created (Actual)
- `FreshTrack/Models/Recipe.swift` — Recipe, RecipeDetail, RecipeByIngredient models
- `FreshTrack/Models/SavedRecipe.swift` — SwiftData model for saved/favorited recipes
- `FreshTrack/Services/RecipeAPIService.swift` — Spoonacular API service (direct call)
- `FreshTrack/Views/RecipeListView.swift` — Recipe list with Saved, Search, My Ingredients, Expiring modes
- `FreshTrack/Views/RecipeDetailView.swift` — Full recipe detail with save/unsave functionality
- `FreshTrack/Components/RecipeCard.swift` — RecipeCard and RecipeByIngredientCard components

### Notification Features (Added)
- [x] Create `ExpirationNotificationService` for local notifications
- [x] Request notification permissions on app launch
- [x] Schedule notifications for expiring items (3 days, 1 day, and day-of)
- [x] Category-specific notification messages with recipe/usage suggestions
- [x] Notification actions: "Mark as Used", "Find Recipes"

### Notification Files Created
- `FreshTrack/Services/ExpirationNotificationService.swift` — Notification scheduling and management

---

## Phase 4: Expiration Prediction (ML)

**Goal**: ML-powered expiration date prediction

### Data Preparation Tasks
- [ ] Collect USDA FoodKeeper baseline data
- [ ] Clean and preprocess training data
- [ ] Engineer features (category encoding, seasonality, storage type)
- [ ] Create train/validation/test splits
- [ ] Build data pipeline for continuous learning

### Backend ML Tasks
- [ ] Implement XGBoost expiration prediction model
- [ ] Train model on baseline data
- [ ] Evaluate model accuracy (MAE, RMSE)
- [ ] Export model to Core ML format using coremltools
- [ ] Create model versioning system
- [ ] Set up model hosting (S3 or Cloud Storage)
- [ ] Create endpoint for model metadata and download

### Backend Files to Create
- `backend/app/ml/data/food_keeper_data.json`
- `backend/app/ml/data/preprocessor.py`
- `backend/app/ml/data/feature_engineering.py`
- `backend/app/ml/training/train_expiration.py`
- `backend/app/ml/training/evaluate_model.py`
- `backend/app/ml/training/export_coreml.py`
- `backend/app/api/v1/endpoints/ml.py`
- `backend/app/api/v1/schemas/ml.py`

### iOS Tasks
- [ ] Create `CoreMLManager` for model loading
- [ ] Implement `ExpirationPredictionService`
- [ ] Create `PredictExpirationUseCase`
- [ ] Integrate prediction into `AddGroceryView`
- [ ] Display confidence scores in UI
- [ ] Implement model update checking
- [ ] Download and cache ML models
- [ ] Handle prediction errors gracefully

### iOS Files to Create
- `FreshTrack/Infrastructure/ML/CoreMLManager.swift`
- `FreshTrack/Infrastructure/ML/ExpirationPredictionService.swift`
- `FreshTrack/Infrastructure/ML/ModelUpdateManager.swift`
- `FreshTrack/Infrastructure/ML/Models/ExpirationPredictor.mlmodel`
- `FreshTrack/Domain/Models/ExpirationPrediction.swift`
- `FreshTrack/Domain/UseCases/ML/PredictExpirationUseCase.swift`
- `FreshTrack/Data/Network/Services/MLSyncService.swift`

---

## Phase 5: Advanced ML Recommendations (Post-MVP)

**Goal**: Personalized recommendations with time-of-day learning

### Backend ML Tasks
- [ ] Implement collaborative filtering with Surprise library
- [ ] Train user-user similarity model
- [ ] Train item-item similarity model
- [ ] Create time-of-day preference model
- [ ] Build ensemble recommendation scorer
- [ ] Implement recommendation weights tuning
- [ ] Set up A/B testing infrastructure
- [ ] Create model retraining pipeline with Celery
- [ ] Export time-of-day model to Core ML

### Backend Files to Create
- `backend/app/ml/models/collaborative_filter.py`
- `backend/app/ml/models/time_preference_model.py`
- `backend/app/ml/inference/recipe_recommender.py`
- `backend/app/ml/training/train_collaborative.py`
- `backend/app/ml/training/train_time_preference.py`
- `backend/app/tasks/celery_app.py`
- `backend/app/tasks/model_training_task.py`

### iOS Tasks
- [ ] Integrate time-of-day Core ML model
- [ ] Create `RecipeRecommendationService`
- [ ] Build personalized home screen recommendations
- [ ] Add "Why recommended?" explanations
- [ ] Implement preference learning feedback
- [ ] Create meal planning widgets
- [ ] Track user interactions for ML training
- [ ] Submit anonymized training data to backend

### iOS Files to Create
- `FreshTrack/Infrastructure/ML/RecipeRecommendationService.swift`
- `FreshTrack/Infrastructure/ML/TimeOfDayPredictor.swift`
- `FreshTrack/Infrastructure/ML/Models/TimeOfDayPredictor.mlmodel`
- `FreshTrack/Infrastructure/ML/Models/RecipeRecommender.mlmodel`
- `FreshTrack/Domain/Models/UserPreferences.swift`
- `FreshTrack/Domain/Models/RecommendationExplanation.swift`
- `FreshTrack/Domain/UseCases/ML/GetPersonalizedRecommendationsUseCase.swift`
- `FreshTrack/Presentation/Components/RecommendationCard.swift`
- `FreshTrack/Presentation/Components/MealTimeWidget.swift`

---

## Phase 6: Polish & Launch

**Goal**: Notifications, sync, onboarding, production readiness

### Notification Tasks
- [ ] Implement local expiration notifications
- [ ] Set up APNs for push notifications
- [ ] Create notification scheduling logic
- [ ] Add notification preferences UI
- [ ] Implement morning/evening reminder options
- [ ] Create notification action handlers

### iOS Files to Create
- `FreshTrack/Infrastructure/Notifications/ExpirationNotificationService.swift`
- `FreshTrack/Infrastructure/Notifications/NotificationScheduler.swift`
- `FreshTrack/Presentation/Screens/Settings/NotificationPreferencesView.swift`

### CloudKit Sync Tasks
- [ ] Enable CloudKit in Xcode capabilities
- [ ] Configure SwiftData with CloudKit
- [ ] Implement `SyncEngine` for conflict resolution
- [ ] Handle offline/online state transitions
- [ ] Test multi-device sync

### iOS Files to Create
- `FreshTrack/Data/CloudKit/SyncEngine.swift`
- `FreshTrack/Data/CloudKit/CloudKitManager.swift`

### Onboarding Tasks
- [ ] Design onboarding flow (3-5 screens)
- [ ] Create `OnboardingView` with welcome screens
- [ ] Implement dietary restrictions selection
- [ ] Add household size input
- [ ] Request notification permissions
- [ ] Request camera permissions
- [ ] Track onboarding completion

### iOS Files to Create
- `FreshTrack/Presentation/Screens/Onboarding/OnboardingView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/OnboardingViewModel.swift`
- `FreshTrack/Presentation/Screens/Onboarding/WelcomeStepView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/PreferencesStepView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/PermissionsStepView.swift`

### Settings Tasks
- [ ] Build `SettingsView` with all preferences
- [ ] Add account management section
- [ ] Implement data export functionality
- [ ] Add privacy controls
- [ ] Create about/help section

### iOS Files to Create
- `FreshTrack/Presentation/Screens/Settings/SettingsView.swift`
- `FreshTrack/Presentation/Screens/Settings/SettingsViewModel.swift`
- `FreshTrack/Presentation/Screens/Settings/AccountView.swift`
- `FreshTrack/Presentation/Screens/Settings/PrivacyView.swift`

### Testing & QA Tasks
- [ ] Write unit tests for ViewModels
- [ ] Write unit tests for UseCases
- [ ] Write integration tests for repositories
- [ ] Create UI tests for critical flows
- [ ] Test ML model accuracy
- [ ] Performance optimization
- [ ] Memory leak detection
- [ ] Accessibility audit

### Launch Preparation Tasks
- [ ] Create App Store screenshots
- [ ] Write App Store description
- [ ] Design app icon
- [ ] Set up App Store Connect
- [ ] Configure TestFlight for beta testing
- [ ] Set up crash reporting (Crashlytics)
- [ ] Set up analytics
- [ ] Backend scaling and monitoring
- [ ] Create privacy policy
- [ ] Create terms of service

---

## Verification Checklist

### Functional Testing
- [ ] Add grocery items manually
- [ ] Add grocery items via barcode scan
- [ ] Verify expiration predictions are reasonable
- [ ] Search and filter recipes by ingredients
- [ ] Test recipe recommendations at different times
- [ ] Verify notifications are delivered
- [ ] Test CloudKit sync between devices
- [ ] Complete onboarding flow

### Performance Metrics
- [ ] App launch time < 2 seconds
- [ ] Smooth 60fps scrolling
- [ ] ML inference < 100ms
- [ ] API response times < 500ms
- [ ] Memory usage < 100MB typical

### ML Metrics
- [ ] Expiration prediction MAE < 2 days
- [ ] Recipe recommendation click-through > 10%
- [ ] Time-of-day prediction accuracy > 70%

---

## Dependencies & API Keys Required

| Service | Purpose | Required Phase |
|---------|---------|----------------|
| Spoonacular | Recipe database | Phase 3 |
| Open Food Facts | Barcode lookup | Phase 2 |
| Apple Developer | App Store, APNs | Phase 6 |
| AWS/GCP (optional) | Production hosting | Phase 6 |
