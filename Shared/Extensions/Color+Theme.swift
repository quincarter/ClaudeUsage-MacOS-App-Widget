import SwiftUI

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Claude Branding & Peak Accents
    static let claudeBrand = Color(hex: "#CC785C")
    static let claudeBrandLight = Color(hex: "#E59880")
    static let claudeBrandDark = Color(hex: "#9F4D32")

    static let peakRed = Color(hex: "#EF4444")
    static let peakOrange = Color(hex: "#F97316")
    static let peakAmber = Color(hex: "#F59E0B")
    static let offPeakGreen = Color(hex: "#10B981")
    static let offPeakTeal = Color(hex: "#06B6D4")

    static let glassCardBackground = Color.black.opacity(0.2)
    static let surfaceSecondary = Color.secondary.opacity(0.12)
}
