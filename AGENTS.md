# AGENTS.md

## Purpose

This repository contains `CodexManager`, a macOS SwiftUI menu bar app for managing local Codex account profiles.

The codebase is split into:

- `Sources/CodexManagerApp`: SwiftUI app entry point, windows, view models, and views
- `Sources/CodexManagerCore`: profile storage, auth file switching, Codex app-server usage reads, and related models/services
- `Sources/CodexManagerSelfTest`: lightweight self-tests run without XCTest
- `scripts/build-app.sh`: creates a local `.app` bundle in `.build/`

## Stack

- Swift 5.9
- Swift Package Manager
- macOS 13+
- SwiftUI/AppKit interop where needed

## Working Rules

- Prefer small, local changes that fit the current structure.
- Keep app-layer UI code in `CodexManagerApp` and business/file-system logic in `CodexManagerCore`.
- Avoid introducing new dependencies unless clearly necessary.
- Preserve the app's current privacy model: account secrets live in isolated local Codex homes; metadata stays in app-managed storage.
- Do not add any feature that automates account rotation, bypasses Codex limits, or weakens auth isolation.

## Build And Test

Use these commands from the repository root:

```bash
swift build
swift run CodexManagerSelfTest
bash scripts/build-app.sh
```

Run the built executable directly with:

```bash
.build/debug/CodexManager
```

## Change Guidelines

- For UI changes, update the smallest relevant SwiftUI view or view model first.
- For persistence or switching behavior, keep writes atomic and avoid partial auth-file updates.
- For Codex usage/account reads, prefer graceful failure when local app-server data is unavailable.
- When changing models or storage formats, keep backward compatibility unless the task explicitly allows a migration.

## Validation Expectations

- Run `swift run CodexManagerSelfTest` after meaningful logic changes.
- Run `swift build` after UI or package changes.
- If behavior touches profile switching, storage, or auth handling, verify error paths as well as success paths.

## Notes For Agents

- Read `README.md` and `Package.swift` before larger refactors.
- Treat `.build/` as generated output.
- Be careful with any code that touches `~/.codex/auth.json` or profile-local `codex-home` directories.
- If a requested change could expose secrets or alter the app's trust boundaries, stop and clarify before implementing it.
