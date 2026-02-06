# 🎓 DITA App - The Ultimate Student Companion

![DITA App Banner](assets/banner.png)

DITA App is the official mobile application for the Daystar Information Technology Association (DITA). It serves as a comprehensive digital companion for students, integrating academic tools, social features, gamification, and campus services into a single, polished platform.

Designed with a **Midnight Blue & Gold** aesthetic, the app features a robust **Dark Mode**, **Offline Capabilities**, **AI Assistant** powered by Gemini 2.5, and an **Achievement System** that rewards engagement.

## ✨ Key Features

### 🧠 Intelligent AI Assistant

- **DITA AI**: Context-aware chatbot (Gemini 2.5 Flash) with deep knowledge of:
  - Your personal exam schedule and class timetable
  - Athi River & Nairobi campus locations (ICT Building, Hope Center, etc.)
  - All app features and how to use them
- **Smart Answers**: Ask "When is my next exam?" or "Where is the nursing block?" and get instant, personalized responses
- **Image Upload**: Attach images for help with diagrams or assignments

### 📅 Academic Management

- **Exam Timetable**: 
  - Automatically fetches from backend
  - Filter by program and year
  - Works **offline** via local caching
- **Class Schedule**: 
  - Sync directly from Student Portal (via secure WebView extraction)
  - Manual entry with color-coded days
  - Edit/delete individual classes
- **Smart Reminders**:
  - **Exams**: Alerts the evening before and 1 hour before
  - **Classes**: Alerts the evening before and 30 minutes before
- **Portal Import**: Extracts both class schedule AND exam timetable with program/section detection

### 💬 Social & Community

- **Community Hub**: Instagram-style feed with:
  - **Categories**: Academic (Help), Market (Sell items), General, Lost & Found
  - Image uploads via Cloudinary
  - Like and comment on posts
  - Optimistic UI for instant feedback
- **Stories**: 
  - Share 24-hour image/video stories
  - Like, comment, and view analytics
  - See who viewed your stories
  - Caption support
- **Study Groups**:
  - Create or join course-specific groups
  - Real-time chat with group members
  - Deep linking for easy sharing
  - Admin controls (delete group, remove members)
- **Lost & Found**: Report lost items with photos; mark as "Found" when recovered

### 🎮 Games & Gamification

- **3 Playable Games**:
  - **Snake**: Classic arcade game - earn points based on score
  - **Binary Tac-Toe**: Play vs AI (Easy/Medium/Hard difficulty) - win to earn 10-30 points
  - **RAM Optimizer**: Memory puzzle game - clear blocks to optimize "RAM"
- **🏆 Achievement System**: Unlock 7 achievements:
  - 🎯 **AI Slayer** - Beat Binary hard AI 5 times
  - ⚡ **Speed Demon** - Score 1000+ in Snake
  - 🧠 **Strategy Master** - Win 10 Binary games
  - 🎮 **Game Hobbyist** - Play all 3 games
  - 💰 **Point Collector** - Earn 1000 points
  - 📚 **Scholar** - Earn 500 points
  - 🎉 **Event Explorer** - Earn 200 points
- **Push Notifications**: Get instant alerts when you unlock achievements!
- **Leaderboard**: Compete with other students for the top rank based on total points

### 📢 Events & Attendance

- **Event Feed**: View all DITA events with dates, venues, and descriptions
- **RSVP System**: Indicate your attendance plans
- **QR Check-In**: Scan QR codes at events to earn **+20 points**
- **Attendance History**: Track your event participation

### 🛠️ Utilities

- **Secure Payments**: Integrated M-Pesa (STK Push) for Gold membership fees (KES 200/semester)
- **Task Planner**: Built-in To-Do list to track assignments
- **Resources Library**: Access past papers and PDF notes (Gold Members only)
- **Biometric Login**: Secure entry using Fingerprint/Face ID
- **GPA Calculator**: Plan your semester and calculate expected GPA
- **Home Widget**: Android widget showing next class/exam on home screen

### 🔔 Notifications

- **Push Notifications** via Firebase:
  - Announcements from DITA admins (with images)
  - Achievement unlocks
  - Exam/class reminders
- **Foreground display** with custom UI
- **Data-only messages** for background delivery

### 🎨 UI/UX Highlights

- **True Dark Mode**: Sleek "Midnight Navy" theme that activates based on system settings
- **Glassmorphism**: Modern translucent effects in search bars and headers
- **Smooth Animations**: Page transitions, like animations, story progressions
- **Empty States**: Custom SVG illustrations (No tasks, No internet, etc.)
- **Optimistic UI**: Instant feedback before server responses
- **Riverpod State Management**: Offline-first architecture with caching

## 📸 Screenshots

| Home (Light) | Dark Mode | Community | AI Assistant |
|--------------|-----------|-----------|--------------| 
| <img src="screenshots/home-light.jpg" width="200"/> | <img src="screenshots/dark-mode.jpg" width="200"/> | <img src="screenshots/community.jpg" width="200"/> | <img src="screenshots/ai-assistant.jpg" width="200"/> |

## 🛠️ Tech Stack

### Mobile (Frontend)

- **Framework**: Flutter 3.x (Dart)
- **State Management**: Riverpod (with offline-first repository pattern)
- **Networking**: `http` + `dio`
- **Local Storage**: `shared_preferences` + custom caching layer
- **Notifications**: `firebase_messaging` + `awesome_notifications`
- **Scanning**: `mobile_scanner` (QR Codes)
- **AI**: `google_generative_ai` (Gemini 2.5 Flash)
- **Biometrics**: `local_auth`
- **Deep Linking**: `app_links`
- **Ads**: `google_mobile_ads`

### Backend (API)

- **Framework**: Django REST Framework (Python)
- **Database**: PostgreSQL (Production) / SQLite (Dev)
- **Auth**: JWT (djangorestframework-simplejwt)
- **Storage**: Cloudinary (Profile Pictures, Post Images, Stories)
- **Push Notifications**: Firebase Admin SDK
- **Hosting**: Render
- **Updates**: Shorebird (Code Push for Flutter)

### Key Architecture Patterns

- **Repository Pattern**: Separates data sources (remote/local)
- **Offline-First**: Local caching with network fallback
- **Django Signals**: Auto-grant achievements when stats update
- **ViewSet Actions**: Custom endpoints like `update_game_stats`

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.0+ installed
- Python 3.10+ installed
- A Firebase project (for Push Notifications)
- A Cloudinary account (for Image Storage)
- Google Gemini API key (for AI Assistant)

### 1. Clone the Repository
```bash
git clone https://github.com/Iconia7/Dita-app.git
cd Dita-app
```

### 2. Backend Setup

Navigate to the backend folder and set up the virtual environment.
```bash
cd backend/dita_backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

**Configure Environment Variables**: Create a `.env` file in the backend root:
```env
SECRET_KEY=your_django_secret
DEBUG=True
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
BACKEND_URL=http://localhost:8000
```

**Run Migrations & Server**:
```bash
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### 3. Frontend Setup

Navigate to the app folder.
```bash
cd dita_app
flutter pub get
```

**Configure Environment Variables**: 

> **⚠️ SECURITY WARNING**: Never commit your `.env` file to version control! It contains sensitive API keys.

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` and add your actual API keys:
```env
# Google Gemini API Key (for AI Assistant)
# Get your key from: https://makersuite.google.com/app/apikey
GOOGLE_API_KEY=your_gemini_api_key_here

# Backend API Base URL
# Development: http://localhost:8000/api
# Staging: https://staging-api.dita.co.ke/api
# Production: https://api.dita.co.ke/api
API_BASE_URL=http://localhost:8000/api

# Backend media URL (for images)
BACKEND_URL=http://localhost:8000

# Environment (development, staging, production)
ENVIRONMENT=development
```

**Run the App**:
```bash
flutter run
```

## 🔧 Key Implementation Details

### Achievement System
- Game stats tracked in User model (snake_high_score, binary_wins_hard, etc.)
- Django signals auto-check thresholds on User save
- FCM push notification sent on UserAchievement creation
- Endpoint: `POST /api/users/update_game_stats/`

### Portal Import
- Uses WebView with JavaScript injection
- Extracts timetable HTML and parses with Regex
- Detects program/section from student info
- Stores locally in TimetableModel

### Stories System
- 24-hour TTL stored in backend
- Viewers tracked via StoryView model
- Image upload via Cloudinary with transformation
- Real-time comment and like counts

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

## 📞 Contact

**DITA Club** - Daystar University

- **Email**: dita@daystar.ac.ke
- **Developer**: Newton Mwangi (Founder Nexora Creative Solutions)
- **GitHub**: [@Iconia7](https://github.com/Iconia7)

---

*Built with ❤️ by the DITA Tech Team.*
