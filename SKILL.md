---
name: camus-sh
description: Apply the Camus.sh profile — a restricted shell scripting profile based on the Camus Method. Use this skill whenever the user asks to write, review, or certify shell scripts under the Camus.sh specification. The skill guides AI agents through the Lexicon, Grammar, and Certification phases for shell context.
---

# Camus.sh Agent Skill

This skill implements the **Camus.sh specification** (see `specification.md`).
It applies the three Camus Method phases to shell scripting with the
restrictions and block conventions defined by the profile.

## The Workflow

```
1. Define the Lexicon (terms the script manipulates)
2. Write the script following Camus.sh Grammar rules
3. Review and verify compliance
4. Sign and certify (future: kiss.sh sign)
```

---

## Phase 1: Lexicon

The Lexicon defines **what** the script manipulates. Terms are declared
either in a `LEXICON.md` at the project root or inline via the
`## CAMUS-LEXICON` block at the top of the script.

### Inline Lexicon

When a script is standalone or needs only a few terms:

```sh
#!/bin/bash

## CAMUS-LEXICON
# <term>: <definition>
## CAMUS-END
```

### Project Lexicon

For larger projects, use the LEXICON.md format defined by the
generic [Camus Method skill](https://github.com/Camus-Project/Skill).
If a `LEXICON.md` exists at the project root, the inline
`## CAMUS-LEXICON` block MAY be omitted.

### Interaction with AI

- Reference terms from the Lexicon explicitly in prompts
- Ask the AI to explain how it maps each term to script functions
- Verify that new code introduces only defined terms

---

## Phase 2: Grammar

Shell scripts written under Camus.sh MUST respect the following
rules, derived from the specification.

### Core Rules (Must Follow)

1. **Function Declaration** — Use `name() { ... }` syntax only.
   The `function` keyword is prohibited.

2. **Entry Point** — Every script MUST define a `main()` function
   and terminate with `main "$@"`. No executable statements may
   appear after this invocation.

3. **Executable Code** — Executable statements MUST NOT appear at
   top level. The only exception is the `main "$@"` invocation.

4. **Camus Blocks** — Structured metadata MUST be enclosed in
   `## CAMUS-` / `## CAMUS-END` delimiters.

5. **CAMUS-SL** — Every function MUST be preceded by a
   `## CAMUS-SL` block declaring required `intent:`, and optional`input:`, and `output:`.
   Keys MUST be in lowercase.

6. **Size Limits** — Functions MUST NOT exceed 50 lines
   (SHOULD NOT exceed 20). Lines MUST NOT exceed 120 characters
   (SHOULD NOT exceed 80).

7. **No Public Primitives** — Top-level executable code is
   prohibited (§5). All logic lives inside functions.

8. **Explicit Exceptions** — Any deviation from these rules
   MUST be documented with a reason.

### Prohibition Rules

- **No `function` keyword** — Use POSIX-compatible syntax only
- **No top-level code** — All logic inside functions
- **No bare numeric return codes** — Every `return N` or `exit N` with `N > 0`
  MUST reference a named `readonly` constant (see Specification §11).

### Error Code Conventions

When writing a Camus.sh script, define error code constants at the top of
the file, after the `## CAMUS-LEXICON` block:

```sh
# --- Error code constants ---
# I_ (0-49): boolean / information
readonly I_OK=0
readonly I_FALSE=1
# W_ (50-99): SHOULD warnings
readonly W_LEXICON_MISSING=50
# E_ (100-255): MUST errors
readonly E_EMPTY_PASSWORD=100
readonly E_KEY_NOT_FOUND=102
```

Rules:
- Constants are declared with `readonly` at the top of the file
- All `return N` / `exit N` with `N > 0` MUST use a constant
- Within each range (`I_`, `W_`, `E_`), values MUST be sequential without gaps
- In CAMUS-SL blocks, reference constants by name (without `$`), e.g.
  `E_KEY_NOT_FOUND,"key not found in key directory"`
- Propagated errors use the wildcard `*` in CAMUS-SL blocks:
  `*,"propagated from prompt_password"`

### Verifying Grammar

For each function, verify:

- [ ] Is it preceded by a `## CAMUS-SL` block?
- [ ] Does the block declare `intent:`, `input:`, `output:`?
- [ ] Are all keys in lowercase?
- [ ] Does the function stay under 50 lines (ideally 20)?
- [ ] Are lines under 120 characters (ideally 80)?
- [ ] Is it a single identifiable responsibility?
- [ ] Are variables declared `local` where possible?
- [ ] Does it only reference Lexicon-defined terms?

### When Writing Code

- Ask the user for the Lexicon before the first line of code
- Deliver functions one at a time with their CAMUS-SL block
- State the claim (`intent:`) before writing the implementation
- Keep functions small and focused on a single term
- Always end the script with `main "$@"`

---

## Phase 3: Certification

Certification is **exclusively human**. Neither the AI agent nor
any automated tool may generate a final signature.

### Human-Only Rule

- **Only a human MAY sign.** Signing = assuming responsibility.
- AI-generated signatures are **invalid by definition**.
- An AI MAY, with explicit human authorization, generate a
  temporary signature for testing during development, but that
  signature MUST be removed before delivery.
- **The private key MUST be password-protected.** A passwordless
  key enables signing without human involvement and is invalid
  for production use. Passwordless keys are for local testing only.

### Workflow

When the script passes Grammar review:

1. **Format** — Ensure UTF-8, LF endings, consistent indentation
2. **Review** — Use the checklist below
3. **Sign** — The human appends a `## CAMUS-SIGNATURE` block after
   each function using `kiss.sh sign` (or `sign.sh`)

### The Signature Block

```sh
## CAMUS-SIGNATURE
# signatory: <identifier>
# date: <iso 8601>
# fingerprint: sha256:<hex>
# signature: <base64>
## CAMUS-END
```

Only the human operator appends this block. By signing, they
assume responsibility for the function's correctness.

---

## Quick Reference

### Full Script Template

```sh
#!/bin/bash

## CAMUS-LEXICON
# <term>: <definition>
## CAMUS-END

## CAMUS-SL
# intent: <what this function does>
# input[1]{param,desc}:
#   $1,<description>
# output:
#   <description>
## CAMUS-END
main() {
    local ...
    ...
}

main "$@"
```

### CAMUS-SL Template

```sh
## CAMUS-SL
# intent: <what this function does>
# input[1]{param,desc}:
#   $<n>,<description>
# output:
#   <description>
## CAMUS-END
```

### Review Checklist

- [ ] Shebang present: `#!/bin/bash` or `#!/usr/bin/env bash`
- [ ] Lexicon declared (inline or project-level)
- [ ] All functions use `name() { ... }` syntax
- [ ] `main()` defined and called at end of file
- [ ] No executable statements at top level
- [ ] Every function preceded by `## CAMUS-SL` with intent/input/output
- [ ] All Camus block keys in lowercase
- [ ] Camus blocks properly closed with `## CAMUS-END`
- [ ] No function exceeds 50 lines
- [ ] No line exceeds 120 characters
- [ ] Variables use `local` where possible
- [ ] Exceptions documented
- [ ] **No AI-generated `CAMUS-SIGNATURE` blocks** — only human signatures
- [ ] **Private key password-protected** — no passwordless keys in production

---

## Interaction Pattern with AI

1. **Start with the Lexicon** — Ask what terms the script manipulates
2. **Request function-by-function** — Each function delivered with its
   CAMUS-SL block
3. **Demand explicit intent** — "State what this function claims to do"
   before writing it
4. **Verify on delivery** — Run through the review checklist above
5. **Iterate** — Refine the Lexicon as understanding deepens

The AI is a tool. The human is the author.
Camus.sh ensures the human masters what the AI produces.

---

<pre>
*camus-sig-1*
**Signed — Lan Jing**
Date: 2026-06-15T21:00:00Z
Fingerprint: SHA256:11:0E:1B:6E:21:89:66:AF:F0:BF:CD:A5:A8:4D:7E:01:63:82:29:B3:08:6B:70:3F:52:D6:F3:21:23:52:CE:7F
Signature: <!-- to be added -->
</pre>
