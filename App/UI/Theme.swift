import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.957, green: 0.957, blue: 0.961)
    static let canvasDark = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let stroke = Color.white.opacity(0.46)
    static let strokeDark = Color.white.opacity(0.10)
    static let ease = Animation.timingCurve(0.16, 1.0, 0.30, 1.0, duration: 0.18)
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let cardRadius: CGFloat = 24
    static let buttonRadius: CGFloat = 16
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
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07), radius: 20, x: 0, y: 10)
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
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
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

struct SelectableTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let selected: Bool
    var appearance: AppearanceStyle

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(width: 36, height: 36)
                .background(selected ? AppTheme.ink : Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scaleEffect(selected ? 1.04 : 1)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background {
            if appearance == .frosted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? AppTheme.ink.opacity(0.85) : Color.white.opacity(0.28), lineWidth: selected ? 1.4 : 0.6)
        )
        .shadow(color: selected ? Color.black.opacity(0.08) : .clear, radius: 10, y: 4)
        .animation(AppTheme.spring, value: selected)
    }
}

struct StatusBadge: View {
    let broadcasting: Bool
    let running: Bool
    let translating: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: translating ? 6 : 0)
                        .scaleEffect(translating ? 1.6 : 1)
                        .opacity(translating ? 0 : 1)
                        .animation(translating ? .easeOut(duration: 1.1).repeatForever(autoreverses: false) : .default, value: translating)
                )
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
    }

    private var color: Color {
        if broadcasting { return .green }
        if running { return .orange }
        return .gray.opacity(0.55)
    }

    private var label: String {
        if translating { return "翻译中" }
        if broadcasting { return "直播中" }
        if running { return "等待直播" }
        return "未开始"
    }
}
