import SwiftUI
#if os(tvOS)
import Accessibility
#endif

/// SwiftUI-native gallery view that replaces the previous UIPageViewController bridge.
/// Displays remote images in a paged carousel with accessibility identifiers that
/// match legacy UI tests ("Gallery_Page_<uri>").
internal struct MediaGalleryView: View {
    internal let uris: [String]
    @State private var selection: Int = 0

    private var pages: [(index: Int, uri: String)] {
        uris.enumerated().map { (index: $0.offset, uri: $0.element) }
    }

    internal var body: some View {
        TabView(selection: $selection) {
            ForEach(pages, id: \.index) { page in
                GalleryPage(uri: page.uri)
                    .tag(page.index)
            }
        }
        #if os(tvOS)
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        .focusSection()
        .onChange(of: selection) { _, newValue in
            guard pages.indices.contains(newValue) else { return }
            let announcement = "Image \(newValue + 1) of \(pages.count)"
            AccessibilityNotification.Announcement(announcement).post()
        }
        #elseif os(iOS)
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        #elseif os(macOS)
        .tabViewStyle(.automatic)  // macOS uses tab-based navigation
        #endif
    }
}

private struct GalleryPage: View {
    internal let uri: String

    internal var body: some View {
        ZStack {
            // If URL validation fails (nil), show failure placeholder immediately
            // instead of passing nil to AsyncImage which causes infinite spinner
            if let validURL = URLValidator.allowedMediaURL(from: uri) {
                AsyncImage(url: validURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        failurePlaceholder
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Invalid URL scheme (not HTTPS)
                failurePlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityIdentifier("Gallery_Page_\(uri)")
    }

    private var failurePlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.2)
            Image(systemName: "photo")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
