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

## Phase 4: Expiration Prediction (ML) ✅ COMPLETED

**Goal**: ML-powered expiration date prediction (on-device Core ML)

### Data Preparation Tasks
- [x] Collect USDA FoodKeeper baseline data
- [x] Clean and preprocess training data
- [x] Engineer features (category encoding, storage type)
- [x] Create train/validation/test splits
- [ ] Build data pipeline for continuous learning (Post-MVP)

### iOS ML Tasks (Local Core ML - No Backend Required)
- [x] Create training data JSON with food storage guidelines
- [x] Train Boosted Tree Regressor using Create ML
- [x] Export model to Core ML format (.mlmodel)
- [x] Implement `ExpirationPredictionService` with model loading
- [x] Integrate prediction into `AddGroceryView`
- [x] Integrate prediction into `EditGroceryView`
- [x] Display confidence scores in UI
- [x] Handle prediction errors with fallback logic

### iOS Files Created
- `FreshTrack/Resources/ExpirationTrainingData.json` — Training data (122 samples)
- `FreshTrack/Resources/ExpirationPredictor.mlmodel` — Trained Core ML model
- `FreshTrack/Resources/TrainExpirationModel.swift` — Model training script
- `FreshTrack/Services/ExpirationPredictionService.swift` — ML service with fallback

### iOS Files Modified
- `FreshTrack/Views/ViewsAddGroceryView.swift` — ML prediction integration
- `FreshTrack/Views/EditGroceryView.swift` — ML prediction integration

### Model Details
- **Algorithm**: Boosted Tree Regressor (Create ML)
- **Inputs**: category (String), storageLocation (String)
- **Output**: expirationDays (Double)
- **Training Samples**: 122 (11 categories × 4 storage locations)
- **Confidence Scores**: Pre-calculated per category-storage combination (60%-95%)

---

## Phase 5: On-Device ML Recommendations ✅ COMPLETED

**Goal**: Personalized recipe recommendations using on-device Core ML — no server required

### Strategy
- Ship a pre-trained base model (trained once by developer using general food preference data)
- Use Core ML's `MLUpdateTask` to fine-tune the model locally from each user's recipe interactions
- All training, inference, and personalization happens on-device
- Collaborative filtering (cross-user recommendations) deferred to a future update

### No Backend Required
All previous backend ML tasks removed. No Celery, no Surprise library, no server-side retraining.

### iOS Tasks
- [x] Track user recipe interactions in SwiftData (viewed, saved, unsaved, liked, disliked — with timestamp + hour of day)
- [x] Implement `RecipeRecommendationService` — scores recipes using interaction history, time-of-day affinity, and expiring items boost
- [x] Build personalized recommendations section on `HomeView` (horizontal scroll, meal-time label)
- [x] Add "Why recommended?" explanation sheet on each card
- [x] Add preference feedback (thumbs up/down on recommendation cards)
- [x] Log interactions in `RecipeDetailView` (viewed, saved, unsaved)

### iOS Files Created
- `FreshTrack/Services/RecipeRecommendationService.swift` — Scoring engine (interaction history + time-of-day + expiring boost)
- `FreshTrack/Services/InteractionTrackingService.swift` — Logs recipe interactions to SwiftData
- `FreshTrack/Models/RecipeInteraction.swift` — SwiftData model for interaction history (500 entry cap)
- `FreshTrack/Components/RecommendationCard.swift` — Card with image, reason, "Why?" sheet, thumbs up/down

### iOS Files Modified
- `FreshTrack/Views/HomeView.swift` — Recommendations section (horizontal scroll, meal-time label, refresh on interaction change)
- `FreshTrack/Views/RecipeDetailView.swift` — Logs viewed/saved/unsaved interactions
- `FreshTrack/FreshTrack/FreshTrackApp.swift` — Added RecipeInteraction to ModelContainer schema

### Future Update (Collaborative Filtering)
When the user base grows, cross-user recommendations can be layered on top:
- Collect anonymized interaction data on a backend
- Train collaborative filtering model (Surprise library) server-side
- Push updated base model to devices via CDN or Firebase Remote Config

---

## Phase 6: Polish & Launch ✅ COMPLETED (Core Features)

**Goal**: Meal-time notifications, settings, sync, onboarding, production readiness

### Notification Strategy
Local notifications only — no server required. iOS schedules and fires all notifications on-device.
Each meal time (breakfast, lunch, dinner) gets its own notification slot per expiring item.
Notifications are rescheduled whenever: app opens, grocery is added/edited, or meal times change.
Cap: iOS allows 64 scheduled notifications — scheduling for next 7 days keeps us well under limit.

### Notification Tasks
- [x] Add meal time preferences to user settings (breakfast, lunch, dinner — each with a time picker and toggle)
- [x] Store meal time preferences in `UserDefaults`
- [x] Refactor `ExpirationNotificationService` to accept meal times and schedule per-meal notifications
- [x] Replace hardcoded 9am trigger with user's meal time triggers (one notification per meal per expiring item)
- [x] Add "Find Recipes" deep link action on notifications (already exists as `VIEW_RECIPES` action)
- [x] Reschedule all notifications on app foreground (`scenePhase` change)
- [x] Reschedule notifications when meal times are changed in Settings

### iOS Files Created
- `FreshTrack/Views/SettingsView.swift` — Settings screen with meal time pickers, notification status, data management
- `FreshTrack/Services/MealTimeSettings.swift` — UserDefaults-backed meal time + onboarding state
- `FreshTrack/Views/OnboardingView.swift` — 3-step onboarding (welcome, meal times, permissions)

### iOS Files Modified
- `FreshTrack/Services/ExpirationNotificationService.swift` — Per-meal scheduling, updated identifier format
- `FreshTrack/Views/MainTabView.swift` — Added Settings tab
- `FreshTrack/FreshTrack/FreshTrackApp.swift` — scenePhase rescheduling, onboarding gate

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
- [x] Design onboarding flow (3 screens)
- [x] Create `OnboardingView` with welcome screens
- [x] Request notification permissions
- [x] Request camera permissions (on-demand when scanner opens)
- [x] Track onboarding completion

### iOS Files to Create
- `FreshTrack/Presentation/Screens/Onboarding/OnboardingView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/OnboardingViewModel.swift`
- `FreshTrack/Presentation/Screens/Onboarding/WelcomeStepView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/PreferencesStepView.swift`
- `FreshTrack/Presentation/Screens/Onboarding/PermissionsStepView.swift`

### Settings Tasks
- [x] Build `SettingsView` with meal time preferences
- [x] Notification permission status + enable button
- [x] App version / build info
- [x] Clear all data option
- [ ] Data export functionality (future)
- [ ] Privacy policy link (future)

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
