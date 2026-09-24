// GET /api/episodes?show=<slug>
// Server-side port of Show.fetchEpisodes() from MonocleRadioKit/Models.swift —
// the browser can't fetch monocle.com directly (no CORS). Upstream HTML is
// cached 30 minutes, matching the native apps' episode cache TTL.

import { NextResponse } from "next/server";
import { fetchEpisodes } from "@/lib/episodes";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const slug = new URL(request.url).searchParams.get("show") ?? "";
  if (!slug || !/^[a-z0-9-]+$/.test(slug)) {
    return NextResponse.json({ error: "invalid show" }, { status: 400 });
  }

  try {
    const episodes = await fetchEpisodes(slug);
    return NextResponse.json({ episodes });
  } catch {
    return NextResponse.json({ error: "could not reach monocle.com" }, { status: 502 });
  }
}
