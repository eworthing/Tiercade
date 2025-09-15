import SwiftUI

struct SettingsView: View {
    @AppStorage("ui.theme") private var themeRaw: String = ThemePreference.system.rawValue

    private var theme: ThemePreference {
        get { ThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeRaw) {
                        ForEach(ThemePreference.allCases, id: \.rawValue) { t in
                            Text(t.rawValue.capitalized).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section(header: Text("About")) {
                    HStack { Text("Version"); Spacer(); Text("1.0") }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
