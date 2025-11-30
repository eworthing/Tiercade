import SwiftUI

// MARK: - Image Preview Sheet

struct ImagePreviewSheet: View {
    let image: Image
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Generated Image")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
            }
            .padding()

            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            HStack(spacing: 12) {
                Spacer()

                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(maxWidth: 600, maxHeight: 700)
    }
}

// Preview intentionally omitted to keep compile times fast
