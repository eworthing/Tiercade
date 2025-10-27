#if os(macOS)
import SwiftUI

/// macOS menu bar commands for Tiercade
/// Note: Only includes features with proper AppState backing
internal struct TiercadeCommands: Commands {
    internal var appState: AppState

    internal var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Tier List") {
                appState.showTierListCreator = true
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])
            .help("Create a new tier list")

            Divider()

            Button("Save") {
                Task {
                    try? await appState.saveAsync()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save the current tier list")

            Button("Tier List Browser") {
                appState.showingTierListBrowser.toggle()
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Browse and load saved tier lists")
        }

        CommandGroup(after: .newItem) {
            Menu("Export") {
                Button("Export as Text") {
                    Task {
                        await exportToFormat(.text)
                    }
                }

                Button("Export as JSON") {
                    Task {
                        await exportToFormat(.json)
                    }
                }

                Button("Export as Markdown") {
                    Task {
                        await exportToFormat(.markdown)
                    }
                }

                Button("Export as CSV") {
                    Task {
                        await exportToFormat(.csv)
                    }
                }

                Button("Export as PNG") {
                    Task {
                        await exportToFormat(.png)
                    }
                }

                Button("Export as PDF") {
                    Task {
                        await exportToFormat(.pdf)
                    }
                }
            }
            .keyboardShortcut("e", modifiers: [.shift, .command])
            .help("Export tier list to various formats")
        }

        // View menu commands
        CommandGroup(after: .sidebar) {
            Button(appState.showThemePicker ? "Close Theme Picker" : "Theme Picker") {
                appState.showThemePicker.toggle()
            }
            .keyboardShortcut("t", modifiers: .command)
            .help("Open theme picker")

            Button(appState.showingAnalysis ? "Close Analysis" : "Analysis") {
                appState.showingAnalysis.toggle()
            }
            .keyboardShortcut("a", modifiers: [.shift, .command])
            .help("Show tier list analysis")
            .disabled(!appState.canShowAnalysis)
        }

        // Tier menu commands (custom menu)
        CommandMenu("Tier") {
            Button("Head-to-Head Ranking") {
                appState.startH2H()
            }
            .keyboardShortcut("h", modifiers: .command)
            .help("Compare items head-to-head")
            .disabled(!appState.canStartHeadToHead)

            Divider()

            Button("Randomize") {
                appState.randomize()
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
