#if os(tvOS)
import SwiftUI
import TiercadeCore

struct DetailSidebarView: View {
    @Environment(AppState.self) private var app: AppState
    let item: Item
    let focus: FocusState<MainAppView.DetailFocus?>.Binding

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.52, 760)
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    DetailView(item: item)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 72)
                        .padding(.bottom, 88)
                        .padding(.horizontal, 48)
                }
                .scrollIndicators(.hidden)

                closeButton
                    .padding(.top, 36)
                    .padding(.trailing, 36)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 28, x: -18, y: 0)
            .padding(.vertical, 48)
            .padding(.trailing, 48)
            .focusSection()
            .onExitCommand {
                app.detailItem = nil
            }
            .onAppear { focus.wrappedValue = .close }
        }
    }

    private var closeButton: some View {
        Button {
            app.detailItem = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44, weight: .bold))
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Details")
        .accessibilityHint("Dismiss the details sidebar")
        .focused(focus, equals: .close)
    }
}
#endif
