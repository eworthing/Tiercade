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
    @ObservedObject var app: AppState
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
    @ObservedObject var app: AppState
    @FocusState private var focused: FocusField?
    private enum FocusField: Hashable { case left, right, finish, cancel }
    var body: some View {
        if app.h2hActive {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { /* block background interaction */ }
                    .accessibilityHidden(true)
                VStack(spacing: 16) {
                    Text("Head-to-Head").font(.headline)
                    if let pair = app.h2hPair {
                        HStack(spacing: 16) {
                            H2HButton(item: pair.0) { app.voteH2H(winner: pair.0) }
                                .accessibilityIdentifier("H2H_Left")
                                .focused($focused, equals: .left)
                            Text("vs").font(.headline)
                            H2HButton(item: pair.1) { app.voteH2H(winner: pair.1) }
                                .accessibilityIdentifier("H2H_Right")
                                .focused($focused, equals: .right)
                        }
                    } else {
                        Text("No more pairs. Tap Finish.").foregroundStyle(.secondary)
                    }
                        HStack {
                        Button("Finish") { app.finishH2H() }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("H2H_Finish")
                            .focused($focused, equals: .finish)
                        Button("Cancel", role: .cancel) { app.h2hActive = false }
                            .accessibilityHint("Cancel head to head and return to the main view")
                            .accessibilityIdentifier("H2H_Cancel")
                            .focused($focused, equals: .cancel)
                    }
                }
                .padding(Metrics.grid)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(Metrics.grid * 2)
                .accessibilityIdentifier("H2H_Overlay")
                .accessibilityElement(children: .contain)
                #if os(macOS) || os(tvOS)
                .focusable(true)
                .accessibilityAddTraits(.isModal)
                .defaultFocus($focused, .left)
                .focusSection()
                #else
                .accessibilityAddTraits(.isModal)
                #endif
            }
            .transition(.opacity)
        }
    }
}

struct H2HButton: View {
    let item: Item
    var action: () -> Void
    var body: some View {
        Button(action: action, label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor)
                    .frame(minWidth: 140, idealWidth: 160, minHeight: 88, idealHeight: 100)
                    .overlay(Text((item.name ?? item.id).prefix(14)).font(.headline).foregroundStyle(.white))
                Text(item.seasonString ?? "?").font(.caption)
            }
            .padding(Metrics.grid)
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44)
        })
        .accessibilityLabel(item.name ?? item.id)
        .buttonStyle(GhostButtonStyle())
        .accessibilityIdentifier("H2HButton_\(item.id)")
    }
}
