import { test } from "node:test";
import assert from "node:assert/strict";
import { PlaybackGuard, type MediaLike } from "../lib/playback.ts";

class FakeAudio implements MediaLike {
  src = "";
  currentSrc = "";
  currentTime = 0;
  duration = NaN;
  readyState = 4;
  networkState = 1;
  paused = true;
  ended = false;
  error: unknown = null;
  loads = 0;
  playCalls = 0;
  listeners: Record<string, Array<() => void>> = {};
  playImpl: () => Promise<void> = () => { this.paused = false; return Promise.resolve(); };
  load() { this.loads++; this.currentSrc = this.src; this.readyState = 0; this.error = null; this.networkState = 2; }
  play() { this.playCalls++; return this.playImpl(); }
  addEventListener(t: string, fn: () => void) { (this.listeners[t] ??= []).push(fn); }
  fire(t: string) { (this.listeners[t] ?? []).splice(0).forEach((f) => f()); }
}
const mk = (stallMs = 20) => {
  const a = new FakeAudio();
  const ev = { connecting: 0, failed: 0, tap: 0 };
  const g = new PlaybackGuard(a, {
    onConnecting: () => ev.connecting++,
    onFailed: () => ev.failed++,
    onNeedsTap: () => ev.tap++,
  }, stallMs);
  return { a, g, ev };
};
const tick = (ms = 0) => new Promise((r) => setTimeout(r, ms));
const rejectWith = (name: string) => () => Promise.reject(Object.assign(new Error(name), { name }));

test("healthy resume just plays, no reload", async () => {
  const { a, g } = mk();
  a.src = a.currentSrc = "https://x/ep.mp3"; a.currentTime = 100;
  g.resume(false, 100);
  await tick(40);
  assert.equal(a.loads, 0);
  assert.equal(a.playCalls, 1);
  assert.equal(a.paused, false);
});

test("dead element (error) reloads same URL and restores position", async () => {
  const { a, g, ev } = mk();
  a.src = a.currentSrc = "https://x/ep.mp3"; a.error = { code: 2 }; a.currentTime = 0;
  g.resume(false, 321);
  assert.equal(a.loads, 1);
  assert.equal(a.src, "https://x/ep.mp3");
  assert.equal(ev.connecting, 1);
  a.duration = 3600; a.readyState = 1; a.fire("loadedmetadata");
  assert.equal(a.currentTime, 321);
});

test("rejected play() (non-abort) reloads once and shows no error", async () => {
  const { a, g, ev } = mk();
  a.src = a.currentSrc = "https://x/ep.mp3"; a.currentTime = 50;
  let n = 0;
  a.playImpl = () => (n++ === 0 ? rejectWith("NotSupportedError")() : (a.paused = false, Promise.resolve()));
  g.resume(false, 50);
  await tick(10);
  assert.equal(a.loads, 1);
  assert.equal(ev.failed, 0);
});

test("stalled play (never starts) reloads after the stall timeout, once", async () => {
  const { a, g } = mk(15);
  a.src = a.currentSrc = "https://x/ep.mp3"; a.currentTime = 60;
  a.playImpl = () => new Promise(() => {}); // hangs, element stays paused
  g.resume(false, 60);
  await tick(60);
  assert.equal(a.loads, 1);
});

test("stall timer is cancelled once playback starts", async () => {
  const { a, g } = mk(15);
  a.src = a.currentSrc = "https://x/ep.mp3";
  g.resume(false, 0);
  g.clearStall(); // what the 'play' event handler does
  await tick(40);
  assert.equal(a.loads, 0);
});

test("NotAllowedError asks for a tap and does not reload or error", async () => {
  const { a, g, ev } = mk();
  a.src = a.currentSrc = "https://x/ep.mp3"; a.currentTime = 10;
  a.playImpl = rejectWith("NotAllowedError");
  g.resume(false, 10);
  await tick(5);
  g.clearStall();
  assert.equal(ev.tap, 1);
  assert.equal(ev.failed, 0);
  assert.equal(a.loads, 0);
});

test("AbortError from a superseding load is ignored", async () => {
  const { a, g, ev } = mk();
  a.playImpl = rejectWith("AbortError");
  g.load("https://x/a.mp3");
  await tick(5);
  assert.equal(ev.failed, 0);
});

test("a real play() failure on load surfaces the error state", async () => {
  const { a, g, ev } = mk();
  a.playImpl = rejectWith("NotSupportedError");
  g.load("https://x/a.mp3");
  await tick(5);
  assert.equal(ev.failed, 1);
});

test("stale seek from a replaced episode never applies to the new one", () => {
  const { a, g } = mk();
  a.readyState = 0;
  g.load("https://x/old.mp3", 500); // waits for metadata
  g.load("https://x/new.mp3");      // replaces it, no seek
  a.duration = 3600; a.readyState = 1; a.fire("loadedmetadata");
  assert.equal(a.currentTime, 0);
});

test("seek is clamped to the duration", () => {
  const { a, g } = mk();
  a.readyState = 0;
  g.load("https://x/a.mp3", 9999);
  a.duration = 100; a.fire("loadedmetadata");
  assert.equal(a.currentTime, 99);
});

test("live resume reloads with a cache-busting param and never seeks", () => {
  const { a, g } = mk();
  a.src = a.currentSrc = "https://live/stream"; a.error = { code: 4 }; a.currentTime = 12;
  g.resume(true, 12);
  assert.match(a.src, /^https:\/\/live\/stream\?_r=\d+$/);
  a.readyState = 1; a.fire("loadedmetadata");
  assert.equal(a.currentTime, 12); // unchanged; no seek applied on live
});
