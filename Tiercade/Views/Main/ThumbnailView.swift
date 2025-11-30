import Foundation
import SwiftUI
import TiercadeCore

// MARK: - Thumbnail View

struct ThumbnailView: View {

    // MARK: Internal

    let item: Item
    #if os(tvOS)
    let layout: TVCardLayout
    #else
    let layout: PlatformCardLayout
    #endif

    var body: some View {
        #if os(tvOS)
        RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
            .fill(Color.clear)
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            .overlay {
                thumbnailContent
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: max(layout.cornerRadius - 4, 8),
                            style: .continuous,
                        ),
                    )
            }
        #else
        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous)
            .fill(Color.clear)
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            .overlay {
                thumbnailContent
                    .clipShape(
                        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous),
                    )
            }
        #endif
    }

    // MARK: Private

    @ViewBuilder
    private var thumbnailContent: some View {
        if
            let asset = item.imageUrl ?? item.videoUrl,
            let url = URLValidator.allowedMediaURL(from: asset)
        {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            .clipped()
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        #if os(tvOS)
        if layout.density == .ultraMicro {
            RoundedRectangle(cornerRadius: max(layout.cornerRadius - 4, 6), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.brand, Palette.brand.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .overlay(
                    Image(systemName: "wand.and.stars")
                        .font(
                            .system(
                                size: min(
                                    layout.thumbnailSize.width,
                                    layout.thumbnailSize.height,
                                ) * 0.32,
                                weight: .semibold,
                            ),
                        )
                        .accessibilityHidden(true)
                        .foregroundStyle(Palette.textOnAccent.opacity(0.78)),
                )
        } else {
            RoundedRectangle(cornerRadius: max(layout.cornerRadius - 4, 8), style: .continuous)
                .fill(Palette.brand)
                .overlay(
                    Text(String((item.name ?? item.id).prefix(18)))
                        .font(layout.titleFont)
                        .foregroundColor(Palette.textOnAccent)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12),
                )
        }
        #else
        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.brand, Palette.brand.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .overlay(
                Text(String((item.name ?? item.id).prefix(18)))
                    .font(layout.titleFont)
                    .foregroundColor(Palette.textOnAccent)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12),
            )
        #endif
    }
}
