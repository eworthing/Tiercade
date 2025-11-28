import SwiftUI
import Observation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Observable state (0...255 channels, fine-grained invalidation)

#if os(tvOS)

@Observable
final class ColorPickerState {
    private var _red: Double = 0
    private var _green: Double = 0
    private var _blue: Double = 0

    var red: Double {
        get { _red }
        set {
            _red = min(255, max(0, newValue))
            syncHex()
        }
    }

    var green: Double {
        get { _green }
        set {
            _green = min(255, max(0, newValue))
            syncHex()
        }
    }

    var blue: Double {
        get { _blue }
        set {
            _blue = min(255, max(0, newValue))
            syncHex()
        }
    }

    private(set) var hex: String = "#000000"

    var color: Color { Color(red: red / 255, green: green / 255, blue: blue / 255) }

    private func syncHex() {
        hex = String(format: "#%02X%02X%02X", Int(_red), Int(_green), Int(_blue))
    }

    func load(fromHex input: String) {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .uppercased()
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return }
        red   = Double((value & 0xFF0000) >> 16)
        green = Double((value & 0x00FF00) >> 8)
        blue  = Double(value & 0x0000FF)
    }

    // Convert any input CGColor to sRGB before extracting components.
    func load(from cgColor: CGColor) {
        guard
            let srgb = cgColor.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!,
                intent: .defaultIntent,
                options: nil
            ),
            let components = srgb.components,
            components.count >= 3
        else { return }
        red = Double(components[0] * 255)
        green = Double(components[1] * 255)
        blue = Double(components[2] * 255)
    }
}

// MARK: - Public ColorPicker View (tvOS 26, SwiftUI-only)

public struct TVColorPickerView: View {
    public struct Swatch: Hashable, Equatable {
        public let name: String
        public let rgb: (UInt8, UInt8, UInt8)

        public init(_ name: String, _ red: UInt8, _ green: UInt8, _ blue: UInt8) {
            self.name = name
            self.rgb = (red, green, blue)
        }

        var color: Color {
            Color(
                red: Double(rgb.0) / 255,
                green: Double(rgb.1) / 255,
                blue: Double(rgb.2) / 255
            )
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(rgb.0)
            hasher.combine(rgb.1)
            hasher.combine(rgb.2)
        }

        public static func == (lhs: Swatch, rhs: Swatch) -> Bool {
            lhs.name == rhs.name && lhs.rgb == rhs.rgb
        }
    }

    @Binding private var selection: Color
    @State private var state = ColorPickerState()

    @State private var showHexEditor = false
    @State private var hexDraft = ""

    private let title: String
    private let swatches: [Swatch]

    private enum Field: Hashable {
        case red, green, blue, hexBtn, swatch(Int), apply, cancel
    }
    @FocusState private var focus: Field?

    public init(
        selection: Binding<Color>,
        title: String = "Color",
        swatches: [Swatch] = [
            .init("Red", 255, 59, 48), .init("Orange", 255, 149, 0),
            .init("Yellow", 255, 204, 0), .init("Green", 52, 199, 89),
            .init("Blue", 0, 122, 255), .init("Indigo", 88, 86, 214),
            .init("Purple", 175, 82, 222), .init("Pink", 255, 45, 85),
            .init("Cyan", 50, 173, 230), .init("Mint", 99, 230, 226)
        ]
    ) {
        self._selection = selection
        self.title = title
        self.swatches = swatches
    }

    public var body: some View {
        ZStack {
            RadialGradient(
                colors: [state.color.opacity(0.32), Palette.bg.opacity(0.88)],
                center: .topLeading, startRadius: 120, endRadius: 1000
            ).ignoresSafeArea()

            // Glass is applied to inner sections only.
            tvGlassContainer(spacing: Metrics.grid * 4) {
                ScrollView {
                    VStack(spacing: Metrics.grid * 4) {
                        Text(title).font(TypeScale.h2)
                        previewSection
                        swatchesSection
                        slidersSection
                        actionsSection
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
            }
        }
        .onAppear {
            // SwiftUI Color → CGColor (deprecated in 26.1 but still available)
            if let cgColor = selection.cgColor {
                state.load(from: cgColor)
            }
            focus = .red
        }
        .onChange(of: state.color) { _, newColor in
            selection = newColor
        }
        .sheet(isPresented: $showHexEditor) { hexSheet }
    }

    // MARK: sections

    private var previewSection: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 24)
                .fill(state.color)
                .frame(width: 480, height: 200)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .accessibilityLabel("Selected color")
                .accessibilityValue(
                    "Red \(Int(state.red)), Green \(Int(state.green)), Blue \(Int(state.blue))"
                )

            HStack(spacing: 16) {
                Text(state.hex)
                    .font(TypeScale.monoLarge)

                Button {
                    hexDraft = state.hex
                    showHexEditor = true
                } label: {
                    Image(systemName: "square.and.pencil").font(.title3)
                }
                .buttonStyle(.card)
                .focused($focus, equals: .hexBtn)
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(Palette.surface.opacity(0.5), in: Capsule())
            .overlay {
                Capsule().stroke(Palette.stroke, lineWidth: 1)
            }
        }
    }

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Fine-tune RGB")
                .font(TypeScale.h3)
                .padding(.leading, 28)

            VStack(spacing: 28) {
                ChannelSlider(value: $state.red, label: "Red", tint: .red)
                    .focused($focus, equals: .red)
                ChannelSlider(value: $state.green, label: "Green", tint: .green)
                    .focused($focus, equals: .green)
                ChannelSlider(value: $state.blue, label: "Blue", tint: .blue)
                    .focused($focus, equals: .blue)
            }
            .padding(28)
        }
        .frame(maxWidth: 1200)
        .background(Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Metrics.rLg + 8))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.rLg + 8)
                .stroke(Palette.stroke, lineWidth: 1)
        }
        .focusSection()
    }

    private var swatchesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Start with a color")
                .font(TypeScale.h3)
                .padding(.leading, 28)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 28)],
                spacing: 28
            ) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { index, swatch in
                    Button {
                        state.red = Double(swatch.rgb.0)
                        state.green = Double(swatch.rgb.1)
                        state.blue = Double(swatch.rgb.2)
                    } label: {
                        VStack(spacing: Metrics.grid) {
                            RoundedRectangle(cornerRadius: Metrics.rMd + 2)
                                .fill(swatch.color)
                                .frame(width: 90, height: 90)
                            Text(swatch.name)
                                .font(TypeScale.label)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.card)
                    .focused($focus, equals: .swatch(index))
                    .accessibilityLabel("Swatch \(swatch.name)")
                }
            }
            .padding(28)
        }
        .background(Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Metrics.rLg + 8))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.rLg + 8)
                .stroke(Palette.stroke, lineWidth: 1)
        }
        .focusSection()
    }

    private var actionsSection: some View {
        HStack(spacing: 48) {
            Button("Cancel") {
                if let cgColor = selection.cgColor {
                    state.load(from: cgColor)
                }
            }
            .buttonStyle(.glass)
            .focused($focus, equals: .cancel)
            .frame(width: ScaledDimensions.actionButtonWidth)

            Button("Apply Color") {
                selection = state.color
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .focused($focus, equals: .apply)
            .frame(width: ScaledDimensions.actionButtonWidth)
        }
        .focusSection()
    }

    private var hexSheet: some View {
        VStack(spacing: 28) {
            Text("Enter Hex Code").font(TypeScale.h3)

            TextField("#RRGGBB", text: $hexDraft)
                .textInputAutocapitalization(.characters)
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .onSubmit {
                    state.load(fromHex: hexDraft)
                    showHexEditor = false
                }
                .font(TypeScale.monoBody)
                .frame(maxWidth: 600)
                .padding(20)
                .background(Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.rLg)
                        .stroke(Palette.stroke.opacity(2.0), lineWidth: 2)
                }
                .cornerRadius(Metrics.rLg)
                #if os(tvOS)
                .focusEffectDisabled(false)
                #endif

            Text("Format: #RRGGBB").font(TypeScale.label).foregroundStyle(Palette.textDim)

            HStack(spacing: 44) {
                Button("Cancel") { showHexEditor = false }
                    .buttonStyle(.glass)
                    .frame(width: 220)
                Button("Apply") {
                    state.load(fromHex: hexDraft)
                    showHexEditor = false
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .frame(width: 220)
            }
        }
        .padding(64)
        .frame(maxWidth: 800)
    }
}

// MARK: - Remote-optimized slider (focus, step size tuned for TV)

private struct ChannelSlider: View {
    @Binding var value: Double   // 0...255
    let label: String
    let tint: Color
    @FocusState private var isFocused: Bool

    private var pos: Double { value / 255.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(TypeScale.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFocused ? Palette.text : Palette.textDim)
                Spacer()
                Text("\(Int(value))")
                    .font(TypeScale.body.monospacedDigit())
                    .foregroundStyle(Palette.textDim)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Palette.surface.opacity(0.5), in: Capsule())
                    .overlay {
                        Capsule().stroke(Palette.stroke, lineWidth: 1)
                    }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.black, tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 32)
                        .overlay {
                            Capsule().stroke(isFocused ? .white : .clear, lineWidth: 4)
                        }

                    Capsule()
                        .fill(tint.opacity(0.88))
                        .frame(width: geometry.size.width * pos, height: 32)

                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.35), radius: isFocused ? 18 : 10)
                        .scaleEffect(isFocused ? 1.28 : 1.0)
                        .offset(x: geometry.size.width * pos - 22)
                }
            }
            .frame(height: 44)
        }
        .focusable()
        .focused($isFocused)
        .onMoveCommand { direction in
            let step = 6.0
            switch direction {
            case .left:  value = max(0, value - step)
            case .right: value = min(255, value + step)
            default: break
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) channel")
        .accessibilityValue("\(Int(value)) out of 255")
        .accessibilityHint("Swipe left or right to adjust")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(255, value + 12)
            case .decrement: value = max(0, value - 12)
            @unknown default: break
            }
        }
    }
}

#endif // os(tvOS)
