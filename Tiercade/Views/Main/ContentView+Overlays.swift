import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage
    @State private var isVisible = false

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
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let title = toast.actionTitle, let action = toast.action {
                Button(title) { action() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, Metrics.grid * 2)
        .padding(.vertical, Metrics.grid * 1.5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        #if os(macOS)
        .focusable(true)
        .accessibilityAddTraits(.isModal)
        #endif
    }
}

// MARK: - Progress Indicator View

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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Drag Target Highlight

struct DragTargetHighlight: View {
    let isTarget: Bool
    let color: Color

    var body: some View {
        if isTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )
                .shadow(color: color.opacity(0.45), radius: 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTarget)
        }
    }
}

// MARK: - Quick Rank overlay

struct QuickRankOverlay: View {
    @Bindable var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable { case firstTier, cancel }
    var body: some View {
        if let item = app.quickRankTarget {
            VStack(spacing: 12) {
                // mark overlay for UI tests
                Text("Quick Rank: \(item.name ?? item.id)").font(.headline)
                HStack(spacing: 8) {
                    ForEach(app.tierOrder, id: \.self) { t in
                        Button(t) { app.commitQuickRank(to: t) }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("QuickRank_Tier_\(t)")
                            .focused($focused, equals: t == app.tierOrder.first ? .firstTier : nil)
                    }
                    Button("Cancel", role: .cancel) { app.cancelQuickRank() }
                        .accessibilityHint("Cancel quick rank")
                        .accessibilityIdentifier("QuickRank_Cancel")
                        .focused($focused, equals: .cancel)
                }
            }
            .accessibilityIdentifier("QuickRank_Overlay")
            .padding(Metrics.grid * 1.5)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(Metrics.grid)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            #if os(macOS) || os(tvOS)
            .focusable(true)
            .accessibilityAddTraits(.isModal)
            .defaultFocus($focused, .firstTier)
            .focusSection()
            #endif
        }
    }
}

// MARK: - Head-to-Head overlay

struct HeadToHeadOverlay: View {
    @Bindable var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable { case left, right, skip, finish, cancel }

    var body: some View {
        if app.h2hActive {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { /* block background interaction */ }
                    .accessibilityHidden(true)
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Head-to-Head")
                            .font(.largeTitle.weight(.semibold))
                        Text("Choose the stronger option or skip to revisit later.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    if app.h2hTotalComparisons > 0 {
                        VStack(spacing: 8) {
                            ProgressView(value: app.h2hProgress) {
                                Text("Progress")
                                    .font(.caption.weight(.semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                            }
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(maxWidth: 320)
                            .accessibilityIdentifier("H2H_Progress")

                            Text("\(app.h2hCompletedComparisons) decided • \(app.h2hRemainingComparisons) remaining")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if app.h2hSkippedCount > 0 {
                                Text("\(app.h2hSkippedCount) skipped to revisit soon")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("H2H_SkippedCount")
                            }
                        }
                    }

                    if let pair = app.h2hPair {
                        HStack(alignment: .center, spacing: 32) {
                            H2HButton(item: pair.0) { app.voteH2H(winner: pair.0) }
                                .accessibilityIdentifier("H2H_Left")
                                .focused($focused, equals: .left)

                            VStack(spacing: 16) {
                                Text("vs")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.secondary)

                                H2HSkipButton {
                                    app.skipCurrentH2HPair()
                                }
                                .focused($focused, equals: .skip)
                            }

                            H2HButton(item: pair.1) { app.voteH2H(winner: pair.1) }
                                .accessibilityIdentifier("H2H_Right")
                                .focused($focused, equals: .right)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("All comparisons reviewed.")
                                .font(.headline)
                            Text("Choose Finish to apply the results or Cancel to discard.")
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        Button("Finish") {
                            app.finishH2H()
                        }
                        .buttonStyle(TVRemoteButtonStyle(role: .primary))
                        .accessibilityIdentifier("H2H_Finish")
                        .focused($focused, equals: .finish)

                        Button("Cancel", role: .cancel) {
                            app.cancelH2H()
                        }
                        .buttonStyle(TVRemoteButtonStyle(role: .secondary))
                        .accessibilityHint("Cancel head-to-head and return to the main view")
                        .accessibilityIdentifier("H2H_Cancel")
                        .focused($focused, equals: .cancel)
                    }
                }
                .padding(Metrics.grid * 2)
                .frame(maxWidth: 1000)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                        )
                )
                .padding(Metrics.grid * 2)
                .accessibilityIdentifier("H2H_Overlay")
                .accessibilityElement(children: .contain)
                .onAppear { updateFocus(hasPair: app.h2hPair != nil) }
                .defaultFocus($focused, .left)
                .onChange(of: app.h2hPair?.0.id) { _, _ in
                    updateFocus(hasPair: app.h2hPair != nil)
                }
                .onChange(of: app.h2hPair?.1.id) { _, _ in
                    updateFocus(hasPair: app.h2hPair != nil)
                }
                .onChange(of: app.h2hPair == nil) { _, _ in
                    updateFocus(hasPair: app.h2hPair != nil)
                }
                #if os(macOS) || os(tvOS)
                .focusable(true)
                .accessibilityAddTraits(.isModal)
                .focusSection()
                #else
                .accessibilityAddTraits(.isModal)
                #endif
            }
            .transition(.opacity)
            #if os(tvOS)
            .onExitCommand {
                app.cancelH2H(fromExitCommand: true)
            }
            #endif
        }
    }

    private func updateFocus(hasPair: Bool) {
        Task { @MainActor in
            focused = hasPair ? .left : .finish
        }
    }
}

struct H2HButton: View {
    let item: Item
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.name ?? item.id)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let season = item.seasonString, !season.isEmpty {
                    Text("Season \(season)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let status = item.status, !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                }
            }
            .padding(Metrics.grid * 2)
            .frame(minWidth: 280, maxWidth: 380, minHeight: 240, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel(item.name ?? item.id)
        .accessibilityHint(item.description ?? "Head-to-head option")
        .accessibilityIdentifier("H2HButton_\(item.id)")
    }
}

struct H2HSkipButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                Text("Skip")
                    .font(.headline.weight(.semibold))
            }
            .frame(width: 180, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityLabel("Skip This Pair")
        .accessibilityHint("Skip to revisit later")
        .accessibilityIdentifier("H2H_Skip")
    }
}
