import Foundation
import SwiftUI
import TiercadeCore
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// A simple, deterministic renderer for exporting a static image or PDF
// of the current tier list. It intentionally avoids live focus/overlay
// elements and lays out a compact grid: header per tier + row of item thumbnails.
internal struct ExportRenderer {
    internal struct Config {
        internal var maxSize: CGSize = CGSize(width: 4096, height: 4096)
        internal var rowHeight: CGFloat = 220
        internal var itemSize: CGSize = CGSize(width: 180, height: 180)
        internal var itemSpacing: CGFloat = 16
        internal var sectionSpacing: CGFloat = 24
        internal var contentInsets: EdgeInsets = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        internal var background: Color = Color.black
        internal var headerFont: Font = .system(size: 48, weight: .bold)
        internal var subtitleFont: Font = .system(size: 18, weight: .regular)
        internal var titleColor: Color = .white
        internal var subtitleColor: Color = .white.opacity(0.7)
        internal var headerHeight: CGFloat = 64
        internal var cornerRadius: CGFloat = 12
        internal var strokeColor: Color = .white.opacity(0.1)
        internal var strokeLineWidth: CGFloat = 1
    }

    internal struct Context {
        internal let tiers: [String: [Item]]
        internal let order: [String]
        internal let labels: [String: String]
        internal let colors: [String: String]
        internal let group: String
        internal let themeName: String
    }

    internal static func makeView(context: Context, cfg: Config = Config()) -> some View {
        VStack(alignment: .leading, spacing: cfg.sectionSpacing) {
            headerView(context: context, cfg: cfg)
            ForEach(context.order, id: \.self) { tier in
                tierSection(for: tier, context: context, cfg: cfg)
            }
            unrankedSection(context: context, cfg: cfg)
        }
        .padding(cfg.contentInsets)
        .background(cfg.background)
    }

    @ViewBuilder
    private static func headerView(context: Context, cfg: Config) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tier List — \(context.group)")
                .font(cfg.headerFont)
                .foregroundColor(cfg.titleColor)

            Text(themeLine(context: context))
                .font(cfg.subtitleFont)
                .foregroundColor(cfg.subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private static func tierSection(for tier: String, context: Context, cfg: Config) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow(for: tier, context: context)
            let tint = Color(hex: context.colors[tier] ?? "")
            let items = context.tiers[tier] ?? []
            ExportRow(items: items, itemSize: cfg.itemSize, spacing: cfg.itemSpacing)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: cfg.cornerRadius)
                        .fill((tint ?? Color.clear).opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cfg.cornerRadius)
                        .stroke(cfg.strokeColor, lineWidth: cfg.strokeLineWidth)
                )
        }
    }

    @ViewBuilder
    private static func unrankedSection(context: Context, cfg: Config) -> some View {
        if let unranked = context.tiers["unranked"], !unranked.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "Unranked", count: unranked.count)
                ExportRow(items: unranked, itemSize: cfg.itemSize, spacing: cfg.itemSpacing)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: cfg.cornerRadius)
                            .stroke(cfg.strokeColor, lineWidth: cfg.strokeLineWidth)
                    )
            }
        }
    }

    private static func headerRow(for tier: String, context: Context) -> some View {
        let label = context.labels[tier] ?? tier
        let count = context.tiers[tier]?.count ?? 0
        return sectionHeader(title: label, count: count)
    }

    private static func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.title).bold()
                .foregroundColor(.white)
            Spacer()
            Text("\(count)")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 6)
    }

    private static func themeLine(context: Context) -> String {
        let dateString = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .medium,
            timeStyle: .none
        )
        return "Theme: \(context.themeName) • \(dateString)"
    }

    // Render to PNG data, clamped to max size by scaling the container view.
    @MainActor
    internal static func renderPNG(context: Context,
                          targetSize: CGSize? = nil,
                          cfg: Config = Config()) -> Data? {
        let renderer = makeRenderer(context: context, cfg: cfg)
        renderer.scale = 1.0

        guard let baseImage = renderer.cgImage else { return nil }
        let baseSize = CGSize(width: CGFloat(baseImage.width), height: CGFloat(baseImage.height))
        let sizing = resolveSizing(for: baseSize, targetSize: targetSize, cfg: cfg)

        if sizing.scale != 1.0 {
            renderer.scale = sizing.scale
            guard let scaledImage = renderer.cgImage else { return nil }
            return makePNGData(from: scaledImage)
        }

        return makePNGData(from: baseImage)
    }

    // Render to vector PDF on iOS/macOS; tvOS doesn't support PDF context.
    @MainActor
    internal static func renderPDF(context: Context,
                          targetSize: CGSize? = nil,
                          cfg: Config = Config()) -> Data? {
        #if os(tvOS)
        return nil
        #else
        let renderer = makeRenderer(context: context, cfg: cfg)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }

        renderer.render { size, renderClosure in
            let sizing = resolveSizing(for: size, targetSize: targetSize, cfg: cfg)
            var mediaBox = CGRect(origin: .zero, size: sizing.finalSize)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            context.scaleBy(x: sizing.scale, y: sizing.scale)
            renderClosure(context)
            context.endPDFPage()
            context.closePDF()
        }

        return data as Data
        #endif
    }
}

private struct SizingResult {
    let finalSize: CGSize
    let scale: CGFloat
}

@MainActor
private extension ExportRenderer {
    static func makeRenderer(context: Context, cfg: Config) -> ImageRenderer<AnyView> {
        let baseWidth: CGFloat = 1920
        let view = makeView(context: context, cfg: cfg)
            .frame(width: baseWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: AnyView(view))
        renderer.proposedSize = ProposedViewSize(width: baseWidth, height: nil)
        renderer.isOpaque = true
        return renderer
    }

    static func resolveSizing(for size: CGSize, targetSize: CGSize?, cfg: Config) -> SizingResult {
        guard size.width > 0, size.height > 0 else {
            return SizingResult(finalSize: targetSize ?? cfg.maxSize, scale: 1.0)
        }

        let maxSize = targetSize ?? cfg.maxSize
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1.0)
        let finalSize = CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )
        return SizingResult(finalSize: finalSize, scale: scale)
    }

    static func makePNGData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

private struct ExportRow: View {
    let items: [Item]
    let itemSize: CGSize
    let spacing: CGFloat

    var body: some View {
        let columns = max(1, Int((1920 - 48) / (itemSize.width + spacing)))
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let idx = row * columns + col
                        if idx < items.count {
                            ExportCard(item: items[idx])
                        } else {
                            Spacer().frame(width: itemSize.width, height: itemSize.height)
                        }
                    }
                }
            }
        }
    }
}

private struct ExportCard: View {
    let item: Item

    var body: some View {
        ZStack {
            // Simple thumb placeholder using initials if no image URL.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            VStack(spacing: 8) {
                if let urlStr = item.imageUrl, let url = URL(string: urlStr) {
                    // Lightweight sync fetch avoided — we rely on label for export.
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(item.name ?? item.id)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
        }
        .frame(width: 180, height: 180)
    }
}
