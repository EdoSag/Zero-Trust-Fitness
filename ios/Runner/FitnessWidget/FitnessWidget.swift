import WidgetKit
import SwiftUI

struct FitnessEntry: TimelineEntry {
    val date: Date
    val steps: Int
    val heartPoints: Int
    val isLocked: Bool
}

struct FitnessWidgetEntryView : View {
    var entry: FitnessEntry

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
            // Apply the "Security Blur" if the vault is locked
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

// Ensure you use the App Group ID set in your entitlements
let userDefaults = UserDefaults(suiteName: "group.zerotrustfitness")