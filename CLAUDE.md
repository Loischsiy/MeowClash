# CLAUDE.md

This file intentionally contains no rules of its own.

**`AGENTS.md` in the repository root is the single source of truth.** It is a short router:
the always-on rules live there, and each topic (project structure, build, core version, Nix,
codegen/lint, testing, CI/release, platform gotchas, iOS runtime, runtime contracts, fork
history) has a guide in `.agents/` listed in its file-routing table. The documentation policy
lives there too (no `docs/` folder: agent notes go in `AGENTS.md` or `.agents/`, user-facing
docs go in the six READMEs). Read it first, and update it or the matching `.agents/` guide
instead of adding rules here — duplicated rule files always drift apart.
