# Wellness Monitoring & Coaching App

A comprehensive wellness monitoring and coaching platform featuring iOS native app, React web app, and Python backend. Integrates with Apple HealthKit for health data, uses Claude AI for personalized analysis, and ElevenLabs for daily podcast generation.

## Features

- **Health Data Integration**: Heart rate, HRV, sleep stages, exercise, glucose, mindfulness from Apple Health
- **Manual Tracking**: Diet, mood, substances, gratitude, meditation, negativity exposure
- **AI Analysis**: Daily wellness analysis powered by Claude with pattern detection and correlations
- **Personalized Podcasts**: 3-5 minute daily briefings generated with ElevenLabs TTS
- **Sound Healing**: Library of binaural beats, solfeggio frequencies, and dynamic sound generation

## Tech Stack

| Component | Technology |
|-----------|------------|
| iOS App | Swift/SwiftUI |
| Web App | React + Vite + TypeScript |
| Backend | Python/FastAPI |
| Database | Supabase (PostgreSQL) |
| AI | Anthropic Claude |
| TTS | ElevenLabs |
| Hosting | Google Cloud (Cloud Run + Firebase) |

## Project Structure

```
wellness-app/
├── backend/           # FastAPI backend
│   ├── app/
│   │   ├── api/v1/   # API endpoints
│   │   ├── services/ # Business logic
│   │   └── models/   # Pydantic models
│   ├── supabase/     # Database schema
│   └── Dockerfile
├── frontend/         # React web app
│   └── src/
│       ├── components/
│       ├── pages/
│       ├── hooks/
│       └── lib/
└── ios/              # iOS app
    └── WellnessApp/
        ├── Core/
        │   ├── HealthKit/
        │   └── Networking/
        └── Features/
```

## Setup

### Prerequisites

- Python 3.12+
- Node.js 18+
- Xcode 15+ (for iOS)
- Supabase account
- Anthropic API key
- ElevenLabs API key

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
# Edit .env with your credentials

# Run the server
uvicorn app.main:app --reload
```

### Database Setup

1. Create a new Supabase project
2. Run the SQL schema in `backend/supabase/schema.sql`
3. Enable Row Level Security on all tables
4. Set up storage buckets for `images` and `audio`

### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
# Edit .env with your Supabase credentials

# Run development server
npm run dev
```

### iOS Setup

1. Open `ios/WellnessApp.xcodeproj` in Xcode
2. Update `Config.swift` with your API URLs
3. Add required capabilities:
   - HealthKit
   - Background Modes (fetch, processing, audio)
4. Configure signing & capabilities
5. Build and run on device (HealthKit requires physical device)

## API Documentation

When running locally with `DEBUG=true`, API docs are available at:
- Swagger UI: http://localhost:8080/docs
- ReDoc: http://localhost:8080/redoc

## Environment Variables

### Backend (.env)

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
ANTHROPIC_API_KEY=sk-ant-your-key
ELEVENLABS_API_KEY=your-elevenlabs-key
JWT_SECRET_KEY=your-supabase-jwt-secret
```

### Frontend (.env)

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

## Deployment

### Backend (Cloud Run)

```bash
cd backend
gcloud builds submit --tag gcr.io/PROJECT_ID/wellness-api
gcloud run deploy wellness-api --image gcr.io/PROJECT_ID/wellness-api
```

### Frontend (Firebase Hosting)

```bash
cd frontend
npm run build
firebase deploy --only hosting
```

## License

Private - All rights reserved
