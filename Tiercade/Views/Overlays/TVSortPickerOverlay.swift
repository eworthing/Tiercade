import SwiftUI
import TiercadeCore

#if os(tvOS)
internal struct TVSortPickerOverlay: View {
    @Bindable var app: AppState
    @Binding var isPresented: Bool
    @FocusState private var focusedOption: FocusOption?

    private enum FocusOption: Hashable {
        case custom
        case alphabeticalAsc
        case alphabeticalDesc
        case attribute(String, Bool) // key, ascending
        case close
    }

    internal var body: some View {
        VStack(spacing: 28) {
            // Title
            Text("Sort Mode")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            // Current selection indicator
            Text("Current: \(app.globalSortMode.displayName)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()
                .opacity(0.3)

            // Sort options
            ScrollView {
                VStack(spacing: 12) {
                    // Manual Order
                    SortOptionButton(
                        title: "Manual Order",
                        isSelected: app.globalSortMode.isCustom,
                        action: {
                            app.setGlobalSortMode(.custom)
                            isPresented = false
                        }
                    )
                    .focused($focusedOption, equals: .custom)

                    // Alphabetical Ascending
                    SortOptionButton(
                        title: "A → Z",
                        isSelected: {
                            if case .alphabetical(let asc) = app.globalSortMode, asc { return true }
                            return false
                        }(),
                        action: {
                            app.setGlobalSortMode(.alphabetical(ascending: true))
                            isPresented = false
                        }
                    )
                    .focused($focusedOption, equals: .alphabeticalAsc)

                    // Alphabetical Descending
                    SortOptionButton(
                        title: "Z → A",
                        isSelected: {
                            if case .alphabetical(let asc) = app.globalSortMode, !asc { return true }
                            return false
                        }(),
                        action: {
                            app.setGlobalSortMode(.alphabetical(ascending: false))
                            isPresented = false
                        }
                    )
                    .focused($focusedOption, equals: .alphabeticalDesc)

                    // Discovered attributes
                    let discovered = app.discoverSortableAttributes()
                    if !discovered.isEmpty {
                        Divider()
                            .opacity(0.3)
                            .padding(.vertical, 8)

                        ForEach(Array(discovered.keys.sorted()), id: \.self) { key in
                            if let type = discovered[key] {
                                // Ascending
                                SortOptionButton(
                                    title: "\(key.capitalized) ↑",
                                    isSelected: {
                                        if case .byAttribute(let k, let asc, _) = app.globalSortMode,
                                           k == key, asc { return true }
                                        return false
                                    }(),
                                    action: {
                                        app.setGlobalSortMode(.byAttribute(key: key, ascending: true, type: type))
                                        isPresented = false
                                    }
                                )
                                .focused($focusedOption, equals: .attribute(key, true))

                                // Descending
                                SortOptionButton(
                                    title: "\(key.capitalized) ↓",
                                    isSelected: {
                                        if case .byAttribute(let k, let asc, _) = app.globalSortMode,
                                           k == key, !asc { return true }
                                        return false
                                    }(),
                                    action: {
                                        app.setGlobalSortMode(.byAttribute(key: key, ascending: false, type: type))
                                        isPresented = false
                                    }
                                )
                                .focused($focusedOption, equals: .attribute(key, false))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 500)
            .focusSection()

            Divider()
                .opacity(0.3)

            // Close button
            Button("Close", role: .cancel) {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .focused($focusedOption, equals: .close)
        }
        .padding(32)
        .tvGlassRounded(28)
        .shadow(color: Color.black.opacity(0.22), radius: 24, y: 8)
        .focusSection()
        .defaultFocus($focusedOption, .custom)
        .onAppear { focusedOption = .custom }
        .onDisappear { focusedOption = nil }
        .onExitCommand { isPresented = false }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct SortOptionButton: View {
    internal let title: String
    internal let isSelected: Bool
    internal let action: () -> Void

    internal var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(TypeScale.cardBody)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.brand)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .tvGlassRounded(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Palette.brand.opacity(0.9) : Color.white.opacity(0.3),
                        lineWidth: isSelected ? 3 : 2
                    )
            )
        }
        .buttonStyle(.tvRemote(.secondary))
    }
}
#endif
