//
//  TiercadeApp.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

import SwiftUI

//
//  TiercadeApp.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

@main
struct TiercadeApp: App {
    @AppStorage("ui.theme") private var themeRaw: String = ThemePreference.system.rawValue
    @State private var appState = AppState()

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
    }
}
