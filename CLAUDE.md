# CLAUDE.md — MeowClash

**Read `AGENTS.md` first** for all general rules, project context, tech stack, directory structure, and coding standards. This file contains ONLY Claude-specific instructions.

---

## Thinking and Reasoning

### XML Tag Usage
Use XML tags for structured reasoning and output formatting:

```xml
<analysis>
[Your analysis of the problem]
</analysis>

<plan>
[Step-by-step plan]
</plan>

<implementation>
[Code changes]
</implementation>

<verification>
[How you verified the solution]
</verification>
```

### Chain of Thought
- Break complex problems into explicit thinking steps before implementing.
- Show reasoning before implementing solutions, especially for Go↔Dart FFI bridge work.
- Use `<thinking>` tags for internal reasoning when analyzing `core/` or `setup.dart`.

### Structured Output
- Use XML tags to organize complex responses.
- Wrap code blocks with language specification (`dart`, `go`, `nix`, `rust`).
- Use `<code>` tags for inline code references: `<code>lib/controller.dart:712</code>`.

## Tool Usage Patterns

### File Operations
- Always read a file before editing it — especially critical for generated files (`*.g.dart`, `*.freezed.dart`).
- Use parallel reads when examining multiple provider or model files.
- Verify changes after editing by running `flutter analyze`.

### Search and Discovery
- Use grep/glob tools to find patterns before editing (e.g., find all usages of `commonPrint` before replacing).
- Search for existing implementations before creating new ones — check `lib/common/` first (47 utility files).
- Check for similar code patterns in `lib/providers/` and `lib/views/` before adding new ones.

### Bash Commands
- Run `flutter analyze` after every Dart change.
- Run `dart run build_runner build --delete-conflicting-outputs` after model/provider changes.
- Run `flutter test` to verify no regressions.
- Run `nix flake check` after Nix-related changes.

## Output Formatting

### Code Responses
- Match existing Dart code style exactly (see `analysis_options.yaml` for strict lint rules).
- Include file path and line numbers for references: `lib/views/dashboard/dashboard.dart:42`.
- Use backticks for inline code: `SubscriptionCrypto.decryptBase64`.

### Explanations
- Be concise and direct — match the compact style of AGENTS.md.
- Provide actionable guidance with specific file paths.
- Reference specific files and line numbers for context.

### Error Handling
- Explain what went wrong with file paths and line numbers.
- Suggest specific fixes referencing existing patterns.
- Include relevant code context from the codebase.

## Proactive Behaviors

### Code Quality
- Suggest improvements when you notice them in `lib/common/` or `lib/widgets/`.
- Flag potential issues before they become problems (especially around generated code).
- Recommend test cases for new crypto or subscription logic.

### Documentation
- Suggest updating AGENTS.md when code changes affect architecture.
- Flag outdated documentation references.
- Note when `core/constant/version.go` version changes need propagation.

## Constraints

- Do NOT duplicate rules from AGENTS.md.
- Focus only on Claude-specific behaviors.
- Keep instructions concise and actionable.
- Reference AGENTS.md for general project rules.
