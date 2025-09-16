import SwiftUI

struct ItemTrayView: View {
    @EnvironmentObject var app: AppState
    // Use AppState.searchQuery so filtering is centralized
    @State private var showingAdd = false
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            HStack {
                Text("Items").font(TypeScale.h3).foregroundColor(Palette.text)
                Spacer()
                Button("Add") { showingAdd = true }
                    .buttonStyle(PrimaryButtonStyle())
            }

            TextField("Search items...", text: $app.searchQuery)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Metrics.grid)]) {
                    ForEach(app.allItems(), id: \.id) { item in
                        Button(action: { app.beginQuickRank(item) }) {
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: Metrics.rSm)
                                    .frame(minHeight: 72, idealHeight: 88)
                                    .overlay(
                                        Group {
                                            // Prefer canonical imageUrl; fall back to legacy thumbUri if available
                                            let thumbSrc = item.imageUrl ?? item.thumbUri
                                            if let thumb = thumbSrc, let url = URL(string: thumb) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let img):
                                                        img.resizable().scaledToFill()
                                                    case .failure:
                                                        RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                            .overlay(Text((item.name ?? item.id).prefix(18))
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
                                                    .overlay(Text((item.name ?? item.id).prefix(18))
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
                        .accessibilityLabel(item.name ?? item.id)
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
        .sheet(isPresented: $showingAdd) {
            AddItemsView(isPresented: $showingAdd)
                .environmentObject(app)
        }
    }
}

// Simple modal for adding items
struct AddItemsView: View {
    @EnvironmentObject var app: AppState
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var id: String = ""
    @State private var season: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Item")) {
                    TextField("ID (unique)", text: $id)
                    TextField("Name", text: $name)
                    TextField("Season (optional)", text: $season)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let finalId = id.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !finalId.isEmpty else { return }
                        var attrs: [String: String] = [:]
                        if !name.isEmpty { attrs["name"] = name }
                        if !season.isEmpty { attrs["season"] = season }
                        app.addItem(id: finalId, attributes: attrs.isEmpty ? nil : attrs)
                        isPresented = false
                    }
                    .disabled(id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
