import { NextResponse } from "next/server";
import { shows } from "@/lib/catalog";
import { fetchEpisodes } from "@/lib/episodes";

export const revalidate = 1800;

const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function dateValue(raw: string): number {
  const match = raw.trim().match(/^(\d{1,2}) ([A-Za-z]{3}) (\d{4})$/);
  if (!match) return 0;
  const month = months.indexOf(match[2]);
  return month < 0 ? 0 : Date.UTC(Number(match[3]), month, Number(match[1]));
}

export async function GET() {
  const results = await Promise.allSettled(
    shows.map(async (show) => {
      const [episode] = await fetchEpisodes(show.slug);
      return episode ? { show, episode } : null;
    })
  );

  const updates = results
    .flatMap((result) =>
      result.status === "fulfilled" && result.value ? [result.value] : []
    )
    .sort((a, b) => dateValue(b.episode.date) - dateValue(a.episode.date));

  return NextResponse.json({ updates });
}
