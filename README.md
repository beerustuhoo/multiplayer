# Tic Tac Toe - Multiplayer Mobile Game

A real-time multiplayer Tic-Tac-Toe game built entirely in **Dart** — Flutter for the mobile client and a Dart shelf/WebSocket server for the backend.

## Project Overview

Play Tic-Tac-Toe with friends from anywhere in the world! Features include:

- **Registration & Authentication** — email/password with password strength validation
- **Email Verification** — verify your account via a 6-digit code
- **Password Recovery** — email-based password reset
- **Persistent Sessions** — stay logged in across app restarts
- **Opponent Search** — find players by username or email
- **Game Invitations** — send/receive/accept/decline game invites
- **Real-Time Gameplay** — WebSocket-powered instant updates
- **Server-Authoritative** — all game logic validated server-side
- **Chess-Clock Timers** — 5, 10, or 15 minute time controls per player
- **Game Restart** — request restart with 30-second accept/decline window
- **Disconnect Handling** — 2-minute reconnection window, auto-forfeit
- **Move History** — real-time move log side panel
- **Play vs Bot** — offline mode with AI opponent
- **Data Security** — passwords hashed (HMAC-SHA256), emails/usernames AES-256 encrypted

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter (Dart) |
| Backend Server | Dart (shelf + shelf_router + dart:io WebSocket) |
| Database | SQLite (via sqlite3 package) |
| Auth | JWT (dart_jsonwebtoken) |
| Real-time | Raw WebSocket (JSON protocol) |
| Email | mailer package (configurable SMTP) |

## Project Structure

```
tictactoe/
├── lib/                    # Flutter app source
│   ├── main.dart           # App entry point
│   ├── config/             # Constants & configuration
│   ├── models/             # Data models (User, Game, Invite)
│   ├── services/           # API & WebSocket services
│   ├── providers/          # State management (Provider)
│   ├── screens/            # UI screens
│   │   ├── auth/           # Login, Register, Verify, Reset
│   │   ├── home/           # Home lobby
│   │   ├── game/           # Game screen & Bot game
│   │   └── search/         # Opponent search
│   ├── widgets/            # Reusable widgets
│   └── theme/              # App theme
├── server/                 # Dart backend server
│   ├── bin/server.dart     # Server entry point
│   ├── lib/                # Server modules
│   ├── pubspec.yaml        # Server dependencies
│   └── Dockerfile          # Docker build
├── docker-compose.yml      # One-command server start
└── pubspec.yaml            # Flutter dependencies
```

## Setup & Installation

### Prerequisites

- **Flutter SDK** (3.10+): https://docs.flutter.dev/get-started/install
- **Dart SDK** (3.0+): Included with Flutter
- **Docker** (optional, for one-command server start)
- For Windows server dev: download `sqlite3.dll` from https://www.sqlite.org/download.html and place it in `server/` or your PATH

### 1. Start the Backend Server

#### Option A: Docker (Recommended - Single Command)

```bash
docker compose up --build
```

The server starts on port 3000.

#### Option B: Run directly with Dart

```bash
cd server
./start.ps1
```

The server starts on `http://localhost:3000`.

> **Note:** On Windows, ensure `sqlite3.dll` is available. On Linux/macOS, SQLite is typically pre-installed.

### 2. Configure the Flutter App

This project uses `SERVER_BASE_URL` at build time, so you do not need to edit source code to switch environments.

- Local backend example:
  - `--dart-define=SERVER_BASE_URL=http://10.0.2.2:3000` (Android emulator)
- Render/backend URL example:
  - `--dart-define=SERVER_BASE_URL=https://your-service.onrender.com`

### 3. Run the Flutter App

```bash
flutter pub get
flutter run --dart-define=SERVER_BASE_URL=http://10.0.2.2:3000
```

### 4. Build APK

```bash
flutter build apk --release --dart-define=SERVER_BASE_URL=https://your-service.onrender.com
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Reviewer Guide

### Running the Backend

The simplest way is Docker:

```bash
docker compose up --build
```

This starts the server with all dependencies — no manual runtime or library installation needed.

### Installing the App

Prebuilt APK location in this repository/workspace:

- `build/app/outputs/flutter-apk/app-release.apk`

Recommended review build command:

```bash
flutter build apk --release --dart-define=SERVER_BASE_URL=https://your-service.onrender.com
```

If your Git host rejects large files, upload the same APK to a GitHub Release/Drive/Dropbox and paste the public URL here:

- APK download URL:  https://drive.google.com/file/d/1Tc7QOS1E_jkuQkcW8Gtzn90Iduox3spk/view?usp=drive_link

#### Option 1: Install APK on Android Device

1. Transfer the `.apk` file to your Android device
2. Open the file and tap "Install" (enable "Install from unknown sources" if prompted)
3. Launch "Tic Tac Toe" from your app drawer

#### Option 2: Lightweight Emulator (NoxPlayer / BlueStacks)

1. Install NoxPlayer or BlueStacks
2. Drag and drop the `.apk` file into the emulator window
3. Launch the app from the emulator's home screen

#### Option 3: Browser-Based Emulator (Appetize.io)

1. Go to https://appetize.io
2. Upload the `.apk` file
3. Run the app directly in your browser

### Testing with Two Players

To test multiplayer:

1. Start the server
2. Run the app on two emulators (or one emulator + one physical device)
3. Register two different accounts
4. Search for the other player and send a game invite
5. Accept the invite on the other device — the game begins!

## Game Features

### Tic-Tac-Toe Rules
- 3x3 grid, two players (X and O)
- Take turns placing your mark
- First to get 3 in a row (horizontal, vertical, or diagonal) wins
- If all cells are filled with no winner, it's a draw

### Timer System
- Each player has their own countdown clock
- Choose 5, 10, or 15 minute time controls
- Only the active player's timer ticks
- Running out of time means you lose

### Restart System
- Either player can request a restart
- Game pauses while waiting for response
- Opponent has 30 seconds to accept/decline
- If no response, the restart is cancelled

### Disconnect Handling
- If a player disconnects, the game pauses
- The remaining player sees a 2-minute countdown
- If the player reconnects in time, the game resumes
- Otherwise, the disconnected player forfeits

## Additional Features

- **Play vs Bot**: Practice offline against an AI that tries to win, block, and play strategically
- **Move History**: Toggle a side panel showing every move in chronological order
- **Connection Status**: Visual indicator (Wi-Fi icon) showing server connection state
- **Modern Dark UI**: Beautiful dark theme with purple/teal accent colors
