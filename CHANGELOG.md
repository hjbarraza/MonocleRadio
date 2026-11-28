# Changelog

## Web (monocle.yuno.to) — 2026-11-28

- iOS lock screen: pause and resume now work, and playback races are fixed.
- Recovery timer stops when iOS needs a tap to resume playback.
- Hero card stays open; play controls are separate buttons.
- Dark mode: text on ink surfaces is readable.
- Episode numbers and dates stay aligned with their episode.
- Now Playing: opaque background, larger ±15 s skip icons.
- Regression tests for episode parsing and playback recovery (`npm test`).

## Web — 2026-09-24

- Latest episodes are the homepage.
- `?view=` deep links for manifest shortcuts.
- Open Graph / Twitter metadata.

## Web — 2026-08-23

- First release: Next.js PWA port of the app.

## macOS 1.2.0 — 2026-11-28

- Lock screen and Control Center: skip ±15 s and scrub on-demand episodes.
- Show cover art in Now Playing.
- Play/pause starts the current selection when nothing is loaded.
- Fixed: `make app` now copies the resource bundle into the app; without it, the app could crash on launch.
- Shared playback core (`MonocleRadioKit`) with the iOS and Watch apps.

## macOS 1.1.0 — 2026-05-27

- Sharp menu bar icon at 1x/2x/3x.
- Wider popover, two-line episode titles, LIVE / ON DEMAND sections.
- Live pane shows the current track from stream metadata.

## macOS 1.0.0 — 2026-03-12

- First release: menu bar player with live stream, 25 shows, media keys, auto-reconnect, launch at login.
