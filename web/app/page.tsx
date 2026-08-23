"use client";

// page.tsx — the whole web app: browser, mini player, Now Playing sheet.
// Mirrors MonocleRadioiOS (RootView/ShowListView/EpisodeListView/NowPlayingView)
// on the shared MonocleRadioKit behavior: 30-min episode cache, resume,
// schedule. Design tokens per DESIGN.md.

import { useCallback, useEffect, useRef, useState } from "react";
import "./player.css";
import {
  allShows,
  desks,
  displayDate,
  episodeId,
  liveShow,
  liveStreamURL,
  shows,
  type Episode,
  type Show,
} from "@/lib/catalog";

interface Current {
  show: Show;
  episode: Episode | null;
}

interface ResumeEntry {
  slug: string;
  title: string;
  audioURL: string;
  number: string;
  date: string;
  position: number;
}

interface ScheduleRow {
  time: string;
  title: string;
}

const EPISODE_TTL = 30 * 60 * 1000;

// ---------- Icons ----------

const IconPlay = () => (
  <svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
);
const IconPause = () => (
  <svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 5h4v14H7zm6 0h4v14h-4z" /></svg>
);
const IconBack15 = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="11 19 2 12 11 5" /><polyline points="22 19 13 12 22 5" />
    <text x="12" y="10" textAnchor="middle" fontSize="7.5" fill="currentColor" stroke="none" fontWeight="600">15</text>
  </svg>
);
const IconFwd15 = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="13 19 22 12 13 5" /><polyline points="2 19 11 12 2 5" />
    <text x="12" y="10" textAnchor="middle" fontSize="7.5" fill="currentColor" stroke="none" fontWeight="600">15</text>
  </svg>
);
const IconChevronDown = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="6 9 12 15 18 9" />
  </svg>
);

// ---------- Helpers ----------

function fmt(t: number): string {
  if (!Number.isFinite(t) || t <= 0) return "0:00";
  const m = Math.floor(t / 60);
  const s = Math.floor(t) % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

function hhmm(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

// ---------- Page ----------

export default function Page() {
  // Navigation
  const [selected, setSelected] = useState<Show | null>(null);
  const [isWide, setIsWide] = useState(false);

  // Episodes
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [epLoading, setEpLoading] = useState(false);
  const [epError, setEpError] = useState(false);
  const cacheRef = useRef(new Map<string, { eps: Episode[]; at: number }>());
  const selectedSlugRef = useRef<string | null>(null);

  // Schedule
  const [schedule, setSchedule] = useState<ScheduleRow[]>([]);

  // Player
  const audioRef = useRef<HTMLAudioElement>(null);
  const [current, setCurrent] = useState<Current | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isBuffering, setIsBuffering] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [playError, setPlayError] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [duration, setDuration] = useState(0);
  const [scrubbing, setScrubbing] = useState<number | null>(null);
  const [volume, setVolume] = useState(1);
  const [npOpen, setNpOpen] = useState(false);
  const [resume, setResume] = useState<ResumeEntry | null>(null);
  const lastResumeSave = useRef(0);

  const isLive = current?.show.isLive ?? false;

  // Wide-pane detection from 600px up (iPad mini portrait included);
  // iPad lands on the live destination like RootView
  useEffect(() => {
    const mq = window.matchMedia("(min-width: 600px)");
    const sync = () => {
      setIsWide(mq.matches);
      if (mq.matches) setSelected((s) => s ?? liveShow);
    };
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  // Manifest-shortcut deep links: /?view=live|schedule land on the live pane.
  // On wide screens that's the auto-opened drawer; "schedule" then collapses it
  // so the rail's programme is in view. On mobile (<600px) the rail already IS
  // the live destination, so we don't swap panes at all.
  useEffect(() => {
    const view = new URLSearchParams(window.location.search).get("view");
    if ((view === "live" || view === "schedule") && window.matchMedia("(min-width: 600px)").matches) {
      setSelected(liveShow);
      if (view === "schedule") scheduleFirstRef.current = true;
    }
  }, []);

  // Restore continue-listening + fetch today's schedule + SW registration
  useEffect(() => {
    if (process.env.NODE_ENV === "production" && "serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => {});
    }
    try {
      const raw = localStorage.getItem("resume.position");
      const slug = localStorage.getItem("resume.showSlug");
      const title = localStorage.getItem("resume.title");
      const url = localStorage.getItem("resume.audioURL");
      if (raw && slug && title && url && parseFloat(raw) > 30) {
        setResume({
          slug,
          title,
          audioURL: url,
          number: localStorage.getItem("resume.number") ?? "",
          date: localStorage.getItem("resume.date") ?? "",
          position: parseFloat(raw),
        });
      }
    } catch {}
    fetch("/api/schedule")
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => d?.entries && setSchedule(d.entries))
      .catch(() => {});
  }, []);

  // ---------- Playback ----------

  const playURL = useCallback((url: string, seekTo?: number) => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.src = url;
    setElapsed(0);
    setDuration(0);
    setConnecting(true);
    setPlayError(false);
    if (seekTo && seekTo > 0) {
      const onMeta = () => {
        audio.currentTime = seekTo;
        audio.removeEventListener("loadedmetadata", onMeta);
      };
      audio.addEventListener("loadedmetadata", onMeta);
    }
    // Surface failures instead of dying silently
    audio.play().catch(() => {
      setConnecting(false);
      setPlayError(true);
    });
  }, []);

  const playLive = useCallback(() => {
    setCurrent({ show: liveShow, episode: null });
    playURL(liveStreamURL);
  }, [playURL]);

  function playEpisode(ep: Episode, show: Show) {
    if (!ep.audioURL) return;
    if (current?.episode && episodeId(current.episode) === episodeId(ep)) {
      togglePlayPause();
      return;
    }
    setCurrent({ show, episode: ep });
    playURL(ep.audioURL);
    setNpOpen(true);
  }

  function togglePlayPause() {
    const audio = audioRef.current;
    if (!audio || !audio.src) {
      if (current) playURL(current.episode?.audioURL ?? liveStreamURL);
      else playLive();
      return;
    }
    if (audio.paused) audio.play().catch(() => {});
    else audio.pause();
  }

  function seek(to: number) {
    const audio = audioRef.current;
    if (audio && Number.isFinite(to)) audio.currentTime = Math.max(0, to);
  }

  function skip(by: number) {
    const audio = audioRef.current;
    if (audio) seek(audio.currentTime + by);
  }

  // Audio element events → state (+ resume persistence)
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const onPlay = () => { setIsPlaying(true); setIsBuffering(false); setConnecting(false); };
    const onPause = () => setIsPlaying(false);
    const onWaiting = () => setIsBuffering(true);
    const onTime = () => {
      setElapsed(audio.currentTime);
      // Save resume position ~every 5s (>30s in, >60s left — kit semantics)
      const cur = currentRef.current;
      if (
        cur?.episode &&
        audio.currentTime > 30 &&
        (!audio.duration || audio.currentTime < audio.duration - 60) &&
        Date.now() - lastResumeSave.current > 5000
      ) {
        lastResumeSave.current = Date.now();
        saveResume(cur, audio.currentTime);
      }
    };
    const onDur = () =>
      setDuration(Number.isFinite(audio.duration) ? audio.duration : 0);
    const onEnded = () => {
      clearResume();
      setIsPlaying(false);
    };
    const onError = () => {
      if (audio.error && audio.src) {
        setIsBuffering(false);
        setIsPlaying(false);
        setConnecting(false);
        setPlayError(true);
      }
    };
    audio.addEventListener("play", onPlay);
    audio.addEventListener("pause", onPause);
    audio.addEventListener("waiting", onWaiting);
    audio.addEventListener("playing", onPlay);
    audio.addEventListener("timeupdate", onTime);
    audio.addEventListener("durationchange", onDur);
    audio.addEventListener("loadedmetadata", onDur);
    audio.addEventListener("ended", onEnded);
    audio.addEventListener("error", onError);
    return () => {
      audio.removeEventListener("play", onPlay);
      audio.removeEventListener("pause", onPause);
      audio.removeEventListener("waiting", onWaiting);
      audio.removeEventListener("playing", onPlay);
      audio.removeEventListener("timeupdate", onTime);
      audio.removeEventListener("durationchange", onDur);
      audio.removeEventListener("loadedmetadata", onDur);
      audio.removeEventListener("ended", onEnded);
      audio.removeEventListener("error", onError);
    };
  }, []);

  // Ref mirror of `current` for event handlers defined once
  const currentRef = useRef<Current | null>(null);
  useEffect(() => {
    currentRef.current = current;
  }, [current]);

  // Keep "on air" honest when idle — schedule rows tick over every ~30s
  const [, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 30_000);
    return () => clearInterval(id);
  }, []);

  // ---------- Keyboard (global) ----------
  // Space play/pause, ←/→ ±15s, Esc closes Now Playing. Skips form fields
  // and native buttons so their own Space/Enter semantics stay intact.
  const keyHandler = useRef<(e: KeyboardEvent) => void>(() => {});
  keyHandler.current = (e) => {
    const t = e.target as HTMLElement | null;
    if (!t || t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)
      return;
    if (t.tagName === "BUTTON" || t.getAttribute?.("role") === "button") return;
    if (e.code === "Space") {
      e.preventDefault();
      togglePlayPause();
    } else if (e.key === "ArrowLeft" && !isLive) {
      commitScrubRef.current();
      skip(-15);
    } else if (e.key === "ArrowRight" && !isLive) {
      commitScrubRef.current();
      skip(15);
    }
  };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (npOpenRef.current) setNpOpen(false);
        else if (isWideRef.current) setSelected(null);
      } else keyHandler.current(e);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const npOpenRef = useRef(false);
  useEffect(() => {
    npOpenRef.current = npOpen;
  }, [npOpen]);
  const isWideRef = useRef(false);
  useEffect(() => {
    isWideRef.current = isWide;
  }, [isWide]);
  // When set, the next wide-layout render skips the auto-opened drawer so a
  // ?view=schedule deep link shows the rail's programme first.
  const scheduleFirstRef = useRef(false);
  useEffect(() => {
    if (scheduleFirstRef.current && isWide && selected?.isLive) {
      scheduleFirstRef.current = false;
      const t = setTimeout(() => setSelected(null), 350);
      return () => clearTimeout(t);
    }
  }, [isWide, selected]);
  // Commit a scrub drag; also called by arrow keys so a pending drag never
  // desyncs from a keyboard seek
  const commitScrubRef = useRef<() => void>(() => {});
  commitScrubRef.current = () => {
    if (scrubbing != null) {
      seek(scrubbing);
      setScrubbing(null);
    }
  };

  // Now Playing focus management — focus moves into the sheet, returns on close
  const npCloseRef = useRef<HTMLButtonElement>(null);
  const lastFocusRef = useRef<Element | null>(null);
  useEffect(() => {
    if (npOpen) {
      lastFocusRef.current = document.activeElement;
      npCloseRef.current?.focus();
    } else if (lastFocusRef.current instanceof HTMLElement) {
      lastFocusRef.current.focus();
      lastFocusRef.current = null;
    }
  }, [npOpen]);

  function saveResume(cur: Current, position: number) {
    const ep = cur.episode!;
    try {
      localStorage.setItem("resume.showSlug", cur.show.slug);
      localStorage.setItem("resume.audioURL", ep.audioURL!);
      localStorage.setItem("resume.title", ep.title);
      localStorage.setItem("resume.number", ep.number);
      localStorage.setItem("resume.date", ep.date);
      localStorage.setItem("resume.position", String(position));
    } catch {}
  }

  function clearResume() {
    ["showSlug", "audioURL", "title", "number", "date", "position"].forEach((k) =>
      localStorage.removeItem(`resume.${k}`)
    );
    setResume(null);
  }

  function resumePlayback(entry: ResumeEntry) {
    const show = allShows.find((s) => s.slug === entry.slug);
    if (!show) return;
    setSelected(show);
    selectShow(show);
    setCurrent({
      show,
      episode: {
        title: entry.title,
        audioURL: entry.audioURL,
        number: entry.number,
        date: entry.date,
        description: "",
        imageURL: null,
      },
    });
    playURL(entry.audioURL, entry.position);
  }

  // ---------- Media Session (lock screen / Control Center) ----------

  useEffect(() => {
    if (!("mediaSession" in navigator)) return;
    const ms = navigator.mediaSession;
    ms.setActionHandler("play", () => audioRef.current?.play().catch(() => {}));
    ms.setActionHandler("pause", () => audioRef.current?.pause());
    ms.setActionHandler("seekbackward", () => !isLive && skip(-15));
    ms.setActionHandler("seekforward", () => !isLive && skip(15));
    ms.setActionHandler("seekto", (d) => {
      if (d.seekTime != null && !isLive) seek(d.seekTime);
    });
    return () => {
      ["play", "pause", "seekbackward", "seekforward", "seekto"].forEach((a) =>
        ms.setActionHandler(a as MediaSessionAction, null)
      );
    };
  }, [isLive]);

  useEffect(() => {
    if (!("mediaSession" in navigator) || !current) return;
    const title = current.episode?.title ?? current.show.name;
    navigator.mediaSession.metadata = new MediaMetadata({
      title,
      artist: "Monocle 24",
      album: current.show.isLive ? "Monocle 24 Live" : current.show.name,
      artwork: [
        { src: current.show.coverURL, sizes: "822x616", type: "image/jpeg" },
      ],
    });
  }, [current]);

  useEffect(() => {
    if (!("mediaSession" in navigator)) return;
    navigator.mediaSession.playbackState = isPlaying ? "playing" : "paused";
    if (duration > 0 && !isLive) {
      try {
        navigator.mediaSession.setPositionState({
          duration,
          playbackRate: 1,
          position: Math.min(elapsed, duration),
        });
      } catch {}
    }
  }, [isPlaying, elapsed, duration, isLive]);

  // ---------- Show selection & episode loading ----------

  const selectShow = useCallback(
    (show: Show) => {
      setSelected(show);
      selectedSlugRef.current = show.slug;
      if (show.isLive) {
        setEpisodes([]);
        setEpError(false);
        return;
      }
      const cached = cacheRef.current.get(show.slug);
      if (cached && Date.now() - cached.at < EPISODE_TTL) {
        setEpisodes(cached.eps);
        setEpError(false);
        return;
      }
      loadEpisodes(show.slug);
    },
    []
  );

  async function loadEpisodes(slug: string) {
    setEpLoading(true);
    setEpError(false);
    setEpisodes([]);
    try {
      const res = await fetch(`/api/episodes?show=${slug}`);
      if (!res.ok) throw new Error();
      const data = await res.json();
      cacheRef.current.set(slug, { eps: data.episodes, at: Date.now() });
      if (selectedSlugRef.current === slug) setEpisodes(data.episodes);
    } catch {
      if (selectedSlugRef.current === slug) setEpError(true);
    } finally {
      if (selectedSlugRef.current === slug) setEpLoading(false);
    }
  }

  function retryEpisodes() {
    if (selected && !selected.isLive) loadEpisodes(selected.slug);
  }

  // ---------- Derived ----------

  const onAirIdx = (() => {
    const now = Date.now();
    let idx = -1;
    schedule.forEach((e, i) => {
      if (new Date(e.time).getTime() <= now) idx = i;
    });
    return idx;
  })();

  const npTitle = current?.episode?.title ?? current?.show.name ?? "";
  const npSub = current?.episode ? current.show.name : "24/7 live radio";

  // ---------- Render ----------

  return (
    <div className="app">
      <div className="panes">
        {/* Sidebar / mobile root */}
        <aside className={`side${!isWide && selected ? " off" : ""}`}>
          {/* Masthead hero */}
          <button
            className="hero"
            onClick={() => selectShow(liveShow)}
            aria-label="Monocle 24 live"
          >
            <span className="hero-art">
              <img src={liveShow.coverURL} alt="" />
              <span className={`hero-live${isLive && isPlaying ? " on" : ""}`}>
                <span className={`live-dot${isLive && isPlaying ? "" : " paused"}`} />
                <span className="kicker">Live</span>
              </span>
            </span>
            <span className="hero-foot">
              <span className="hero-titles">
                <span className="hero-title">Monocle Radio</span>
                <span className="hero-sub">
                  {onAirIdx >= 0 ? schedule[onAirIdx].title : liveShow.description}
                </span>
              </span>
              <span
                className="play-btn"
                role="button"
                tabIndex={0}
                aria-label={isLive && isPlaying ? "Pause live stream" : "Play live stream"}
                onClick={(e) => {
                  e.stopPropagation();
                  if (isLive) togglePlayPause();
                  else playLive();
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    e.stopPropagation();
                    if (isLive) togglePlayPause();
                    else playLive();
                  }
                }}
              >
                {connecting && isLive ? (
                  <span className="spinner" />
                ) : isLive && isPlaying ? (
                  <IconPause />
                ) : (
                  <IconPlay />
                )}
              </span>
            </span>
          </button>

          {/* Continue listening */}
          {resume && (
            <div className="resume-banner">
              <img
                src={allShows.find((s) => s.slug === resume.slug)?.coverURL ?? ""}
                alt=""
              />
              <button
                className="resume-titles"
                onClick={() => resumePlayback(resume)}
              >
                <span className="kicker resume-kicker">Continue</span>
                <span className="resume-title">{resume.title}</span>
              </button>
              <span className="kicker">{fmt(resume.position)}</span>
              <button
                className="resume-dismiss"
                aria-label="Dismiss"
                onClick={clearResume}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
                  <line x1="5" y1="5" x2="19" y2="19" /><line x1="19" y1="5" x2="5" y2="19" />
                </svg>
              </button>
            </div>
          )}

          {/* Catalog grouped by desk — cover grid at every width:
              3-up on phones, 2-up in the tablet/desktop sidebar */}
          {desks.map((desk) => {
            const deskShows = shows.filter((s) => s.desk === desk);
            return (
              <section key={desk}>
                <div className="kicker desk-label">{desk}</div>
                <div className="show-grid">
                  {deskShows.map((s) => (
                    <button
                      key={s.slug}
                      className={`tile${selected?.slug === s.slug ? " sel" : ""}`}
                      onClick={() => selectShow(s)}
                    >
                      <span className="tile-art">
                        <img src={s.coverURL} alt="" loading="lazy" />
                        {current?.show.slug === s.slug && isPlaying && (
                          <span className="tile-dot" />
                        )}
                      </span>
                      <span className="tile-name">{s.name}</span>
                    </button>
                  ))}
                </div>
              </section>
            );
          })}
          <div style={{ height: 96 }} />
        </aside>

        {/* Detail — right drawer from 600px up, full-screen swap below */}
        {selected && (
          <>
            {isWide && <div className="drawer-scrim" onClick={() => setSelected(null)} aria-hidden="true" />}
            <main className={`detail${!isWide && !selected ? " off" : ""}${isWide ? " drawer" : ""}`}>
              <div className="detail-pad">
                {!isWide && selected && (
                  <button
                    className="detail-top"
                    onClick={() => setSelected(null)}
                    aria-label="Back to shows"
                  >
                    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="15 18 9 12 15 6" />
                    </svg>
                    Shows
                  </button>
                )}
                {isWide && (
                  <button
                    className="drawer-close"
                    onClick={() => setSelected(null)}
                    aria-label="Close panel"
                  >
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="15 18 9 12 15 6" />
                    </svg>
                    Shows
                  </button>
                )}

            {!selected ? (
              <div className="centered">Select a show</div>
            ) : selected.isLive ? (
              <LivePane
                onAir={onAirIdx >= 0 ? schedule[onAirIdx].title : ""}
                upcoming={schedule.slice(onAirIdx + 1, onAirIdx + 6)}
                isPlaying={isLive && isPlaying}
                onToggle={() => (isLive ? togglePlayPause() : playLive())}
                buffering={isLive && isBuffering}
                connecting={isLive && connecting}
                error={isLive && playError}
              />
            ) : (
              <>
                <header className="show-header">
                  <div className="kicker">{selected.desk}</div>
                  <h1 className="show-name">{selected.name}</h1>
                  <p className="show-desc">{selected.description}</p>
                </header>
                {epLoading ? (
                  <div className="centered"><span className="spinner" /></div>
                ) : epError ? (
                  <div className="retry-wrap">
                    <p className="error-text">Could not load episodes.</p>
                    <button className="retry-btn" onClick={retryEpisodes}>
                      Retry
                    </button>
                  </div>
                ) : episodes.length === 0 ? (
                  <div className="centered">No episodes found</div>
                ) : (
                  episodes.map((ep) => {
                    const now =
                      current?.episode != null &&
                      episodeId(current.episode) === episodeId(ep) &&
                      current.show.slug === selected.slug;
                    return (
                      <button
                        key={episodeId(ep)}
                        className={`row-ep${now ? " now" : ""}${!ep.audioURL ? " unavailable" : ""}`}
                        onClick={() => playEpisode(ep, selected)}
                      >
                        <span className="ep-mark">
                          {now && isPlaying ? (
                            <span className="dot" />
                          ) : (
                            <IconPlay />
                          )}
                        </span>
                        <span className="ep-body">
                          <span className="ep-title">{ep.title}</span>
                          {(ep.number || ep.date || !ep.audioURL) && (
                            <span className="ep-meta">
                              {ep.number && <span>{ep.number}</span>}
                              {ep.date && <span className="ep-date">{displayDate(ep.date)}</span>}
                              {!ep.audioURL && <span className="ep-unavailable">Unavailable</span>}
                            </span>
                          )}
                          {ep.description && (
                            <span className="ep-desc">{ep.description}</span>
                          )}
                        </span>
                      </button>
                    );
                  })
                )}
              </>
            )}
              </div>
            </main>
          </>
        )}
      </div>

      {/* Mini player */}
      {current && !npOpen && (
        <div
          className="mini"
          role="button"
          tabIndex={0}
          aria-label="Open Now Playing"
          onClick={() => setNpOpen(true)}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              setNpOpen(true);
            }
          }}
        >
          {!isLive && duration > 0 && (
            <div className="mini-progress">
              <i style={{ width: `${Math.min(100, ((scrubbing ?? elapsed) / duration) * 100)}%` }} />
            </div>
          )}
          <div className="mini-inner">
            <img src={current.show.coverURL} alt="" />
            <div className="mini-titles">
              <div className="mini-kicker">
                {isLive && (
                  <>
                    <span className={`live-dot${isPlaying ? "" : " paused"}`} style={{ width: 6, height: 6 }} />
                    <span className="kicker" style={{ color: "var(--live)" }}>
                      Live
                    </span>
                  </>
                )}
                {!isLive && <span className="kicker">{current.show.name}</span>}
              </div>
              <div className="mini-title">{npTitle}</div>
            </div>
            <button
              className="play-btn small"
              aria-label={isPlaying ? "Pause" : "Play"}
              onClick={(e) => {
                e.stopPropagation();
                togglePlayPause();
              }}
            >
              {(connecting || (isBuffering && isPlaying)) ? (
                <span className="spinner" />
              ) : isPlaying ? (
                <IconPause />
              ) : (
                <IconPlay />
              )}
            </button>
          </div>
        </div>
      )}

      {/* Now Playing sheet */}
      {npOpen && current && (
        <div className="np">
          <div
            className="np-bg"
            style={{ backgroundImage: `url(${current.show.coverURL})` }}
          />
          <div className="np-inner">
            <div className="np-top">
              <button
                className="np-close"
                ref={npCloseRef}
                onClick={() => setNpOpen(false)}
                aria-label="Close"
              >
                <IconChevronDown />
              </button>
              {isLive && (
                <span className="np-livebadge">
                  <span className={`live-dot${isPlaying ? "" : " paused"}`} />
                  <span className="kicker">Live</span>
                </span>
              )}
            </div>

            <div className="np-art">
              <img src={current.show.coverURL} alt="" />
            </div>

            <div className="np-meta">
              <div className="kicker np-kicker">{current.show.name}</div>
              <h2 className="np-title">{npTitle}</h2>
              <p className="np-sub">{npSub}</p>
            </div>

            {!isLive && duration > 0 && (
              <div className="np-scrub">
                <input
                  type="range"
                  min={0}
                  max={Math.floor(duration)}
                  value={scrubbing ?? Math.floor(elapsed)}
                  style={{ "--p": `${((scrubbing ?? elapsed) / duration) * 100}%` } as React.CSSProperties}
                  onChange={(e) => setScrubbing(Number(e.target.value))}
                  onPointerUp={() => commitScrubRef.current()}
                  onTouchEnd={() => commitScrubRef.current()}
                  onKeyUp={() => commitScrubRef.current()}
                  aria-label="Seek"
                />
                <div className="np-times">
                  <span>{fmt(scrubbing ?? elapsed)}</span>
                  <span>-{fmt(duration - (scrubbing ?? elapsed))}</span>
                </div>
              </div>
            )}

            {/* Live has no timeline, so volume gives the sheet its anchor */}
            <div className="np-volume">
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M3 9v6h4l5 5V4L7 9H3z" />
                <path
                  d="M16 8.5a5 5 0 010 7"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                />
              </svg>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={volume}
                style={{ "--p": `${volume * 100}%` } as React.CSSProperties}
                onChange={(e) => {
                  const v = Number(e.target.value);
                  setVolume(v);
                  if (audioRef.current) audioRef.current.volume = v;
                }}
                aria-label="Volume"
              />
            </div>

            <div className="np-controls">
              {!isLive && (
                <button className="np-skip" onClick={() => skip(-15)} aria-label="Back 15 seconds">
                  <IconBack15 />
                </button>
              )}
              <button
                className="np-playpause"
                onClick={togglePlayPause}
                aria-label={isPlaying ? "Pause" : "Play"}
              >
                {(connecting || (isBuffering && isPlaying)) ? (
                  <span className="spinner" />
                ) : isPlaying ? (
                  <IconPause />
                ) : (
                  <IconPlay />
                )}
              </button>
              {!isLive && (
                <button className="np-skip" onClick={() => skip(15)} aria-label="Forward 15 seconds">
                  <IconFwd15 />
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      <audio ref={audioRef} preload="none" />
    </div>
  );
}

// ---------- Live detail pane ----------

function LivePane({
  onAir,
  upcoming,
  isPlaying,
  onToggle,
  buffering,
  connecting,
  error,
}: {
  onAir: string;
  upcoming: ScheduleRow[];
  isPlaying: boolean;
  onToggle: () => void;
  buffering: boolean;
  connecting: boolean;
  error: boolean;
}) {
  return (
    <div className="live-pane">
      <header className="show-header">
        <div className="hero-live on" style={{ position: "static", marginBottom: 6 }}>
          <span className={`live-dot${isPlaying ? "" : " paused"}`} />
          <span className="kicker" style={{ color: "var(--live)" }}>
            Live
          </span>
        </div>
        <h1 className="show-name">Monocle 24</h1>
        <p className="show-desc">24/7 live radio from Monocle</p>
        <button
          className="play-btn"
          style={{ marginTop: 16 }}
          onClick={onToggle}
          aria-label={isPlaying ? "Pause" : "Play live"}
        >
          {(connecting || (buffering && isPlaying)) ? (
            <span className="spinner" />
          ) : isPlaying ? (
            <IconPause />
          ) : (
            <IconPlay />
          )}
        </button>
        {error && (
          <p className="error-text play-error">
            Couldn&rsquo;t start playback. Check your connection and try again.
          </p>
        )}
      </header>

      {(onAir || upcoming.length > 0) && (
        <div className="onair-block">
          <div className="kicker">Today&rsquo;s programme</div>
          {onAir && (
            <div className="onair-row">
              <span className="onair-time">NOW</span>
              <span className="onair-title now">{onAir}</span>
            </div>
          )}
          {upcoming.map((e) => (
            <div className="onair-row" key={e.time + e.title}>
              <span className="onair-time">{hhmm(e.time)}</span>
              <span className="onair-title">{e.title}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
