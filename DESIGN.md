# Monocle Radio — Design System (iOS/iPadOS)

## Color

| Token | Light | Dark | Use |
|---|---|---|---|
| paper | #FAF7F1 (warm off-white) | #141210 (warm near-black) | App background |
| ink | #171512 (constant) | same | Masthead/live hero card background, both modes |
| monocleGold | #C8A55A | same | Playback accents: progress, slider, now-playing marks |
| monocleRed | #CD1D1D | same | LIVE only. Red means live, nothing else |

Neutrals are warm-tinted (toward gold hue), never pure #000/#fff. Text on ink is paper-white.

## Typography

- Display/show names/headlines: **serif** (`.fontDesign(.serif)` — New York). Masthead ~34pt bold, show titles title3 semibold serif, episode titles subheadline semibold serif.
- Chrome, metadata, controls: SF (system default).
- Kickers: caption2 semibold, tracking 1.5, uppercase — "ON AIR", "LIVE", desk names, section headers.
- Scale contrast ≥1.25 between hierarchy steps.

## Artwork

Show tiles are 822×616 (4:3). Honor the ratio everywhere: list thumbs, mini bar, hero, Now Playing. Never `.fill`-crop to square. Corner radius 6 (thumbs) / 10–12 (heroes).

## Components

- **Live masthead hero**: ink card, full-bleed 4:3 art, LIVE kicker, serif title, explicit play button. The front page's cover.
- **Kicker**: tracked uppercase caption (see typography).
- **Mini player bar**: `.regularMaterial`, 4:3 thumb, gold 2pt progress hairline.
- **Now Playing**: blurred-artwork ambiance background, adaptive layout (VStack compact portrait, side-by-side regular/landscape), sleep timer + AirPlay row.
- **Ambient mode (iPad)**: full-bleed art, serif clock, ON AIR line. Idle timer disabled.

## Motion

- `contentTransition(.symbolEffect(.replace))` on play/pause marks.
- Ease-out only, no bounce.

## States

- Buffering: spinner replaces play glyph (mini bar) / overlays artwork (Now Playing).
- Live dot: red when playing, secondary when paused.
- Episodes without audio: dimmed, disabled, "Unavailable" caption.
