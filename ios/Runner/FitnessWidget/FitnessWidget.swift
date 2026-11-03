import WidgetKit
import SwiftUI

struct FitnessEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let heartPoints: Int
    let momentum: Int
    let momentumLabel: String
    let heartTarget: Int
    let isLocked: Bool

    var targetProgress: Double {
        guard heartTarget > 0 else { return 0 }
        return min(1, Double(heartPoints) / Double(heartTarget))
    }
}

struct Provider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.zerotrustfitness")

    func placeholder(in context: Context) -> FitnessEntry {
        FitnessEntry(date: Date(), steps: 0, heartPoints: 0, momentum: 0, momentumLabel: "", heartTarget: 0, isLocked: true)
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
        let momentum = userDefaults?.integer(forKey: "momentum") ?? 0
        let momentumLabel = userDefaults?.string(forKey: "momentumLabel") ?? ""
        let heartTarget = userDefaults?.integer(forKey: "heartTarget") ?? 0
        let isLocked = userDefaults?.bool(forKey: "isLocked") ?? true
        return FitnessEntry(
            date: Date(),
            steps: steps,
            heartPoints: heartPoints,
            momentum: momentum,
            momentumLabel: momentumLabel,
            heartTarget: heartTarget,
            isLocked: isLocked
        )
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

struct MomentumRow: View {
    let entry: FitnessEntry
    let compact: Bool

    private let amber = Color(red: 0.96, green: 0.62, blue: 0.04)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(amber)
                Text(entry.isLocked ? "---" : "\(entry.momentum)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                if !compact && !entry.isLocked {
                    Text(entry.momentumLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(targetText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(amber)
                        .frame(width: proxy.size.width * CGFloat(entry.isLocked ? 0 : entry.targetProgress))
                }
            }
            .frame(height: 4)
        }
    }

    private var targetText: String {
        if entry.isLocked { return compact ? "" : "Unlock to view" }
        guard entry.heartTarget > 0 else { return "" }
        return compact
            ? "\(entry.heartPoints)/\(entry.heartTarget)"
            : "\(entry.heartPoints) / \(entry.heartTarget) pts"
    }
}

struct FitnessWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
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

                MomentumRow(entry: entry, compact: family == .systemSmall)
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
        .description("Displays your secured steps, heart points and Momentum.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FitnessWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitnessWidget()
    }
}
