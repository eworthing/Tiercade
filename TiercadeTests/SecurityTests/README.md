# Security Test Suite

Comprehensive security tests validating mitigations for OWASP-class vulnerabilities.

## Test Coverage

### URLValidationTests.swift (18 tests)

**Security Domain**: SSRF Prevention (S-H1)

- HTTPS-only validation for media URLs and external links
- Rejects file://, ftp://, http://, javascript:, data:, and custom schemes
- Case-insensitive scheme validation
- Convenience method testing

### PathTraversalTests.swift (6 tests)

**Security Domain**: Path Traversal Prevention (S-H2)

- Rejects .. sequences and ./ followed by ..
- Blocks absolute paths outside bundle
- Validates bundle-relative path resolution
- Tests URL-encoded traversal attempts (%2E%2E)

### CSVInjectionTests.swift (10 tests)

**Security Domain**: CSV Injection Prevention (S-H5)

- Sanitizes formula injection (=, +, -, @)
- Tests CSV parsing with escaped quotes
- Handles empty fields and quoted content with commas
- Validates duplicate ID prevention (placeholder tests)

### PromptInjectionTests.swift (18 tests)

**Security Domain**: AI Prompt Injection Prevention (S-H6)

- Control character removal (null bytes, Unicode controls)
- Excessive punctuation limiting (!!!, ..., ???)
- Length truncation (500 char limit)
- Whitespace normalization
- Real-world attack vector handling (jailbreaks, context manipulation)

## Test Framework

Uses Swift Testing framework (@Test, @Suite, #expect) following Swift 6 patterns.

## Setup Required

⚠️ **Note**: These tests require a TiercadeTests unit test target to be created in Xcode.

**To enable these tests:**

1. Open Tiercade.xcodeproj in Xcode
2. Create a new Unit Test Target named "TiercadeTests"
3. Add all `.swift` files from `TiercadeTests/SecurityTests/` to the target
4. Add `@testable import Tiercade` to access internal types
5. Run tests via: `xcodebuild test -scheme Tiercade -only-testing:TiercadeTests`

**Current Status**: Test files exist as specifications but are not yet integrated into the Xcode build system.

## Implementation Status

All security implementations tested here are **already deployed**:

- ✅ URLValidator (Tiercade/Util/URLValidator.swift)
- ✅ Path traversal guards (AppState+Persistence.swift)
- ✅ CSV sanitization (AppState+Export.swift, AppState+Import.swift)
- ✅ Prompt validation (Tiercade/Util/PromptValidator.swift)

These tests validate existing security controls and should be integrated into CI/CD once the test target is created.
