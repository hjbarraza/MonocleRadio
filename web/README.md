# Monocle Radio — Web (PWA)

Browser port of the iOS app for Monocle 24. Deployable on Vercel; installable
on iPhone/iPad via Safari → Share → **Add to Home Screen** — it then runs
full-screen like a native app, with lock-screen playback controls.

## Run locally

```sh
cd web
npm install
npm run dev    # http://localhost:3000
```

## Deploy to Vercel

1. Import the repo at [vercel.com/new](https://vercel.com/new)
2. Set **Root Directory** to `web` (framework auto-detects Next.js)
3. Deploy — no environment variables needed

Or from the CLI:

```sh
cd web && npx vercel --prod
```

## Architecture

| Path | Role |
|---|---|
| `app/page.tsx` | Whole UI: hero, show list, episodes, mini player, Now Playing sheet |
| `app/api/episodes/route.ts` | Server-side episode scraper (port of `Show.fetchEpisodes()`) |
| `app/api/schedule/route.ts` | Server-side programme scraper (port of `Schedule.fetchToday()`) |
| `lib/catalog.ts` | Hardcoded show catalog + types (mirror of `MonocleRadioKit/Models.swift`) |
| `public/manifest.json`, `sw.js` | PWA shell: standalone display, icons, offline fallback |

Design tokens in `app/globals.css` follow the repo's DESIGN.md (paper/ink/gold,
serif display type, red reserved for LIVE).

### Why server routes?

monocle.com sends no CORS headers, so the browser can't scrape it directly.
The API routes do what SwiftSoup does natively, caching upstream HTML for 30
minutes — same TTL as the native apps' episode cache. Audio itself streams
straight from StreamTheWorld/Omny.fm to the client `<audio>` element.

### Feature parity notes

- Live stream, 24-show catalog, on-demand episodes: full parity.
- Lock-screen / Control Center controls: via Media Session API (play/pause,
  ±15 s, scrubbing on episodes).
- Continue-listening resume: localStorage, same semantics as the kit.
- Today's programme schedule: parity.
- No ICY "now playing" metadata (browsers don't expose it), no offline
  downloads (iOS Safari limitation), no sleep timer or ambient mode yet.
