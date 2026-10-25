import SwiftUI

enum MomentumTheme {
    static let ink = Color(red: 13/255, green: 14/255, blue: 16/255)
    static let muted = Color(red: 83/255, green: 92/255, blue: 101/255)
    static let primary = Color(red: 100/255, green: 111/255, blue: 121/255)
    static let canvas = Color.white
    static let surface = Color(white: 243/255)
    static let border = Color(white: 210/255)
    static let space: CGFloat = 4
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MomentumTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(isEnabled ? (configuration.isPressed ? MomentumTheme.ink : MomentumTheme.primary) : .gray,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
