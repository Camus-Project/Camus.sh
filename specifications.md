# Camus.sh Specification v1 (Draft)

## 1. Purpose

Camus.sh defines a restricted shell scripting profile intended for human-reviewed and human-assumed software artifacts.

The profile provides a uniform structure that enables:

- human review;
- function-level documentation;
- function-level attestation;
- automated processing by tools;
- cryptographic signing of reviewed artifacts.

Camus.sh is intentionally more restrictive than the underlying shell languages it supports.

---

## 2. Supported Shells

A Camus.sh script MUST be executable by one of the following interpreters:

| Shell | Status |
| ------- | ------- |
| Bash | Supported |
| Zsh | Supported |
| Ksh | Supported |
| Dash | Supported |
| BusyBox ash | Supported |

The support status applies only when the script complies with the Camus.sh profile.

The following shells are out of scope:

| Shell | Status |
| ------- | ------- |
| Fish | Not supported |
| Nushell | Not supported |

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

## 7. Comments

Comments MUST use the shell comment syntax:

```sh
# comment
```

Block comment syntaxes are not supported.

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

Future Camus specifications may define a structured documentation format.

---

## 9. Function Responsibility

Each function SHOULD implement a single identifiable responsibility.

Functions SHOULD be small enough to allow complete human review.

The specification does not currently define size limits.

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

# Design Rationale

Camus.sh treats functions as units of human responsibility.

A reviewer is expected to understand, verify, and assume individual functions rather than arbitrary fragments of source code.

The mandatory `main()` entry point ensures a predictable program structure and simplifies both human review and automated tooling.
