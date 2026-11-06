import SwiftUI
import UIKit
import CoreImage

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6, let number = UInt64(value, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    func mixed(with other: Color, amount: Double) -> Color {
        let amount = min(max(amount, 0), 1)
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red: Double(ar + (br - ar) * amount),
            green: Double(ag + (bg - ag) * amount),
            blue: Double(ab + (bb - ab) * amount),
            opacity: Double(aa + (ba - aa) * amount)
        )
    }

    var uiColor: UIColor { UIColor(self) }
}

extension UIColor {
    convenience init(hex: String) {
        self.init(Color(hex: hex))
    }

    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 0.45
    }

    /// Lifts very dark or desaturated artwork colours into something usable as an accent.
    func accentAdjusted() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        s = min(max(s, 0.38), 0.9)
        b = min(max(b, 0.55), 0.94)
        return UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
    }
}

extension UIImage {
    func averageColor() -> Color? {
        guard let input = CIImage(image: self) else { return nil }
        let extent = CIVector(cgRect: input.extent)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: extent
        ]), let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return Color(
            .sRGB,
            red: Double(bitmap[0]) / 255,
            green: Double(bitmap[1]) / 255,
            blue: Double(bitmap[2]) / 255,
            opacity: 1
        )
    }
}

// MARK: - Palette

struct MochyPalette {
    var background: Color
    var surface: Color
    var elevated: Color
    var bubble: Color
    var text: Color
    var secondaryText: Color
    var tertiaryText: Color
    var separator: Color
    var accent: Color
    var accentSoft: Color
    var accentText: Color
    var isPureBlack: Bool
}

struct MochyTheme {
    static let fallbackAccent = Color(hex: "#8E8E8E")

    static func palette(settings: AppSettings, artworkColor: Color?) -> MochyPalette {
        let pure = settings.pureBlack
        let baseAccent: Color
        if settings.dynamicTheme, let artworkColor {
            baseAccent = Color(artworkColor.uiColor.accentAdjusted())
        } else {
            baseAccent = Color(hex: settings.accentHex)
        }

        let background = pure ? Color.black : Color(hex: "#08080A")
        let surface = pure ? Color(hex: "#0C0C0E") : Color(hex: "#111114")
        let elevated = pure ? Color(hex: "#151518") : Color(hex: "#1B1B20")

        return MochyPalette(
            background: background,
            surface: surface,
            elevated: elevated,
            bubble: Color.white.opacity(pure ? 0.055 : 0.075),
            text: .white,
            secondaryText: Color.white.opacity(0.62),
            tertiaryText: Color.white.opacity(0.4),
            separator: Color.white.opacity(0.09),
            accent: baseAccent,
            accentSoft: baseAccent.opacity(0.22),
            accentText: baseAccent.uiColor.isDark ? .white : .black,
            isPureBlack: pure
        )
    }
}

// MARK: - Fonts

enum MochyFont {
    static func regular(_ size: CGFloat) -> Font { .custom("Inter24pt-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Inter24pt-Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font { .custom("Inter24pt-SemiBold", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Inter24pt-Bold", size: size) }
    static func black(_ size: CGFloat) -> Font { .custom("Inter24pt-Black", size: size) }
    static func light(_ size: CGFloat) -> Font { .custom("Inter24pt-Light", size: size) }
    static func display(_ size: CGFloat) -> Font { .custom("BBHBartle-Regular", size: size) }
}

// MARK: - Glass and cards

struct GlassBackground: View {
    var radius: CGFloat = 24
    var tint: Color = .white

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.7)
            )
    }
}

struct MochyCardModifier: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 18
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.6)
                    )
            )
    }
}

extension View {
    func mochyCard(radius: CGFloat = 24, padding: CGFloat = 18, tint: Color = .white) -> some View {
        modifier(MochyCardModifier(radius: radius, padding: padding, tint: tint))
    }

    func mochyText(_ font: Font, color: Color = .white) -> some View {
        self.font(font).foregroundStyle(color)
    }

    @ViewBuilder
    func conditional<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Backgrounds

struct MochyBackground: View {
    var palette: MochyPalette
    var artworkColor: Color?
    var showGlow: Bool = true

    var body: some View {
        ZStack {
            palette.background
            if showGlow, let artworkColor {
                RadialGradient(
                    colors: [artworkColor.opacity(0.24), artworkColor.opacity(0.06), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 520
                )
                .blur(radius: 40)
                RadialGradient(
                    colors: [palette.accent.opacity(0.12), .clear],
                    center: .bottomTrailing,
                    startRadius: 40,
                    endRadius: 460
                )
                .blur(radius: 50)
            }
            if !palette.isPureBlack {
                LinearGradient(
                    colors: [Color.white.opacity(0.015), .clear, Color.black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Accent choices

struct AccentOption: Identifiable, Hashable {
    var id: String { hex }
    var name: String
    var hex: String
}

enum AccentPalette {
    static let options: [AccentOption] = [
        .init(name: "Mochy", hex: "#8E8E8E"),
        .init(name: "Sky", hex: "#6FA8FF"),
        .init(name: "Teal", hex: "#4ED8C3"),
        .init(name: "Green", hex: "#77D97A"),
        .init(name: "Lime", hex: "#C8E96A"),
        .init(name: "Yellow", hex: "#F2D35C"),
        .init(name: "Orange", hex: "#F4A259"),
        .init(name: "Red", hex: "#F06A6A"),
        .init(name: "Pink", hex: "#F28DB2"),
        .init(name: "Purple", hex: "#B58CFF"),
        .init(name: "Indigo", hex: "#7E8CFF"),
        .init(name: "Cream", hex: "#E8DFC8")
    ]
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = MochyTheme.palette(settings: AppSettings(), artworkColor: nil)
}

extension EnvironmentValues {
    var mochyPalette: MochyPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
