# You Too Art

A modern social and casting platform connecting actors, directors, artists, and production houses.

---

## Features

- **Multi-Role Authentication & Onboarding** — Email OTP verification via Supabase Auth supporting distinct roles: Actor, Director, and Production House.
- **Social Feed** — Create, share, and interact with posts, photos, and video updates. Includes like, comment, and bookmark capabilities.
- **Talent Discovery** — Browse, search, and discover verified creative talent across industries.
- **Professional Networking** — Follow industry professionals and send/accept connection requests with real-time status updates.
- **Real-Time Direct Chat** — Fast, 1:1 messaging powered by Supabase Realtime subscriptions.
- **Casting Calls & Auditions** — Production houses and directors can post casting calls; actors can apply directly and track their application progress.
- **Portfolio Showcase** — Showcase videos and photo galleries with unsigned Cloudinary CDN media uploads.
- **In-App Notifications** — Real-time alerts for incoming connection requests, accepted connections, post interactions, and casting updates.
- **Account Management & Verification** — Complete profile customisation, account verification status, and responsive layout for mobile and web.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Material 3) |
| **State Management** | Riverpod 3.x (`Notifier` / `AsyncNotifier` / code-generation free) |
| **Navigation** | GoRouter 14.x with auth state redirect guards |
| **Backend & Database** | Supabase (PostgreSQL, Auth, Row-Level Security, Realtime) |
| **Media Storage** | Cloudinary (Unsigned direct client uploads) |
| **Local Storage** | SharedPreferences |
| **Design / Icons** | Cupertino Icons & Flutter SVG |

---

## Getting Started

### Prerequisites

- Flutter SDK (stable channel, 3.22+)
- Dart SDK `^3.13.1`

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd you_too_art
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Database (Supabase):**
   - Create a project on [Supabase](https://supabase.com).
   - In the Supabase SQL Editor, run [`supabase/schema.sql`](supabase/schema.sql).
   - Execute the sequential migrations in [`supabase/migrations/`](supabase/migrations/) if configuring incrementally.

4. **Configure API Credentials:**
   - **Supabase:** Update `url` and `publishableKey` in [`lib/main.dart`](lib/main.dart).
   - **Cloudinary:** Update `cloudName` and `unsignedPreset` in [`lib/core/repositories/storage_repository.dart`](lib/core/repositories/storage_repository.dart).

5. **Run the Application:**
   ```bash
   # Run on Chrome / Web
   flutter run -d chrome

   # Run on connected mobile device or emulator
   flutter run
   ```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point & service initialisation
├── app/                               # App-wide routing, theme, and constants
│   ├── config/                        # GoRouter configuration & routes
│   └── theme/                         # Light / Dark theme definitions
├── core/                              # Shared foundation
│   ├── constants/                     # DB tables, assets, and design tokens
│   ├── models/                        # Core data models
│   ├── providers/                     # App-wide Riverpod providers
│   ├── repositories/                  # Supabase & Cloudinary data access layer
│   ├── services/                      # Persistent state & web utilities
│   └── widgets/                       # Shared UI components & web wrapper
└── features/                          # Feature modules
    ├── account/                       # Account settings & verification
    ├── auth/                          # Login, OTP verification & role selection
    ├── casting/                       # Casting call boards & application flow
    ├── chats/                         # Direct messaging & conversation lists
    ├── home/                          # Main social feed, post creation & comments
    ├── network/                       # Connection suggestions & network list
    ├── notifications/                 # Real-time notification feed
    ├── onboarding/                    # Welcome walkthrough
    ├── profile/                       # User profile view, edit & portfolio builder
    └── talent/                        # Talent discovery directory & search
```

---

## Architecture Guidelines

- **UI Screens (`presentation/` / `widgets/`)** → Consume state via `ref.watch` / `ref.read`. Strictly invoke Notifiers or navigate with GoRouter. Never execute database or network calls directly.
- **State Notifiers (`providers/`)** → Manage domain business logic. Interact exclusively with repositories and mutate immutable state.
- **Repositories (`repositories/`)** → Pure data layer communicating with Supabase PostgreSQL/Auth and Cloudinary.
- **Models (`models/`)** → Plain Dart classes with `fromJson` and `toJson` serialization.

---

## License

Private — Skypulse Solutions. All rights reserved.
