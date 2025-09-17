import SwiftUI

// Central place to manage colors, fonts, spacing etc.
struct AppTheme {
    // Colors
    static let accentColor = Color("AccentColor")
    static let backgroundColor = Color(.systemBackground)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let buttonGradientStart = Color.blue
    static let buttonGradientEnd = Color.purple

    // Typography
    struct FontStyle {
        static let title = Font.system(size: 32, weight: .bold, design: .rounded)
        static let subtitle = Font.system(size: 18, weight: .medium, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
        static let button = Font.system(size: 18, weight: .semibold)
    }

    // Layout
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 32
    }

    // Components
    struct ButtonStylePrimary: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(AppTheme.FontStyle.button)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [AppTheme.buttonGradientStart, AppTheme.buttonGradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    ).opacity(configuration.isPressed ? 0.7 : 1)
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}
