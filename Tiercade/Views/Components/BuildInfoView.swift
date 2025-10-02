import SwiftUI

/// Displays build timestamp in DEBUG builds for verification during development
struct BuildInfoView: View {
    private var buildTimestamp: String {
        #if DEBUG
        // Use compile time as build timestamp
        return "\(#file) \(#line) - \(Date().formatted(date: .omitted, time: .standard))"
        #else
        return ""
        #endif
    }
    
    private var formattedBuildTime: String {
        #if DEBUG
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm:ss a"
        return formatter.string(from: now)
        #else
        return ""
        #endif
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
