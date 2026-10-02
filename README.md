# You Too Art

A social and casting platform connecting actors, artists, and production houses.

## Features

- **Social Feed** — Share updates with images and videos
- **Talent Discovery** — Find and connect with talent
- **Networking** — Build professional connections
- **Direct Chat** — 1:1 messaging with real-time updates
- **Casting Calls** — Post and apply for roles
- **Portfolio** — Showcase your work

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3) |
| State Management | Riverpod 3.x (Notifier/AsyncNotifier) |
| Navigation | GoRouter with auth guards |
| Backend | Supabase (Auth, Postgres, Realtime) |
| Media Storage | Cloudinary (unsigned uploads) |
| Local Storage | SharedPreferences |

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Dart SDK ^3.13.1

### Setup

1. Clone the repository
2. Run `flutter pub get`
3. Configure Supabase credentials in `lib/main.dart`
4. Configure Cloudinary credentials in `lib/core/repositories/storage_repository.dart`
5. Run the app: `flutter run`

### Project Structure

```
lib/
├── main.dart                          # App entry point
├── app/                               # App-level config (routes, theme, constants)
├── core/                              # Shared infrastructure (repos, services, widgets)
└── features/                          # Feature modules (auth, home, talent, etc.)
```

### Architecture Rules

- **Screens** → Only import providers, widgets, and go_router
- **Providers** → Only import repositories, models, and flutter_riverpod
- **Repositories** → Only import Supabase SDK, models, and utils
- **Models** → Only import json_utils and dart core

## License

Private — All rights reserved.
