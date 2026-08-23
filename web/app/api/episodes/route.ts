// GET /api/episodes?show=<slug>
// Server-side port of Show.fetchEpisodes() from MonocleRadioKit/Models.swift —
// the browser can't fetch monocle.com directly (no CORS). Upstream HTML is
// cached 30 minutes, matching the native apps' episode cache TTL.

import { NextResponse } from "next/server";
import * as cheerio from "cheerio";

export const dynamic = "force-dynamic";

const AUDIO_PATTERN =
  /https:\/\/traffic\.omny\.fm\/d\/clips\/[^"'\s]+\/audio\.mp3/g;

export async function GET(request: Request) {
  const slug = new URL(request.url).searchParams.get("show") ?? "";
  if (!slug || !/^[a-z0-9-]+$/.test(slug)) {
    return NextResponse.json({ error: "invalid show" }, { status: 400 });
  }

  let html: string;
  try {
    const res = await fetch(`https://monocle.com/radio/shows/${slug}/`, {
      next: { revalidate: 1800 },
      headers: { "User-Agent": "MonocleRadioWeb/1.0" },
    });
    if (!res.ok) throw new Error(`upstream ${res.status}`);
    html = await res.text();
  } catch {
    return NextResponse.json({ error: "could not reach monocle.com" }, { status: 502 });
  }

  const $ = cheerio.load(html);

  // Omny.fm MP3 URLs, deduplicated in document order
  const audioURLs = [...new Set(html.match(AUDIO_PATTERN) ?? [])];

  // Episode metadata via CSS selectors (legacy classes + c-episode-card markup)
  const titles = $("h3.episode-title a, h3 a[href*='episode'], h3 a[href*='/radio/shows/']").toArray();
  const dates = $(".episode-date, .c-episode-card__date").toArray();
  const numbers = $(".episode-number, .c-episode-card__number").toArray();
  const descs = $(".episode-description, p.episode-description, .c-episode-card__description").toArray();
  const images = $(".c-episode-card figure img").toArray();

  const text = ($el: ReturnType<typeof $>) => $el.text().trim();

  const episodes: import("@/lib/catalog").Episode[] = audioURLs.map((audioURL, i) => ({
    title: titles[i] ? text($(titles[i])) : `Episode ${i + 1}`,
    audioURL,
    number: numbers[i] ? text($(numbers[i])) : "",
    date: dates[i] ? text($(dates[i])) : "",
    description: descs[i] ? text($(descs[i])) : "",
    imageURL: images[i] ? $(images[i]).attr("src") ?? null : null,
  }));

  // Fallback: titles found but no audio — still list them (native parity)
  if (episodes.length === 0) {
    const fallback =
      titles.length > 0
        ? titles
        : $("h2 a, h3 a, h4 a")
            .toArray()
            .filter((el) => ($(el).attr("href") ?? "").includes("/radio/shows/"));
    fallback.forEach((el, i) => {
      episodes.push({
        title: text($(el)) || `Episode ${i + 1}`,
        audioURL: null,
        number: numbers[i] ? text($(numbers[i])) : "",
        date: dates[i] ? text($(dates[i])) : "",
        description: "",
        imageURL: null,
      });
    });
  }

  return NextResponse.json({ episodes });
}
