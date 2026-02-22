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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.85))

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }
}

struct FitnessWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.24),
                    Color(red: 0.10, green: 0.29, blue: 0.63),
                    Color(red: 0.65, green: 0.12, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 120, height: 120)
                .offset(x: 80, y: -60)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ZERO-TRUST FITNESS")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white.opacity(0.92))
                    Spacer()
                    Text(entry.isLocked ? "Vault Locked" : "Securely Synced")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(entry.isLocked ? .white : Color(red: 0.82, green: 0.98, blue: 0.90))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    StatCard(
                        title: "STEPS",
                        value: entry.isLocked ? "---" : "\(entry.steps)",
                        icon: "figure.walk",
                        gradient: LinearGradient(
                            colors: [Color(red: 0.21, green: 0.30, blue: 0.91), Color(red: 0.30, green: 0.53, blue: 0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    StatCard(
                        title: "HEART POINTS",
                        value: entry.isLocked ? "---" : "\(entry.heartPoints)",
                        icon: "heart.fill",
                        gradient: LinearGradient(
                            colors: [Color(red: 0.86, green: 0.18, blue: 0.34), Color(red: 0.95, green: 0.34, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }

                Text(entry.isLocked ? "Unlock in app to reveal your latest stats." : "Encrypted sync is active.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(12)
        }
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
