---
id: TASK-1
title: Implement kiss.sh — Camus.sh companion tool
status: Done
assignee:
  - '@agent'
created_date: '2026-06-16 11:30'
updated_date: '2026-06-16 13:49'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
kiss.sh is the shell adaptation of the kiss companion tool, first prototype of the Camus ecosystem. It implements the 3 responsibilities defined in the specification (S1): compliance checking, block validation, and cryptographic signing.

Signatures: per-function (CAMUS-SIGNATURE) for .sh files; whole-file (--- separator) for .txt; whole-file (--- with pre) for .md/.markdown. Auto-detection by extension or explicit flags (--txt/--text/--md/--markdown).

Key storage: default location is .secrets/ relative to the script. All subcommands support --key-dir (init) or --pubkey (sign/verify) to override.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `kiss.sh init` generates an Ed25519 key pair and makes it usable
- [x] #2 `kiss.sh check` validates/invalidates a script with useful messages
- [x] #3 `kiss.sh sign` appends valid ## CAMUS-SIGNATURE blocks per function
- [x] #4 `kiss.sh verify` verifies signatures (OK on valid, FAIL on invalid)
- [x] #5 `kiss.sh` itself is a conforming Camus.sh script
- [x] #6 helloWorld.sh signed with the previous method is verifiable with kiss.sh verify
- [x] #7 `.txt` files signed with whole-file mode (`---` separator)
- [x] #8 `.md`/`.markdown` files signed with whole-file mode (`---` + `<pre>` block)
- [x] #9 File extension auto-detection works (`.sh` → per-function, `.txt` → text, `.md` → markdown)
- [x] #10 Explicit flags `--txt`, `--text`, `--md`, `--markdown` override auto-detection
- [x] #11 `--key-dir` option on init changes key storage location
- [x] #12 `--pubkey` option on sign and verify specifies public key path
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Implement key management + `kiss.sh init` (duplicate crypto primitives from `tools/sign.sh`)
2. Implement compliance checking: `kiss.sh check`
3. Implement per-function signing: `kiss.sh sign`
4. Implement signature verification: `kiss.sh verify`
5. Refactor `helloWorld.sh` to use `kiss.sh` signatures and verify
6. Self-certify: make `kiss.sh` a conforming Camus.sh script
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Session 1 — Implementation + bugfixes

### Implémenté
- `kiss.sh init` — génération paire Ed25519, fingerprint, certificat X.509
- `kiss.sh check` — 10 règles (shebang, LEXICON, syntaxe, main, code top-level, SL, intent:, fermeture blocs, longueur fonctions/lignes)
- `kiss.sh sign` — per-function (.sh) + whole-file (.txt/.md)
- `kiss.sh verify` — per-function + whole-file
- `kiss.sh list-keys` — lister les clés publiques disponibles

### Correctifs
- `get_function_body()` : `echo "$content"` → `printf '%s' "$content"` (bogue verify_buffer différait de sign_buffer)
- Flag `--signatory` ajouté à la sous-commande `sign`
- Support `PASSWORD` env var dans `prompt_password()` pour mode non-interactif
- Nettoyage des placeholders `## CAMUS-SIGNATURE` nus lors du re-signing

### Restant
- AC #6 : tester rétrocompatibilité avec helloWorld.sh signé via tools/sign.sh

Fichiers clés :
- Camus.sh/kiss.sh (~1660 lignes)
- Camus.sh/specification.md (§7.2 mis à jour)
- Camus.sh/AGENTS.md créé (6 chapitres)

AC #6 validee : helloWorld.sh signe avec tools/sign.sh (whole-file --- + <pre>) est verifiable par kiss.sh verify. helloWorld.sh re-signe avec kiss.sh (format canonique per-function ## CAMUS-SIGNATURE). helloWorld.sh passe check avec 0 erreurs (2 warnings > 80 chars).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
kiss.sh: implémentation complète du companion tool Camus.sh. Fichier unique (~1660 lignes), 5 sous-commandes (init/check/sign/verify/list-keys), 3 modes de signature (per-function .sh, whole-file .txt/.md). Rétrocompatibilité avec l'ancien tools/sign.sh assurée. helloWorld.sh re-signé comme exemple canonique.
<!-- SECTION:FINAL_SUMMARY:END -->
