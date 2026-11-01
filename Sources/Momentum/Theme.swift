import SwiftUI

enum MomentumTheme {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let primary = Color.primary
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.12)
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(MomentumTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MomentumTheme.border))
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18).frame(minHeight: 40).frame(maxWidth: .infinity)
            .foregroundStyle(MomentumTheme.canvas)
            .background(Color.primary.opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35),
                        in: RoundedRectangle(cornerRadius: 8))
    }
}
