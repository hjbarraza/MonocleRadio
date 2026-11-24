// playback.ts — audio recovery logic, kept free of React so it can be tested.
// iOS drops the network connection / suspends the media element while paused
// (especially with the screen locked), so a bare play() can reject or hang.
// PlaybackGuard reloads the same source once, restores the position and plays.

export interface MediaLike {
  src: string;
  currentSrc: string;
  currentTime: number;
  duration: number;
  readyState: number;
  networkState: number;
  paused: boolean;
  ended: boolean;
  error: unknown;
  load(): void;
  play(): Promise<void>;
  addEventListener(type: string, fn: () => void, opts?: { once?: boolean }): void;
}

export interface GuardCallbacks {
  onConnecting(): void; // a (re)load started
  onFailed(): void; // stream could not start; show the error state
  onNeedsTap(): void; // browser wants a user gesture; no error, Play stays
}

export const NETWORK_NO_SOURCE = 3;
export const STALL_MS = 4000;

export class PlaybackGuard {
  private token = 0;
  private timer: ReturnType<typeof setTimeout> | null = null;

  private audio: MediaLike;
  private cb: GuardCallbacks;
  private stallMs: number;

  constructor(audio: MediaLike, cb: GuardCallbacks, stallMs: number = STALL_MS) {
    this.audio = audio;
    this.cb = cb;
    this.stallMs = stallMs;
  }

  clearStall() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  // Seek once metadata is ready (clamped), only if this load is still current.
  private seekWhenReady(seekTo: number, token: number) {
    const a = this.audio;
    const apply = () => {
      if (token !== this.token) return;
      const max = Number.isFinite(a.duration) && a.duration > 0 ? a.duration - 1 : seekTo;
      try {
        a.currentTime = Math.max(0, Math.min(seekTo, max));
      } catch {}
    };
    if (a.readyState >= 1) apply();
    else a.addEventListener("loadedmetadata", apply, { once: true });
  }

  private start(token: number) {
    this.audio.play().catch((err: unknown) => {
      if (token !== this.token) return; // superseded by a newer load
      const name = (err as { name?: string })?.name;
      if (name === "AbortError") return; // interrupted by a newer load()/pause()
      if (name === "NotAllowedError") { this.clearStall(); return this.cb.onNeedsTap(); }
      this.cb.onFailed();
    });
  }

  /** Load a new source and play it, optionally from a position. */
  load(url: string, seekTo = 0) {
    this.clearStall();
    const token = ++this.token;
    this.audio.src = url;
    this.cb.onConnecting();
    if (seekTo > 0) this.seekWhenReady(seekTo, token);
    this.start(token);
  }

  isDead(live: boolean): boolean {
    const a = this.audio;
    return !!a.error || a.networkState === NETWORK_NO_SOURCE || (!live && a.readyState === 0);
  }

  /** Resume after a pause; reloads once if the element stalled or died. */
  resume(live: boolean, savedPos: number) {
    const a = this.audio;
    const src = a.currentSrc || a.src;
    if (!src) return;
    this.clearStall();
    const token = this.token;
    let reloaded = false;
    const reload = () => {
      if (reloaded || token !== this.token) return;
      reloaded = true;
      this.clearStall();
      const pos = live ? 0 : a.currentTime > 1 ? a.currentTime : savedPos;
      const base = src.replace(/([?&])_r=\d+&?/, "$1").replace(/[?&]$/, "");
      const url = live ? `${base}${base.includes("?") ? "&" : "?"}_r=${Date.now()}` : base;
      const t = ++this.token;
      this.cb.onConnecting();
      a.src = url;
      a.load();
      if (pos > 0) this.seekWhenReady(pos, t);
      this.start(t);
    };
    if (this.isDead(live)) return reload();
    a.play().catch((err: unknown) => {
      const name = (err as { name?: string })?.name;
      if (name === "AbortError" || token !== this.token) return;
      if (name === "NotAllowedError") { this.clearStall(); return this.cb.onNeedsTap(); }
      reload();
    });
    // play() that resolves/hangs without starting is the iOS stall case
    this.timer = setTimeout(() => {
      this.timer = null;
      if (token === this.token && a.paused && !a.ended) reload();
    }, this.stallMs);
  }
}
