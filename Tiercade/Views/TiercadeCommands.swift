#if os(macOS)
import SwiftUI

internal struct TiercadeCommands: Commands {
    @Bindable internal var appState: AppState

    internal var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Tier List") {
                appState.wizardActive = true
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])
            .help("Create a new tier list")

            Divider()

            Button("Save") {
                Task {
                    await appState.saveCurrentState()
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save the current tier list")

            Button("Load...") {
                appState.showingLoadPicker = true
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Load a saved tier list")
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

            Button("Import...") {
                appState.showingImportPicker = true
            }
            .keyboardShortcut("i", modifiers: [.shift, .command])
            .help("Import a tier list from file")
        }

        // View menu commands
        CommandGroup(after: .sidebar) {
            Button(appState.themesActive ? "Close Theme Picker" : "Theme Picker") {
                appState.themesActive.toggle()
            }
            .keyboardShortcut("t", modifiers: .command)
            .help("Open theme picker")

            Button(appState.analysisActive ? "Close Analysis" : "Analysis") {
                appState.analysisActive.toggle()
            }
            .keyboardShortcut("a", modifiers: .command)
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
            .disabled(!appState.canStartH2H)

            Divider()

            Button("Randomize All") {
                appState.randomizeAll()
            }
            .keyboardShortcut("r", modifiers: [.shift, .command])
            .help("Randomly assign all items to tiers")

            Button("Reset to Unranked") {
                appState.resetToUnranked()
            }
            .keyboardShortcut("u", modifiers: [.shift, .command])
            .help("Move all items to unranked tier")

            Divider()

            Button("Add Items") {
                appState.showingAddItems = true
            }
            .keyboardShortcut("i", modifiers: .command)
            .help("Add new items to the tier list")

            Button("Edit Custom Schema") {
                appState.showingSchemaEditor = true
            }
            .keyboardShortcut("e", modifiers: .command)
            .help("Edit custom fields for items")
        }

        // Edit menu enhancements
        CommandGroup(after: .pasteboard) {
            Button("Select All Items") {
                appState.selectAllItems()
            }
            .keyboardShortcut("a", modifiers: [.shift, .command])
            .help("Select all items in the tier list")

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
