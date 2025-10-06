import SwiftUI
import Observation

struct SettingsView: View {
    @Bindable var app: AppState
    @AppStorage("ui.theme") private var themeRaw: String = ThemePreference.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemePreference {
        get { ThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    ForEach(ThemePreference.allCases) { option in
                        ThemeOptionRow(option: option, selectionRaw: $themeRaw)
                            .listRowInsets(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
                            .listRowBackground(Color.clear)
                    }
                }

                Section("Card Size") {
                    ForEach(CardDensityPreference.allCases) { option in
                        CardDensityOptionRow(
                            option: option,
                            isSelected: app.cardDensityPreference == option,
                            onSelect: { app.setCardDensityPreference(option) }
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
                        .listRowBackground(Color.clear)
                    }
                }

                Section("About") {
                    SettingsInfoRow(title: "Version", value: versionString)
                        .listRowInsets(EdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32))
                        .listRowBackground(Color.clear)
                }
            }
            .environment(\.defaultMinListRowHeight, 68)
            .background(Color.appBackground.ignoresSafeArea())
            .listStyle(.plain)
            .navigationTitle("Settings")
            #if os(tvOS)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CloseButton(dismiss: dismiss) } }
            #endif
        }
    }
}

private struct SettingsOptionLabel: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .font(.headline)
        .padding(.vertical, 4)
    }
}

#if os(tvOS)
private struct CloseButton: View {
    let dismiss: DismissAction

    var body: some View {
        Button("Done") { dismiss() }
            .buttonStyle(.tvRemote(.secondary))
    }
}
#endif

private extension ThemePreference {
    var displayName: String { rawValue.capitalized }
}

private struct CardDensityOptionRow: View {
    let option: CardDensityPreference
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: option.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.detailDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.white)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
        }
        #if os(tvOS)
        .buttonStyle(.tvRemote(.list))
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityIdentifier("Settings_CardSize_\(option.displayName)")
        .accessibilityValue(isSelected ? "Selected" : "Not Selected")
    }
}

private extension SettingsView {
    var versionString: String {
        let bundle = Bundle.main
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?): return "\(s) (\(b))"
        case let (s?, nil): return s
        default: return "1.0"
        }
    }
}

private struct ThemeOptionRow: View {
    let option: ThemePreference
    @Binding var selectionRaw: String

    var body: some View {
        Button {
            selectionRaw = option.rawValue
        } label: {
            SettingsOptionLabel(title: option.displayName, isSelected: selectionRaw == option.rawValue)
        }
        #if os(tvOS)
        .buttonStyle(.tvRemote(.list))
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityIdentifier("Settings_Theme_\(option.rawValue.capitalized)")
    }
}
