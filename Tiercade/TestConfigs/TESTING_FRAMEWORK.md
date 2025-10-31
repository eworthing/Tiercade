# Unified Prompt Testing Framework

<!-- markdownlint-config: using repo default (line length 120) -->

This directory contains JSON configuration files for the
**UnifiedPromptTester** framework, which consolidates and replaces the old
testing infrastructure (AcceptanceTestSuite, PilotTestRunner,
EnhancedPromptTester).

> Prototype disclaimer
> - These suites are for evaluation and benchmarking only, not production behavior.
> - Queries are intentionally cross-domain; avoid domain-specific prompt tuning.
> - The final product will be re-architected using the winning technique; treat these configs as disposable scaffolding.

## Overview

The unified testing framework provides config-driven, multi-dimensional testing
of Apple Intelligence prompt effectiveness. Tests run across multiple
dimensions:

- **Prompts** × **Queries** × **Decoders** × **Seeds** × **Guided Modes**

Results are aggregated and stratified by:

- **N-bucket** (small ≤25, medium 26-50, large >50)
- **Domain** (food, entertainment, geography, etc.)
- **Decoder** (greedy, topK, topP)

## File Structure

```text
TestConfigs/
├── README.md                    # This file
├── SystemPrompts.json           # 48 system prompts (S01-S36, G0-G11, F2-F3)
├── TestQueries.json             # Test queries with target counts
├── DecodingConfigs.json         # Sampling configurations
└── TestSuites.json              # Predefined test suites
```

## Configuration Files

### SystemPrompts.json

Contains all system prompts used for testing. Each prompt specifies how the model should generate unique lists.

**Schema:**

```json
{
  "prompts": [
    {
      "id": "string",              // Unique identifier (e.g., "S01-UltraSimple")
      "name": "string",            // Display name
      "category": "string",        // Category (baseline, enhanced, etc.)
      "description": "string",     // Human-readable description
      "text": "string",            // Actual prompt text (may contain variables)
      "metadata": {
        "expectedDupRate": "string",    // "low", "medium", "high"
        "recommendedFor": ["string"],   // Use cases
        "requiresVariables": ["string"], // Variables needed (QUERY, DELTA, etc.)
        "source": "string"              // Origin (SystemPromptTester, Enhanced, etc.)
      }
    }
  ]
}
```

**Variables:**
Prompts can contain template variables:

- `{QUERY}` - The user query (e.g., "top 15 fruits")
- `{DELTA}` - Shortfall count for fill operations
- `{AVOID_LIST}` - Items to avoid (for deduplication)
- `{TARGET_COUNT}` - Explicit count target
- `{DOMAIN}` - Query domain hint

**Example:**

```json
{
  "id": "S01-UltraSimple",
  "name": "Ultra Simple Baseline",
  "category": "baseline",
  "description": "Minimal prompt with no uniqueness guidance",
  "text": "Please list {TARGET_COUNT} {QUERY}. Return as JSON array.",
  "metadata": {
    "expectedDupRate": "high",
    "recommendedFor": ["baseline-comparison"],
    "requiresVariables": ["QUERY", "TARGET_COUNT"],
    "source": "SystemPromptTester"
  }
}
```

### TestQueries.json

Contains test queries representing different domains and difficulty levels.

**Schema:**

```json
{
  "queries": [
    {
      "id": "string",              // Unique identifier (e.g., "fruits-15")
      "query": "string",           // User query text
      "targetCount": int | null,   // Target count (null for open-ended)
      "domain": "string",          // Domain (food, entertainment, geography, etc.)
      "difficulty": "string",      // easy, medium, hard
      "metadata": {
        "description": "string",
        "source": "string"
      }
    }
  ]
}
```

**Example:**

```json
{
  "id": "fruits-15",
  "query": "top 15 most popular fruits",
  "targetCount": 15,
  "domain": "food",
  "difficulty": "easy",
  "metadata": {
    "description": "Small, easy query to test basic functionality",
    "source": "AcceptanceTestSuite"
  }
}
```

### DecodingConfigs.json

Contains sampling configurations for model generation.

**Schema:**

```json
{
  "decoders": [
    {
      "id": "string",              // Unique identifier (e.g., "greedy")
      "name": "string",            // Display name
      "description": "string",     // Human-readable description
      "sampling": {
        "mode": "string",          // "greedy", "topK", or "topP"
        "k": int | null,           // For topK mode
        "threshold": float | null  // For topP mode
      },
      "temperature": float,        // 0.0 to 2.0
      "metadata": {
        "recommendedFor": ["string"]
      }
    }
  ]
}
```

**Sampling Modes:**

- **greedy**: Deterministic, always picks highest probability token
- **topK**: Samples from top-K highest probability tokens
- **topP**: Nucleus sampling, samples from tokens with cumulative probability ≥ threshold

**Example:**

```json
{
  "id": "topk50-t08",
  "name": "TopK50-T0.8",
  "description": "Top-K sampling with K=50, temperature 0.8",
  "sampling": {
    "mode": "topK",
    "k": 50,
    "threshold": null
  },
  "temperature": 0.8,
  "metadata": {
    "recommendedFor": ["diversity-testing", "creative-generation"]
  }
}
```

### TestSuites.json

Contains predefined test suites that specify which combinations to test.

**Schema:**

```json
{
  "suites": [
    {
      "id": "string",              // Unique identifier (e.g., "quick-smoke")
      "name": "string",            // Display name
      "description": "string",     // Human-readable description
      "config": {
        "promptIds": ["string"],   // Prompt IDs to test (or ["*"] for all)
        "queryIds": ["string"],    // Query IDs to test (or ["*"] for all)
        "decoderIds": ["string"],  // Decoder IDs to test (or ["*"] for all)
        "seeds": [int],            // Random seeds for reproducibility
        "guidedModes": [bool]      // Test with/without guided JSON schema
      },
      "metadata": {
        "estimatedDuration": "string",
        "totalRuns": int
      }
    }
  ]
}
```

**Wildcards:**
Use `"*"` to include all available items:

```json
{
  "promptIds": ["*"],  // Test all prompts
  "queryIds": ["fruits-15", "us-places-50"],  // Only these queries
  "decoderIds": ["*"]  // All decoders
}
```

**Example:**

```json
{
  "id": "quick-smoke",
  "name": "Quick Smoke Test",
  "description": "Fast validation with 2 prompts × 1 query × 1 decoder",
  "config": {
    "promptIds": ["G0-Minimal", "G2-LightUnique"],
    "queryIds": ["fruits-15"],
    "decoderIds": ["greedy"],
    "seeds": [42],
    "guidedModes": [false]
  },
  "metadata": {
    "estimatedDuration": "< 1 minute",
    "totalRuns": 2
  }
}
```

## Running Tests

### From UI (AI Chat Overlay)

The test button in the AI Chat interface runs predefined suites:

```swift
// In AIChatOverlay+Tests.swift
runUnifiedTestSuite(suiteId: "quick-smoke")
```

### From Code

```swift
import FoundationModels

@MainActor
func runTests() async {
    do {
        let report = try await UnifiedPromptTester.runSuite(
            suiteId: "quick-smoke",
            onProgress: { message in
                print("📊 \(message)")
            }
        )

        print("✅ \(report.suiteName) Complete")
        print("Success rate: \(report.successfulRuns)/\(report.totalRuns)")
    } catch {
        print("❌ Test error: \(error)")
    }
}
```

## Predefined Test Suites

### quick-smoke

**Purpose:** Fast validation (< 1 min)
**Runs:** 2 prompts × 1 query × greedy decoder
**Use for:** Quick sanity check after code changes

### standard-prompt-test

**Purpose:** Standard acceptance testing
**Runs:** 12 baseline prompts × 2 queries × greedy decoder
**Use for:** Validating core prompt variations

### enhanced-pilot

**Purpose:** Enhanced prompt diversity testing
**Runs:** 12 enhanced prompts × 3 queries × 3 decoders × 3 seeds
**Use for:** Comprehensive prompt comparison

### diversity-comparison

**Purpose:** Decoder comparison study
**Runs:** 2 prompts × 2 queries × 5 decoders × 2 seeds
**Use for:** Comparing sampling strategies

### full-acceptance

**Purpose:** Complete test matrix (SLOW)
**Runs:** All prompts × all queries × all decoders × 5 seeds
**Use for:** Comprehensive regression testing

## Adding New Configurations

### Adding a New Prompt

1. Open `SystemPrompts.json`
2. Add to the `prompts` array:

```json
{
  "id": "MY-NewPrompt",
  "name": "My Experimental Prompt",
  "category": "experimental",
  "description": "Tests a new prompting strategy",
  "text": "Generate exactly {TARGET_COUNT} unique items for: {QUERY}\n\nRules:\n1. No duplicates\n2. JSON array only\n\nOutput:",
  "metadata": {
    "expectedDupRate": "low",
    "recommendedFor": ["experimental-testing"],
    "requiresVariables": ["QUERY", "TARGET_COUNT"],
    "source": "Custom"
  }
}
```

### Adding a New Query

1. Open `TestQueries.json`
2. Add to the `queries` array:

```json
{
  "id": "my-query",
  "query": "popular programming languages",
  "targetCount": 30,
  "domain": "technology",
  "difficulty": "medium",
  "metadata": {
    "description": "Tests tech domain generation",
    "source": "Custom"
  }
}
```

### Adding a New Decoder

1. Open `DecodingConfigs.json`
2. Add to the `decoders` array:

```json
{
  "id": "topp98-t10",
  "name": "TopP98-T1.0",
  "description": "High diversity nucleus sampling",
  "sampling": {
    "mode": "topP",
    "k": null,
    "threshold": 0.98
  },
  "temperature": 1.0,
  "metadata": {
    "recommendedFor": ["creative-generation"]
  }
}
```

### Creating a Custom Test Suite

1. Open `TestSuites.json`
2. Add to the `suites` array:

```json
{
  "id": "my-custom-suite",
  "name": "My Custom Test Suite",
  "description": "Tests my new configurations",
  "config": {
    "promptIds": ["MY-NewPrompt", "G0-Minimal"],
    "queryIds": ["my-query"],
    "decoderIds": ["topp98-t10", "greedy"],
    "seeds": [42, 123],
    "guidedModes": [false, true]
  },
  "metadata": {
    "estimatedDuration": "~5 minutes",
    "totalRuns": 8
  }
}
```

1. Run your suite:

```swift
runUnifiedTestSuite(suiteId: "my-custom-suite")
```

## Migration from Old Testers

### From AcceptanceTestSuite

**Old:**

```swift
let report = try await AcceptanceTestSuite.runAll { print($0) }
```

**New:**

```swift
let report = try await UnifiedPromptTester.runSuite(
    suiteId: "standard-prompt-test",
    onProgress: { print($0) }
)
```

**Prompts migrated:** S01-S36 baseline prompts
**Location:** `SystemPrompts.json` under `category: "baseline"`

### From PilotTestRunner

**Old:**

```swift
let runner = PilotTestRunner { print($0) }
let report = await runner.runPilot()
```

**New:**

```swift
let report = try await UnifiedPromptTester.runSuite(
    suiteId: "enhanced-pilot",
    onProgress: { print($0) }
)
```

**Configuration migrated:**

- Sizes (15, 50, 150) → queries with varying targetCount
- Decoders → `DecodingConfigs.json`
- Seeds → defined in test suite config

### From EnhancedPromptTester

**Old:**

```swift
let results = await EnhancedPromptTester.testPrompts(
    config: TestConfig(),
    onProgress: { print($0) }
)
```

**New:**

```swift
let report = try await UnifiedPromptTester.runSuite(
    suiteId: "diversity-comparison",
    onProgress: { print($0) }
)
```

**Prompts migrated:** G0-G11, F2-F3 enhanced prompts
**Location:** `SystemPrompts.json` under `category: "enhanced-baseline"` and `category: "enhanced-fill"`

## Test Results

### Output Format

Test reports are saved to `/tmp/tiercade_unified_test_report.json` with structure:

```json
{
  "id": "uuid",
  "timestamp": "iso8601",
  "suiteId": "quick-smoke",
  "suiteName": "Quick Smoke Test",
  "totalRuns": 2,
  "successfulRuns": 2,
  "failedRuns": 0,
  "totalDuration": 45.2,
  "environment": {
    "osVersion": "26.0",
    "hasTopP": true,
    "device": "Apple TV 4K (3rd gen)"
  },
  "aggregateResults": [...],
  "allResults": [...],
  "rankings": {
    "byPassRate": [...],
    "byQuality": [...],
    "bySpeed": [...],
    "byConsistency": [...]
  }
}
```

### Key Metrics

**Per-run metrics:**

- `passAtN`: Did we generate N unique items?
- `dupRate`: Duplicate rate (0.0 = perfect uniqueness)
- `jsonStrict`: Parsed as JSON without fallback?
- `qualityScore`: Combined quality metric (0.0 to 1.0)
- `timePerUnique`: Seconds per unique item generated

**Aggregate metrics:**

- `passAtNRate`: Success rate across all runs
- `meanDupRate`: Average duplicate rate
- `stdevDupRate`: Consistency of deduplication
- `jsonStrictRate`: JSON compliance rate
- `seedVariance`: Consistency across different seeds

**Stratification:**

- Results grouped by N-bucket (small/medium/large)
- Results grouped by domain (food/entertainment/etc.)
- Results grouped by decoder (greedy/topK/topP)

## Validation

All configuration files are validated at load time:

**SystemPrompts:**

- Non-empty `id`, `text`
- Variables documented in metadata
- No duplicate IDs

**TestQueries:**

- Non-empty `id`, `query`
- Valid `targetCount` (1-500 or null)
- No duplicate IDs

**DecodingConfigs:**

- Valid sampling mode (greedy/topK/topP)
- Temperature in range [0.0, 2.0]
- topK requires positive `k`
- topP requires threshold in (0.0, 1.0]
- No duplicate IDs

**TestSuites:**

- At least one prompt, query, decoder, seed, guided mode
- All referenced IDs must exist
- No duplicate suite IDs

## Troubleshooting

### "Configuration not found" error

**Problem:** Suite references non-existent prompt/query/decoder ID

**Solution:** Check spelling of IDs in `TestSuites.json` against the source files

### "Missing required variable" error

**Problem:** Prompt template uses `{QUERY}` but variable not provided

**Solution:** Ensure prompt's `requiresVariables` metadata matches template

### Tests timing out

**Problem:** Large test matrix (e.g., full-acceptance) takes too long

**Solution:** Use smaller suite (quick-smoke, standard-prompt-test) or reduce seeds/decoders

### Model unavailable error

**Problem:** Apple Intelligence not enabled or FoundationModels framework missing

**Solution:**

1. Ensure running on iOS/macOS 26+
2. Enable Apple Intelligence in System Settings
3. Verify DEBUG build includes FoundationModels

## Best Practices

1. **Start small:** Use `quick-smoke` during development
2. **Incremental testing:** Add one prompt at a time and validate
3. **Seed consistency:** Use fixed seeds (42, 123, 456) for reproducibility
4. **Domain coverage:** Test multiple domains (food, entertainment, geography)
5. **Decoder diversity:** Compare greedy vs topK vs topP performance
6. **Version control:** Commit configuration changes with meaningful messages
7. **Documentation:** Update prompt descriptions when modifying behavior

## Configuration Tips

### Prompt Design

- **Baseline prompts (S01-S36):** Minimal instructions, test basic capability
- **Enhanced prompts (G0-G11):** Add uniqueness constraints and format guidance
- **Fill prompts (F2-F3):** Specialized for backfill operations with avoid lists

### Query Selection

- **Easy (N≤25):** Common domains (fruits, colors, countries)
- **Medium (N=26-50):** Moderate specificity (US states, programming languages)
- **Hard (N>50):** Challenging specificity (animated series, video games)

### Decoder Tuning

- **greedy:** Reproducible baseline, low diversity
- **topK (K=40-50, T=0.7-0.8):** Balanced diversity and quality
- **topP (P=0.92-0.95, T=0.8-0.9):** High diversity, creative generation

## Performance Notes

**Approximate run times (Apple TV 4K, 3rd gen):**

- quick-smoke: < 1 minute (2 runs)
- standard-prompt-test: ~5 minutes (24 runs)
- enhanced-pilot: ~30 minutes (324 runs)
- diversity-comparison: ~10 minutes (80 runs)
- full-acceptance: ~2 hours (2,400 runs)

**Memory usage:**

- Per run: ~50-100 MB
- Full report: ~5-10 MB JSON

**Disk usage:**

- Configuration files: ~200 KB
- Test report: ~5-10 MB per suite

## Future Enhancements

Planned improvements:

- [ ] Web-based configuration editor
- [ ] Real-time test progress visualization
- [ ] Automated prompt regression detection
- [ ] Multi-device distributed testing
- [ ] Historical trend analysis
- [ ] Prompt mutation and evolution
- [ ] A/B testing framework
- [ ] Custom validation rules per query

## Contributing

When adding new configurations:

1. Follow existing naming conventions (S## for baseline, G## for enhanced, etc.)
2. Provide detailed descriptions and metadata
3. Test your configuration with quick-smoke first
4. Document any special requirements or dependencies
5. Include estimated run times for custom suites
6. Validate JSON syntax before committing

## References

- **Main framework:** `AppleIntelligence+UnifiedPromptTester.swift`
- **Models:** `AppleIntelligence+UnifiedPromptTester+*Models.swift`
- **Validation:** `AppleIntelligence+UnifiedPromptTester+Validation.swift`
- **Integration:** `AIChatOverlay+Tests.swift`

## Support

For issues or questions:

1. Check deprecated testers for migration examples
2. Review test report JSON for detailed error messages
3. Validate configuration files for syntax errors
4. Consult `AppleIntelligence+UnifiedPromptTester+Validation.swift` for validation rules
