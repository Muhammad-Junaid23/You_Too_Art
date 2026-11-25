# You Too Art

A modern social and casting platform connecting actors, directors, artists, and production houses.

---

## Features

- **Multi-Role Authentication & Onboarding** — Email OTP verification via Supabase Auth supporting multi-category individual creative roles (Actor, Director, Cinematographer, Art Director, Writer, Producer, etc.) as well as Production Houses.
- **Social Feed** — Create, edit, delete, and interact with posts, photos, and tagged collaborators. Includes like, comment, and bookmark capabilities.
- **Talent Discovery** — Browse, search, and filter verified creative talent and production houses across disciplines.
- **Professional Networking** — Follow production houses/studios and send/accept connection requests with real-time relationship updates.
- **Real-Time Direct Chat** — 1:1 messaging powered by Supabase Realtime subscriptions, with per-user conversation deletion and unread message indicators.
- **Casting Calls & Auditions** — Production houses and eligible creatives can publish casting calls; matching creative roles can apply directly with experience details and track application statuses.
- **Portfolio Showcase (My Work)** — Individual artist profiles include dedicated Videos and Photos showcase tabs with unsigned Cloudinary uploads and persistent editing/deletion.
- **In-App Notifications** — Real-time alerts for connection requests, accepted connections, post interactions, and casting call updates.
- **Account Management & Verification** — Profile editing, country/city selection, account verification badges, and permanent account deletion.

---

## Tech Stack

| Layer                  | Technology                                                         |
| ---------------------- | ------------------------------------------------------------------ |
| **Framework**          | Flutter (Material 3)                                               |
| **State Management**   | Riverpod 3.x (`Notifier` / `AsyncNotifier` / code-generation free) |
| **Navigation**         | GoRouter 14.x with auth state redirect guards                      |
| **Backend & Database** | Supabase (PostgreSQL, Auth, Row-Level Security, Realtime)          |
| **Media Storage**      | Cloudinary (Unsigned direct client uploads)                        |
| **Local Storage**      | SharedPreferences                                                  |
| **Design / Icons**     | Cupertino Icons & Flutter SVG                                      |

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

6. **Build Release APK (Android):**

   ```bash
   # Recommended: smaller per-ABI APKs (use app-arm64-v8a-release.apk for modern phones)
   flutter build apk --release --split-per-abi

   # Or universal APK (all ABIs)
   flutter build apk --release
   ```

   The generated APKs will be located in `build/app/outputs/flutter-apk/` (for physical Android devices, share `app-arm64-v8a-release.apk`).

   > **Note:** Configure a production Android keystore in `android/app/build.gradle.kts` (`signingConfigs`) before publishing to Google Play.

7. **Run Static Analysis & Tests:**
   ```bash
   flutter analyze
   flutter test
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
