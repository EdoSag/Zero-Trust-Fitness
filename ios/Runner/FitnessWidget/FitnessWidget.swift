import WidgetKit
import SwiftUI

struct FitnessEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let heartPoints: Int
    let isLocked: Bool
}

struct Provider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.zerotrustfitness")

    func placeholder(in context: Context) -> FitnessEntry {
        FitnessEntry(date: Date(), steps: 0, heartPoints: 0, isLocked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FitnessEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitnessEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> FitnessEntry {
        let steps = userDefaults?.integer(forKey: "steps") ?? 0
        let heartPoints = userDefaults?.integer(forKey: "heartPoints") ?? 0
        let isLocked = userDefaults?.bool(forKey: "isLocked") ?? true
        return FitnessEntry(date: Date(), steps: steps, heartPoints: heartPoints, isLocked: isLocked)
    }
}

struct FitnessWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Zero-Trust Stats")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                VStack(alignment: .leading) {
                    Text("\(entry.steps)").font(.title).bold()
                    Text("Steps").font(.caption2)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(entry.heartPoints)").font(.title).bold()
                    Text("Points").font(.caption2)
                }
            }
            .blur(radius: entry.isLocked ? 12 : 0)

            if entry.isLocked {
                Text("Tap to Unlock")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct FitnessWidget: Widget {
    let kind: String = "FitnessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FitnessWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zero-Trust Fitness")
        .description("Displays your secured steps and heart points.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FitnessWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitnessWidget()
    }
}
