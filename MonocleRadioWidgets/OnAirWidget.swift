// OnAirWidget.swift — home screen widget: what's on Monocle 24 right now
// Monocle Radio — iOS player for Monocle 24
//
// Timeline follows today's scraped schedule: one entry per programme slot,
// so ON AIR / UP NEXT flip exactly on the hour marks with no polling.

import WidgetKit
import SwiftUI
import MonocleRadioKit

private let ink = Color(red: 0.090, green: 0.082, blue: 0.070)
private let paperWhite = Color(red: 0.980, green: 0.969, blue: 0.945)
private let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)
private let monocleRed = Color(red: 0.804, green: 0.114, blue: 0.114)

struct OnAirEntry: TimelineEntry {
    let date: Date
    let onAir: String?
    let upNext: ScheduleEntry?
}

struct OnAirProvider: TimelineProvider {
    func placeholder(in context: Context) -> OnAirEntry {
        OnAirEntry(date: Date(), onAir: "The Globalist", upNext: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OnAirEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OnAirEntry>) -> Void) {
        Task {
            let schedule = (try? await Schedule.fetchToday()) ?? []
            guard !schedule.isEmpty else {
                // Retry in 30 minutes if the scrape failed
                let entry = OnAirEntry(date: Date(), onAir: nil, upNext: nil)
                completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
                return
            }

            // One timeline entry per remaining slot today (plus "now")
            var entries: [OnAirEntry] = []
            let now = Date()
            let times = [now] + schedule.map(\.time).filter { $0 > now }
            for at in times {
                let onAir = schedule.last { $0.time <= at }?.title
                let next = schedule.first { $0.time > at }
                entries.append(OnAirEntry(date: at, onAir: onAir, upNext: next))
            }
            // Refresh after the last slot to pick up tomorrow's schedule
            let refresh = (schedule.map(\.time).max() ?? now).addingTimeInterval(5 * 60)
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }
}

struct OnAirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OnAirWidget", provider: OnAirProvider()) { entry in
            OnAirWidgetView(entry: entry)
                .containerBackground(ink, for: .widget)
        }
        .configurationDisplayName("On Air")
        .description("What's playing on Monocle 24 right now.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct OnAirWidgetView: View {
    let entry: OnAirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(monocleRed).frame(width: 7, height: 7)
                Text("On Air")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(monocleRed)
            }

            Text(entry.onAir ?? "Monocle 24")
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(paperWhite)
                .lineLimit(family == .systemSmall ? 3 : 2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if let next = entry.upNext {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up Next")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(paperWhite.opacity(0.45))
                    HStack(spacing: 6) {
                        Text(next.time, format: .dateTime.hour().minute())
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(monocleGold)
                        Text(next.title)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(paperWhite.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
