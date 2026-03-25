## 🎬 VideoEditor (R&D Project)

VideoEditor is an **R&D / educational** iOS video editing app experiment targeting iOS 16.0+. The goal is to explore modern Swift, UIKit, and media technologies (e.g. AVFoundation) with a **sustainable and testable** architecture.

> **Production notice:** This project is currently a “playground” and should not be considered production-ready.

---

## Project vision

- **Modularity**: Clear separation of UI, Domain, and Data layers.
- **Testability**: Dependencies are injected via DI.
- **Simplicity**: KISS principle; avoid unnecessary abstraction.
- **UIKit-first**: Screens are built with programmatic UIKit + Auto Layout.

---

## Requirements

- **Xcode**: 26.3
- **iOS Deployment Target**: 16.0+
- **Language**: Swift (async/await preferred)

---

## Run

1. Open `VideoEditor.xcodeproj` in Xcode.
2. Select a Simulator or a physical device.
3. Press `Run` (⌘R).

> Note: If you hit first-run / caching issues, deleting the app from the Simulator and re-running, or using `Product > Clean Build Folder` can help.

---

## App lifecycle

The app uses UIKit scene-based lifecycle:

- **`AppDelegate`**: Scene configuration and (when needed) the Core Data stack.
- **`SceneDelegate`**: Creates `UIWindow` + the root `UINavigationController` and loads the initial screen.

The initial screen is `Landing`, and navigation is handled via a **Router**.

---

## Navigation

For simple flows, the project uses a **Router** approach:

- **`AppRouter`**: Builds screens from the `Route` enum and manages navigation.
- View controllers receive the router via DI (constructor injection).

---

## Folder structure (high level)

- **`App/`**: App lifecycle + root navigation (`AppDelegate`, `SceneDelegate`, `AppRouter`)
- **`Presentation/`**: UIKit screens and UI components
- **`Domain/`**: Business rules, models, protocols (Use Case / Repository contracts)
- **`Data/`**: Repository implementations, persistence (e.g. Core Data)
- **`Engine/`**: Rendering/media engine (e.g. AVFoundation/Metal/Core Image)
- **`Shared/`**: Shared extensions, utilities, helpers
- **`Resources/`**: Asset catalog and Info.plist (target usage)

---

## Architectural principles

- **Clean Architecture**: UI → (Use Case) → Domain → Data/Engine
- **DI (constructor-based)**: View controllers receive dependencies via initializers.
- **Optionals**: Safe handling with `guard` / `if let`, no force unwraps.
- **Memory**: Prevent retain cycles (use `weak self` in closures).

---

## Roadmap (short)

- Media import (Photos / Files)
- Timeline + trim/crop
- Export pipeline (presets/bitrate)
- Testing infrastructure (XCTest, mocks)