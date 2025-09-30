import SwiftUI
import TiercadeCore

struct DetailView: View {
    let item: Item
    #if os(tvOS)
    @State private var playNow: Bool = false
    #endif
    @State private var showQR: Bool = false
    @State private var pendingURL: URL?
    var body: some View {
        VStack(spacing: 16) {
            // Hero gallery (image URIs only)
            let galleryUris: [String] = [item.imageUrl, item.videoUrl]
                .compactMap { $0 }
                .filter { s in
                    guard let url = URL(string: s) else { return false }
                    return ["png", "jpg", "jpeg", "gif", "webp"].contains(url.pathExtension.lowercased())
                }
            if !galleryUris.isEmpty {
                PageGalleryView(uris: galleryUris)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 340)
                    .overlay(Text("No images").foregroundStyle(.secondary))
            }

            // Metadata grid placeholder
            VStack(alignment: .leading, spacing: 8) {
                Text("Metadata").font(.headline)
                if let name = item.name { Text("Name: \(name)") }
                if let s = item.seasonString { Text("Season: \(s)") }
                if let d = item.description { Text(d).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // External links / video open
            HStack {
                if let v = item.videoUrl, let url = URL(string: v) {
                    #if os(tvOS)
                    Button("Play Video") { playNow = true }
                        .buttonStyle(.borderedProminent)
                        .background(
                            AVPlayerPresenter(url: url, isPresented: $playNow)
                                .frame(width: 0, height: 0)
                                .hidden()
                        )
                    #else
                    Button("Play Video") {
                        OpenExternal.open(url) { result in
                            if case .unsupported = result { pendingURL = url; showQR = true }
                        }
                    }
                        .buttonStyle(.bordered)
                    #endif
                }
                Spacer()
            }
            .sheet(isPresented: $showQR, content: {
                if let u = pendingURL { QRSheet(url: u) }
            })
        }
        .padding(24)
    }
}
