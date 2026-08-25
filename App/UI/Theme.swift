import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.957, green: 0.957, blue: 0.961)
    static let canvasDark = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let stroke = Color.white.opacity(0.46)
    static let strokeDark = Color.white.opacity(0.10)
    static let ease = Animation.timingCurve(0.16, 1.0, 0.30, 1.0, duration: 0.18)
    static let cardRadius: CGFloat = 22
    static let buttonRadius: CGFloat = 14
}

struct GlassCard<Content: View>: View {
    var appearance: AppearanceStyle
    var breathing: Bool = false
    var content: Content
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    init(appearance: AppearanceStyle, breathing: Bool = false, @ViewBuilder content: () -> Content) {
        self.appearance = appearance
        self.breathing = breathing
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: breathing ? (pulse ? 1.6 : 0.6) : 0.7)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.38),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 18, x: 0, y: 8)
            .onAppear {
                guard breathing else { return }
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: breathing) { value in
                pulse = false
                guard value else { return }
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }

    @ViewBuilder
    private var background: some View {
        if appearance == .frosted {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        } else {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private var borderColor: Color {
        if breathing {
            return Color.white.opacity(pulse ? 0.85 : 0.28)
        }
        return colorScheme == .dark ? AppTheme.strokeDark : AppTheme.stroke
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(AppTheme.ease, value: configuration.isPressed)
    }
}

struct GlassChip: View {
    let title: String
    let value: String
    var appearance: AppearanceStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if appearance == .frosted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
        )
    }
}
