import SwiftUI

public struct PeakTimelineBar: View {
    public let slice: DayTimelineSlice
    public let height: CGFloat
    public let showLabels: Bool

    public init(slice: DayTimelineSlice, height: CGFloat = 16, showLabels: Bool = true) {
        self.slice = slice
        self.height = height
        self.showLabels = showLabels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // Base 24h background track (Off-peak zone)
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: height)

                    // Peak window band (if today has peak hours)
                    if slice.hasPeakToday {
                        let startX = width * CGFloat(slice.peakStartFraction)
                        let endX = width * CGFloat(slice.peakEndFraction)
                        let bandWidth = max(4, endX - startX)

                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color.peakOrange, Color.peakRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: bandWidth, height: height)
                            .offset(x: startX)
                            .overlay(
                                // Subtle diagonal hatch or glow
                                RoundedRectangle(cornerRadius: height / 2)
                                    .stroke(Color.peakOrange.opacity(0.6), lineWidth: 1)
                                    .frame(width: bandWidth, height: height)
                                    .offset(x: startX)
                            )
                    }

                    // Current time cursor
                    let cursorX = max(0, min(width - 2, width * CGFloat(slice.currentFraction)))
                    ZStack {
                        // Cursor glow
                        Circle()
                            .fill(Color.white)
                            .frame(width: height + 2, height: height + 2)
                            .shadow(color: Color.black.opacity(0.3), radius: 2)

                        Circle()
                            .fill(slice.hasPeakToday && slice.currentFraction >= slice.peakStartFraction && slice.currentFraction < slice.peakEndFraction ? Color.peakRed : Color.offPeakGreen)
                            .frame(width: height - 4, height: height - 4)
                    }
                    .offset(x: cursorX - (height / 2))
                }
            }
            .frame(height: height)

            if showLabels {
                HStack {
                    Text("12 AM")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    if slice.hasPeakToday {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.peakOrange)
                                .frame(width: 5, height: 5)
                            Text("Peak: \(slice.localStartString) – \(slice.localEndString)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    } else {
                        Text("Weekend (Off-Peak All Day)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.offPeakGreen)
                    }

                    Spacer()

                    Text("11:59 PM")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
