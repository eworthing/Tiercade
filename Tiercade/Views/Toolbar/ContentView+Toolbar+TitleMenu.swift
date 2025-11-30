import SwiftUI
import TiercadeCore

// MARK: - iOS Title Menu Extension

#if os(iOS)
extension ToolbarView {
    // iOS title menu content (tap navigation title to reveal)
    @ViewBuilder
    var titleMenuContent: some View {
        Button {
            app.startHeadToHead()
        } label: {
            Label("HeadToHead", systemImage: "person.line.dotted.person.fill")
        }
        .disabled(!app.canStartHeadToHead)
        .accessibilityIdentifier("TitleMenu_HeadToHead")

        Button {
            app.toggleAnalysis()
        } label: {
            Label(
                app.showingAnalysis ? "Hide Analysis" : "Show Analysis",
                systemImage: app.showingAnalysis ? "chart.bar.fill" : "chart.bar",
            )
        }
        .disabled(!app.canShowAnalysis && !app.showingAnalysis)
        .accessibilityIdentifier("TitleMenu_Analysis")

        Button {
            app.toggleThemePicker()
        } label: {
            Label("Themes", systemImage: "paintpalette")
        }
        .accessibilityIdentifier("TitleMenu_Themes")

        Menu("Sort") {
            // Current sort mode indicator
            Section {
                Label(
                    "Current: \(app.globalSortMode.displayName)",
                    systemImage: "checkmark.circle",
                )
            }

            Divider()

            // Manual order
            Button {
                app.setGlobalSortMode(.custom)
            } label: {
                Label(
                    "Manual Order",
                    systemImage: app.globalSortMode.isCustom ? "checkmark" : "",
                )
            }

            // Alphabetical
            Button {
                app.setGlobalSortMode(.alphabetical(ascending: true))
            } label: {
                let isSelected = {
                    if case let .alphabetical(asc) = app.globalSortMode, asc {
                        return true
                    }
                    return false
                }()
                Label("A → Z", systemImage: isSelected ? "checkmark" : "")
            }

            Button {
                app.setGlobalSortMode(.alphabetical(ascending: false))
            } label: {
                let isSelected = {
                    if case let .alphabetical(asc) = app.globalSortMode, !asc {
                        return true
                    }
                    return false
                }()
                Label("Z → A", systemImage: isSelected ? "checkmark" : "")
            }

            // Discovered attributes
            let discovered = app.discoverSortableAttributes()
            if !discovered.isEmpty {
                Divider()

                ForEach(Array(discovered.keys.sorted()), id: \.self) { key in
                    if let type = discovered[key] {
                        Menu(key.capitalized) {
                            Button {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: true, type: type))
                            } label: {
                                let isSelected = {
                                    if
                                        case let .byAttribute(k, asc, _) = app.globalSortMode,
                                        k == key, asc
                                    {
                                        return true
                                    }
                                    return false
                                }()
                                Label("\(key.capitalized) ↑", systemImage: isSelected ? "checkmark" : "")
                            }

                            Button {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: false, type: type))
                            } label: {
                                let isSelected = {
                                    if
                                        case let .byAttribute(k, asc, _) = app.globalSortMode,
                                        k == key, !asc
                                    {
                                        return true
                                    }
                                    return false
                                }()
                                Label("\(key.capitalized) ↓", systemImage: isSelected ? "checkmark" : "")
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("TitleMenu_Sort")

        Menu("Card Size") {
            ForEach(CardDensityPreference.allCases, id: \.self) { density in
                Button {
                    app.setCardDensityPreference(density)
                } label: {
                    Label(
                        density.displayName,
                        systemImage: app.cardDensityPreference == density ? "checkmark" : "",
                    )
                }
            }
        }
        .accessibilityIdentifier("TitleMenu_CardSize")
    }
}
#endif
