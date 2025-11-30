import SwiftUI
#if os(tvOS)
import Accessibility
#endif

// MARK: - MediaGalleryView

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
        #if os(tvOS)
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        .focusSection()
        .onChange(of: selection) { _, newValue in
            guard pages.indices.contains(newValue) else {
                return
            }
            let announcement = "Image \(newValue + 1) of \(pages.count)"
            AccessibilityNotification.Announcement(announcement).post()
        }
        #elseif os(iOS)
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .automatic : .never))
        #elseif os(macOS)
        .tabViewStyle(.automatic) // macOS uses tab-based navigation
        #endif
    }
}

// MARK: - GalleryPage

private struct GalleryPage: View {

    // MARK: Internal

    let uri: String

    var body: some View {
        ZStack {
            // If URL validation fails (nil), show failure placeholder immediately
            // instead of passing nil to AsyncImage which causes infinite spinner
            if let validURL = URLValidator.allowedMediaURL(from: uri) {
                AsyncImage(url: validURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(.circular)
                    case let .success(image):
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

    // MARK: Private

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
