//
//  TiercadeApp.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

import SwiftUI
import SwiftData

//
//  TiercadeApp.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

@main
struct TiercadeApp: App {
    @AppStorage("ui.theme") private var themeRaw: String = ThemePreference.system.rawValue
    private let modelContainer: ModelContainer
    @State private var appState: AppState

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
            for: TierListEntity.self,
                TierEntity.self,
                TierItemEntity.self,
                TierThemeEntity.self,
                TierColorEntity.self,
                TierProjectDraft.self,
                TierDraftTier.self,
                TierDraftItem.self,
                TierDraftOverride.self,
                TierDraftMedia.self,
                TierDraftAudit.self,
                TierDraftCollabMember.self
            )
        } catch {
            fatalError("Failed to initialize model container: \(error.localizedDescription)")
        }
        modelContainer = container
        _appState = State(initialValue: AppState(modelContext: container.mainContext))
    }

    private var preferredScheme: ColorScheme? {
        ThemePreference(rawValue: themeRaw)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ContentView()
                    .environment(appState)
            }
            .font(TypeScale.body)
            .preferredColorScheme(preferredScheme)
        }
        .modelContainer(modelContainer)

#if DEBUG
        WindowGroup("Toolbar Debug") {
            NavigationSplitView {
                List {
                    Text("Sidebar Item")
                }
            } detail: {
                NavigationStack {
                    Text("Debug Detail")
                        .padding()
                        .navigationTitle("Toolbar Debug")
#if !os(tvOS)
                        .toolbarRole(.editor)
#endif
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Test Toolbar") {
                                    print("Debug toolbar tapped")
                                }
                            }
                        }
                }
            }
        }
#endif
    }
}
