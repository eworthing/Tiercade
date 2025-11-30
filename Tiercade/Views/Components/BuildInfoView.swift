import SwiftUI

/// Displays build timestamp in DEBUG builds for verification during development
struct BuildInfoView: View {

    // MARK: Internal

    var body: some View {
        #if DEBUG
        Text("Build: \(formattedBuildTime)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .tvGlassCapsule()
            .opacity(0.8)
            .accessibilityIdentifier("BuildInfo_Timestamp")
        #else
        EmptyView()
        #endif
    }

    // MARK: Private

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

    private var formattedBuildTime: String {
        buildTimestamp
    }

    private func getActualBuildDate() -> Date? {
        #if DEBUG
        // Prefer Info.plist so the timestamp matches the build script's output
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
            if
                let attributes = try? FileManager.default.attributesOfItem(atPath: infoPath),
                let infoDate = attributes[.modificationDate] as? Date
            {
                return infoDate
            }
        }

        // Fallback: use the executable modification time
        if let executablePath = Bundle.main.executablePath {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: executablePath)
                return attributes[.modificationDate] as? Date
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

}

#Preview {
    BuildInfoView()
        .padding()
        .background(.black)
}
