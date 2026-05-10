# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Silver Voice** (`silver_voice`) — a Flutter mobile app that lets Korean seniors build resumes through voice conversation. Users speak into a microphone, audio is sent to a backend server via WebSocket for STT/LLM processing, and AI responses stream back as text + TTS audio.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run (debug, Android)
flutter run

# Run with custom server endpoints
flutter run --dart-define=SERVER_URL=https://your-server/ --dart-define=WS_URL=wss://your-server/voice/ws --dart-define=USER_ID=my-user

# Analyze (lint)
flutter analyze

# Run tests (none exist yet)
flutter test
```

Android build uses Gradle 8.5 with Java 17 / Kotlin targeting JVM 17.

## Architecture

### Service Layer (`lib/services/`)
State lives in `_MainScreenState` in `main.dart`, which owns three services:

- **WebSocketService** — persistent WebSocket connection to backend with exponential-backoff reconnect (max 5 attempts). Receives JSON messages (`ready`, `resume_state`, `transcript`, `llm_token`, `reply_done`, `error`) and binary audio chunks. Callbacks push events up to `MainScreen`.
- **AudioService** — microphone recording via `record` package, TTS playback via `audioplayers`. Binary audio chunks from WebSocket are queued and played sequentially; temp files are cleaned up after playback.
- **ApiService** — HTTP client wrapping two REST endpoints: `POST /recommend/{userId}` (job recommendations) and `DELETE /resume/{userId}` (resume reset). Returns typed `ApiResult<T>`.

### Configuration (`lib/config/app_config.dart`)
Server URLs and user ID are injected via `--dart-define` flags, with hardcoded defaults pointing to a RunPod proxy. UI constants for senior-friendly sizing (font sizes, 48dp minimum touch targets) are centralized here.

### Platform Abstraction (`lib/services/file_helper_*.dart`)
Conditional imports (`file_helper_io.dart` / `file_helper_web.dart` / `file_helper_stub.dart`) abstract file I/O so the app compiles for both native and web targets. Native uses `dart:io`; web uses an in-memory map.

### Screen Structure (`lib/screens/`)
Bottom navigation with 4 tabs — all are stateless widgets receiving data and callbacks from `MainScreen`:
- **HomeTab** (index 1, default) — voice recording interface with press-and-hold mic button
- **JobsTab** (index 0) — AI-recommended job listings with 2-minute client-side cache
- **ResumeTab** (index 2) — displays resume fields populated from voice conversation
- **MyPageTab** (index 3) — settings and account info

### WebSocket Message Protocol
Outbound: `sync_resume` (request resume state), `turn` + binary audio (voice input).
Inbound: `ready`, `resume_state`/`resume_updated`, `transcript` (STT result), `llm_token` (streaming LLM response), `reply_done`, `error`.

## Conventions

- All user-facing strings are in Korean
- UI follows senior-friendly accessibility guidelines: large fonts (`AppConfig.fontSizeTitle` 26px, body 18px, caption 16px), 48dp minimum touch targets, `Semantics` widgets on interactive elements
- LLM token streaming uses a 50ms throttle timer to batch `setState` calls
- `DebugLogger` provides 3-level structured logging (app events, API/WS traffic, errors with stack traces); in-app debug panel toggled via AppBar bell icon
- Lint config: `package:flutter_lints/flutter.yaml`
