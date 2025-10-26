import SwiftUI

internal struct QRSheet: View {
    internal let url: URL

    internal var body: some View {
        VStack(spacing: 16) {
            Text("Open on your phone")
                .font(.title2)
            Text(url.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .tvGlassRounded(16)
        .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
    }
}
