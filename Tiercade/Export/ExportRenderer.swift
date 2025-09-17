import Foundation
import SwiftUI
import TiercadeCore
#if canImport(UIKit)
import UIKit
#endif

// A simple, deterministic renderer for exporting a static image or PDF
// of the current tier list. It intentionally avoids live focus/overlay
// elements and lays out a compact grid: header per tier + row of item thumbnails.
struct ExportRenderer {
    struct Config {
        var maxSize: CGSize = CGSize(width: 4096, height: 4096)
        var rowHeight: CGFloat = 220
        var itemSize: CGSize = CGSize(width: 180, height: 180)
        var itemSpacing: CGFloat = 16
        var sectionSpacing: CGFloat = 24
        var contentInsets: EdgeInsets = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        var background: Color = Color.black
        var headerFont: Font = .system(size: 48, weight: .bold)
        var subtitleFont: Font = .system(size: 18, weight: .regular)
        var titleColor: Color = .white
        var subtitleColor: Color = .white.opacity(0.7)
        var headerHeight: CGFloat = 64
        var cornerRadius: CGFloat = 12
        var strokeColor: Color = .white.opacity(0.1)
        var strokeLineWidth: CGFloat = 1
    }

    static func makeView(tiers: [String: [Item]],
                         order: [String],
                         labels: [String: String],
                         colors: [String: String],
                         group: String,
                         themeName: String,
                         cfg: Config = Config()) -> some View {
        let header = VStack(alignment: .leading, spacing: 8) {
            Text("Tier List — \(group)")
                .font(cfg.headerFont)
                .foregroundColor(cfg.titleColor)
            Text("Theme: \(themeName) • \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))")
                .font(cfg.subtitleFont)
                .foregroundColor(cfg.subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return VStack(alignment: .leading, spacing: cfg.sectionSpacing) {
            header
            ForEach(order, id: \.self) { tier in
                VStack(alignment: .leading, spacing: 8) {
                    let label = labels[tier] ?? tier
                    HStack {
                        Text(label)
                            .font(.title).bold()
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(tiers[tier]?.count ?? 0)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 6)

                    let tint = Color(hex: colors[tier] ?? "")
                    let items = tiers[tier] ?? []
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

            if let unranked = tiers["unranked"], !unranked.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Unranked")
                            .font(.title).bold()
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(unranked.count)")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 6)

                    ExportRow(items: unranked, itemSize: cfg.itemSize, spacing: cfg.itemSpacing)
                        .padding(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: cfg.cornerRadius)
                                .stroke(cfg.strokeColor, lineWidth: cfg.strokeLineWidth)
                        )
                }
            }
        }
        .padding(cfg.contentInsets)
        .background(cfg.background)
    }

    // Render to PNG data, clamped to max size by scaling the container view.
    static func renderPNG(tiers: [String: [Item]],
                          order: [String],
                          labels: [String: String],
                          colors: [String: String],
                          group: String,
                          themeName: String,
                          targetSize: CGSize? = nil,
                          cfg: Config = Config()) -> Data? {
        let view = makeView(tiers: tiers, order: order, labels: labels, colors: colors, group: group, themeName: themeName, cfg: cfg)

        // Estimate intrinsic width based on widest row
        let screenWidth: CGFloat = 1920 // base logical width for layout; will scale down if needed
        let hosting = UIHostingController(rootView: view.frame(width: screenWidth))
        hosting.view.bounds = CGRect(origin: .zero, size: CGSize(width: screenWidth, height: 100))
        hosting.view.backgroundColor = .clear
        let size = hosting.sizeThatFits(in: CGSize(width: screenWidth, height: CGFloat.greatestFiniteMagnitude))

        let maxSize = targetSize ?? cfg.maxSize
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1.0)
        let finalSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let data = renderer.pngData { ctx in
            // Scale context
            ctx.cgContext.scaleBy(x: scale, y: scale)
            hosting.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        return data
    }

    // Render to vector PDF on iOS/macOS; tvOS doesn't support PDF context.
    static func renderPDF(tiers: [String: [Item]],
                          order: [String],
                          labels: [String: String],
                          colors: [String: String],
                          group: String,
                          themeName: String,
                          targetSize: CGSize? = nil,
                          cfg: Config = Config()) -> Data? {
        #if os(tvOS)
        return nil
        #else
        let view = makeView(tiers: tiers, order: order, labels: labels, colors: colors, group: group, themeName: themeName, cfg: cfg)

        let screenWidth: CGFloat = 1920
        let hosting = UIHostingController(rootView: view.frame(width: screenWidth))
        hosting.view.bounds = CGRect(origin: .zero, size: CGSize(width: screenWidth, height: 100))
        hosting.view.backgroundColor = .clear
        let size = hosting.sizeThatFits(in: CGSize(width: screenWidth, height: CGFloat.greatestFiniteMagnitude))

        let maxSize = targetSize ?? cfg.maxSize
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1.0)
        let finalSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: finalSize)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        ctx.beginPDFPage(nil)
        ctx.scaleBy(x: scale, y: scale)
        hosting.view.layer.render(in: ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
        #endif
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
