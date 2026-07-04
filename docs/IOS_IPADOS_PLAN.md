# Monocle Radio for iOS & iPadOS — Plan and Specification

Plan for bringing the existing macOS menu bar player to iPhone and iPad as a
single adaptive SwiftUI app, sharing the playback core with the Mac app.

---

## 1. Goal and scope

**Goal:** A native iOS/iPadOS app with feature parity with the Mac app — live
Monocle 24 stream, the 25-show catalog, on-demand episode playback — plus the
behaviors iOS users expect: background audio, lock screen controls, proper
interruption handling, and an adaptive layout for iPhone and iPad.

**Distribution: personal use only.** The app is installed on the owner's own
devices via Xcode — no App Store, TestFlight, or public release. This removes
the content-IP concern and the review process entirely. With free
provisioning the app must be re-installed from Xcode every 7 days; a paid
developer account ($99/yr) extends signing to 1 year and is the only upgrade
worth considering.

**Non-goals for v1:** downloads/offline playback, CarPlay, widgets, sleep
timer, playback history/resume. These are listed in §9 as follow-ups.

**Minimum OS:** iOS 17 / iPadOS 17. The codebase already uses `@Observable`
(Observation framework), which requires iOS 17 — matching the existing
macOS 14 floor, so no shared code needs back-porting.

---

## 2. Portability audit of the existing code

| File | Portable to iOS? | Notes |
|------|------------------|-------|
| `Models.swift` | ✅ As-is | Foundation + SwiftSoup only. SwiftSoup supports iOS. |
| `AudioEngine.swift` | ✅ As-is | AVFoundation only. Needs `AVAudioSession` added *around* it (iOS-only concept), not changes *inside* it. |
| `RadioViewModel.swift` | ⚠️ Mostly | `MPRemoteCommandCenter` / `MPNowPlayingInfoCenter` code works unchanged on iOS. Two AppKit pieces must be conditionalized: `import AppKit` and `NSWorkspace.didWakeNotification` (macOS-only). Auto-play-on-launch must become macOS-only behavior (§6.3). |
| `MonocleRadioApp.swift` | ❌ macOS-only | `MenuBarExtra`, `NSRunningApplication`, `NSImage`. iOS gets its own `App` entry point. |
| `Views/PopoverView.swift` | ❌ Rewrite | Designed for a fixed 420×520 popover with hover states and a Quit button. iOS needs touch-first, adaptive UI (§5). Small pieces (progress bar, status dot logic) can be lifted. |

**Conclusion:** the playback core (~400 lines) ports nearly verbatim; the work
is packaging, iOS UI, and iOS audio-session behavior.

---

## 3. Target architecture

Extract the shared core into a SwiftPM library target consumed by both apps:

```
MonocleRadio/
├── Package.swift                      # gains .library "MonocleRadioKit", platforms [.macOS(.v14), .iOS(.v17)]
├── Sources/
│   └── MonocleRadioKit/               # SHARED — moved from MonocleRadio/
│       ├── Models.swift               # Show, Episode, catalog, scraper
│       ├── AudioEngine.swift          # AVPlayer wrapper (unchanged)
│       └── RadioViewModel.swift       # platform bits behind #if os(macOS) / os(iOS)
├── MonocleRadio/                      # macOS app (thin: entry point + PopoverView + resources)
├── MonocleRadioiOS/                   # NEW — iOS app target
│   ├── MonocleRadioiOSApp.swift       # @main, AVAudioSession setup, scenePhase handling
│   ├── Info.plist                     # UIBackgroundModes: audio
│   ├── Assets.xcassets                # iOS app icon set
│   └── Views/
│       ├── RootView.swift             # NavigationSplitView (adaptive iPhone/iPad)
│       ├── ShowListView.swift         # sidebar / root list
│       ├── EpisodeListView.swift      # detail column
│       ├── MiniPlayerBar.swift        # persistent bottom bar
│       └── NowPlayingView.swift       # full-screen player sheet
└── MonocleRadio.xcodeproj             # NEW — two app targets, both depending on the local package
```

**Build system:** SwiftPM alone cannot produce an iOS app bundle, so an Xcode
project is required. Recommendation: commit a single `MonocleRadio.xcodeproj`
containing both app targets, each depending on the local `MonocleRadioKit`
package. The existing `Makefile`/SPM flow keeps working for the Mac app during
the transition; once the Xcode project exists it can optionally replace the
Makefile's manual bundle assembly. (Alternative: XcodeGen with a committed
`project.yml` if a diff-friendly project definition is preferred.)

**View model split:** `RadioViewModel` stays shared. Platform-specific pieces:

- `#if os(macOS)`: wake observer (`NSWorkspace.didWakeNotification`), auto-play on init.
- `#if os(iOS)`: audio session activation, interruption/route-change observers (§6), foreground re-sync via `scenePhase`.

---

## 4. iOS platform requirements

| Requirement | Implementation |
|---|---|
| Background audio | `UIBackgroundModes = [audio]` in Info.plist. Without this, playback stops when the app is backgrounded — table stakes for a radio app. |
| Audio session | `AVAudioSession.setCategory(.playback)` + `setActive(true)` before first play. `.playback` silences other audio and enables background playback + lock screen controls. |
| Lock screen / Control Center | Existing `MPNowPlayingInfoCenter` code, plus artwork (§6.5) and skip commands for on-demand (§6.4). |
| App Transport Security | All endpoints are HTTPS (`monocle.com`, `streamtheworld.com`, `traffic.omny.fm`) — no ATS exceptions needed. |
| Orientation | iPhone: portrait (landscape optional, low value). iPad: all orientations, full multitasking (Split View / Slide Over / Stage Manager) — the adaptive layout in §5 handles this via size classes for free. |
| AirPlay | `AVRoutePickerView` (wrapped in `UIViewRepresentable`) in the Now Playing screen. AVPlayer handles the rest. |

---

## 5. UI specification

One adaptive layout built on `NavigationSplitView`, which collapses to a
navigation stack on compact width — a single codebase covers iPhone, iPad
full-screen, and iPad multitasking.

### 5.1 Structure (all devices)

```
┌────────────────────────────────┐
│  Content (split view / stack)  │
│                                │
├────────────────────────────────┤
│  MiniPlayerBar (persistent)    │  ← hidden only if nothing has ever played
├────────────────────────────────┤
│  (tab bar — none in v1)        │
└────────────────────────────────┘
```

- **iPhone (compact):** root list of shows → push to episode list. Mini player
  overlays the bottom, above the home indicator.
- **iPad (regular):** two-column `NavigationSplitView` — sidebar = shows,
  detail = episodes/live pane. Mini player spans the bottom of the whole
  window. Mirrors the Mac popover's two-pane layout at larger scale.

### 5.2 Show list (sidebar / root)

- Sections: **LIVE** (Monocle 24 pinned first) and **ON DEMAND** (24 shows),
  same split as the Mac app.
- Row: cover art thumbnail (~44 pt, rounded 6 pt), show name, one-line
  description. The Mac app omits art in the list; on iOS rows are large enough
  that art meaningfully aids scanning. `AsyncImage` with the existing
  `coverURL`s.
- Now-playing indicator: small animated equalizer bars (or the existing dot —
  red for live, gold `#C8A55A` for on-demand) on the trailing edge of the
  playing show's row.
- Tapping the live row starts the live stream immediately (same as Mac).
  Tapping an on-demand show navigates to its episode list (unlike Mac, where
  selection loads episodes in the adjacent pane — on compact width navigation
  *is* the selection).

### 5.3 Episode list (detail)

- Header: large cover art, show name, description.
- Episode row: title (2-line limit), episode number + date in secondary style —
  same data as Mac. Tap anywhere on the row to play.
- States, matching the Mac behavior: loading spinner, "Could not load
  episodes" + Retry button, "No episodes found". Add pull-to-refresh
  (`.refreshable`) to bypass the 30-minute cache.
- Live "show" detail (iPad, when live is selected in sidebar): the LIVE pane —
  red LIVE badge, show info, current ON AIR title from ICY metadata.

### 5.4 Mini player bar

Persistent bar above the bottom edge, visible whenever `currentShow != nil`:

- Cover thumbnail · title (episode title, or ICY stream title when live) ·
  play/pause button.
- Live indicator: red dot + "LIVE" when streaming live.
- Tap anywhere (except play/pause) → opens Now Playing sheet.
- Thin progress line along the top edge for on-demand playback.

### 5.5 Now Playing screen (sheet)

Full-height sheet with drag-to-dismiss:

- Large cover art (≤ 320 pt square), show name, episode/stream title.
- **On-demand:** seekable progress slider with elapsed/remaining labels,
  skip ±15 s buttons, play/pause. (The Mac app has no seek — the iOS player
  screen is where it belongs; `AudioEngine` gains one `seek(to:)` method,
  which the Mac UI can adopt later.)
- **Live:** red LIVE badge instead of the slider; ON AIR title from ICY
  metadata; play/pause only.
- AirPlay route picker button.
- **No volume slider** — iOS convention is hardware buttons/Control Center.
  The Mac footer's volume slider, "Start at login" toggle, and Quit button all
  have no iOS equivalent and are dropped.

### 5.6 Visual design

- Monocle gold `#C8A55A` as accent (shared constant moves into
  MonocleRadioKit or an asset catalog color).
- System backgrounds/materials; dark mode automatic (as on Mac).
- Dynamic Type: all text uses semantic font styles (the Mac code already does).
- Accessibility: VoiceOver labels on play/pause ("Play"/"Pause"), live status
  announced ("Live, on air: …"), episode rows read title + date; slider is
  adjustable.

---

## 6. iOS audio behavior specification

The areas where iOS is genuinely different from macOS. All new logic lives in
iOS-only code (app target or `#if os(iOS)` blocks in the view model).

### 6.1 Interruptions (calls, Siri, alarms)

Observe `AVAudioSession.interruptionNotification`:

- **Began** → pause, remember `wasPlayingBeforeInterruption`.
- **Ended with `.shouldResume`** → live: call `playLive()` (rejoin the live
  edge — resuming a stalled live buffer plays stale audio or fails);
  on-demand: `resume()`.

### 6.2 Route changes (headphones unplugged)

Observe `AVAudioSession.routeChangeNotification`; on
`.oldDeviceUnavailable` → pause (never blast the speaker). New device
attached → do nothing (user presses play).

### 6.3 No auto-play on launch

The Mac app auto-plays the live stream on launch. On iOS this is wrong (apps
can be launched into the background; users expect silence until they act).
Launch behavior: live stream **selected and shown in the mini player, paused**
— one tap to listen. The auto-play call in `RadioViewModel.init` becomes
macOS-only.

### 6.4 Remote commands

Existing play/pause/toggle targets work unchanged. Add, for on-demand only:
`skipForwardCommand` / `skipBackwardCommand` (15 s) and
`changePlaybackPositionCommand` (lock screen scrubbing → `seek(to:)`).
Keep next/previous disabled. Live: playback position command disabled.

### 6.5 Lock screen artwork

`updateNowPlaying()` gains `MPMediaItemPropertyArtwork`: fetch the current
show's `coverURL` once per show change, cache the `UIImage` in memory. Shared
code path — on macOS this also improves the Control Center widget, so
implement it in the shared view model with a small cross-platform image type.

### 6.6 Reconnect & network changes

`AudioEngine`'s 3-attempt reconnect ports as-is, but cellular↔Wi-Fi handoffs
make fixed retries insufficient. Add an `NWPathMonitor`: when the path becomes
satisfied and the user *was* playing live before the drop, restart the live
stream and reset the retry counter. On returning to foreground
(`scenePhase == .active`), re-sync UI state with actual player state (the iOS
equivalent of the Mac wake observer).

---

## 7. Implementation plan

Phased so the Mac app stays green throughout; each phase is a mergeable unit.

### Phase 0 — Extract shared core (no behavior change)
1. Restructure `Package.swift`: add `MonocleRadioKit` library target with
   `platforms: [.macOS(.v14), .iOS(.v17)]`; move `Models`, `AudioEngine`,
   `RadioViewModel` into `Sources/MonocleRadioKit/`.
2. Conditionalize AppKit usage in `RadioViewModel` (`#if os(macOS)`), make the
   needed types/members `public`.
3. Mac app builds and behaves identically (`make app && make run`).

**Acceptance:** `swift build` for macOS and `swift build -Xswiftc -sdk … ios`
(or `xcodebuild` once Phase 1 lands) both compile the Kit; Mac app unchanged.

### Phase 1 — iOS app scaffold
1. Create `MonocleRadio.xcodeproj` with the macOS target (wrapping the
   existing sources) and a new iOS target depending on `MonocleRadioKit`.
2. iOS entry point: `AVAudioSession` category setup, instantiate
   `RadioViewModel`, placeholder root view. Info.plist with
   `UIBackgroundModes: audio`. iOS app icon (reuse `scripts/gen_icon.py`).

**Acceptance:** app runs on iPhone & iPad simulators; live stream plays from a
temporary button; audio continues when backgrounded; lock screen shows
title + play/pause works.

### Phase 2 — Full UI
1. `RootView` with `NavigationSplitView`, show list, episode list (loading /
   error / empty states, pull-to-refresh).
2. `MiniPlayerBar` + `NowPlayingView` sheet; `seek(to:)` added to
   `AudioEngine`; skip ±15 s.

**Acceptance:** browse → play episodes and live on iPhone; iPad shows
two-column layout; behavior correct in Split View; feature parity checklist
vs. Mac app passes (minus volume/login/quit, per §5.5).

### Phase 3 — iOS audio robustness
1. Interruption + route-change observers (§6.1–6.2).
2. `NWPathMonitor` reconnect + foreground re-sync (§6.6).
3. Remote skip/scrub commands + lock screen artwork (§6.4–6.5).

**Acceptance:** manual test matrix — phone call during live and on-demand;
unplug headphones; Airplane Mode toggle mid-stream; Wi-Fi→cellular handoff;
lock screen artwork, scrubbing, and ±15 s all functional.

### Phase 4 — Polish & release readiness
1. VoiceOver pass, Dynamic Type audit (largest sizes), landscape iPhone
   decision, Stage Manager check.
2. Launch screen; `make ios-install` target for one-command deploy to the
   owner's devices (eases the 7-day free-provisioning re-sign cycle).
3. Unit tests for the scraper against fixture HTML (benefits both platforms —
   the scraper is the most fragile component and currently untested).

---

## 8. Risks and open questions

| Risk | Impact | Mitigation |
|---|---|---|
| **Scraper fragility** — episodes come from parsing monocle.com HTML; a site redesign breaks both apps. | High | Fixture-based tests (Phase 4) to catch breakage early; graceful error UI already exists. Investigate whether Monocle publishes RSS feeds per show (Omny.fm-hosted shows usually have RSS) — would remove SwiftSoup entirely. **Worth checking before Phase 0.** |
| **7-day signing expiry** — with free provisioning (no paid developer account), the app stops launching 7 days after install and must be re-deployed from Xcode. | Low (annoyance) | Accepted for personal use. A `make ios-install` target (via `xcodebuild` + `ios-deploy` or Xcode) makes re-signing a one-command chore. Paid account ($99/yr) extends this to 1 year if it becomes tiresome. |
| **Live stream URL stability** — hardcoded StreamTheWorld URL. | Medium | Same risk as today on Mac; keep the URL in one shared constant. |
| **iCloud sync of state** (volume, last show) | None for v1 | Out of scope; `UserDefaults` per-device. |

**Open questions for the product owner:**
1. ~~Distribution target~~ — **resolved: personal use only, sideloaded via
   Xcode.** No App Store/TestFlight; IP concerns moot.
2. Should iPhone support landscape in v1? (Recommend portrait-only.)
3. Is auto-select-live-but-paused the right launch state, or should iOS
   remember and restore the last-played show/episode?

---

## 9. Future work (post-v1 backlog)

- **Sleep timer** — high value for a radio app, small effort.
- **Playback resume** — remember position within on-demand episodes.
- **CarPlay** — natural fit for radio; requires a CarPlay entitlement from
  Apple (application + approval) and `CPTemplateApplicationScene`.
- **Widgets / Live Activities** — Now Playing on the lock screen/Dynamic Island.
- **Downloads for offline** — the Omny MP3 URLs are direct; needs storage UI.
- **RSS migration** — replace the HTML scraper if per-show feeds exist (see §8).
- **Mac app adopts the Kit's new features** — `seek(to:)`, artwork in Now
  Playing came along for free; expose seeking in the Mac popover.
