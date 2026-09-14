import Foundation
import SwiftUI

/// A SwiftUI view that renders a live-updating countdown for peak status using system relative date formatting.
public struct PeakStatusLiveSubheadingView: View {
    public let status: PeakStatus

    public init(status: PeakStatus) {
        self.status = status
    }

    public var body: some View {
        switch status {
        case .peakActive(let endsAt, _):
            Text("Ends in ") + Text(endsAt, style: .relative)
        case .approachingPeak(let startsAt, _):
            Text("Starts in ") + Text(startsAt, style: .relative)
        case .offPeak(let nextDate, let until):
            if until > 24 * 3600 {
                Text("Next: \(formatNextDate(nextDate))")
            } else {
                Text("Starts in ") + Text(nextDate, style: .relative)
            }
        }
    }

    private func formatNextDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE 'at' h:mm a"
        return formatter.string(from: date)
    }
}
