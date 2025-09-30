import SwiftUI

import TiercadeCore

struct ItemTrayView: View {
    @Bindable private var app: AppState
    @State private var showingAdd = false

    init(app: AppState) {
        self.app = app
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            HStack {
                Text("Items").font(TypeScale.h3).foregroundColor(Palette.text)
                Spacer()
                Button("Add") { showingAdd = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("Items_AddButton")
            }

            TextField("Search items...", text: $app.searchQuery)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
            #endif

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Metrics.grid)]) {
                    ForEach(app.allItems(), id: \.id) { item in
                        Button(action: { app.beginQuickRank(item) }, label: {
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: Metrics.rSm)
                                    .frame(minHeight: 72, idealHeight: 88)
                                    .overlay(
                                        Group {
                                            // Use canonical imageUrl only (legacy thumbUri removed).
                                            let thumbSrc = item.imageUrl
                                            let titleText = String((item.name ?? item.id).prefix(18))
                                            if let thumb = thumbSrc, let url = URL(string: thumb) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        ProgressView()
                                                    case .success(let img):
                                                        img.resizable().scaledToFill()
                                                    default:
                                                        RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                            .overlay(Text(titleText)
                                                                        .font(.headline)
                                                                        .foregroundColor(.white)
                                                                        .padding(Metrics.grid))
                                                    }
                                                }
                                                .clipped()
                                            } else {
                                                RoundedRectangle(cornerRadius: Metrics.rSm).fill(Palette.brand)
                                                    .overlay(Text(titleText)
                                                                .font(.headline)
                                                                .foregroundColor(.white)
                                                                .padding(Metrics.grid))
                                            }
                                        }
                                        , alignment: .bottomLeading)
                            }
                            .card()
                        })
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .accessibilityLabel(item.name ?? item.id)
                        .accessibilityIdentifier("ItemButton_\(item.id)")
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
        .sheet(isPresented: $showingAdd, content: {
            AddItemsView(isPresented: $showingAdd)
                .environment(app)
        })
    }
}

// Simple modal for adding items
struct AddItemsView: View {
    @Environment(AppState.self) private var app: AppState
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var id: String = ""
    @State private var season: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Item")) {
                    TextField("ID (unique)", text: $id)
                    TextField("Name", text: $name)
                    TextField("Season (optional)", text: $season)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
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
