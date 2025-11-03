import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Aggregate Computation

@available(iOS 26.0, macOS 26.0, *)
internal extension EnhancedPromptTester {
static func computeAggregate(
    config: TestConfig,
    promptNumber: Int,
    promptName: String,
    promptText: String,
    runs: [SingleRunResult]
) -> AggregateResult {
    internal let domain = runs.first?.domain ?? "unknown"
    internal let nBucket = runs.first?.nBucket ?? "unknown"

    internal let metrics = calculateAggregateMetrics(runs: runs)
    internal let (bestRun, worstRun) = findBestAndWorstRuns(runs: runs)

    return AggregateResult(
        promptNumber: promptNumber,
        promptName: promptName,
        promptText: promptText,
        totalRuns: runs.count,
        nBucket: nBucket,
        domain: domain,
        passAtNRate: metrics.passAtNRate,
        meanUniqueItems: metrics.meanUniqueItems,
        jsonStrictRate: metrics.jsonStrictRate,
        meanTimePerUnique: metrics.meanTimePerUnique,
        meanDupRate: metrics.meanDupRate,
        stdevDupRate: metrics.stdevDupRate,
        meanSurplusAtN: metrics.meanSurplusAtN,
        truncationRate: metrics.truncationRate,
        seedVariance: metrics.seedVariance,
        insufficientRate: metrics.insufficientRate,
        formatErrorRate: metrics.formatErrorRate,
        bestRun: bestRun,
        worstRun: worstRun,
        allRuns: runs
    )
}

internal struct AggregateMetrics {
    internal let passAtNRate: Double
    internal let jsonStrictRate: Double
    internal let meanUniqueItems: Double
    internal let meanTimePerUnique: Double
    internal let meanDupRate: Double
    internal let stdevDupRate: Double
    internal let meanSurplusAtN: Double
    internal let truncationRate: Double
    internal let seedVariance: Double
    internal let insufficientRate: Double
    internal let formatErrorRate: Double
}

static func calculateAggregateMetrics(runs: [SingleRunResult]) -> AggregateMetrics {
    internal let passAtNCount = runs.filter { $0.passAtN }.count
    internal let passAtNRate = Double(passAtNCount) / Double(runs.count)

    internal let jsonStrictCount = runs.filter { $0.jsonStrict }.count
    internal let jsonStrictRate = Double(jsonStrictCount) / Double(runs.count)

    internal let meanUniqueItems = runs.map { Double($0.uniqueItems) }.reduce(0, +) / Double(runs.count)
    internal let meanTimePerUnique = runs.map { $0.timePerUnique }.reduce(0, +) / Double(runs.count)

    internal let (meanDupRate, stdevDupRate) = calculateDupRateStats(runs: runs)
    internal let meanSurplusAtN = runs.map { Double($0.surplusAtN) }.reduce(0, +) / Double(runs.count)

    internal let truncationCount = runs.filter { $0.wasTruncated }.count
    internal let truncationRate = Double(truncationCount) / Double(runs.count)

    internal let seedVariance = calculateSeedVariance(runs: runs)

    internal let insufficientCount = runs.filter { $0.insufficient }.count
    internal let insufficientRate = Double(insufficientCount) / Double(runs.count)

    internal let formatErrorCount = runs.filter { $0.formatError }.count
    internal let formatErrorRate = Double(formatErrorCount) / Double(runs.count)

    return AggregateMetrics(
        passAtNRate: passAtNRate,
        jsonStrictRate: jsonStrictRate,
        meanUniqueItems: meanUniqueItems,
        meanTimePerUnique: meanTimePerUnique,
        meanDupRate: meanDupRate,
        stdevDupRate: stdevDupRate,
        meanSurplusAtN: meanSurplusAtN,
        truncationRate: truncationRate,
        seedVariance: seedVariance,
        insufficientRate: insufficientRate,
        formatErrorRate: formatErrorRate
    )
}

static func calculateDupRateStats(runs: [SingleRunResult]) -> (mean: Double, stdev: Double) {
    internal let dupRates = runs.map { $0.dupRate }
    internal let meanDupRate = dupRates.reduce(0, +) / Double(runs.count)
    internal let variance = dupRates.map { pow($0 - meanDupRate, 2) }.reduce(0, +) / Double(runs.count)
    internal let stdevDupRate = sqrt(variance)
    return (meanDupRate, stdevDupRate)
}

static func calculateSeedVariance(runs: [SingleRunResult]) -> Double {
    internal let uniqueByRun = runs.map { $0.uniqueItems }
    internal let meanUnique = uniqueByRun.reduce(0, +) / uniqueByRun.count
    internal let varianceSum = uniqueByRun.map { pow(Double($0 - meanUnique), 2) }.reduce(0, +)
    internal let seedVarianceVal = varianceSum / Double(uniqueByRun.count)
    return sqrt(seedVarianceVal)
}

static func findBestAndWorstRuns(runs: [SingleRunResult])
    -> (best: SingleRunResult?, worst: SingleRunResult?) {
    internal let bestRun = runs.max { lhs, rhs in
        if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
        if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
        if lhs.formatError != rhs.formatError { return lhs.formatError }
        return lhs.dupRate > rhs.dupRate
    }
    internal let worstRun = runs.min { lhs, rhs in
        if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
        if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
        if lhs.formatError != rhs.formatError { return lhs.formatError }
        return lhs.dupRate > rhs.dupRate
    }
    return (bestRun, worstRun)
}
}
#endif
