# Camus.sh Specification v1 (Draft)

## 1. Purpose

Camus.sh defines a restricted shell scripting profile intended for human-reviewed and human-assumed software artifacts. The profile applies the Camus Method to shell scripts.

The profile provides a uniform structure that enables:

- human review;
- function-level documentation;
- function-level attestation;
- automated processing by tools;
- cryptographic signing of reviewed artifacts.

Camus.sh is intentionally more restrictive than the underlying shell languages it supports.

Future versions may integrate the Method's Lexicon phase.

---

## 2. Shell Compatibility

Camus.sh is developed and tested with **Bash**.

Scripts written under this profile SHOULD also be compatible with:

- Zsh
- Ksh
- Dash
- BusyBox ash

Compatibility with these shells is expected but not continuously tested.
Reports and feedback can be filed at the [issue tracker](https://github.com/Camus-Project/Camus.sh/issues).

The following shells are NOT compatible:

- Fish
- Nushell

---

## 3. Source Encoding

A script MUST:

- use UTF-8 encoding;
- use LF line endings.

---

## 4. Function Declaration

Functions MUST be declared using the following syntax:

```sh
function_name() {
    ...
}
```

The following syntax is prohibited:

```sh
function function_name {
    ...
}
```

This restriction ensures uniform parsing across supported shells.

---

## 5. Executable Code

Executable statements MUST NOT appear at top level.

The only executable statement allowed outside functions is the invocation of the entry point.

Valid example:

```sh
#!/usr/bin/env bash

main() {
    echo "Hello"
}

main "$@"
```

Invalid example:

```sh
#!/usr/bin/env bash

echo "Hello"
```

---

## 6. Entry Point

Every Camus.sh script MUST define a function named:

```sh
main()
```

The script MUST terminate with:

```sh
main "$@"
```

No executable statements may appear after this invocation.

---

## 7. Camus Blocks

Camus.sh uses delimiter-marked blocks for structured metadata.

A Camus block opens with a line starting with `## CAMUS-` and
closes with `## CAMUS-END`. These lines are reserved markers —
they are not ordinary comments and MUST NOT be used outside a
Camus block definition.

Content inside a block uses shell comments (`# key: value`).

Three block types are defined:

| Block | Placement | Purpose |
|---|---|---|
| `## CAMUS-LEXICON` | File header (after shebang) | Declares project terms |
| `## CAMUS-SL` | Before a function definition | Declares intent, inputs, outputs |
| `## CAMUS-SIGNATURE` | After a function body | Cryptographic attestation |

---

## 8. Function Documentation

Every function SHOULD be preceded by a documentation block.

Example:

```sh
# Print a greeting.
#
# Parameters:
#   $1 - name
greet() {
    printf 'Hello %s\n' "$1"
}
```

The structured equivalent for tooling is the `## CAMUS-SL` block (see §7).

---

## 9. Function Responsibility

Each function SHOULD implement a single identifiable responsibility.

Functions SHOULD be small enough to allow complete human review.

Functions MUST NOT exceed 50 lines.

Functions SHOULD NOT exceed 20 lines.

### Line Length

Lines MUST NOT exceed 120 characters.

Lines SHOULD NOT exceed 80 characters.

---

## 10. Signature Scope

Camus.sh v1 defines functions as the primary review and attestation unit.

Future specifications may define:

- function signatures;
- function attestations;
- review metadata;
- reviewer identities.

These mechanisms are outside the scope of this document.

---

## 11. Block Reference

### 11.1 CAMUS-LEXICON

Placed at the top of a script (after shebang) to declare project terms.
If the script belongs to a larger project with a LEXICON.md, this block
MAY be omitted.

```sh
## CAMUS-LEXICON
# <term>: <definition>
## CAMUS-END
```

### 11.2 CAMUS-SL

Placed immediately before a function definition.
Keys MUST be in lowercase. Keys SHOULD be omitted if they carry
no information. Sub-entries are indented (tooling MUST preserve
indentation).

```sh
## CAMUS-SL
# intent: <what this function does>
# input:
#   $<n>: <description>
# output:
#   <description>
## CAMUS-END
name() {
    ...
}
```

### 11.3 CAMUS-SIGNATURE

Placed immediately after the closing } of a function.
Only the human operator appends this block via sign.sh.
Keys MUST be in lowercase.

```sh
## CAMUS-SIGNATURE
# signatory: <identifier>
# date: <iso 8601>
# fingerprint: sha256:<hex>
# signature: <base64>
## CAMUS-END
```


---

# Design Rationale

Camus.sh treats functions as units of human responsibility.

A reviewer is expected to understand, verify, and assume individual functions rather than arbitrary fragments of source code.

The mandatory `main()` entry point ensures a predictable program structure and simplifies both human review and automated tooling.
