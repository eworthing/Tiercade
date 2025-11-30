import SwiftUI
import TiercadeCore

// MARK: - SidebarView

struct SidebarView: View {
    @Environment(AppState.self) var app
    let tierOrder: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tier List").font(.largeTitle.bold())
                Spacer()
                Button(action: { /* stub: show add dialog */ }, label: {
                    Label("Add Items", systemImage: "plus")
                })
                .buttonStyle(PrimaryButtonStyle())
            }

            SidebarSearchView()
            Divider()
            SidebarStatsView(tierOrder: tierOrder)
            Divider()
            SidebarTierListView(tierOrder: tierOrder)
            Divider()
            ItemTrayView(app: app)
        }
        .padding(Metrics.grid * 2)
        .frame(minWidth: 280)
        .panel()
    }
}

// MARK: - SidebarSearchView

struct SidebarSearchView: View {

    // MARK: Internal

    var body: some View {
        @Bindable var state = app
        VStack(alignment: .leading, spacing: 8) {
            Text("Search & Filter").font(.headline)

            #if !os(tvOS)
            TextField("Search items...", text: $state.searchQuery)
                .textFieldStyle(.roundedBorder)

            if state.isProcessingSearch {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing search...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            }
            #endif

            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(filter.rawValue) {
                        state.activeFilter = filter
                    }
                    .buttonStyle(GhostButtonStyle())
                    #if !os(tvOS)
                        .controlSize(.small)
                    #endif
                        .background(
                            state.activeFilter == filter ? Color.accentColor.opacity(0.2) : Color.clear,
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    state.activeFilter == filter ? Color.accentColor : Color.clear,
                                    lineWidth: 2,
                                ),
                        )
                }
            }
        }
    }

    // MARK: Private

    @Environment(AppState.self) private var app
}

// MARK: - SidebarStatsView

struct SidebarStatsView: View {
    @Environment(AppState.self) var app
    let tierOrder: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics").font(.headline)
            HStack { Text("Total:")
                Spacer()
                Text("\(app.allItems().count)").bold()
            }
            HStack { Text("Ranked:")
                Spacer()
                Text("\(app.rankedCount())").bold()
            }
            HStack { Text("Unranked:")
                Spacer()
                Text("\(app.unrankedCount())").bold()
            }
            if !app.searchQuery.isEmpty {
                HStack {
                    Text("Filtered:")
                    Spacer()
                    Text("\(app.allItems().count)")
                        .bold()
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - SidebarTierListView

struct SidebarTierListView: View {
    @Environment(AppState.self) var app
    let tierOrder: [String]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tierOrder, id: \.self) { t in
                    HStack {
                        Label(t, systemImage: "flag")
                        Spacer()
                        Text("\(app.tierCount(t))")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - PersistenceStatusView

struct PersistenceStatusView: View {

    // MARK: Internal

    @Bindable var app: AppState

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let fileName = app.persistence.currentFileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 4) {
                if app.persistence.hasUnsavedChanges {
                    Circle()
                        .fill(Palette.tierColor("A", from: app.tierColors))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundColor(Palette.tierColor("A", from: app.tierColors))
                } else {
                    Circle()
                        .fill(Palette.tierColor("B", from: app.tierColors))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(Palette.tierColor("B", from: app.tierColors))
                }
            }

            if let lastSaved = app.persistence.lastSavedTime {
                Text("Last saved: \(lastSaved, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Metrics.grid)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .opacity(app.persistence.hasUnsavedChanges || app.persistence.currentFileName != nil ? 1.0 : 0.0)
        .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.2), value: app.persistence.hasUnsavedChanges)
        .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.2), value: app.persistence.currentFileName)
    }

    // MARK: Private

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

}
