import { test } from "node:test";
import assert from "node:assert/strict";
import { parseEpisodes } from "../lib/parse-episodes.ts";

const A = (id: string) => `https://traffic.omny.fm/d/clips/x/${id}/audio.mp3`;
const card = (o: { title: string; id?: string; num?: string; date?: string; desc?: string }) => `
<article class="c-episode-card">
  <div class="c-episode-card__media"><figure><img src="https://img/${o.title}.jpg"></figure>
    <div class="c-episode-card__meta">
      ${o.date ? `<span class="c-episode-card__date"> ${o.date} </span>` : ""}
      ${o.num ? `<span class="c-episode-card__number">${o.num}</span>` : ""}
    </div></div>
  <div class="c-episode-card__content"><h3><a href="/radio/shows/x/episode">${o.title}</a></h3>
    ${o.desc ? `<p class="c-episode-card__description">${o.desc}</p>` : ""}
    ${o.id ? `<audio src="${A(o.id)}"></audio>` : ""}
  </div>
</article>`;

test("fields stay on their own card when some cards lack a number", () => {
  const html = `<html><body>
    ${card({ title: "First", id: "a1", date: "23 Nov 2026" })}
    ${card({ title: "Second", id: "a2", date: "21 Nov 2026", num: "#788", desc: "Two" })}
    ${card({ title: "Third", id: "a3", date: "19 Nov 2026" })}
  </body></html>`;
  const eps = parseEpisodes(html);
  assert.equal(eps.length, 3);
  assert.deepEqual(eps.map((e) => e.number), ["", "#788", ""]);
  assert.deepEqual(eps.map((e) => e.title), ["First", "Second", "Third"]);
  assert.deepEqual(eps.map((e) => e.audioURL), [A("a1"), A("a2"), A("a3")]);
  assert.equal(eps[1].description, "Two");
  assert.equal(eps[0].description, "");
  assert.equal(eps[0].date, "23 Nov 2026");
});

test("a card without audio stays unavailable instead of stealing the next audio", () => {
  const html = `${card({ title: "NoAudio" })}${card({ title: "HasAudio", id: "b1" })}`;
  const eps = parseEpisodes(html);
  assert.equal(eps[0].audioURL, null);
  assert.equal(eps[1].audioURL, A("b1"));
});

test("falls back to index matching for markup without cards", () => {
  const html = `<h3 class="episode-title"><a href="/radio/shows/x/episode-1">Old</a></h3>
    <span class="episode-date">1 Jan 2026</span><script>"${A("z9")}"</script>`;
  const eps = parseEpisodes(html);
  assert.equal(eps.length, 1);
  assert.equal(eps[0].title, "Old");
  assert.equal(eps[0].audioURL, A("z9"));
});

test("empty page gives no episodes", () => {
  assert.deepEqual(parseEpisodes("<html></html>"), []);
});
