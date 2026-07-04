# Monocle Radio

register: product

## Product purpose

Native macOS (menu bar) and iOS/iPadOS player for Monocle 24, the radio arm of Monocle magazine. Live stream plus on-demand episodes of ~24 shows, scraped from monocle.com. No accounts, no ads, no analytics: open the app, listen.

## Users

- Monocle readers/subscribers: design-literate, urbane, international. They chose this brand *because* of its print craft; they notice typography.
- Commuters with AirPods (lock-screen is a primary surface).
- Kitchen-counter iPad listeners (ambient, glanceable).

## Brand

Monocle is a print-first editorial brand: serif display type, ink black, paper white, restrained warm gold, red reserved for LIVE. Quality feels like a magazine spread, not a software dashboard. Photography and show tile art (822×616, 4:3) are art-directed; never crop them square.

## Tone

Quiet confidence. Editorial, not promotional. Small tracked-uppercase kickers ("ON AIR", "LIVE") are a signature gesture.

## Anti-references

- Apple Settings / default grouped-list look.
- Generic podcast app template (Overcast/Podcasts clones).
- SaaS dashboard tropes: gradient text, glassmorphism, hero metrics.

## Strategic principles

1. Playback is the hero: the magazine's "cover" is what's on air now.
2. Editorial layer over clean architecture: the NavigationSplitView skeleton stays.
3. Feature depth must serve listening: resume, sleep timer, schedule — no gimmicks.
4. Shared MonocleRadioKit changes must stay additive; the macOS menu bar app ships from the same kit.
