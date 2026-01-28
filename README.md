# FreshTrack - iOS Grocery Tracking App

An iOS application that tracks groceries, predicts expiration dates using machine learning, and provides personalized recipe recommendations.

## Features

- **Grocery Tracking**: Add items manually or via barcode scan
- **Expiration Prediction**: ML model predicts when food will expire
- **Recipe Search**: Find recipes using ingredients you have
- **Personalized Recommendations**: Learn user preferences and time-of-day habits (coming soon)

## Project Structure

```
Food Waste Prediction/
├── FreshTrack/                    # iOS App (Swift/SwiftUI)
│   ├── App/                       # App entry point
│   ├── Core/                      # Extensions, utilities, protocols
│   ├── Domain/                    # Business logic, models, use cases
│   ├── Data/                      # SwiftData, network, repositories
│   ├── Infrastructure/            # ML, Vision, Notifications
│   ├── Presentation/              # UI components and screens
│   └── Resources/                 # Assets, localization
│
├── backend/                       # Python FastAPI Backend
│   ├── app/
│   │   ├── api/v1/               # API endpoints
│   │   ├── core/                 # Security, config
│   │   ├── db/                   # Database models
│   │   ├── ml/                   # Machine learning
│   │   └── services/             # Business services
│   ├── docker-compose.yml
│   └── requirements.txt
│
└── README.md
```

## Getting Started

### iOS App

1. Open `FreshTrack/` folder in Xcode
2. Create a new iOS App project and add the source files
3. Set minimum deployment target to iOS 17.0
4. Build and run

**Or create the Xcode project:**
```bash
# In Xcode:
# 1. File > New > Project
# 2. Choose "App" under iOS
# 3. Product Name: FreshTrack
# 4. Interface: SwiftUI
# 5. Language: Swift
# 6. Storage: SwiftData
# 7. Copy the source files from FreshTrack/ into the project
```

### Backend

1. Start the backend services:
```bash
cd backend
docker-compose up -d
```

2. The API will be available at `http://localhost:8000`
3. API documentation: `http://localhost:8000/docs`

### Environment Setup

1. Copy the environment template:
```bash
cp backend/.env.example backend/.env
```

2. Update the `.env` file with your API keys:
   - `SPOONACULAR_API_KEY`: Get from [Spoonacular](https://spoonacular.com/food-api)

## Tech Stack

### iOS
- SwiftUI (UI Framework)
- SwiftData (Persistence)
- Core ML (On-device ML)
- Vision (Barcode scanning)

### Backend
- FastAPI (Python web framework)
- PostgreSQL (Database)
- Redis (Caching)
- Docker (Containerization)

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | User registration |
| `/api/v1/auth/login` | POST | User login |
| `/api/v1/auth/apple` | POST | Sign in with Apple |
| `/api/v1/groceries` | GET | List groceries |
| `/api/v1/groceries` | POST | Add grocery |
| `/api/v1/groceries/{id}` | PATCH | Update grocery |
| `/api/v1/groceries/{id}` | DELETE | Delete grocery |
| `/api/v1/groceries/sync` | POST | Sync from iOS |

## Development Phases

- [x] Phase 1: Foundation - Core app structure, grocery tracking
- [ ] Phase 2: Barcode Scanning
- [ ] Phase 3: Expiration Prediction ML
- [ ] Phase 4: Recipe Integration
- [ ] Phase 5: Advanced ML Recommendations
- [ ] Phase 6: Polish & Launch

## License

MIT
