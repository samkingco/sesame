---
name: codex
description: Consult OpenAI Codex CLI for a second opinion. Use when stuck on an approach, want to verify a decision, or the user says "verify with codex" / "ask codex". Also self-invoke when genuinely stuck or uncertain about a technical approach.
user_invocable: true
argument-hint: <question or topic to verify>
---

# /codex — Second Opinion

Consult OpenAI Codex (via `codex exec`) for an independent perspective.

## When to use

- **User-triggered**: user says "verify with codex", "ask codex", or `/codex <question>`
- **Self-triggered**: you are genuinely stuck, uncertain about a platform API, or want to validate an approach before committing to it

## How to call

Use `codex exec` in read-only sandbox mode. Always pass context about what we're working on.

```bash
codex exec "CONTEXT: [brief project/file context]. QUESTION: [specific question]" 2>&1
```

### Rules

- **Be specific** — don't ask vague questions. Include the relevant types, method signatures, or error messages.
- **Include constraints** — mention the platform (macOS 14+, Swift, AppKit, Astro, etc.) and any decisions already made.
- **Strip the header** — the first ~10 lines of output are metadata. The actual response follows after the `codex` line.
- **Don't blindly trust it** — Codex is a second opinion, not an oracle. Evaluate its answer against what you know. If it contradicts verified facts, trust the verified facts.
- **Report back** — always show the user what Codex said and your assessment of whether it's correct/useful.

## If user-triggered with $ARGUMENTS

Frame the question from `$ARGUMENTS` with relevant context from the current conversation, then call Codex.

## If user-triggered without arguments

Ask: "What should I ask Codex about?" One question. Wait.

## If self-triggered

1. State to the user: "I'm uncertain about [topic] — consulting Codex for a second opinion."
2. Call Codex with a focused question.
3. Present the response and your evaluation.

## Output format

```
## Codex says

[Codex's response, trimmed of metadata]

## My assessment

[Whether you agree, disagree, or want to investigate further. Note any conflicts with verified facts.]
```
