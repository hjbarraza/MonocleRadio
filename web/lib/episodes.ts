import "server-only";

import type { Episode } from "@/lib/catalog";
import { parseEpisodes } from "@/lib/parse-episodes";

export async function fetchEpisodes(slug: string): Promise<Episode[]> {
  const res = await fetch(`https://monocle.com/radio/shows/${slug}/`, {
    next: { revalidate: 1800 },
    headers: { "User-Agent": "MonocleRadioWeb/1.0" },
  });
  if (!res.ok) throw new Error(`upstream ${res.status}`);
  return parseEpisodes(await res.text());
}
