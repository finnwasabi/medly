import AlarmKit
import SwiftUI
import WidgetKit

@main
struct NersDailyWidgets: WidgetBundle {
    var body: some Widget {
        DoseAlarmLiveActivity()
    }
}

/// Màn khoá và Dynamic Island khi báo thức đang kêu hoặc đang hoãn.
struct DoseAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<DoseAlarmMetadata>.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "pills.fill")
                    .font(.title)
                    .foregroundStyle(context.attributes.tintColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(context.state, context.attributes.metadata))
                        .font(.headline)
                    Text("Ner's Daily")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                countdown(context.state)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(context.attributes.tintColor)
            }
            .padding(16)
            .fontDesign(.rounded)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(title(context.state, context.attributes.metadata), systemImage: "pills.fill")
                        .font(.headline)
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state)
                        .font(.title2.bold().monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "pills.fill")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                countdown(context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "pills.fill")
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    private func title(_ state: AlarmPresentationState, _ metadata: DoseAlarmMetadata?) -> String {
        let en = metadata?.language == "en"
        switch state.mode {
        case .countdown: return en ? "Pill snoozed" : "Đang hoãn uống thuốc"
        case .paused: return en ? "Snooze paused" : "Đã dừng hoãn"
        default: return en ? "Time to take your pill" : "Tới giờ uống thuốc"
        }
    }

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        if case .countdown(let countdown) = state.mode {
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
        } else {
            Image(systemName: "alarm.waves.left.and.right.fill")
        }
    }
}
