# Monocle Radio

Native macOS menu bar radio player for [Monocle 24](https://monocle.com/radio/).

Live stream and on-demand episodes — one click from your menu bar.

![Monocle Radio](screenshot.png)

## Install

**Requirements:** macOS 14 (Sonoma) or later.

1. Download `MonocleRadio-1.0.0.dmg` from [Releases](https://github.com/hjbarraza/MonocleRadio/releases)
2. Open the DMG and drag **Monocle Radio** to Applications
3. Launch from Applications

### Gatekeeper Notice

This app is not notarized with Apple (no $99/yr developer account). macOS will block it on first launch. To open it:

**Option A — Right-click:**
```
Right-click "Monocle Radio.app" → Open → click "Open" in the dialog
```

**Option B — Terminal (removes quarantine flag):**
```sh
xattr -cr /Applications/Monocle\ Radio.app
```

**Option C — System Settings:**
```
System Settings → Privacy & Security → scroll down → click "Open Anyway"
```

After the first launch, macOS will remember your choice.

## Usage

The app lives in your menu bar — no Dock icon. Click the Monocle monogram to open the popover.

### Controls

| Action | How |
|--------|-----|
| Play / Pause | Click ▶/❚❚ button, or press Space |
| Volume | Slider in the footer |
| Browse shows | Click any show in the left panel |
| Play episode | Click any episode in the right panel |
| Live stream | Click "Monocle 24 (Live)" at the top of the show list |
| Quit | Click ✕ in the footer |

### Features

- **Live stream** — Monocle 24 AAC auto-plays on launch
- **25 shows** — full catalog with cover art
- **On-demand episodes** — scraped from monocle.com
- **Media keys** — play/pause from keyboard, AirPods, headphones
- **Control Center** — Now Playing widget shows current track
- **AirPlay** — works automatically via AVPlayer
- **Auto-reconnect** — stream recovers after network drops
- **Launch at Login** — toggle in the footer
- **Dark mode** — automatic

## iOS & iPadOS

The iOS app shares its playback core with the Mac app (see the
[port plan](docs/IOS_IPADOS_PLAN.md)). It is for personal sideloading —
there is no App Store release. The Xcode project is generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen                      # generates MonocleRadio.xcodeproj from project.yml
open MonocleRadio.xcodeproj
```

In Xcode: pick the **MonocleRadioiOS** scheme, set your personal team under
*Signing & Capabilities*, and Run on your device. With free provisioning the
install expires after 7 days — re-run from Xcode to re-sign.

## Build from Source

```sh
git clone https://github.com/hjbarraza/MonocleRadio.git
cd MonocleRadio
make app    # → build/Monocle Radio.app (~5MB)
make dmg    # → build/MonocleRadio-1.0.0.dmg (~2MB)
make run    # debug build and run
```

Requires Xcode command line tools (`xcode-select --install`).

## Architecture

5 Swift files, 1 external dependency ([SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML scraping).

The playback core lives in a shared SwiftPM library (`MonocleRadioKit`) so the
macOS app and the planned iOS/iPadOS app ([plan](docs/IOS_IPADOS_PLAN.md))
build from the same code.

```
Sources/MonocleRadioKit/      # shared core (macOS + iOS)
├── AudioEngine.swift         # AVPlayer — streaming, ICY metadata, auto-reconnect
├── RadioViewModel.swift      # @Observable — state, media keys, Now Playing
└── Models.swift              # Show/Episode catalog + SwiftSoup scraper

MonocleRadio/                 # macOS menu bar app
├── MonocleRadioApp.swift     # @main — MenuBarExtra scene
└── Views/
    └── PopoverView.swift     # All UI in one file
```
