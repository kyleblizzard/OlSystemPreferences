# CLAUDE.md — OlSystemPreferences

## Project: OlSystemPreferences

Mac OS X Snow Leopard (10.6) System Preferences recreation with full parity with modern macOS System Settings.

### Tech Stack
- Swift 5.10 + AppKit (programmatic UI, no SwiftUI)
- Xcode project via `xcodegen` from `project.yml`
- macOS 14.0+, unsandboxed, ad-hoc signed

### Build
```bash
xcodegen generate && xcodebuild build -project OlSystemPreferences.xcodeproj -scheme OlSystemPreferences -configuration Debug
```

### Architecture
- `PreferenceItem` struct — title, sfSymbol, iconColor, category, settingsURL
- `PaneProtocol` — interface for native pane VCs
- `PaneRegistry` — factory for creating pane instances
- `GridViewController` → NSCollectionView with category sections
- `MainWindowController` → toolbar + grid, URL launching
- `SnowLeopardColors` / `SnowLeopardFonts` in Constants.swift
- `SkeuomorphicIconFactory` — glossy Aqua-style icons with SF Symbol overlays
- `RedirectPaneViewController` — graceful fallback for panes without native implementations
