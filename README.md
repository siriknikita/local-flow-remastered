# LocalFlow

A local-first voice capture system. Record thoughts on Android, have them transcribed on your MacBook — all over the local network, no cloud required.

## How It Works

1. Open the Android app
2. App discovers your MacBook on the local network
3. Tap to record your voice
4. Audio is sent to your MacBook over WiFi
5. MacBook receives audio and routes it to SuperWhisper Pro for transcription
6. Transcribed text is saved to a folder on your Mac

## Features

### Android App
- **mDNS discovery** — automatically finds your MacBook on the local network
- **Manual IP fallback** — enter Mac's address directly if discovery fails
- **6-digit pairing** — simple one-time pairing with code displayed on Mac
- **Tap-to-record** — large record button with pulse animation and duration timer
- **Automatic upload** — audio sent immediately after recording stops
- **Upload feedback** — clear success/failure status with retry on reconnect
- **Haptic feedback** — on record start/stop
- **Offline queueing** — recordings saved locally when Mac is unreachable

### macOS Receiver
- **Menu bar app** — lightweight, always-available status and controls
- **HTTP server** — Vapor-based, accepts audio uploads on configurable port
- **Bonjour advertisement** — publishes `_localflow._tcp` for Android discovery
- **Token auth** — paired devices authenticated via Bearer token
- **Configurable directories** — separate paths for audio files and transcriptions
- **Auto-transcribe** — routes audio to SuperWhisper Pro via CLI
- **Transcription monitoring** — watches SuperWhisper recordings folder for results
- **Fallback backend** — saves audio even if SuperWhisper isn't running

### SuperWhisper Integration
- Sends audio via `open -a superwhisper` CLI
- Monitors `~/Documents/Apps/superwhisper/recordings/` for new transcription entries
- Extracts text from `meta.json` `result` field
- Uses whichever SuperWhisper mode is currently active
- Decoupled via `TranscriptionBackend` protocol — swappable for other engines

## Flows

### Discovery & Pairing
```
Android                          MacBook
  │                                │
  ├── mDNS scan ──────────────────▶│ (Bonjour _localflow._tcp)
  │◀── service resolved ──────────┤
  ├── POST /api/pair ─────────────▶│
  │                                ├── show 6-digit code on screen
  │◀── "enter code on Mac" ───────┤
  ├── POST /api/pair/confirm ─────▶│
  │◀── {token, serverName} ───────┤
  │    (token stored locally)      │
```

### Record & Upload
```
Android                          MacBook
  │                                │
  ├── tap record                   │
  ├── ... recording ...            │
  ├── tap stop                     │
  ├── POST /api/upload ──────────▶│
  │   (multipart audio + token)    ├── save audio to configured dir
  │◀── {status: received} ────────┤
  │                                ├── open audio -a superwhisper
  │                                ├── watch recordings dir
  │                                ├── read meta.json → extract text
  │                                └── save .txt to transcription dir
```

### Retry on Failure
```
Android
  ├── upload fails (Mac offline / network error)
  ├── recording saved to local queue
  ├── exponential backoff retry (15s, 30s, 60s, 5m, 15m)
  ├── on WiFi reconnect → immediate retry
  └── user can view/retry/delete pending uploads
```

## Tech Stack

### Android
| Component | Technology |
|---|---|
| Language | Kotlin |
| UI | Jetpack Compose + Material 3 |
| DI | Hilt |
| Network | OkHttp (multipart upload) |
| Discovery | NsdManager (mDNS) |
| Persistence | DataStore (pairing), Room (upload queue) |
| Background | WorkManager (retry) |
| Architecture | MVVM |

### macOS
| Component | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI (MenuBarExtra) |
| Server | Vapor 4 (embedded HTTP) |
| Discovery | Bonjour / NetService |
| Transcription | SuperWhisper Pro via CLI |

## Build & Run

### Android

Requires Android Studio and JDK 17.

```bash
cd android-app
just build          # Build debug APK (copies to clipboard on macOS)
just test           # Run unit tests
just install        # Install on connected device
just deploy         # Build + wireless install via adeploy
just lint           # Lint check
just check          # Build + test + lint
just clean          # Clean build artifacts
just release        # Build release APK
```

### macOS

Requires Xcode and Swift 5.10+.

```bash
cd macos-app/LocalFlow
swift run           # Build and run the receiver
swift build         # Build only
swift test          # Run tests
```

## Project Structure

```
local-flow-remastered/
├── android-app/                    # Android Studio project
│   ├── app/src/main/java/com/localflow/
│   │   ├── ui/                     # Compose screens (Main, Discovery, Pairing)
│   │   ├── discovery/              # mDNS via NsdManager
│   │   ├── recording/              # MediaRecorder wrapper
│   │   ├── upload/                 # OkHttp multipart upload
│   │   ├── data/                   # API client, DataStore, Room
│   │   ├── model/                  # Data classes and sealed states
│   │   └── di/                     # Hilt modules
│   ├── justfile                    # Task runner
│   └── scripts/                    # Shell build scripts
├── macos-app/LocalFlow/            # Swift Package
│   └── Sources/
│       ├── App/                    # SwiftUI app entry + AppState
│       ├── Server/                 # Vapor HTTP server + controllers
│       ├── Discovery/              # Bonjour advertisement
│       ├── Transcription/          # Backend protocol + SuperWhisper + Stub
│       ├── Models/                 # Configuration, PairedDevice, UploadRecord
│       └── Views/                  # MenuBar + Settings UI
└── protocol/
    └── API.md                      # HTTP API contract
```

## Configuration (macOS)

| Setting | Default |
|---------|---------|
| Server port | 8080 |
| Audio save directory | ~/Documents/LocalFlow/audio |
| Transcription save directory | ~/Documents/LocalFlow/transcriptions |
| SuperWhisper recordings path | ~/Documents/Apps/superwhisper/recordings |
| Auto-transcribe | Enabled |
| Auto-delete audio after transcription | Disabled |
| Filename prefix | localflow |

## Min SDK

Android: API 26 (Android 8.0)
macOS: 14.0 (Sonoma)

## License

MIT
