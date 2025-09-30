import SwiftUI

struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(TypeScale.label)
            .foregroundColor(Palette.text)
            .padding(.horizontal, Metrics.grid)
            .padding(.vertical, Metrics.grid * 0.75)
            .background(Palette.surfHi)
            .cornerRadius(999)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct ColorSwatch: View {
    let color: Color
    let action: (() -> Void)?
    var body: some View {
        Button(action: { action?() }, label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
        })
        .buttonStyle(PlainButtonStyle())
        // Increase tappable area to at least 44x44 while keeping the visual circle small
        .frame(minWidth: 44, minHeight: 44, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityLabel("Color swatch")
        .accessibilityHint("Opens color selector")
        .accessibilityAddTraits(.isButton)
    }
}
