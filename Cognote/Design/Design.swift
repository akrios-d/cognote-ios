import SwiftUI
import UIKit

/// Looks up a key from Localizable.xcstrings (same keys as the web app's i18n JSON).
func L(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}

// MARK: - Themes (the five themes from src/styles.css)

enum AppTheme: String, CaseIterable, Identifiable {
    case auto
    case warm
    case bw
    case dark
    case blue
    case navy

    static let storageKey = "appTheme"

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .auto
    }

    var id: String { rawValue }
    var labelKey: String { "theme." + rawValue }

    /// Dark themes force dark system UI; `auto` follows the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark, .navy: return .dark
        case .warm, .bw, .blue: return .light
        }
    }

    func palette(darkMode: Bool) -> ThemePalette {
        switch self {
        case .auto: return darkMode ? .dark : .warm
        case .warm: return .warm
        case .bw: return .bw
        case .dark: return .dark
        case .blue: return .blue
        case .navy: return .navy
        }
    }
}

struct ThemePalette {
    let bg, surface, surfaceAlt, border: UInt32
    let ink, ink2, ink3: UInt32
    let accent, accentLight, onAccent, starOff, danger: UInt32
    let pos, posLight, neg, negLight, negText: UInt32
    /// Five-step intensity tints (web: --c-pos-tint-*, --c-neg-tint-*).
    let posTints, negTints: [UInt32]
    /// Space row backgrounds: strong positive, mid positive, mid negative, strong negative.
    let spaceBackgrounds: [UInt32]
    /// Space row bars: mid positive, mid negative, strong negative (strong positive uses accent).
    let spaceBars: [UInt32]

    static let warm = ThemePalette(
        bg: 0xFAF9F7, surface: 0xFFFFFF, surfaceAlt: 0xF4F2EF, border: 0xE2DDD8,
        ink: 0x1C1917, ink2: 0x57534E, ink3: 0x78716C,
        accent: 0xA3561E, accentLight: 0xFDF0E8, onAccent: 0xFFFFFF, starOff: 0xDDD8D2, danger: 0xD96B6B,
        pos: 0x4A7C59, posLight: 0xEAF2EC, neg: 0x6B7FA3, negLight: 0xEEF1F7, negText: 0x3D526E,
        posTints: [0xFFFCF8, 0xFFF7EF, 0xFFF1E4, 0xFFE8D5, 0xFDDFC4],
        negTints: [0xFAFBFC, 0xF3F6FA, 0xE9EFF7, 0xDDE6F1, 0xD0DCEA],
        spaceBackgrounds: [0xFFF5ED, 0xFFFAF5, 0xF8F9FC, 0xF2F4F9],
        spaceBars: [0xE09060, 0x8FA3C4, 0x6B7FA3]
    )

    static let bw = ThemePalette(
        bg: 0xF5F5F5, surface: 0xFFFFFF, surfaceAlt: 0xEBEBEB, border: 0xD0D0D0,
        ink: 0x0A0A0A, ink2: 0x333333, ink3: 0x666666,
        accent: 0x111111, accentLight: 0xEEEEEE, onAccent: 0xFFFFFF, starOff: 0xCCCCCC, danger: 0xCC2200,
        pos: 0x2A2A2A, posLight: 0xF0F0F0, neg: 0x666666, negLight: 0xEEEEEE, negText: 0x444444,
        posTints: [0xFAFAFA, 0xF6F6F6, 0xF0F0F0, 0xEAEAEA, 0xE3E3E3],
        negTints: [0xF7F7F7, 0xF2F2F2, 0xEBEBEB, 0xE4E4E4, 0xDCDCDC],
        spaceBackgrounds: [0xF0F0F0, 0xF6F6F6, 0xF2F2F2, 0xEBEBEB],
        spaceBars: [0xAAAAAA, 0x888888, 0x666666]
    )

    static let dark = ThemePalette(
        bg: 0x191919, surface: 0x242424, surfaceAlt: 0x2E2E2E, border: 0x383838,
        ink: 0xC8C8C8, ink2: 0x8C8C8C, ink3: 0x606060,
        accent: 0xABABAB, accentLight: 0x2A2A2A, onAccent: 0x191919, starOff: 0x404040, danger: 0xE07070,
        pos: 0x909090, posLight: 0x272727, neg: 0x686868, negLight: 0x272727, negText: 0x8C8C8C,
        posTints: [0x222222, 0x272727, 0x2C2C2C, 0x313131, 0x363636],
        negTints: [0x202020, 0x242424, 0x282828, 0x2C2C2C, 0x303030],
        spaceBackgrounds: [0x2C2C2C, 0x272727, 0x252525, 0x222222],
        spaceBars: [0x606060, 0x4A4A4A, 0x3E3E3E]
    )

    static let blue = ThemePalette(
        bg: 0xF0F4FD, surface: 0xFFFFFF, surfaceAlt: 0xE6EDF8, border: 0xC5D3E8,
        ink: 0x1A2540, ink2: 0x445070, ink3: 0x6476A0,
        accent: 0x1E44D4, accentLight: 0xEFF6FF, onAccent: 0xFFFFFF, starOff: 0xB8C8E0, danger: 0xDC3545,
        pos: 0x2E7D52, posLight: 0xE8F5ED, neg: 0x7C5CBF, negLight: 0xF3F0FA, negText: 0x5A3F9A,
        posTints: [0xF8FBFF, 0xF0F7FF, 0xE5F0FF, 0xD8E8FF, 0xC8DCFF],
        negTints: [0xFAF8FF, 0xF4F0FF, 0xECE6FF, 0xE2D8FF, 0xD6C8FF],
        spaceBackgrounds: [0xE5F0FF, 0xF0F7FF, 0xF4F0FF, 0xECE6FF],
        spaceBars: [0x60A0E8, 0x9070C8, 0x7050A8]
    )

    static let navy = ThemePalette(
        bg: 0x111827, surface: 0x1A2236, surfaceAlt: 0x222D45, border: 0x2D3D5C,
        ink: 0xB8C8E8, ink2: 0x7A90B8, ink3: 0x516080,
        accent: 0x5B8DEE, accentLight: 0x1E2A44, onAccent: 0x111827, starOff: 0x2D3D5C, danger: 0xE07070,
        pos: 0x60A878, posLight: 0x182A22, neg: 0x6080B8, negLight: 0x182236, negText: 0x88A0C8,
        posTints: [0x161E30, 0x1A2438, 0x1E2A40, 0x223048, 0x263650],
        negTints: [0x141C2C, 0x181F2E, 0x1C2434, 0x20293A, 0x242E42],
        spaceBackgrounds: [0x1E2A44, 0x1A2236, 0x18202E, 0x141C2A],
        spaceBars: [0x3D5280, 0x2D4060, 0x263550]
    )
}

// MARK: - Palette (resolves against the selected theme)

enum Palette {
    static let bg = themed { $0.bg }
    static let surface = themed { $0.surface }
    static let surfaceAlt = themed { $0.surfaceAlt }
    static let border = themed { $0.border }
    static let ink = themed { $0.ink }
    static let ink2 = themed { $0.ink2 }
    static let ink3 = themed { $0.ink3 }
    static let accent = themed { $0.accent }
    static let accentLight = themed { $0.accentLight }
    /// Text and icons on an accent-filled button.
    static let onAccent = themed { $0.onAccent }
    static let starOff = themed { $0.starOff }
    static let danger = themed { $0.danger }
    static let pos = themed { $0.pos }
    static let posLight = themed { $0.posLight }
    static let neg = themed { $0.neg }
    static let negLight = themed { $0.negLight }
    static let negText = themed { $0.negText }

    /// Light positive tint, used only for the sample card in the empty space guide.
    static let sampleEntry = themed { $0.posTints[1] }
    private static let spaceBackgrounds = (0..<4).map { index in themed { $0.spaceBackgrounds[index] } }
    private static let spaceBars = (0..<3).map { index in themed { $0.spaceBars[index] } }

    private static func themed(_ pick: @escaping (ThemePalette) -> UInt32) -> Color {
        Color(uiColor: uiColor(pick))
    }

    /// A UIKit colour that follows the selected theme (for UIKit appearance APIs).
    static func uiColor(_ pick: @escaping (ThemePalette) -> UInt32) -> UIColor {
        UIColor { traits in
            let palette = AppTheme.current.palette(darkMode: traits.userInterfaceStyle == .dark)
            return UIColor(hex: pick(palette))
        }
    }

    static func sentiment(_ sentiment: Sentiment) -> Color {
        sentiment == .negative ? neg : accent
    }

    /// Row tint for a space, from its average impact (web: impactClass()).
    static func spaceBackground(avg: Double, hasImpact: Bool) -> Color {
        guard hasImpact else { return surface }
        if avg >= 3 { return spaceBackgrounds[0] }
        if avg >= 0 { return spaceBackgrounds[1] }
        if avg > -2 { return spaceBackgrounds[2] }
        return spaceBackgrounds[3]
    }

    static func spaceBar(avg: Double, hasImpact: Bool) -> Color {
        guard hasImpact else { return border }
        if avg >= 3 { return accent }
        if avg >= 0 { return spaceBars[0] }
        if avg > -2 { return spaceBars[1] }
        return spaceBars[2]
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Formatting

enum Fmt {
    static func one(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    static func signed(_ value: Double) -> String {
        if value > 0 { return "+" + one(value) }
        if value < 0 { return "−" + one(-value) }
        return one(0)
    }

    static func magnitude(_ value: Double) -> String { one(abs(value)) }

    static func badge(_ entry: SpaceEntry) -> String {
        (entry.sentiment == .negative ? "−" : "+") + "\(entry.impact)"
    }

    static func entries(_ count: Int) -> String {
        "\(count) " + (count == 1 ? L("home.itemSingular") : L("home.itemPlural"))
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

// MARK: - Shared pieces

extension Font {
    /// Serif (New York) that scales with Dynamic Type.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

/// Serif navigation titles in the theme's ink colour, so system bars carry CogNote's look.
enum Appearance {
    static func apply() {
        let ink = Palette.uiColor { $0.ink }
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [
            .font: serifFont(.largeTitle, weight: .bold),
            .foregroundColor: ink,
        ]
        navigation.titleTextAttributes = [
            .font: serifFont(.headline, weight: .semibold),
            .foregroundColor: ink,
        ]
    }

    private static func serifFont(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let system = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        guard let descriptor = system.fontDescriptor.withDesign(.serif) else { return system }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Palette.ink3)
    }
}

struct ImpactBadge: View {
    let entry: SpaceEntry

    var body: some View {
        Text(Fmt.badge(entry))
            .font(.caption.weight(.bold).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(entry.sentiment == .negative ? Palette.negText : Palette.accent)
            .background(Capsule().fill(entry.sentiment == .negative ? Palette.negLight : Palette.accentLight))
    }
}

struct ImpactDots: View {
    @Binding var value: Int
    let sentiment: Sentiment

    var body: some View {
        HStack(spacing: 14) {
            ForEach(1...5, id: \.self) { dot in
                Button {
                    value = dot
                } label: {
                    Circle()
                        .fill(dot <= value ? Palette.sentiment(sentiment) : Palette.starOff)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "\(dot)/5"))
                .accessibilityAddTraits(dot == value ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

struct Card<Content: View>: View {
    var background: Color = Palette.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(background))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: 0.5)
            )
    }
}

extension EntryKind {
    var symbol: String {
        switch self {
        case .impact: return "bubble.left"
        case .watchLater: return "hourglass"
        case .note: return "note.text"
        }
    }

    var labelKey: String {
        switch self {
        case .impact: return "list.modeImpact"
        case .watchLater: return "list.modeWatchLater"
        case .note: return "list.modeNote"
        }
    }
}

/// Lays children out left to right and wraps onto new lines when a row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
