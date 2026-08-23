// catalog.ts — show/episode types and the hardcoded catalog.
// Mirrors Sources/MonocleRadioKit/Models.swift — keep in sync.

export const desks = [
  "News",
  "Business",
  "Design & Culture",
  "Food & Travel",
  "Weekend",
] as const;

export type Desk = (typeof desks)[number];

export interface Show {
  slug: string; // "" = live
  name: string;
  description: string;
  coverURL: string;
  isLive: boolean;
  desk: Desk;
}

export interface Episode {
  title: string;
  audioURL: string | null;
  number: string;
  date: string;
  description: string;
  imageURL: string | null;
}

const coverBase = "https://monocle.com/wp-content/uploads/";

function show(
  name: string,
  slug: string,
  description: string,
  coverPath: string,
  desk: Desk
): Show {
  return {
    name,
    slug,
    description,
    coverURL: coverBase + coverPath,
    isLive: false,
    desk,
  };
}

export const liveStreamURL =
  "https://playerservices.streamtheworld.com/api/livestream-redirect/MONOCLE_24AAC.aac";

export const liveShow: Show = {
  slug: "",
  name: "Monocle 24 (Live)",
  description: "24/7 live radio",
  coverURL:
    coverBase + "2025/01/monocle_logo_radio_large_final-6426fda5b7c82.jpg",
  isLive: true,
  desk: "News",
};

export const shows: Show[] = [
  show("The Globalist", "the-globalist", "Essential weekday news show", "2025/02/THE-GLOBALIST_822_616.png", "News"),
  show("The Briefing", "the-briefing", "Fast-paced news on tech, aviation, retail & media", "2025/02/THE-BRIEFING_822_616.png", "News"),
  show("The Monocle Daily", "the-monocle-daily", "Weekday global news and analysis", "2025/02/THE-MONOCLE-DAILY_822_616.png", "News"),
  show("The Urbanist", "the-urbanist", "Guide to making better cities", "2025/02/THE-URBANIST_822_616.png", "Design & Culture"),
  show("The Entrepreneurs", "the-entrepreneurs", "Deep dive into global business", "2025/02/THE-ENTREPRENEURS_822_616.png", "Business"),
  show("Monocle on Design", "monocle-on-design", "Furniture, craft and architecture", "2025/02/MONOCLE-ON-DESIGN_822_616.png", "Design & Culture"),
  show("Monocle on Culture", "monocle-on-culture", "Art, film, books and media", "2025/02/MONOCLE-ON-CULTURE_822_616.png", "Design & Culture"),
  show("Monocle on Fashion", "monocle-on-fashion", "Interviews and breaking fashion news", "2025/03/MONOCLE-ON-FASHION_822_616.png", "Design & Culture"),
  show("Monocle on Saturday", "monocle-on-saturday", "Stories, global news and culture", "2025/02/MONOCLE-ON-SATURDAY_822_616.png", "Weekend"),
  show("Monocle on Sunday", "monocle-on-sunday", "Live from Zurich on global affairs", "2025/02/MONOCLE-ON-SUNDAY_822_616.png", "Weekend"),
  show("The Menu", "the-menu", "Top chefs, food innovators and producers", "2025/02/THE-MENU_822_616.png", "Food & Travel"),
  show("The Foreign Desk", "the-foreign-desk", "Global affairs and geopolitical analysis", "2025/02/THE-FOREIGN-DESK_822_616.png", "News"),
  show("The Big Interview", "the-big-interview", "In-depth conversations with global leaders", "2025/02/THE-BIG-INTERVIEW_822_616.png", "Business"),
  show("The Chiefs", "the-chiefs", "CEO interviews on navigating challenges", "2025/02/THE-CHIEFS_822_616.png", "Business"),
  show("The Bulletin with UBS", "the-bulletin-with-ubs", "Global finance and economic trends", "2025/02/THE-BULLETIN_822_616.png", "Business"),
  show("Meet the Writers", "meet-the-writers", "Conversations with authors", "2025/02/MEET-THE-WRITERS_822_616.png", "Design & Culture"),
  show("The Stack", "the-stack", "For print and publishing enthusiasts", "2025/02/THE-STACK_822_616.png", "Design & Culture"),
  show("The Global Countdown", "the-global-countdown", "Global music charts", "2025/02/THE-GLOBAL-COUNTDOWN_822_616.png", "Design & Culture"),
  show("The Monocle Weekly", "the-monocle-weekly", "Authors, artists and business leaders", "2025/02/THE-MONOCLE-WEEKLY_822_616.png", "Design & Culture"),
  show("Konfekt Korner", "konfekt-korner", "Fashion, craft, food and travel", "2025/02/KONFEKT-KORNER_822_616.png", "Food & Travel"),
  show("Pullman Voices", "pullman-voices", "Cultural pioneers and creative minds", "2025/04/PULLMAN_TILE_822_616.jpg", "Design & Culture"),
  show("The Concierge", "the-concierge", "Travel tips and destination insights", "2025/03/THE-CONCIERGE_822_616.png", "Food & Travel"),
  show("The Curator", "the-curator", "Weekly highlights from Monocle Radio", "2025/02/THE-CURATOR_822_616.png", "Weekend"),
  show("Monocle In Milan", "monocle-in-milan", "Live coverage from Milan", "2026/02/Monocle-In-Milan.jpg", "Design & Culture"),
  show("Monocle Meets", "monocle-meets", "Q&A conversations with the people shaping our world", "2026/08/MONOCLE-MEETS_WEB.png", "Design & Culture"),
];

export const allShows: Show[] = [liveShow, ...shows];

/// Stable identity, mirroring Episode.id in MonocleRadioKit
export function episodeId(ep: Episode): string {
  return ep.audioURL ?? `${ep.title}-${ep.number}`;
}

/// Site dates arrive as "03 Jul 2026" — render as "Today", "Yesterday" or "3 Jul".
export function displayDate(raw: string): string {
  const m = raw.trim().match(/^(\d{1,2}) ([A-Za-z]{3}) (\d{4})$/);
  if (!m) return raw;
  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const month = months.indexOf(m[2]);
  if (month < 0) return raw;
  const parsed = new Date(Date.UTC(+m[3], month, +m[1]));
  const today = new Date();
  const yest = new Date(today);
  yest.setDate(yest.getDate() - 1);
  const same = (a: Date, b: Date) =>
    a.getUTCFullYear() === b.getFullYear() && a.getUTCMonth() === b.getMonth() && a.getUTCDate() === b.getDate();
  if (same(parsed, today)) return "Today";
  if (same(parsed, yest)) return "Yesterday";
  return `${parsed.getUTCDate()} ${months[parsed.getUTCMonth()]}`;
}
