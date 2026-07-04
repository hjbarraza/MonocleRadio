// WatchWidgets.swift — watch-face complications + Smart Stack card
// Monocle Radio — Apple Watch player for Monocle 24
//
// The app's real front door: ON AIR from the scraped schedule, one tap
// from the face. Timeline flips exactly on programme slots, like the
// iOS OnAirWidget.

import WidgetKit
import SwiftUI
import MonocleRadioKit

private let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)
private let monocleRed = Color(red: 0.804, green: 0.114, blue: 0.114)
private let paperWhite = Color(red: 0.980, green: 0.969, blue: 0.945)

@main
struct MonocleRadioWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchOnAirWidget()
    }
}

struct WatchOnAirEntry: TimelineEntry {
    let date: Date
    let onAir: String?
    let upNext: ScheduleEntry?
}

struct WatchOnAirProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchOnAirEntry {
        WatchOnAirEntry(date: Date(), onAir: "The Globalist", upNext: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchOnAirEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchOnAirEntry>) -> Void) {
        Task {
            let schedule = (try? await Schedule.fetchToday()) ?? []
            guard !schedule.isEmpty else {
                completion(Timeline(
                    entries: [WatchOnAirEntry(date: Date(), onAir: nil, upNext: nil)],
                    policy: .after(Date().addingTimeInterval(30 * 60))
                ))
                return
            }
            var entries: [WatchOnAirEntry] = []
            let now = Date()
            let times = [now] + schedule.map(\.time).filter { $0 > now }
            for at in times {
                entries.append(WatchOnAirEntry(
                    date: at,
                    onAir: schedule.last { $0.time <= at }?.title,
                    upNext: schedule.first { $0.time > at }
                ))
            }
            let refresh = (schedule.map(\.time).max() ?? now).addingTimeInterval(5 * 60)
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }
}

struct WatchOnAirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchOnAirWidget", provider: WatchOnAirProvider()) { entry in
            WatchOnAirView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("On Air")
        .description("What's playing on Monocle 24.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

private struct WatchOnAirView: View {
    let entry: WatchOnAirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // Smart Stack card
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(monocleRed).frame(width: 6, height: 6)
                    Text("ON AIR")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(monocleRed)
                }
                Text(entry.onAir ?? "Monocle 24")
                    .font(.system(.footnote, design: .serif).weight(.semibold))
                    .foregroundStyle(paperWhite)
                    .lineLimit(1)
                if let next = entry.upNext {
                    HStack(spacing: 4) {
                        Text(next.time, format: .dateTime.hour().minute())
                            .monospacedDigit()
                            .foregroundStyle(monocleGold)
                        Text(next.title)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("● \(entry.onAir ?? "Monocle 24")")
        default:
            // Circular / corner: the one-tap door from the face
            ZStack {
                Image(systemName: "radio")
                    .font(.title3)
                    .foregroundStyle(paperWhite)
                Circle()
                    .fill(monocleRed)
                    .frame(width: 7, height: 7)
                    .offset(x: 12, y: -12)
            }
            .widgetLabel {
                Text(entry.onAir ?? "Monocle 24")
            }
        }
    }
}
