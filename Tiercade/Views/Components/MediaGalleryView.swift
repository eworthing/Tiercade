import SwiftUI
#if os(tvOS)
import Accessibility
#endif

/// SwiftUI-native gallery view that replaces the previous UIPageViewController bridge.
/// Displays remote images in a paged carousel with accessibility identifiers that
/// match legacy UI tests ("Gallery_Page_<uri>").
struct MediaGalleryView: View {
    let uris: [String]
    @State private var selection: Int = 0

    private var pages: [(index: Int, uri: String)] {
        uris.enumerated().map { (index: $0.offset, uri: $0.element) }
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages, id: \.index) { page in
                GalleryPage(uri: page.uri)
                    .tag(page.index)
            }
        }
        #if os(macOS)
        .tabViewStyle(.automatic)
        #else
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        #if os(tvOS)
        .focusSection()
        .onChange(of: selection) { _, newValue in
        guard pages.indices.contains(newValue) else { return }
        let announcement = "Image \(newValue + 1) of \(pages.count)"
        AccessibilityNotification.Announcement(announcement).post()
        }
        #endif
        #endif
    }
}

private struct GalleryPage: View {
    let uri: String

    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: uri)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    ZStack {
                        Color.secondary.opacity(0.2)
                        Image(systemName: "photo")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityIdentifier("Gallery_Page_\(uri)")
    }
}
