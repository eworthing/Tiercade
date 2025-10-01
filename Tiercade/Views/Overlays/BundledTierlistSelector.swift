import SwiftUI
import TiercadeCore

struct BundledTierlistSelector: View {
    @Bindable var app: AppState
    @FocusState private var focusedProjectId: String?

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 360), spacing: 24)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 24) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(app.bundledProjects) { project in
                            BundledProjectCard(project: project) {
                                app.applyBundledProject(project)
                            }
                            .focused($focusedProjectId, equals: project.id)
                            .accessibilityIdentifier("BundledSelector_\(project.id)")
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(32)
            .frame(maxWidth: 820)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
            .accessibilityIdentifier("BundledSelector_Overlay")
        }
        #if os(tvOS)
        .focusSection()
        .defaultFocus($focusedProjectId, app.bundledProjects.first?.id)
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tier Library")
                    .font(.largeTitle.bold())
                Text("Pick a bundled tier list to jump right in. "
                    + "Everything loads locally and you can tweak it once imported.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Close") { app.dismissBundledTierlists() }
                .buttonStyle(.bordered)
            #if !os(tvOS)
                .keyboardShortcut(.cancelAction)
            #endif
        }
    }
}

private struct BundledProjectCard: View {
    let project: BundledProject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(project.title)
                    .font(.title2.bold())
                Text(project.subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(project.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                tags
                Text("\(project.itemCount) items • offline ready")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackgroundColor)
            )
        }
        #if os(tvOS)
        .buttonStyle(.tvRemote(.primary))
        #else
        .buttonStyle(.borderedProminent)
        #endif
    }

    private var tags: some View {
        HStack(spacing: 8) {
            ForEach(project.tags, id: \.self) { tag in
                Text(tag.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundColor(.accentColor)
            }
        }
    }
}

private extension BundledProjectCard {
    var cardBackgroundColor: Color {
        return Color(.init(white: 0.96, alpha: 1.0))
    }
}
