import SwiftUI

// Shared design system colors for Counsel

public enum CounselColors {
    // Core semantic colors
    public static let primaryText = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.92)
    public static let secondaryText = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.62)
    public static let tertiaryText = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.38)
    public static let icon = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.65)
    public static let iconDisabled = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.45)
    public static let destructive = Color(.sRGB, red: 1.0, green: 0.0, blue: 0.0, opacity: 0.88)
    public static let border = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 0.18)
}

// Paywall-specific palette (shared so it can be reused anywhere)
public enum ProColors {
    public static let white92 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.92)
    public static let white88 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.88)
    public static let white85 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.85)
    public static let white75 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.75)
    public static let white70 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.70)
    public static let white65 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.65)
    public static let white62 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.62)
    public static let white60 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.60)
    public static let white55 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.55)
    public static let white35 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.35)
    public static let white18 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.18)
    public static let white10 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.10)

    public static let red90 = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 0.90)
}
public enum AppGradients {
    public static let counsel = LinearGradient(
        stops: [
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.98), location: 0.0),
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.90), location: 0.55),
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.98), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let pro = LinearGradient(
        stops: [
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.98), location: 0.0),
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.90), location: 0.55),
            .init(color: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 0.98), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

