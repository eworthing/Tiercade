import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS) || targetEnvironment(macCatalyst)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toast View

internal struct ToastView: View {
    internal let toast: ToastMessage
    @State private var isVisible = false
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let symbolMap: [String: String] = [
        "{undo}": "arrow.uturn.backward.circle",
        "{redo}": "arrow.uturn.forward.circle",
        "{lock}": "lock.circle",
        "{import}": "tray.and.arrow.down.fill",
        "{export}": "square.and.arrow.up",
        "{file}": "doc.text",
        "{warning}": "exclamationmark.triangle.fill"
    ]

    internal var body: some View {
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
        .tvGlassRounded(18)
        .tint(toast.type.color.opacity(0.24))
        .shadow(color: Color.black.opacity(0.24), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
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
        #if os(iOS) || targetEnvironment(macCatalyst)
        .focusable(interactions: .activate)
        .accessibilityAddTraits(.isModal)
        #endif
    }

    /// Parses message text and converts symbol markers like {undo} to inline SF Symbols
    private func parseMessageWithSymbols(_ message: String) -> Text {
        let attributedString = NSMutableAttributedString()
        var remaining = message

        while let openBrace = remaining.firstIndex(of: "{"),
              let closeBrace = remaining[openBrace...].firstIndex(of: "}") {
            let beforeMarker = String(remaining[..<openBrace])
            if !beforeMarker.isEmpty {
                attributedString.append(NSAttributedString(string: beforeMarker))
            }

            let marker = String(remaining[openBrace...closeBrace])
            if let symbolName = Self.symbolMap[marker],
               let attachment = makeSymbolAttachment(named: symbolName) {
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
        #if canImport(UIKit)
        guard let image = UIImage(systemName: symbolName) else { return nil }
        let attachment = NSTextAttachment()
        attachment.image = image
        return attachment
        #else
        return nil
        #endif
    }
}

// MARK: - Progress Indicator View

internal struct ProgressIndicatorView: View {
    internal let isLoading: Bool
    internal let message: String
    internal let progress: Double

    internal var body: some View {
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
                .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Drag Target Highlight

internal struct DragTargetHighlight: View {
    internal let isTarget: Bool
    internal let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal var body: some View {
        if isTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )
                .shadow(color: color.opacity(0.45), radius: 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(reduceMotion ? nil : Motion.spring, value: isTarget)
        }
    }
}

// MARK: - Quick Rank overlay

internal struct QuickRankOverlay: View {
    @Bindable var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable {
        case tier(String)
        case cancel
    }
    #if !os(tvOS)
    @FocusState private var overlayHasFocus: Bool
    #endif
    internal var body: some View {
        if let item = app.quickRankTarget {
            let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTest")
            ZStack {
                Color.black.opacity(0.65)
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
                .accessibilityIdentifier("QuickRank_Overlay")
                .padding(Metrics.grid * 1.5)
                .tvGlassRounded(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.25)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 22, y: 8)
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
                .onChange(of: overlayHasFocus) { _, newValue in
                if !newValue {
                Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                overlayHasFocus = true
                }
                }
                }
                #endif
            }
            .transition(isUITest ? .identity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var defaultFocusField: FocusField {
        if let first = app.tierOrder.first {
            return .tier(first)
        }
        return .cancel
    }
}
