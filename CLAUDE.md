# OlSystemPreferences

A Mac OS X Snow Leopard (10.6) System Preferences recreation that provides full parity with modern macOS System Settings.

## Current Version: 0.000

**Launcher mode** — all 35 preference panes are displayed in a Snow Leopard-styled grid. Clicking any icon opens the corresponding pane in the real System Settings via deep links (`x-apple.systempreferences:` URL scheme).

## Next Version: 0.001

### Goal: Hybrid Mode + Pixel-Perfect Snow Leopard

Two parallel tracks:

**Track 1 — Native panes where possible, fallback links where not:**
- Panes that CAN be built natively (public APIs, safe defaults): Appearance, Dock, Sound, Displays, Keyboard, Mouse, Trackpad, Desktop & Screen Saver, Battery, Date & Time, Sharing, Software Update, Startup Disk, Time Machine, Lock Screen, Notifications, Control Center
- Panes that MUST remain as links (private APIs, restricted entitlements): Apple ID, Wallet & Apple Pay
- Panes in the grey zone (fragile/private but possible): Screen Time, Focus, Touch ID, Passwords, Game Center — attempt native, fall back to link if blocked
- The grid icon should behave identically regardless: click opens either the native pane OR System Settings, transparent to the user

**Track 2 — Pixel-perfect Snow Leopard visual fidelity:**
- Category header bars: exact gradient (#6E6E6E → #585858), 1px highlight/shadow lines, white Lucida Grande Bold 11pt with text shadow
- Grid icons: replace SF Symbols with skeuomorphic icon assets (32×32 @2x PNGs) matching the original Snow Leopard preference pane icons
- Selection highlight: Aqua blue gradient with 1px darker border, white text on selection
- Window chrome: unified toolbar appearance, non-resizable in grid view
- Toolbar: pill-shaped back/forward segmented control (custom drawn), Show All icon, classic search field
- Pane views: Aqua-style tabs (rounded top), grouped box sections, classic slider/popup/checkbox styling where possible
- App icon: the classic light switch icon
- Font: Lucida Grande everywhere (already implemented)
- Force light mode (already implemented via `.aqua` appearance)

## Architecture

### Launcher (v0.000 — current)
```
PreferenceItem (struct) → title, sfSymbol, iconColor, category, settingsURL
GridViewController → NSCollectionView with Snow Leopard-styled sections
MainWindowController → toolbar + grid, delegates clicks to open URLs
```

### Hybrid (v0.001 — next)
```
PreferenceItem gains: hasNativePane, nativePaneController
Click flow: hasNativePane ? navigate to pane : open System Settings URL
Native panes reuse existing PaneProtocol + pane VCs (already built for 7 panes)
Window resize animation on pane entry (already built in NSWindow+Animation)
NavigationManager back/forward (already built, currently unused)
```

### Key files
- `Models/PreferenceItem.swift` — pane definitions + System Settings URL registry
- `Window/MainWindowController.swift` — window, toolbar, navigation
- `Window/GridViewController.swift` — icon grid with category sections
- `Window/GridItemView.swift` — Snow Leopard-styled grid item + section header
- `Utilities/Constants.swift` — dimensions, colors (SnowLeopardColors), fonts (SnowLeopardFonts)
- `Protocols/PaneProtocol.swift` — interface for native pane implementations
- `Panes/` — 7 native pane VCs already built (General, Dock, Sound, Desktop, Displays, Keyboard, Mouse)
- `Services/` — AudioService, DefaultsService, DockService

## Build

```bash
xcodegen generate
xcodebuild build -project OlSystemPreferences.xcodeproj -scheme OlSystemPreferences -configuration Debug
```

Run from: `DerivedData/.../Build/Products/Debug/OlSystemPreferences.app`

## Tech Stack
- Swift 5.10, AppKit, programmatic UI (no SwiftUI, no XIBs)
- macOS 14.0+ deployment target
- Unsandboxed (needs system access), ad-hoc signed
- CFPreferences, CoreAudio, CoreGraphics for native pane implementations

## System Settings Deep Link Format
```
x-apple.systempreferences:<bundle-id>
```
Example: `x-apple.systempreferences:com.apple.Sound-Settings.extension`

Full URL registry is in `PreferenceItem.swift`. Some URLs may need adjustment per macOS version — test after OS updates.

## Panes That Can Never Be Native
- **Apple ID** — requires Apple server-side app identity validation
- **Wallet & Apple Pay** — requires Secure Element + Apple server validation

These will always be deep links to System Settings.

## Conventions
- No SwiftUI — pure AppKit with programmatic layout
- Snow Leopard visual style: Lucida Grande, Aqua highlights, dark gradient headers, light gray backgrounds
- Prefer NSColor constants in `SnowLeopardColors` and fonts in `SnowLeopardFonts`
- Each native pane conforms to `PaneProtocol`
- Use `DefaultsService` for reading/writing system preferences, not raw UserDefaults
- Debounce system changes that trigger process restarts (e.g. `killall Dock`)
