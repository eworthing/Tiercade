import SwiftUI
import TiercadeCore
#if os(tvOS)
import AVKit
#endif

internal struct DetailView: View {
    internal let item: Item
    #if os(tvOS)
    @State private var showVideoPlayer: Bool = false
    @State private var activePlayer: AVPlayer?
    #endif
    @State private var showQR: Bool = false
    @State private var pendingURL: URL?
    internal var body: some View {
        VStack(spacing: 16) {
            // Hero gallery (image URIs only)
            let galleryUris: [String] = [item.imageUrl, item.videoUrl]
                .compactMap { $0 }
                .filter { s in
                    guard let url = URL(string: s) else { return false }
                    return ["png", "jpg", "jpeg", "gif", "webp"].contains(url.pathExtension.lowercased())
                }
            if !galleryUris.isEmpty {
                MediaGalleryView(uris: galleryUris)
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
                    Button("Play Video") {
                        if URLValidator.isAllowedExternalURL(url) {
                            activePlayer = AVPlayer(url: url)
                            showVideoPlayer = true
                        } else {
                            pendingURL = url
                            showQR = true
                        }
                    }
                    .buttonStyle(.tvRemote(.primary))
                    .accessibilityIdentifier("Detail_PlayVideo")
                    #else
                    Button("Play Video") {
                        guard URLValidator.isAllowedExternalURL(url) else { pendingURL = url; showQR = true; return }
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
        #if os(tvOS)
        .fullScreenCover(
            isPresented: $showVideoPlayer,
            onDismiss: {
                activePlayer?.pause()
                activePlayer = nil
            },
            content: {
                TVVideoPlayerContainer(player: activePlayer) {
                    showVideoPlayer = false
                    activePlayer?.pause()
                    activePlayer = nil
                }
            }
        )
        #endif
    }
}

#if os(tvOS)
private struct TVVideoPlayerContainer: View {
    internal let player: AVPlayer?
    internal let dismiss: () -> Void

    internal var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Label("Close", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 54, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .accessibilityIdentifier("VideoPlayer_Close")
                }
                Spacer()
            }
        }
        .background(Color.black)
        .focusSection()
    }
}
#endif
