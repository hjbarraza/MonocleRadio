// Models.swift — Show/Episode data, catalog, and episode scraper
// Monocle Radio — macOS menu bar player for Monocle 24

import Foundation
import SwiftSoup

// MARK: - Show

struct Show: Identifiable, Hashable {
    var id: String { slug.isEmpty ? "live" : slug }
    let name: String
    let slug: String
    let description: String
    let coverURL: URL?
    let isLive: Bool

    init(_ name: String, _ slug: String, _ description: String, _ coverPath: String, isLive: Bool = false) {
        self.name = name
        self.slug = slug
        self.description = description
        self.coverURL = URL(string: coverPath)
        self.isLive = isLive
    }

    // Monocle 24 live AAC stream
    static let liveStreamURL = URL(string:
        "https://playerservices.streamtheworld.com/api/livestream-redirect/MONOCLE_24AAC.aac")!

    static let coverBase = "https://monocle.com/wp-content/uploads/"

    /// Full catalog: live stream + 24 on-demand shows
    static func all() -> [Show] {
        let b = coverBase
        return [
            Show("Monocle 24 (Live)", "", "24/7 live radio",
                 b + "2025/01/monocle_logo_radio_large_final-6426fda5b7c82.jpg", isLive: true),
            Show("The Globalist", "the-globalist", "Essential weekday news show",
                 b + "2025/02/THE-GLOBALIST_822_616.png"),
            Show("The Briefing", "the-briefing", "Fast-paced news on tech, aviation, retail & media",
                 b + "2025/02/THE-BRIEFING_822_616.png"),
            Show("The Monocle Daily", "the-monocle-daily", "Weekday global news and analysis",
                 b + "2025/02/THE-MONOCLE-DAILY_822_616.png"),
            Show("The Urbanist", "the-urbanist", "Guide to making better cities",
                 b + "2025/02/THE-URBANIST_822_616.png"),
            Show("The Entrepreneurs", "the-entrepreneurs", "Deep dive into global business",
                 b + "2025/02/THE-ENTREPRENEURS_822_616.png"),
            Show("Monocle on Design", "monocle-on-design", "Furniture, craft and architecture",
                 b + "2025/02/MONOCLE-ON-DESIGN_822_616.png"),
            Show("Monocle on Culture", "monocle-on-culture", "Art, film, books and media",
                 b + "2025/02/MONOCLE-ON-CULTURE_822_616.png"),
            Show("Monocle on Fashion", "monocle-on-fashion", "Interviews and breaking fashion news",
                 b + "2025/03/MONOCLE-ON-FASHION_822_616.png"),
            Show("Monocle on Saturday", "monocle-on-saturday", "Stories, global news and culture",
                 b + "2025/02/MONOCLE-ON-SATURDAY_822_616.png"),
            Show("Monocle on Sunday", "monocle-on-sunday", "Live from Zurich on global affairs",
                 b + "2025/02/MONOCLE-ON-SUNDAY_822_616.png"),
            Show("The Menu", "the-menu", "Top chefs, food innovators and producers",
                 b + "2025/02/THE-MENU_822_616.png"),
            Show("The Foreign Desk", "the-foreign-desk", "Global affairs and geopolitical analysis",
                 b + "2025/02/THE-FOREIGN-DESK_822_616.png"),
            Show("The Big Interview", "the-big-interview", "In-depth conversations with global leaders",
                 b + "2025/02/THE-BIG-INTERVIEW_822_616.png"),
            Show("The Chiefs", "the-chiefs", "CEO interviews on navigating challenges",
                 b + "2025/02/THE-CHIEFS_822_616.png"),
            Show("The Bulletin with UBS", "the-bulletin-with-ubs", "Global finance and economic trends",
                 b + "2025/02/THE-BULLETIN_822_616.png"),
            Show("Meet the Writers", "meet-the-writers", "Conversations with authors",
                 b + "2025/02/MEET-THE-WRITERS_822_616.png"),
            Show("The Stack", "the-stack", "For print and publishing enthusiasts",
                 b + "2025/02/THE-STACK_822_616.png"),
            Show("The Global Countdown", "the-global-countdown", "Global music charts",
                 b + "2025/02/THE-GLOBAL-COUNTDOWN_822_616.png"),
            Show("The Monocle Weekly", "the-monocle-weekly", "Authors, artists and business leaders",
                 b + "2025/02/THE-MONOCLE-WEEKLY_822_616.png"),
            Show("Konfekt Korner", "konfekt-korner", "Fashion, craft, food and travel",
                 b + "2025/02/KONFEKT-KORNER_822_616.png"),
            Show("Pullman Voices", "pullman-voices", "Cultural pioneers and creative minds",
                 b + "2025/04/PULLMAN_TILE_822_616.jpg"),
            Show("The Concierge", "the-concierge", "Travel tips and destination insights",
                 b + "2025/03/THE-CONCIERGE_822_616.png"),
            Show("The Curator", "the-curator", "Weekly highlights from Monocle Radio",
                 b + "2025/02/THE-CURATOR_822_616.png"),
            Show("Monocle In Milan", "monocle-in-milan", "Live coverage from Milan",
                 b + "2026/02/Monocle-In-Milan.jpg"),
        ]
    }
}

// MARK: - Episode

struct Episode: Identifiable, Hashable {
    var id: String { audioURL?.absoluteString ?? "\(title)-\(number)" }
    let title: String
    let audioURL: URL?
    let number: String
    let date: String
    let description: String

    init(title: String, audioURL: URL? = nil, number: String = "", date: String = "", description: String = "") {
        self.title = title
        self.audioURL = audioURL
        self.number = number
        self.date = date
        self.description = description
    }
}

// MARK: - Episode Scraper

extension Show {
    /// Scrape episode titles and Omny.fm MP3 URLs from the show page
    func fetchEpisodes() async throws -> [Episode] {
        guard !slug.isEmpty else { return [] }

        let url = URL(string: "https://monocle.com/radio/shows/\(slug)/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let doc = try SwiftSoup.parse(html)

        // Extract Omny.fm MP3 URLs via regex
        let audioPattern = try NSRegularExpression(
            pattern: #"https://traffic\.omny\.fm/d/clips/[^"'\s]+/audio\.mp3"#)
        let range = NSRange(html.startIndex..., in: html)
        let audioURLs = audioPattern.matches(in: html, range: range)
            .compactMap { match -> URL? in
                guard let r = Range(match.range, in: html) else { return nil }
                return URL(string: String(html[r]))
            }

        // Extract episode metadata via CSS selectors
        let titleEls = try doc.select(
            "h3.episode-title a, h3 a[href*='episode'], h3 a[href*='/radio/shows/']").array()
        let dateEls = try doc.select(".episode-date").array()
        let numberEls = try doc.select(".episode-number").array()
        let descEls = try doc.select(".episode-description, p.episode-description").array()

        // Build episodes matching by index (audio URLs aligned with title elements)
        var episodes: [Episode] = []
        for (i, audioURL) in audioURLs.enumerated() {
            let title = (i < titleEls.count ? try? titleEls[i].text() : nil) ?? "Episode \(i + 1)"
            let num = (i < numberEls.count ? try? numberEls[i].text() : nil) ?? ""
            let date = (i < dateEls.count ? try? dateEls[i].text() : nil) ?? ""
            let desc = (i < descEls.count ? try? descEls[i].text() : nil) ?? ""
            episodes.append(Episode(title: title, audioURL: audioURL, number: num, date: date, description: desc))
        }

        // Fallback: if titles found but no audio, still list them
        if episodes.isEmpty {
            let fallbackTitles = titleEls.isEmpty
                ? try doc.select("h2 a, h3 a, h4 a").array().filter {
                    (try? $0.attr("href"))?.contains("/radio/shows/") == true
                }
                : titleEls
            for (i, el) in fallbackTitles.enumerated() {
                let title = (try? el.text()) ?? "Episode \(i + 1)"
                let num = (i < numberEls.count ? try? numberEls[i].text() : nil) ?? ""
                let date = (i < dateEls.count ? try? dateEls[i].text() : nil) ?? ""
                episodes.append(Episode(title: title, number: num, date: date))
            }
        }

        return episodes
    }
}
