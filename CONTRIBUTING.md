# Contributing

## Commit style
- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`
- Group related changes per feature. Keep app vs. core changes in separate commits when feasible.
- Write concise, present-tense messages. Include scope when helpful, e.g., `feat(app): toolbar with undo/redo`.

## Branching
- `main`: stable, shippable.
- Feature work on short-lived branches: `feat/<area>-<short-name>`; PR into `main`.

## Code quality
- Swift: build and run unit tests (`swift test`) in `TiercadeCore` before pushing.
- iOS/tvOS app: build for iPhone and Apple TV simulators.
- Keep views platform-agnostic; use `#if os(...)` for platform specifics.

Tip: from the repo root, run `cd TiercadeCore && swift test` to validate the core package.

## Git hygiene
- Don’t commit build artifacts, DerivedData, or .DS_Store.
- Avoid embedding nested git repositories; use submodules if intentional.

## Reviews
- Prefer small PRs with clear descriptions and screenshots/GIFs for UI changes.
