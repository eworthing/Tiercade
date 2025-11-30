import Foundation
import SwiftUI
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif
#if os(macOS)
import AppKit
#endif

import TiercadeCore

// MARK: - ToastView

struct ToastView: View {

    // MARK: Internal

    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let message = toast.message {
                    parseMessageWithSymbols(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let title = toast.actionTitle, let action = toast.action {
                Button(title) {
                    action()
                    app.dismissToast()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, Metrics.grid * 2)
        .padding(.vertical, Metrics.grid * 1.5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.bg.opacity(0.88)),
        )
        .tint(toast.type.color.opacity(0.24))
        .shadow(color: Palette.bg.opacity(0.24), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1),
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(Motion.spring) {
                    isVisible = true
                }
            }

            // Auto-dismiss after duration
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(toast.duration))
                if app.currentToast?.id == toast.id {
                    app.dismissToast()
                }
            }
        }
        .onDisappear {
            if reduceMotion {
                isVisible = false
            } else {
                withAnimation(Motion.spring) {
                    isVisible = false
                }
            }
        }
        #if os(iOS)
        .focusable(interactions: .activate)
        .accessibilityAddTraits(.isModal)
        #endif
    }

    // MARK: Private

    private static let symbolMap: [String: String] = [
        "{undo}": "arrow.uturn.backward.circle",
        "{redo}": "arrow.uturn.forward.circle",
        "{lock}": "lock.circle",
        "{import}": "tray.and.arrow.down.fill",
        "{export}": "square.and.arrow.up",
        "{file}": "doc.text",
        "{warning}": "exclamationmark.triangle.fill",
    ]

    @State private var isVisible = false
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Parses message text and converts symbol markers like {undo} to inline SF Symbols
    private func parseMessageWithSymbols(_ message: String) -> Text {
        let attributedString = NSMutableAttributedString()
        var remaining = message

        while
            let openBrace = remaining.firstIndex(of: "{"),
            let closeBrace = remaining[openBrace...].firstIndex(of: "}")
        {
            let beforeMarker = String(remaining[..<openBrace])
            if !beforeMarker.isEmpty {
                attributedString.append(NSAttributedString(string: beforeMarker))
            }

            let marker = String(remaining[openBrace ... closeBrace])
            if
                let symbolName = Self.symbolMap[marker],
                let attachment = makeSymbolAttachment(named: symbolName)
            {
                attributedString.append(NSAttributedString(attachment: attachment))
            } else {
                attributedString.append(NSAttributedString(string: marker))
            }

            let nextIndex = remaining.index(after: closeBrace)
            if nextIndex < remaining.endIndex {
                remaining = String(remaining[nextIndex...])
            } else {
                remaining = ""
            }
        }

        if !remaining.isEmpty {
            attributedString.append(NSAttributedString(string: remaining))
        }

        let converted = AttributedString(attributedString)
        return Text(converted)
    }

    private func makeSymbolAttachment(named symbolName: String) -> NSTextAttachment? {
        #if os(iOS)
        guard let image = UIImage(systemName: symbolName) else {
            return nil
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        return attachment
        #elseif os(macOS)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        return attachment
        #else
        return nil
        #endif
    }
}

// MARK: - ProgressIndicatorView

struct ProgressIndicatorView: View {
    let isLoading: Bool
    let message: String
    let progress: Double

    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.primary)

                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal, Metrics.grid * 2)
                .padding(.vertical, Metrics.grid * 2)
                .tvGlassRounded(20)
                .shadow(color: Palette.bg.opacity(0.2), radius: 18, y: 8)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - DragTargetHighlight

struct DragTargetHighlight: View {
    let isTarget: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12)),
                )
                .shadow(color: color.opacity(0.45), radius: 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(reduceMotion ? nil : Motion.spring, value: isTarget)
        }
    }
}

// MARK: - QuickRankOverlay

struct QuickRankOverlay: View {

    // MARK: Internal

    @Bindable var app: AppState

    var body: some View {
        if let item = app.quickRankTarget {
            let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTest")
            ZStack {
                Palette.bg.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { app.cancelQuickRank() }
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    // mark overlay for UI tests
                    Text("Quick Rank: \(item.name ?? item.id)").font(.headline)
                    HStack(spacing: 8) {
                        ForEach(app.tierOrder, id: \.self) { tier in
                            Button(tier) { app.commitQuickRank(to: tier) }
                                .buttonStyle(PrimaryButtonStyle())
                                .accessibilityIdentifier("QuickRank_Tier_\(tier)")
                                .focused($focused, equals: .tier(tier))
                        }
                        Button("Cancel", role: .cancel) { app.cancelQuickRank() }
                            .accessibilityHint("Cancel quick rank")
                            .accessibilityIdentifier("QuickRank_Cancel")
                            .focused($focused, equals: .cancel)
                    }
                }
                // Overlay root presence is exposed via AccessibilityBridgeView in MainAppView
                .padding(Metrics.grid * 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.bg.opacity(0.85)),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1.25),
                )
                .shadow(color: Palette.bg.opacity(0.22), radius: 22, y: 8)
                .padding(Metrics.grid)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                #if os(tvOS)
                    .focusSection()
                    .defaultFocus($focused, defaultFocusField)
                    .onAppear { focused = defaultFocusField }
                    .onDisappear { focused = nil }
                #else
                    .focusable()
                    .focused($overlayHasFocus)
                    .onKeyPress(.escape) {
                        app.cancelQuickRank()
                        return .handled
                    }
                    .onAppear {
                        focused = defaultFocusField
                        overlayHasFocus = true
                    }
                    .onDisappear {
                        focused = nil
                        overlayHasFocus = false
                    }
                // Note: Removed focus reassertion anti-pattern per AGENTS.md
                // QuickRank is a transient overlay - focus can naturally escape
                #endif
            }
            .transition(isUITest ? .identity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Private

    private enum FocusField: Hashable {
        case tier(String)
        case cancel
    }

    @FocusState private var focused: FocusField?
    #if !os(tvOS)
    @FocusState private var overlayHasFocus: Bool
    #endif

    private var defaultFocusField: FocusField {
        if let first = app.tierOrder.first {
            return .tier(first)
        }
        return .cancel
    }
}
