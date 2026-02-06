---
name: doc-search
description: |
  Search technology documentation for the project's tech stack. Provides
  instructions for looking up API references, framework docs, and best practices.
user-invocable: false
---

# Documentation Search

When you need to look up technical documentation for the project's stack:

## 1. Check Project Configuration

Read `.claude-beads/config.yml` to find the configured tech stack. The `stack` section lists technologies with their official documentation URLs:

```yaml
stack:
  - name: <technology>
    docs: <official docs URL>
    examples: <example repo URL>  # optional
```

## 2. Search Strategy

For each technology question:

1. **Start with official docs**: Use `WebFetch` on the `docs` URL from the config to find the relevant page.
2. **Search for specifics**: Use `WebSearch` with targeted queries like `"<technology> <specific API or concept>"`.
3. **Check examples**: If the config includes an `examples` URL, fetch relevant example code.
4. **Verify versions**: Ensure the documentation matches the version used in the project (check `package.json`, `go.mod`, `Cargo.toml`, etc.).

## 3. When to Search

- Before making technology decisions in architecture
- When implementing unfamiliar APIs or patterns
- When a test framework or build tool has specific conventions
- When the existing codebase uses a pattern you're unsure about

## 4. How to Report Findings

When you find relevant documentation:
- Summarize the key points concisely
- Include the specific API signatures or code patterns needed
- Note any caveats, deprecations, or version-specific behavior
- Do NOT paste entire documentation pages — extract only what's needed
