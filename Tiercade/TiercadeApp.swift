import Foundation
import SwiftData
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// Boot logging for acceptance test diagnostics
private let acceptanceTestFlag = "-runAcceptanceTests"
private let bootLogURL: URL = FileManager.default.temporaryDirectory
    .appendingPathComponent("tiercade_acceptance_boot.log")

private func bootLog(_ s: String) {
    let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(s)\n"
    if let d = line.data(using: .utf8) {
        let path = bootLogURL.path
        if FileManager.default.fileExists(atPath: path) {
            if let h = try? FileHandle(forWritingTo: bootLogURL) {
                _ = try? h.seekToEnd()
                _ = try? h.write(contentsOf: d)
                _ = try? h.close()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: d)
            #if os(macOS)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            #endif
        }
    }
    print(s)
}

// MARK: - TiercadeApp

@main
struct TiercadeApp: App {

    // MARK: Lifecycle

    init() {
        let args = ProcessInfo.processInfo.arguments
        bootLog("🚀 TiercadeApp init, args=\(args)")

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
                TierDraftCollabMember.self,
            )
        } catch {
            fatalError("Failed to initialize model container: \(error.localizedDescription)")
        }
        self.modelContainer = container
        _appState = State(initialValue: AppState(modelContext: container.mainContext))
    }

    // MARK: Internal

    // swiftlint:disable:next private_swiftui_state - internal for TiercadeApp+Debug extension
    @State var appState: AppState

    var body: some Scene {
        WindowGroup {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ContentView()
                    .environment(appState)
            }
            .font(TypeScale.body)
            .preferredColorScheme(preferredScheme)
            .task {
                checkForAutomatedTesting()
                await maybeRunAcceptance()
            }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
            .commands {
                TiercadeCommands(appState: appState)
            }
        #endif
    }

    // MARK: Private

    @AppStorage("ui.theme") private var themeRaw: String = ThemePreference.system.rawValue
    @State private var kicked = false

    private let modelContainer: ModelContainer

    private var preferredScheme: ColorScheme? {
        ThemePreference(rawValue: themeRaw)?.colorScheme
    }

    @MainActor
    private func maybeRunAcceptance() async {
        guard !kicked else {
            return
        }
        kicked = true

        let args = ProcessInfo.processInfo.arguments
        bootLog("🔎 body.task fired, args=\(args)")

        guard args.contains(acceptanceTestFlag) else {
            bootLog("ℹ️  Flag '\(acceptanceTestFlag)' not present; continuing with normal UI")
            return
        }

        bootLog("✅ Flag '\(acceptanceTestFlag)' present → starting acceptance suite")

        // Acceptance tests require macOS/iOS - fail immediately on tvOS
        #if os(tvOS)
        bootLog("❌ FATAL: Acceptance tests cannot run on tvOS (requires macOS 26.0+ or iOS 26.0+)")
        bootLog("ℹ️  Run tests on macOS instead: ./build_install_launch.sh macos")
        print("\n❌ ERROR: -runAcceptanceTests flag is not supported on tvOS")
        print("ℹ️  Acceptance tests require macOS 26.0+ or iOS 26.0+")
        print("ℹ️  Use native macOS build: ./build_install_launch.sh macos\n")
        exit(99)
        #endif

        #if canImport(FoundationModels)
        bootLog("✅ FoundationModels imported at compile time")
        if #available(iOS 26.0, macOS 26.0, *) {
            bootLog("✅ Runtime version check passed (iOS 26.0+/macOS 26.0+)")
            do {
                bootLog("🧪 Calling AcceptanceTestSuite.runAll()...")
                let report = try await AcceptanceTestSuite.runAll { message in
                    bootLog("🧪 \(message)")
                }

                let reportPath = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("tiercade_acceptance_test_report.json").path
                let telemetryPath = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("unique_list_runs.jsonl").path

                try? AcceptanceTestSuite.saveReport(report, to: reportPath)
                bootLog("✅ Suite finished successfully")
                bootLog("📊 Results: \(report.passed)/\(report.totalTests) tests passed")
                bootLog("📄 Report: \(reportPath)")
                bootLog("📄 Telemetry: \(telemetryPath)")

                try? await Task.sleep(for: .seconds(2))
                exit(report.passed == report.totalTests ? 0 : 1)
            } catch {
                bootLog("❌ Suite error: \(error.localizedDescription)")
                exit(2)
            }
        } else {
            bootLog("❌ FoundationModels not available at runtime (version too old)")
            exit(3)
        }
        #else
        bootLog("❌ FoundationModels not compiled in (canImport=false)")
        exit(4)
        #endif
    }
}
