import "server-only";

import * as cheerio from "cheerio";
import type { Episode } from "@/lib/catalog";

const AUDIO_PATTERN =
  /https:\/\/traffic\.omny\.fm\/d\/clips\/[^"'\s]+\/audio\.mp3/g;

export async function fetchEpisodes(slug: string): Promise<Episode[]> {
  const res = await fetch(`https://monocle.com/radio/shows/${slug}/`, {
    next: { revalidate: 1800 },
    headers: { "User-Agent": "MonocleRadioWeb/1.0" },
  });
  if (!res.ok) throw new Error(`upstream ${res.status}`);

  const html = await res.text();
  const $ = cheerio.load(html);

  const audioURLs = [...new Set(html.match(AUDIO_PATTERN) ?? [])];
  const titles = $("h3.episode-title a, h3 a[href*='episode'], h3 a[href*='/radio/shows/']").toArray();
  const dates = $(".episode-date, .c-episode-card__date").toArray();
  const numbers = $(".episode-number, .c-episode-card__number").toArray();
  const descs = $(".episode-description, p.episode-description, .c-episode-card__description").toArray();
  const images = $(".c-episode-card figure img").toArray();
  const text = ($el: ReturnType<typeof $>) => $el.text().trim();

  const episodes: Episode[] = audioURLs.map((audioURL, i) => ({
    title: titles[i] ? text($(titles[i])) : `Episode ${i + 1}`,
    audioURL,
    number: numbers[i] ? text($(numbers[i])) : "",
    date: dates[i] ? text($(dates[i])) : "",
    description: descs[i] ? text($(descs[i])) : "",
    imageURL: images[i] ? $(images[i]).attr("src") ?? null : null,
  }));

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

  return episodes;
}
