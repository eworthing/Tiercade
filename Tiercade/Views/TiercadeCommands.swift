#if os(macOS)
import SwiftUI

/// macOS menu bar commands for Tiercade
/// Note: Only includes features with proper AppState backing
internal struct TiercadeCommands: Commands {
    internal var appState: AppState

    internal var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button {
                appState.overlays.showTierListCreator = true
            } label: {
                Label("New Tier List…", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])
            .help("Create a new tier list")

            Divider()

            Button {
                Task {
                    try? await appState.saveAsync()
                }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save the current tier list")

            Button {
                appState.overlays.showTierListBrowser.toggle()
            } label: {
                Label("Tier List Browser…", systemImage: "list.bullet.rectangle")
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Browse and load saved tier lists")
        }

        CommandGroup(after: .newItem) {
            Menu {
                Button {
                    Task { await exportToFormat(.text) }
                } label: {
                    Label("Text", systemImage: "doc.text")
                }

                Button {
                    Task { await exportToFormat(.json) }
                } label: {
                    Label("JSON", systemImage: "curlybraces.square")
                }

                Button {
                    Task { await exportToFormat(.markdown) }
                } label: {
                    Label("Markdown", systemImage: "doc.plaintext")
                }

                Button {
                    Task { await exportToFormat(.csv) }
                } label: {
                    Label("CSV", systemImage: "tablecells")
                }

                Button {
                    Task { await exportToFormat(.png) }
                } label: {
                    Label("PNG", systemImage: "photo")
                }

                Button {
                    Task { await exportToFormat(.pdf) }
                } label: {
                    Label("PDF", systemImage: "doc.richtext")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .keyboardShortcut("e", modifiers: [.shift, .command])
            .help("Export tier list to various formats")
        }

        // View menu commands
        CommandGroup(after: .sidebar) {
            Button {
                appState.overlays.showThemePicker.toggle()
            } label: {
                Label(
                    appState.overlays.showThemePicker ? "Hide Themes" : "Show Themes",
                    systemImage: "paintpalette"
                )
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            .help("Toggle tier themes (⌥⌘T)")

            Button {
                appState.showingAnalysis.toggle()
            } label: {
                Label(
                    appState.showingAnalysis ? "Hide Analysis" : "Show Analysis",
                    systemImage: appState.showingAnalysis ? "chart.bar.fill" : "chart.bar"
                )
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .help("Toggle analysis (⌥⌘A)")
            .disabled(!appState.canShowAnalysis && !appState.showingAnalysis)
        }

        // Tier menu commands (custom menu)
        CommandMenu("Tier") {
            Button {
                appState.startHeadToHead()
            } label: {
                Label("HeadToHead Ranking", systemImage: "person.line.dotted.person.fill")
            }
            .keyboardShortcut("h", modifiers: [.control, .command])
            .help("Start HeadToHead ranking (⌃⌘H)")
            .disabled(!appState.canStartHeadToHead)

            Divider()

            Button {
                appState.randomize()
            } label: {
                Label("Randomize", systemImage: "shuffle")
            }
            .keyboardShortcut("r", modifiers: [.shift, .command])
            .help("Randomly assign all items to tiers")
        }

        // Edit menu enhancements
        CommandGroup(after: .pasteboard) {
            Button("Deselect All") {
                appState.clearSelection()
            }
            .keyboardShortcut("d", modifiers: .command)
            .help("Clear item selection")
            .disabled(appState.selection.isEmpty)
        }
    }

    private func exportToFormat(_ format: ExportFormat) async {
        do {
            let (data, filename) = try await appState.exportToFormat(format)

            // Save to Downloads folder
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileURL = downloadsURL.appendingPathComponent(filename)

            try data.write(to: fileURL)

            appState.showToast(
                type: .success,
                title: "Export Complete",
                message: "Saved to \(fileURL.path)"
            )
        } catch {
            appState.showToast(
                type: .error,
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }
}
#endif
