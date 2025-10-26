import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Aggregate Computation

@available(iOS 26.0, macOS 26.0, *)
extension EnhancedPromptTester {
private static func computeAggregate(
    config: TestConfig,
    promptNumber: Int,
    promptName: String,
    promptText: String,
    runs: [SingleRunResult]
) -> AggregateResult {
    let domain = runs.first?.domain ?? "unknown"
    let nBucket = runs.first?.nBucket ?? "unknown"

    let metrics = calculateAggregateMetrics(runs: runs)
    let (bestRun, worstRun) = findBestAndWorstRuns(runs: runs)

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

private struct AggregateMetrics {
    let passAtNRate: Double
    let jsonStrictRate: Double
    let meanUniqueItems: Double
    let meanTimePerUnique: Double
    let meanDupRate: Double
    let stdevDupRate: Double
    let meanSurplusAtN: Double
    let truncationRate: Double
    let seedVariance: Double
    let insufficientRate: Double
    let formatErrorRate: Double
}

private static func calculateAggregateMetrics(runs: [SingleRunResult]) -> AggregateMetrics {
    let passAtNCount = runs.filter { $0.passAtN }.count
    let passAtNRate = Double(passAtNCount) / Double(runs.count)

    let jsonStrictCount = runs.filter { $0.jsonStrict }.count
    let jsonStrictRate = Double(jsonStrictCount) / Double(runs.count)

    let meanUniqueItems = runs.map { Double($0.uniqueItems) }.reduce(0, +) / Double(runs.count)
    let meanTimePerUnique = runs.map { $0.timePerUnique }.reduce(0, +) / Double(runs.count)

    let (meanDupRate, stdevDupRate) = calculateDupRateStats(runs: runs)
    let meanSurplusAtN = runs.map { Double($0.surplusAtN) }.reduce(0, +) / Double(runs.count)

    let truncationCount = runs.filter { $0.wasTruncated }.count
    let truncationRate = Double(truncationCount) / Double(runs.count)

    let seedVariance = calculateSeedVariance(runs: runs)

    let insufficientCount = runs.filter { $0.insufficient }.count
    let insufficientRate = Double(insufficientCount) / Double(runs.count)

    let formatErrorCount = runs.filter { $0.formatError }.count
    let formatErrorRate = Double(formatErrorCount) / Double(runs.count)

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

private static func calculateDupRateStats(runs: [SingleRunResult]) -> (mean: Double, stdev: Double) {
    let dupRates = runs.map { $0.dupRate }
    let meanDupRate = dupRates.reduce(0, +) / Double(runs.count)
    let variance = dupRates.map { pow($0 - meanDupRate, 2) }.reduce(0, +) / Double(runs.count)
    let stdevDupRate = sqrt(variance)
    return (meanDupRate, stdevDupRate)
}

private static func calculateSeedVariance(runs: [SingleRunResult]) -> Double {
    let uniqueByRun = runs.map { $0.uniqueItems }
    let meanUnique = uniqueByRun.reduce(0, +) / uniqueByRun.count
    let varianceSum = uniqueByRun.map { pow(Double($0 - meanUnique), 2) }.reduce(0, +)
    let seedVarianceVal = varianceSum / Double(uniqueByRun.count)
    return sqrt(seedVarianceVal)
}

private static func findBestAndWorstRuns(runs: [SingleRunResult])
    -> (best: SingleRunResult?, worst: SingleRunResult?) {
    let bestRun = runs.max { lhs, rhs in
        if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
        if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
        if lhs.formatError != rhs.formatError { return lhs.formatError }
        return lhs.dupRate > rhs.dupRate
    }
    let worstRun = runs.min { lhs, rhs in
        if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
        if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
        if lhs.formatError != rhs.formatError { return lhs.formatError }
        return lhs.dupRate > rhs.dupRate
    }
    return (bestRun, worstRun)
}
}
#endif
