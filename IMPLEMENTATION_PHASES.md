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

## Phase 2: Barcode Scanning

**Goal**: Quick grocery entry via camera

### iOS Tasks
- [ ] Implement `BarcodeScannerService` using Vision framework
- [ ] Create `ScannerView` with camera preview
- [ ] Create `ScannerViewModel` for scan logic
- [ ] Add camera overlay with barcode detection frame
- [ ] Implement barcode lookup from Open Food Facts
- [ ] Add manual entry fallback when barcode not found
- [ ] Cache barcode lookups locally
- [ ] Handle camera permissions
- [ ] Add haptic feedback on successful scan

### iOS Files to Create
- `FreshTrack/Infrastructure/Vision/BarcodeScannerService.swift`
- `FreshTrack/Infrastructure/Vision/CameraPreviewView.swift`
- `FreshTrack/Presentation/Screens/Scanner/ScannerView.swift`
- `FreshTrack/Presentation/Screens/Scanner/ScannerViewModel.swift`
- `FreshTrack/Presentation/Components/ScannerOverlay.swift`
- `FreshTrack/Data/Network/Services/BarcodeAPIService.swift`
- `FreshTrack/Domain/Models/ProductInfo.swift`

### Backend Tasks
- [ ] Create barcode lookup endpoint
- [ ] Integrate Open Food Facts API
- [ ] Integrate UPC Database API as backup
- [ ] Implement barcode result caching with Redis
- [ ] Store product catalog for offline suggestions

### Backend Files to Create
- `backend/app/services/barcode_service.py`
- `backend/app/api/v1/endpoints/barcode.py`
- `backend/app/api/v1/schemas/barcode.py`

---

## Phase 3: Expiration Prediction (ML)

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

## Phase 4: Basic Recipe Search (MVP Complete)

**Goal**: Recipe search and ingredient-based filtering

### Backend Tasks
- [ ] Integrate Spoonacular API
- [ ] Create recipe search endpoint
- [ ] Implement ingredient-based recipe search
- [ ] Create "Use Expiring Items" recipe filter
- [ ] Cache popular recipes
- [ ] Create recipe detail endpoint
- [ ] Track recipe interactions (views, saves)
- [ ] Store user's saved/favorite recipes

### Backend Files to Create
- `backend/app/services/spoonacular_service.py`
- `backend/app/api/v1/endpoints/recipes.py`
- `backend/app/api/v1/schemas/recipe.py`
- `backend/app/db/models/recipe.py`
- `backend/app/db/models/recipe_interaction.py`

### iOS Tasks
- [ ] Create `Recipe` domain model
- [ ] Create `RecipeAPIService` for backend communication
- [ ] Build `RecipeListView` with search
- [ ] Build `RecipeDetailView` with ingredients and instructions
- [ ] Create `RecipeListViewModel`
- [ ] Implement recipe filtering (by ingredients, diet, time)
- [ ] Add recipe saving/favoriting
- [ ] Create cooking completion flow
- [ ] Build `RecipeCard` component

### iOS Files to Create
- `FreshTrack/Domain/Models/Recipe.swift`
- `FreshTrack/Domain/Models/Ingredient.swift`
- `FreshTrack/Domain/UseCases/Recipe/SearchRecipesUseCase.swift`
- `FreshTrack/Domain/UseCases/Recipe/GetRecipeRecommendationsUseCase.swift`
- `FreshTrack/Domain/UseCases/Recipe/SaveRecipeUseCase.swift`
- `FreshTrack/Domain/Repositories/RecipeRepositoryProtocol.swift`
- `FreshTrack/Data/Repositories/RecipeRepository.swift`
- `FreshTrack/Data/Network/Services/RecipeAPIService.swift`
- `FreshTrack/Data/Network/DTOs/RecipeDTO.swift`
- `FreshTrack/Data/SwiftData/Models/RecipeEntity.swift`
- `FreshTrack/Presentation/Screens/Recipes/RecipeListView.swift`
- `FreshTrack/Presentation/Screens/Recipes/RecipeListViewModel.swift`
- `FreshTrack/Presentation/Screens/Recipes/RecipeDetailView.swift`
- `FreshTrack/Presentation/Screens/Recipes/RecipeFilterView.swift`
- `FreshTrack/Presentation/Components/RecipeCard.swift`

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
| Spoonacular | Recipe database | Phase 4 |
| Open Food Facts | Barcode lookup | Phase 2 |
| Apple Developer | App Store, APNs | Phase 6 |
| AWS/GCP (optional) | Production hosting | Phase 6 |
