// GET /api/schedule
// Server-side port of Schedule.fetchToday() from MonocleRadioKit/Schedule.swift.
// Scrapes today's programme cards; times arrive as "HH:mm GMT".

import { NextResponse } from "next/server";
import * as cheerio from "cheerio";

export const dynamic = "force-dynamic";

export async function GET() {
  let html: string;
  try {
    const res = await fetch("https://monocle.com/radio/schedule/", {
      next: { revalidate: 1800 },
      headers: { "User-Agent": "MonocleRadioWeb/1.0" },
    });
    if (!res.ok) throw new Error(`upstream ${res.status}`);
    html = await res.text();
  } catch {
    return NextResponse.json({ error: "could not reach monocle.com" }, { status: 502 });
  }

  const $ = cheerio.load(html);
  const entries: { time: string; title: string }[] = [];

  $(".c-schedule-card").each((_, card) => {
    const metaText = $(card).find(".c-schedule-card__meta p").first().text().trim();
    const title = $(card).find(".c-schedule-card__title").first().text().trim();
    if (!title) return;

    // "00:01 BST" / "00:01 GMT" → ISO instant for today at that UK time
    const m = metaText.match(/^(\d{1,2}):(\d{2})\s*(BST|GMT)?$/);
    if (!m) return;
    const offsetMinutes = m[3] === "BST" ? 60 : 0;
    const d = new Date();
    d.setUTCHours(+m[1], +m[2] - offsetMinutes, 0, 0);
    entries.push({ time: d.toISOString(), title });
  });

  entries.sort((a, b) => a.time.localeCompare(b.time));
  return NextResponse.json({ entries });
}
