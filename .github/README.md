# GitHub Configuration

This directory contains GitHub-specific configuration files.

## copilot-instructions.md

**Type**: Symlink → `../AGENTS.md`

This is a **symlink** pointing to the project's AI agent playbook (`AGENTS.md`)
to provide instructions for GitHub Copilot and other AI coding assistants.

### ⚠️ Important

- **Do NOT delete this symlink** - It provides AI assistants with project context
- **Do NOT create a separate file** - Edit `AGENTS.md` instead
- **The source file is**: [`../AGENTS.md`](../AGENTS.md)

### Symlink Structure

```text
AGENTS.md (root)                         ← SOURCE file (edit this!)
├── CLAUDE.md                            ← Symlink for Claude Code
└── .github/copilot-instructions.md      ← Symlink for GitHub Copilot
```

All changes to AI instructions should be made in `AGENTS.md`.
The symlinks ensure that different AI assistants can find the instructions in
their expected locations.

## Why Symlinks?

Different AI coding assistants look for instructions in different locations:

- **Claude Code** looks for `CLAUDE.md` in the project root
- **GitHub Copilot** looks for `copilot-instructions.md` in `.github/`

Using symlinks ensures we maintain a single source of truth while supporting multiple AI assistants.
