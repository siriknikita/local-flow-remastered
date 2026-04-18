# LocalFlow — Development Guide

## Project Overview

LocalFlow is a local-first voice capture system: Android app records audio, uploads over LAN to a macOS receiver, which saves and transcribes via SuperWhisper Pro. No cloud, no accounts, no internet required. Two separate apps communicating over HTTP on the local network.

## Architecture

Two independent apps connected by an HTTP API:

- **Android app** — Kotlin/Compose client that discovers, pairs with, records audio, and uploads to the Mac
- **macOS app** — Swift/Vapor menu bar receiver that accepts uploads, saves files, and triggers transcription

### Communication Protocol

HTTP upload server on Mac + Android HTTP client. Bonjour/mDNS for discovery. 6-digit pairing code for auth, then Bearer token on all subsequent requests.

Endpoints: `GET /api/health`, `POST /api/pair`, `POST /api/pair/confirm`, `POST /api/upload`. Full spec in `protocol/API.md`.

## Android App (`android-app/`)

### Package Structure

```
app/src/main/java/com/localflow/
├── LocalFlowApp.kt                  # @HiltAndroidApp entry point
├── di/AppModule.kt                  # Hilt singleton providers
├── model/                           # Data classes and sealed states
│   ├── PairedDevice.kt              # Server connection info + auth token
│   ├── ConnectionState.kt           # Disconnected/Discovering/Found/Connected/Error
│   ├── RecordingState.kt            # Idle/Recording/Stopping
│   └── UploadResult.kt              # Idle/Uploading/Success/Failure/Queued
├── discovery/
│   └── NsdDiscoveryManager.kt       # mDNS discovery via NsdManager (_localflow._tcp)
├── data/
│   ├── local/PairedDeviceStore.kt   # DataStore persistence for paired device
│   └── remote/LocalFlowApi.kt       # OkHttp client (health, pair, upload)
├── recording/
│   └── AudioRecorder.kt             # MediaRecorder wrapper (AAC mono)
├── upload/
│   └── UploadManager.kt             # Upload orchestration with state flow
└── ui/
    ├── MainActivity.kt              # @AndroidEntryPoint, Compose host
    ├── Navigation.kt                # NavHost: main → discovery → pairing
    ├── theme/Theme.kt               # Material 3 dynamic color
    ├── main/
    │   ├── MainScreen.kt            # Record button, connection status, upload result
    │   └── MainViewModel.kt         # Recording + upload coordination
    ├── discovery/
    │   ├── DiscoveryScreen.kt       # mDNS search + manual IP entry
    │   └── DiscoveryViewModel.kt
    └── pairing/
        ├── PairingScreen.kt         # 6-digit code entry
        └── PairingViewModel.kt
```

### Key Patterns

- **MVVM**: ViewModels expose StateFlow, Compose screens collect via `collectAsState()`
- **Sealed states**: ConnectionState, RecordingState, UploadResult — exhaustive when blocks
- **Hilt DI**: All managers are @Singleton, injected into ViewModels
- **OkHttp**: Direct multipart POST, no Retrofit (simple enough without it)
- **DataStore**: Paired device JSON stored in preferences datastore

### Audio Format

MediaRecorder with AAC mono 44.1kHz 128kbps → `.m4a` files. SuperWhisper accepts this format.

## macOS App (`macos-app/LocalFlow/`)

### Package Structure

```
Sources/
├── App/
│   ├── LocalFlowApp.swift           # @main SwiftUI MenuBarExtra
│   └── AppState.swift               # ObservableObject: server, devices, uploads
├── Server/
│   ├── LocalFlowServer.swift        # Vapor Application lifecycle
│   ├── UploadController.swift       # POST /api/upload — save + trigger transcription
│   └── PairingController.swift      # POST /api/pair, /api/pair/confirm
├── Discovery/
│   └── BonjourAdvertiser.swift      # NetService publish _localflow._tcp
├── Transcription/
│   ├── TranscriptionBackend.swift   # Protocol + TranscriptionResult + errors
│   ├── SuperWhisperBackend.swift    # open -a superwhisper + FSEvents polling
│   └── StubBackend.swift            # Fallback when SuperWhisper not running
├── Models/
│   ├── AppConfiguration.swift       # Codable settings (dirs, port, toggles)
│   ├── PairedDevice.swift           # Device + DeviceStore (JSON file)
│   └── UploadRecord.swift           # Upload tracking with TranscriptionStatus
└── Views/
    ├── MenuBarView.swift            # Status, devices, pairing code, recent uploads
    └── SettingsView.swift           # Tabs: General, Transcription, Devices
```

### Key Patterns

- **Menu bar app**: MenuBarExtra with popover, no dock icon
- **Embedded Vapor**: HTTP server runs inside the SwiftUI app process
- **TranscriptionBackend protocol**: `transcribe(audioFilePath:) async throws -> TranscriptionResult`
- **SuperWhisper integration**: Snapshot recordings dir → `open -a superwhisper` → poll for new folder → parse `meta.json` → extract `result` field
- **Sequential transcription**: One file at a time to avoid correlation ambiguity
- **Config persistence**: JSON in `~/Library/Application Support/LocalFlow/`
- **Device persistence**: Paired devices in JSON file, validated on each request

### SuperWhisper Facts

- Recordings at: `~/Documents/Apps/superwhisper/recordings/{unix_timestamp}/`
- Each folder contains: `meta.json` + `output.wav`
- `meta.json` has `result` (transcription text), `rawResult`, `segments`, `processingTime`, `modeName`
- CLI: `open /path/to/file.wav -a superwhisper` — processes with active mode
- Deep links: `superwhisper://mode?key=KEY` for mode switching

## Build Commands

### Android (`cd android-app`)

```bash
just build          # assembleDebug (copies APK to clipboard on macOS)
just test           # testDebugUnitTest
just test-android   # connectedDebugAndroidTest
just install        # installDebug
just deploy         # build + wireless install via adeploy
just lint           # lintDebug
just clean          # clean
just check          # build + test + lint
just release        # assembleRelease
```

Shell scripts also available in `scripts/`.

### macOS (`cd macos-app/LocalFlow`)

```bash
swift run           # Build and run
swift build         # Build only
swift test          # Run tests
```

## Testing

### Automated
- Android: unit tests via `just test` (no tests written yet)
- macOS: `swift test` (no tests written yet)

### Manual Test Plan
- Mac starts → menu bar icon → server status "Running"
- `dns-sd -B _localflow._tcp` shows the service
- Android discovers Mac within 5 seconds
- Pairing: code on Mac, enter on Android, token stored
- Record → upload → file on Mac within 3s
- Disconnect WiFi during upload → queued → reconnect → auto-uploaded
- Upload with bad token → 401 rejected
- SuperWhisper not running → audio saved, stub fallback used
- Curl test: `curl -F "audio=@test.wav" -H "Authorization: Bearer TOKEN" http://localhost:8080/api/upload`

## Development Workflow

- Build after each change to catch errors early
- Android: `just build` from `android-app/`
- macOS: `swift build` from `macos-app/LocalFlow/`
- Make granular, atomic commits — one logical unit per commit

## Non-Goals (Phase 1)

- Cloud backend / remote relay
- User accounts / authentication beyond LAN pairing
- iOS / Windows / Linux support
- Multiple simultaneous Mac targets
- Real-time audio streaming (record-then-send only)
- End-to-end encryption (trusted LAN assumed)
- Push-to-talk / continuous capture modes
- Obsidian integration / clipboard actions
