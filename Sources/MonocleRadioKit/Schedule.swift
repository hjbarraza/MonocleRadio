// Schedule.swift — today's Monocle 24 programme, scraped from /radio/schedule/
// MonocleRadioKit — shared core for the macOS and iOS Monocle Radio apps

import Foundation
import SwiftSoup

// MARK: - Schedule Entry

public struct ScheduleEntry: Identifiable, Hashable {
    public let time: Date
    public let title: String

    public var id: String { "\(time.timeIntervalSince1970)-\(title)" }

    public init(time: Date, title: String) {
        self.time = time
        self.title = title
    }
}

// MARK: - Scraper

public enum Schedule {
    /// Scrape today's programme. Card times arrive as "HH:mm GMT" and are
    /// resolved against today's date in GMT; Date display is local for free.
    public static func fetchToday() async throws -> [ScheduleEntry] {
        let url = URL(string: "https://monocle.com/radio/schedule/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let doc = try SwiftSoup.parse(html)
        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = TimeZone(identifier: "GMT")!
        let today = gmt.startOfDay(for: Date())

        var entries: [ScheduleEntry] = []
        for card in try doc.select(".c-schedule-card").array() {
            guard let metaText = try? card.select(".c-schedule-card__meta p").first()?.text(),
                  let title = try? card.select(".c-schedule-card__title").first()?.text(),
                  !title.isEmpty else { continue }

            // "00:01 GMT" → today 00:01 GMT
            let parts = metaText.replacingOccurrences(of: "GMT", with: "")
                .trimmingCharacters(in: .whitespaces)
                .split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  let time = gmt.date(bySettingHour: hour, minute: minute, second: 0, of: today)
            else { continue }

            entries.append(ScheduleEntry(time: time, title: title))
        }
        return entries.sorted { $0.time < $1.time }
    }
}

// MARK: - Live Activity Attributes (shared with the widget extension)

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

public struct NowPlayingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var subtitle: String
        public var isPlaying: Bool
        public var isLive: Bool

        public init(title: String, subtitle: String, isPlaying: Bool, isLive: Bool) {
            self.title = title
            self.subtitle = subtitle
            self.isPlaying = isPlaying
            self.isLive = isLive
        }
    }

    public init() {}
}
#endif
