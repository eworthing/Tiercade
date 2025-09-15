import SwiftUI

struct ItemTrayView: View {
    @EnvironmentObject var app: AppState
    @State private var query: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            HStack {
                Text("Items").font(TypeScale.h3).foregroundColor(Palette.text)
                Spacer()
                Button("Add") { /* show add UI */ }
                    .buttonStyle(PrimaryButtonStyle())
            }

            TextField("Search items...", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Metrics.grid)]) {
                    ForEach(app.tierOrder.flatMap { app.tiers[$0] ?? [] }, id: \.id) { contestant in
                        Button(action: { app.beginQuickRank(contestant) }) {
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: Metrics.rSm)
                                    .frame(minHeight: 72, idealHeight: 88)
                                    .overlay(
                                        Group {
                                            if let thumb = contestant.thumbUri, let url = URL(string: thumb) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let img):
                                                        img.resizable().scaledToFill()
                                                    case .failure:
                                                        RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                            .overlay(Text((contestant.name ?? contestant.id).prefix(18))
                                                                        .font(.headline)
                                                                        .foregroundColor(.white)
                                                                        .padding(Metrics.grid))
                                                    @unknown default:
                                                        RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                    }
                                                }
                                                .clipped()
                                            } else {
                                                RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                    .overlay(Text((contestant.name ?? contestant.id).prefix(18))
                                                                .font(.headline)
                                                                .foregroundColor(.white)
                                                                .padding(Metrics.grid))
                                            }
                                        }
                                    , alignment: .bottomLeading)
                            }
                            .card()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .accessibilityLabel(contestant.name ?? contestant.id)
                    }
                }
            }

            // Quick tags
            HStack(spacing: Metrics.grid) {
                TagChip(text: "Favorite")
                TagChip(text: "Recent")
                TagChip(text: "TV")
            }
        }
        .panel()
        .frame(minWidth: Metrics.paneLeft)
        .padding(.horizontal, Metrics.grid)
    }
}
