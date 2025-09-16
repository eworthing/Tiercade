import SwiftUI
import TiercadeCore

// MARK: - Sidebar (filters/summary)
struct SidebarView: View {
    @EnvironmentObject var app: AppState
    let tierOrder: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tier List").font(.largeTitle.bold())
                Spacer()
                Button(action: { /* stub: show add dialog */ }) {
                    Label("Add Items", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            SidebarSearchView()
            Divider()
            SidebarStatsView(tierOrder: tierOrder)
            Divider()
            SidebarTierListView(tierOrder: tierOrder)
            Divider()
            ItemTrayView()
        }
        .padding(Metrics.grid * 2)
        .frame(minWidth: 280)
        .panel()
    }
}

struct SidebarSearchView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search & Filter").font(.headline)

            #if !os(tvOS)
            TextField("Search items...", text: $app.searchQuery)
                .textFieldStyle(.roundedBorder)

            if app.isProcessingSearch {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Processing search...").font(.caption).foregroundColor(.secondary)
                }
                .transition(.opacity)
            }
            #endif

            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(filter.rawValue) { app.activeFilter = filter }
                        .buttonStyle(GhostButtonStyle())
                        #if !os(tvOS)
                        .controlSize(.small)
                        #endif
                        .background(app.activeFilter == filter ? Color.accentColor.opacity(0.2) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(app.activeFilter == filter ? Color.accentColor : Color.clear, lineWidth: 2))
                }
            }
        }
    }
}

struct SidebarStatsView: View {
    @EnvironmentObject var app: AppState
    let tierOrder: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics").font(.headline)
            HStack { Text("Total:"); Spacer(); Text("\(app.allItems().count)").bold() }
            HStack { Text("Ranked:"); Spacer(); Text("\(app.rankedCount())").bold() }
            HStack { Text("Unranked:"); Spacer(); Text("\(app.unrankedCount())").bold() }
            if !app.searchQuery.isEmpty { HStack { Text("Filtered:"); Spacer(); Text("\(app.allItems().count)").bold().foregroundColor(.accentColor) } }
        }
    }
}

struct SidebarTierListView: View {
    @EnvironmentObject var app: AppState
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

// MARK: - Persistence Status
struct PersistenceStatusView: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let fileName = app.currentFileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 4) {
                if app.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            if let lastSaved = app.lastSavedTime {
                Text("Last saved: \(lastSaved, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Metrics.grid)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .opacity(app.hasUnsavedChanges || app.currentFileName != nil ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: app.hasUnsavedChanges)
        .animation(.easeInOut(duration: 0.2), value: app.currentFileName)
    }
}
