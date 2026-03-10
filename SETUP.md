# Gridlock - Xcode Project Setup

## Quick Start

1. **Open Xcode** (15.0+ recommended)

2. **Create New Project:**
   - File > New > Project
   - Choose: iOS > App
   - Product Name: `Gridlock`
   - Team: Your development team
   - Organization Identifier: `com.yourdomain`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 16.0
   - Uncheck: Include Tests (add later)

3. **Replace Default Files:**
   - Delete the auto-generated `ContentView.swift` and `GridlockApp.swift` from the project
   - In Finder, select ALL folders inside the `Gridlock/` source directory:
     - `App/`, `Core/`, `Scenes/`, `UI/`, `Themes/`, `Extensions/`, `Resources/`
   - Drag them into the Xcode project navigator under the `Gridlock` group
   - Make sure "Copy items if needed" is checked
   - Make sure "Create groups" is selected
   - Target: Gridlock

4. **Project Settings:**
   - Select the Gridlock target > General
   - Deployment Target: iOS 16.0
   - Device Orientation: Portrait only (uncheck Landscape Left/Right)
   - Status Bar Style: Light Content
   - Hide status bar: Yes

5. **Info.plist:**
   - The `App/Info.plist` contains all required keys
   - Set it as the project's Info.plist in Build Settings > Packaging > Info.plist File

6. **Build Settings:**
   - Swift Language Version: Swift 5.9
   - Under Signing & Capabilities:
     - Add "Game Center" capability
     - Add "In-App Purchase" capability
     - Add "Push Notifications" capability

7. **Dependencies (Optional - for ads):**
   - File > Add Package Dependencies
   - Google Mobile Ads SDK: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
   - Version: 11.0.0+

8. **Build & Run:**
   - Select an iPhone simulator (iPhone 15 Pro recommended)
   - Cmd+B to build
   - Cmd+R to run

## Architecture Overview

```
App/             - Entry point, AppDelegate, Info.plist
Core/
  GameEngine/    - Grid model, pieces, scoring, game state, power-ups
  Audio/         - Sound effects (procedural) + haptic feedback
  Data/          - User progress, statistics, daily streaks
  Monetization/  - Ad manager (stub), IAP (StoreKit 2), config
Scenes/          - SpriteKit game scene + extensions
UI/              - SwiftUI views (menu, settings, stats, store)
Themes/          - Theme protocol + 4 themes (Classic, Neon, Ocean, Space)
Extensions/      - Helper extensions + TextureGenerator
Resources/       - Placeholder for future assets
```

## Common Build Fixes

- If you see "No such module 'GoogleMobileAds'": The AdManager uses stub implementations. Ads are non-critical for development.
- If GameKit errors appear: Add the Game Center capability in Signing & Capabilities.
- Font warnings: The app uses system SF fonts which are always available.
