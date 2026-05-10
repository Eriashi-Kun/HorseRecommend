import SwiftUI

// MARK: - Splatoon Color Palette

enum SplatTheme {
    static let bg      = Color(red: 0.05, green: 0.04, blue: 0.08)
    static let surface = Color(red: 0.10, green: 0.09, blue: 0.15)
    static let card    = Color(red: 0.13, green: 0.12, blue: 0.19)
    static let cyan    = Color(red: 0.00, green: 0.95, blue: 1.00)
    static let yellow  = Color(red: 1.00, green: 0.88, blue: 0.00)
    static let magenta = Color(red: 1.00, green: 0.02, blue: 0.65)
    static let purple  = Color(red: 0.72, green: 0.00, blue: 1.00)
}

// MARK: - Ink Blob Background

struct InkBlobBackground: View {
    let primaryColor: Color

    var body: some View {
        ZStack {
            SplatTheme.bg

            Ellipse()
                .fill(primaryColor.opacity(0.22))
                .frame(width: 430, height: 330)
                .blur(radius: 90)
                .offset(x: -70, y: -200)
                .allowsHitTesting(false)

            Ellipse()
                .fill(SplatTheme.purple.opacity(0.15))
                .frame(width: 300, height: 260)
                .blur(radius: 70)
                .offset(x: 150, y: 140)
                .allowsHitTesting(false)

            Circle()
                .fill(primaryColor.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: -110, y: 240)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Splat Button Style (physical press-down effect)

struct SplatButtonStyle: ButtonStyle {
    var color: Color
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.7))
                .offset(y: configuration.isPressed ? 2 : 6)

            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .offset(y: configuration.isPressed ? 2 : 0)

            configuration.label
                .offset(y: configuration.isPressed ? 2 : 0)
        }
        .frame(height: height)
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Scale Press Style

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
