# Camus.sh — AI Agent Rules

## 1. Project Overview

Camus.sh defines a restricted shell scripting profile applying the
Camus Method to shell scripts. See `specification.md` for the normative
specification and `SKILL.md` for the agent skill implementing it.

## 2. Key Files

| File | Role |
|---|---|
| `specification.md` | Normative specification (v1 Draft) |
| `SKILL.md` | Agent skill — load before writing/reviewing scripts |
| `helloWorld.sh` | Canonical example of a compliant script |
| `LICENSE` | MIT |

## 3. Repository Model

- Standalone Git repository (not a submodule)
- Remote: `https://github.com/Camus-Project/Camus.sh.git`
- Branch: `main`

## 4. Camus.sh Grammar Rules

When writing or reviewing shell scripts under this profile:

- Every script MUST define a `main()` function and end with `main "$@"`
- Executable statements MUST NOT appear at top level
- Functions MUST use POSIX syntax: `name() { ... }` (no `function` keyword)
- Every function MUST be preceded by a `## CAMUS-SL` block declaring `intent:`; `input:` and `output:` present only when applicable
- Functions MUST NOT exceed 50 lines (SHOULD NOT exceed 20)
- Lines MUST NOT exceed 120 characters (SHOULD NOT exceed 80)
- Functions are the primary unit of review and attestation

## 5. SKILL.md Usage

Before writing or reviewing any Camus.sh script, load the `camus-sh` skill
(`SKILL.md`). It implements the three-phase workflow:

1. **Lexicon** — define terms
2. **Grammar** — write functions with CAMUS-SL blocks
3. **Certification** — review and sign

## 6. Change Rules

- Always check `git status` before making changes
- If uncommitted changes exist, stop and report them
- No action on a dirty working tree
- `specification.md` changes require explicit human approval
