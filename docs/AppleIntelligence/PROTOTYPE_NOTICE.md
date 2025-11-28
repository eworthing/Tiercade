# Apple Intelligence Prototype Notice

Status: Prototype-only (testing and evaluation)

Purpose

- Evaluate general-purpose techniques to get strong, unique tier list items out of the small on-device Apple Intelligence model.
- Keep prompts and methods domain-agnostic; end-user queries can request any list type.
- Identify a winning approach to re-architect around for the final product.

Non-Goals

- Shipping these exact flows, prompts, or testers to production.
- Domain-specific prompt tuning that narrows applicability to a single category.

Guidance

- Treat current code as disposable scaffolding for experiments.
- Keep feature flags and platform gating intact (macOS/iOS only; DEBUG by default).
- Prefer adding tests, diagnostics, and documentation over deeper coupling with production UI/state.

Next Steps

- When a best-performing strategy is established, design a production-grade architecture and migrate only the minimal, validated pieces.
