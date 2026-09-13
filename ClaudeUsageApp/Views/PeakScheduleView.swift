import ClaudeUsageShared
import SwiftUI

public struct PeakScheduleView: View {
    @State private var selectedTestDate = Date()
    @State private var selectedTimezone: TimeZone = .current
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var testStatus: PeakStatus {
        PeakTimeEngine.shared.currentStatus(at: selectedTestDate)
    }

    var regionalWindows: [TimezonePeakWindow] {
        PeakTimeEngine.shared.regionalWindows(for: currentTime, deviceTimezone: selectedTimezone)
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Peak Window Schedule")
                        .font(.system(size: 20, weight: .bold))
                    Text("Claude experiences peak global demand on weekdays from 5:00 AM to 11:00 AM Pacific Time (PT).")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Regional Windows Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("Regional Timezone Translations")
                        .font(.system(size: 14, weight: .bold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(regionalWindows) { item in
                            regionalCard(item)
                        }
                    }
                }

                Divider()

                // Weekly 7-Day Schedule
                VStack(alignment: .leading, spacing: 10) {
                    Text("7-Day Global Schedule")
                        .font(.system(size: 14, weight: .bold))

                    VStack(spacing: 6) {
                        scheduleDayRow(day: "Monday", isWeekday: true, window: "5:00 AM – 11:00 AM PT")
                        scheduleDayRow(day: "Tuesday", isWeekday: true, window: "5:00 AM – 11:00 AM PT")
                        scheduleDayRow(day: "Wednesday", isWeekday: true, window: "5:00 AM – 11:00 AM PT")
                        scheduleDayRow(day: "Thursday", isWeekday: true, window: "5:00 AM – 11:00 AM PT")
                        scheduleDayRow(day: "Friday", isWeekday: true, window: "5:00 AM – 11:00 AM PT")
                        scheduleDayRow(day: "Saturday", isWeekday: false, window: "Off-Peak All Day")
                        scheduleDayRow(day: "Sunday", isWeekday: false, window: "Off-Peak All Day")
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }

                Divider()

                // Interactive Peak Time Simulator
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interactive Peak Simulator")
                        .font(.system(size: 14, weight: .bold))
                    Text("Check whether a future invocation or scheduled script falls inside the peak window.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        DatePicker("Inspect Date & Time:", selection: $selectedTestDate)
                            .datePickerStyle(.compact)

                        Button("Set to Now") {
                            selectedTestDate = Date()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Result
                    HStack(spacing: 12) {
                        Circle()
                            .fill(testStatus.isPeak ? Color.peakRed : Color.offPeakGreen)
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(testStatus.statusTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(testStatus.isPeak ? Color.peakRed : Color.offPeakGreen)

                            Text(testStatus.statusSubheading)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(testStatus.isPeak ? "⚠️ High Traffic Window" : "🟢 Optimal Speed Window")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((testStatus.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.15))
                            .foregroundColor(testStatus.isPeak ? Color.peakRed : Color.offPeakGreen)
                            .cornerRadius(6)
                    }
                    .padding(12)
                    .background((testStatus.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.06))
                    .cornerRadius(8)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(10)
            }
            .padding(20)
        }
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
        .navigationTitle("Peak Time Intelligence")
    }

    private func regionalCard(_ item: TimezonePeakWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.regionCode)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.isCurrentDeviceZone ? Color.claudeBrand.opacity(0.2) : Color.secondary.opacity(0.15))
                    .foregroundColor(item.isCurrentDeviceZone ? Color.claudeBrand : .primary)
                    .cornerRadius(4)

                Text(item.regionName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                if item.isCurrentDeviceZone {
                    Text("YOUR DEVICE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.claudeBrand)
                }
            }

            Text(item.windowString)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack {
                Text("Current Clock:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(item.localTimeFormatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func scheduleDayRow(day: String, isWeekday: Bool, window: String) -> some View {
        HStack {
            Text(day)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 90, alignment: .leading)

            Spacer()

            if isWeekday {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.peakOrange)
                        .frame(width: 6, height: 6)
                    Text(window)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.offPeakGreen)
                        .frame(width: 6, height: 6)
                    Text(window)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.offPeakGreen)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
