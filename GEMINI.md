# GEMINI.md — MeowClash

**Read `AGENTS.md` first** for all general rules, project context, tech stack, directory structure, and coding standards. This file contains ONLY Gemini-specific instructions.

---

## Context Window Optimization

### Large Codebase Handling
- Leverage Gemini's long context window for comprehensive code analysis across the entire `lib/` tree.
- Process multiple files in single context when comparing patterns (e.g., all provider files, all model files).
- Prioritize relevant sections in very large files like `lib/common/` (47 files) and `lib/widgets/` (39 files).

### Structured Context
- Use clear section headers for organized analysis.
- Reference file paths consistently: `lib/views/dashboard/dashboard.dart:42`.
- Group related code snippets for clarity when analyzing feature modules.

## Multimodal Capabilities

### Visual Analysis
- Can analyze screenshots, diagrams, and UI mockups for Flutter widget work.
- Can process PDFs and document formats for subscription/config analysis.
- Use visual context when available for UI layout and theming tasks.

### Code Visualization
- Can generate and analyze code flow diagrams for the Go↔Dart FFI bridge.
- Can understand ASCII art and text-based diagrams of the build pipeline.

## Output Formatting

### Code Responses
- Use markdown code blocks with language specification (`dart`, `go`, `nix`).
- Include file path and line numbers: `lib/providers/state.dart:15`.
- Format complex data structures (freezed models, Riverpod providers) clearly.

### Structured Analysis
- Use tables for comparative analysis (e.g., before/after refactors).
- Use lists for step-by-step build instructions.
- Use headers for organized sections across large responses.

## Long Context Best Practices

### When Working with Large Files
- Focus on relevant sections first (e.g., specific methods in `setup.dart:841`).
- Use search/grep to locate specific code before reading entire files.
- Provide context for code references across file boundaries.

### When Analyzing Codebases
- Process directory structure systematically starting from `lib/`.
- Identify patterns across multiple files (barrel file exports, provider conventions).
- Synthesize findings into actionable insights for the Flutter+Go architecture.

### When Generating Code
- Maintain consistency with existing patterns in `lib/providers/` and `lib/models/`.
- Reference existing implementations before creating new ones.
- Follow established conventions for Riverpod code-gen and freezed models exactly.

## Constraints

- Do NOT duplicate rules from AGENTS.md.
- Focus only on Gemini-specific behaviors.
- Keep instructions concise and actionable.
- Reference AGENTS.md for general project rules.
