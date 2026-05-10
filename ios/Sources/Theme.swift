import SwiftUI

/// Arkade native design tokens.
///
/// Intent: a bitcoin wallet used quickly, one-handed, and repeatedly. The UI
/// should feel precise and calm, with the PWA's portfolio structure translated
/// into iOS-native glass, sheets, lists, and safe-area behavior.
enum Arkade {
    // Primary
    static let purple = Color(hex: 0x391998)
    static let purpleLight = Color(hex: 0xD5C6FF)
    static let purpleBg = Color(hex: 0x24154F)
    static let purpleText = Color(hex: 0x7043F4)
    static let purple10 = Color(hex: 0x391998, opacity: 0.1)
    static let purple20 = Color(hex: 0x391998, opacity: 0.2)

    // Semantic
    static let green = Color(hex: 0x60B18A)
    static let orange = Color(hex: 0xFF8E24)
    static let red = Color(hex: 0xA51515)
    static let blue = Color(hex: 0x3E73C4)
    static let tether = Color(hex: 0x26A17B)

    // Neutral
    static let black = Color(hex: 0x040404)
    static let white = Color(hex: 0xFBFBFB)
    static let gray = Color(hex: 0x808080)
    static let canvas = Color(.systemBackground)
    static let canvasGrouped = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let inset = Color(.tertiarySystemGroupedBackground)
    static let separator = Color(.separator).opacity(0.18)

    // Opacity layers
    static let dark80 = Color(hex: 0x040404, opacity: 0.8)
    static let dark50 = Color(hex: 0x040404, opacity: 0.5)
    static let dark30 = Color(hex: 0x040404, opacity: 0.3)
    static let dark20 = Color(hex: 0x040404, opacity: 0.2)
    static let dark10 = Color(hex: 0x040404, opacity: 0.1)
    static let dark05 = Color(hex: 0x040404, opacity: 0.05)

    // Backgrounds
    static let bgDark = Color(hex: 0x101010)

    // Design tokens
    static let radius: CGFloat = 12
    static let radiusLarge: CGFloat = 18
    static let radiusPill: CGFloat = 999
    static let hPadding: CGFloat = 16
    static let gap: CGFloat = 16
    static let gapSmall: CGFloat = 8
    static let minTap: CGFloat = 44

    // Fonts
    static let headingFont: Font = .system(size: 24, weight: .medium)
    static let headingTracking: CGFloat = -0.4
    static let balanceFont: Font = .system(size: 38, weight: .medium, design: .rounded)
    static let bodyFont: Font = .system(size: 16, weight: .regular)
    static let smallFont: Font = .system(size: 14, weight: .regular)
    static let tinyFont: Font = .system(size: 12, weight: .regular)
    static let buttonFont: Font = .system(size: 15, weight: .medium)

    static func sats(_ sats: UInt64) -> String {
        sats.formatted(.number.grouping(.automatic))
    }

    static func signedSats(_ sats: Int64) -> String {
        let absolute = UInt64(abs(sats))
        let prefix = sats > 0 ? "+" : sats < 0 ? "-" : ""
        return "\(prefix)\(Self.sats(absolute)) sats"
    }
}

// MARK: - Reusable View Modifiers

/// Arkade primary button style — purple bg, 3D shadow, monospaced uppercase
struct ArkadeButtonStyle: ViewModifier {
    var variant: ArkadeButtonVariant = .primary

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Arkade.minTap + 2)
            .foregroundStyle(variant.foreground)
            .background(variant.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: variant.shadow, radius: 0, x: 0, y: 4)
    }
}

enum ArkadeButtonVariant {
    case primary, secondary, secondaryOnDark, clearOnDark, outline, danger

    var background: Color {
        switch self {
        case .primary: Arkade.purple
        case .secondary: Arkade.dark10
        case .secondaryOnDark: Arkade.white.opacity(0.10)
        case .clearOnDark: .clear
        case .outline: .clear
        case .danger: Arkade.red
        }
    }

    var foreground: Color {
        switch self {
        case .primary, .danger: Arkade.white
        case .secondary: Arkade.black
        case .secondaryOnDark: Arkade.white
        case .clearOnDark: Arkade.white
        case .outline: Arkade.black
        }
    }

    var shadow: Color {
        switch self {
        case .primary: Arkade.purpleBg
        case .secondary, .secondaryOnDark, .outline: Color.black.opacity(0.14)
        case .clearOnDark: .clear
        case .danger: Arkade.red.opacity(0.65)
        }
    }
}

/// Arkade card — subtle background, 8px radius
struct ArkadeCard: ViewModifier {
    var bg: Color = Arkade.dark10

    func body(content: Content) -> some View {
        content
            .padding(Arkade.gap)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Arkade.radius))
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}

struct ArkadeLiquidCard: ViewModifier {
    var cornerRadius: CGFloat = Arkade.radiusLarge

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct ArkadeSection<Content: View>: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Arkade.purpleText)
                        .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 4)

            content
        }
    }
}

struct TokenBadge: View {
    let ticker: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().fill(color)
            Text(symbol)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var normalized: String { ticker.uppercased() }
    private var symbol: String {
        switch normalized {
        case "BTC": "₿"
        case "USDT": "₮"
        case "USDC": "$"
        default: String(normalized.prefix(1))
        }
    }

    private var color: Color {
        switch normalized {
        case "BTC": Arkade.orange
        case "USDT": Arkade.tether
        case "USDC": Arkade.blue
        default: Arkade.purple
        }
    }
}

extension View {
    func arkadeButton(_ variant: ArkadeButtonVariant = .primary) -> some View {
        modifier(ArkadeButtonStyle(variant: variant))
    }

    func arkadeCard(_ bg: Color = Arkade.dark10) -> some View {
        modifier(ArkadeCard(bg: bg))
    }

    func arkadeLiquidCard(cornerRadius: CGFloat = Arkade.radiusLarge) -> some View {
        modifier(ArkadeLiquidCard(cornerRadius: cornerRadius))
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Theme {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}
