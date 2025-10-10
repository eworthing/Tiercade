import SwiftUI

/// Displays build timestamp in DEBUG builds for verification during development
struct BuildInfoView: View {
    private var buildTimestamp: String {
        #if DEBUG
        // Use actual compile time from Info.plist or bundle creation date
        if let buildDate = getActualBuildDate() {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm:ss a"
            return formatter.string(from: buildDate)
        }
        return "Unknown"
        #else
        return ""
        #endif
    }

    private func getActualBuildDate() -> Date? {
        #if DEBUG
        // Try to get build date from executable modification time
        if let executablePath = Bundle.main.executablePath {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: executablePath)
                return attributes[.modificationDate] as? Date
            } catch {
                // Fallback: use Info.plist modification date
                if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
                    do {
                        let infoAttributes = try FileManager.default.attributesOfItem(atPath: infoPath)
                        return infoAttributes[.modificationDate] as? Date
                    } catch {
                        return nil
                    }
                }
            }
        }
        #endif
        return nil
    }

    private var formattedBuildTime: String {
        buildTimestamp
    }

    var body: some View {
        #if DEBUG
        Text("Build: \(formattedBuildTime)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("BuildInfo_Timestamp")
        #else
        EmptyView()
        #endif
    }
}

#Preview {
    BuildInfoView()
        .padding()
        .background(.black)
}
