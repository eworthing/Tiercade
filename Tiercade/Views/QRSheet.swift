import SwiftUI

struct QRSheet: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Text("Open on your phone")
                .font(.title2)
            Text(url.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
