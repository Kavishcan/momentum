import SwiftUI

enum MomentumTheme {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static let ink = adaptive(0x37352F, 0xE4E3DF)
    static let muted = Color.secondary
    static let primary = ink
    static let canvas = adaptive(0xFFFFFF, 0x191919)
    static let surface = adaptive(0xF7F7F5, 0x222222)
    static let sidebar = adaptive(0xF7F7F5, 0x202020)
    static let selection = adaptive(0xEAEAE7, 0x303030)
    static let hover = adaptive(0xEFEFED, 0x292929)
    static let border = adaptive(0xE8E8E5, 0x343434)
}

/// An original M monogram, shared visually with the packaged app icon.
struct MomentumMark: View {
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color.black).offset(x: 1.5, y: 1.5)
            RoundedRectangle(cornerRadius: 3).fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1.2))
            Monogram().fill(Color.black).padding(size * 0.19)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
    private struct Monogram: Shape {
        func path(in rect: CGRect) -> Path {
            let points: [CGPoint] = [
                .init(x: 0, y: 1), .init(x: 0, y: 0), .init(x: 0.2, y: 0),
                .init(x: 0.5, y: 0.52), .init(x: 0.8, y: 0), .init(x: 1, y: 0),
                .init(x: 1, y: 1), .init(x: 0.79, y: 1), .init(x: 0.79, y: 0.4),
                .init(x: 0.5, y: 0.9), .init(x: 0.21, y: 0.4), .init(x: 0.21, y: 1)
            ]
            var path = Path()
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
            path.closeSubpath()
            return path
        }
    }
}

struct Card<Content: View>: View {
    enum Style: Equatable { case section, callout }
    var style: Style = .section
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(style == .callout ? 18 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style == .callout ? MomentumTheme.surface : .clear, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(style == .callout ? MomentumTheme.border : .clear))
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).frame(minHeight: 40).frame(maxWidth: .infinity)
            .foregroundStyle(MomentumTheme.canvas)
            .background(MomentumTheme.ink.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35),
                        in: RoundedRectangle(cornerRadius: 5))
    }
}
struct DocumentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).frame(minHeight: 40).frame(maxWidth: .infinity)
            .foregroundStyle(MomentumTheme.ink.opacity(enabled ? 1 : 0.35))
            .background(configuration.isPressed ? MomentumTheme.selection : MomentumTheme.canvas,
                        in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(MomentumTheme.border))
    }
}
