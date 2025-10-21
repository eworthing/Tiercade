import Foundation
import Testing
@testable import TiercadeCore

@Suite("CSV Import concurrency")
struct CSVImporterConcurrencyTests {
    @Test("Parsing a large CSV on a background executor keeps the MainActor responsive")
    func parseLargeCSVOffMainActor() async throws {
        let rowCount = 25_000
        let csv = Self.makeCSV(rowCount: rowCount)
        let clock = ContinuousClock()

        let (blockingDuration, blockingCount) = try await measureResponsiveness(
            parser: { csv in
                try CSVImporter.parse(csv)
            },
            csv: csv,
            clock: clock
        )

        let (nonBlockingDuration, nonBlockingCount) = try await measureResponsiveness(
            parser: { csv in
                try await CSVImporter.parseInBackground(csv)
            },
            csv: csv,
            clock: clock
        )

        #expect(blockingCount == rowCount)
        #expect(nonBlockingCount == rowCount)
        #expect(blockingDuration > nonBlockingDuration * 2)
        #expect(nonBlockingDuration < .milliseconds(80))
    }
}

private extension CSVImporterConcurrencyTests {
    func measureResponsiveness(
        parser: @escaping (String) async throws -> Items,
        csv: String,
        clock: ContinuousClock
    ) async throws -> (Duration, Int) {
        let recorder = DurationRecorder()
        let parseTask = Task { @MainActor in
            try await parser(csv)
        }

        // Allow the parser task to start before queuing the ping on the MainActor.
        try await Task.sleep(for: .milliseconds(5))

        let requestTime = clock.now
        let pingTask = Task { @MainActor in
            await recorder.record(clock.now - requestTime)
        }

        let items = try await parseTask.value
        await pingTask.value
        let duration = await recorder.first() ?? .zero
        let itemCount = items.values.reduce(into: 0) { partialResult, list in
            partialResult += list.count
        }
        return (duration, itemCount)
    }

    static func makeCSV(rowCount: Int) -> String {
        var rows = ["name,season,tier"]
        let tiers = ["S", "A", "B", "C", "D", "F", "unranked"]
        rows.reserveCapacity(rowCount + 1)

        for index in 0..<rowCount {
            let tier = tiers[index % tiers.count]
            rows.append("Item \(index),Season \(index % 10),\(tier)")
        }

        return rows.joined(separator: "\n")
    }
}

private actor DurationRecorder {
    private var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }

    func first() -> Duration? {
        durations.first
    }
}
