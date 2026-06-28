#!/bin/bash

## CAMUS-LEXICON
# key-pair: Ed25519 cryptographic key pair (private + public)
# fingerprint: SHA256 digest of the public key, used as identifier
# signature-block: metadata block appended after a function or at end-of-file
# camus-block: a metadata block delimited by ## CAMUS- and ## CAMUS-END
# compliance-check: validation of a script against the Camus.sh specification
# whole-file-signature: signature covering an entire non-shell file (.txt, .md)
# per-function-signature: signature covering a single function
#   plus its CAMUS-SL block
## CAMUS-END

# --- Error code constants ---
# I_ (0-49): boolean / information
readonly I_FALSE=1
# W_ (50-99): SHOULD warnings
readonly W_LEXICON_MISSING=50
readonly W_FUNC_SHOULD=51
readonly W_LINE_SHOULD=52
readonly W_COMPLIANCE_ONLY=53
# E_ (100-255): MUST errors
readonly E_EMPTY_PASSWORD=100
readonly E_PASSWORDS_MISMATCH=101
readonly E_KEY_NOT_FOUND=102
readonly E_SIGNATORY_EMPTY=103
readonly E_KEY_EXPIRED=104
readonly E_FILE_NOT_FOUND=105
readonly E_KEY_INVALID_AT_DATE=106
readonly E_CERT_PARSE_FAILED=107
readonly E_NO_SIGNATURE=108
readonly E_MALFORMED_SIG=109
readonly E_INVALID_SIG=110
readonly E_NO_FUNC_DEF_FOR_SIG=111
readonly E_NO_SIGNABLES=112
readonly E_NO_APPROVALS=113
readonly E_UNKNOWN_OPTION=114
readonly E_MISSING_ARG=115
readonly E_NO_SHEBANG=116
readonly E_FUNCTION_KEYWORD=117
readonly E_NO_MAIN=118
readonly E_NO_MAIN_CALL=119
readonly E_TOP_LEVEL_CODE=120
readonly E_NO_INTENT=121
readonly E_UNCLOSED_BLOCK=122
readonly E_FUNC_EXCEEDS_LIMIT=123
readonly E_LINE_EXCEEDS_LIMIT=124
readonly E_CHECK_FAILED=125
readonly E_NO_SL_BLOCK=126

## CAMUS-SL
# intent: print usage information
# output:
#   stdout: usage message
## CAMUS-END
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options] [<file>...]

Commands:
  init       [--key-dir <path>] [--days <n>] Generate Ed25519 key pair
  check      <file>                           Check script compliance
  sign       [options] <file>...              Sign file(s)
  verify     [options] <file>                 Verify signature(s)
  list-keys  [--key-dir <path>]               List available public keys

Sign options:
  --key-dir <path>    Key storage directory (default: ~/.config/camus)
  --signatory <name>  Signatory name (optional, prompts if absent)

Verify options:
  --pubkey <path>     Use specific public key
  --key-dir <path>    Key storage directory (default: ~/.config/camus)
EOF
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-25T13:45:27Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: ycSGWFWJTrvrQUWpeFJyY6QAISEqqrW5oHFkBfziXI7ovTbDVgDm5O2Ard/D7fjWSIOu247YvzLq3KhHWqMKAw==
## CAMUS-END

## CAMUS-SL
# intent: check that a file exists and exit with E_FILE_NOT_FOUND if not
# input[2]{param,desc}:
#   $1,file path
#   $2,label for error message (defaults to file path)
# output:
#   return[1]{code,desc}:
#     0,"file exists"
#     105,"file not found"
## CAMUS-END
assert_file_exists() {
    local file="$1" label="${2:-$1}"
    [ -f "$file" ] && return 0
    echo "Error: file not found: ${label}" >&2
    return $E_FILE_NOT_FOUND
}

## CAMUS-SL
# intent: print an unknown option error and exit
# input[1]{param,desc}:
#   $1,the unknown option string
# output:
#   stderr: error message
#   exit[1]{code,desc}:
#     114,E_UNKNOWN_OPTION
## CAMUS-END
die_unknown_option() {
    echo "Error: unknown option: $1" >&2
    usage; exit $E_UNKNOWN_OPTION
}

## CAMUS-SL
# intent: print a missing argument error and exit
# input[0]{param,desc}:
# output:
#   stderr: error message
#   exit[1]{code,desc}:
#     115,E_MISSING_ARG
## CAMUS-END
die_missing_arg() {
    usage; exit $E_MISSING_ARG
}

## CAMUS-SL
# intent: prompt the user for a password (hidden input)
# input[1]{param,desc,default}:
#   $1,prompt message,"Enter password: "
# output:
#   stdout: the entered password
#   return[1]{code,desc}:
#     E_EMPTY_PASSWORD,"empty password"
## CAMUS-END
prompt_password() {
    local prompt="${1:-Enter password: }"
    if [ -n "${CAMUS_TEST_SIGN_PASSWORD:-}" ]; then
        echo "Warning: CAMUS_TEST_SIGN_PASSWORD env var used -- testing mode only." >&2
        echo "$CAMUS_TEST_SIGN_PASSWORD"
        return
    fi
    local password
    read -r -s -p "$prompt" password
    echo >&2
    if [ -z "$password" ]; then
        echo "Error: password cannot be empty." >&2
        return $E_EMPTY_PASSWORD
    fi
    echo "$password"
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:10:00Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: DBSHN8yilzH1MW8iiBsPI2F8yrECCvsXDmY7StbK5LHIUF4+tztv3ju0xti2afVacBXrdHiNw+4IozpuyPLbCQ==
## CAMUS-END

## CAMUS-SL
# intent: prompt the user for a password twice to confirm
# output:
#   stdout: the confirmed password
#   return[2]{code,desc}:
#     *,"propagated from prompt_password"
#     3,"passwords do not match"
## CAMUS-END
prompt_password_twice() {
    local p1 p2
    p1=$(prompt_password "Enter password: ") || return $?
    p2=$(prompt_password "Confirm password: ")
    if [ "$p1" != "$p2" ]; then
        echo "Error: passwords do not match." >&2
        return $E_PASSWORDS_MISMATCH
    fi
    echo "$p1"
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:32:27Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: qum9pl8gIOjDyhjPEQ7c16MEVgSOu3WJKh/KSTyMqYxkH5MJ4PggRN1l/6e/YfZjdFvMQznZzipcLpCpYBw6Bg==
## CAMUS-END

## CAMUS-SL
# intent: compute the SHA256 fingerprint of a certificate or public key
# input[1]{param,desc}:
#   $1,path to public key file
# output:
#   stdout: colon-formatted SHA256 fingerprint
## CAMUS-END
fingerprint_of() {
    local key="$1"
    if head -1 "$key" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
        openssl x509 -in "$key" -noout -fingerprint -sha256 2>/dev/null \
            | cut -d= -f2
    else
        openssl pkey -in "$key" -pubin -outform DER 2>/dev/null \
            | openssl dgst -sha256 | cut -d' ' -f2
    fi
}

## CAMUS-SL
# intent: normalize a fingerprint string for use as a filename
# input[1]{param,desc}:
#   $1,fingerprint string
# output:
#   stdout: fingerprint with all spaces and colons removed
## CAMUS-END
fingerprint_filepath() {
    echo "$1" | tr -d ' :'
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:32:27Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: lT70FCrRf6zNTlau8e+xxNN7ALttGou7jLK9bkudN2USakWQ+hYgLgJaQY5wPrtkL4Z//WviaPH4yrPsvClYCA==
## CAMUS-END

## CAMUS-SL
# intent: find a public key file by its fingerprint
# input[2]{param,desc}:
#   $1,fingerprint to search for
#   $2,key directory to search in
# output:
#   stdout: path to the matching public key file, if found
## CAMUS-END
find_key_by_fingerprint() {
    local fpr="$1"
    local key_dir="$2"
    local clean
    clean=$(fingerprint_filepath "$fpr")
    local candidate="${key_dir}/public-${clean}.pem"
    if [ -f "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    candidate="${key_dir}/public-${clean}"
    if [ -f "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    return $I_FALSE
}

## CAMUS-SL
# intent: check certificate expiration status at a given date
# input[2]{param,desc}:
#   $1,path to certificate
#   $2,ISO 8601 date string to check against
## CAMUS-END
cert_valid_at() {
    local pubkey="$1" sig_date="$2"
    local cert_end
    cert_end=$(openssl x509 -in "$pubkey" -noout -enddate 2>/dev/null \
        | cut -d= -f2)
    if [ -z "$cert_end" ]; then
        return 0
    fi
    local cert_epoch sig_epoch
    cert_epoch=$(date -d "$cert_end" +%s 2>/dev/null || echo 0)
    sig_epoch=$(date -d "$sig_date" +%s 2>/dev/null || echo 0)
    if [ "$sig_epoch" -le "$cert_epoch" ] 2>/dev/null; then
        return 0
    fi
    return $I_FALSE
}

## CAMUS-SL
# intent: extract remaining validity days of a certificate
# input[1]{param,desc}:
#   $1,path to certificate
# output:
#   stdout: number of remaining days (negative if expired)
## CAMUS-END
key_expiry_info() {
    local cert="$1"
    local end_date
    end_date=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null \
        | cut -d= -f2) || { echo ""; return $E_CERT_PARSE_FAILED; }
    local end_epoch now_epoch
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null) || { echo ""; return $E_CERT_PARSE_FAILED; }
    now_epoch=$(date +%s)
    local remaining=$(( (end_epoch - now_epoch) / 86400 ))
    echo "$remaining"
    [ "$remaining" -ge 0 ]
}

## CAMUS-SL
# intent: detect file type for signing mode
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: "sh", "txt", "md", or "unknown"
## CAMUS-END
detect_file_type() {
    local file="$1" lower
    lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        *.sh) echo "sh" ;;
        *.txt) echo "txt" ;;
        *.md|*.markdown) echo "md" ;;
        *) echo "unknown" ;;
    esac
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:45:14Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: txcWBRyH6Puc4rQG2LZj55cVE3qgkItFzrAjtiHARX+5sJKveZstzEqOBcYB0CIj7Q0S9t8Zl0OoeBjwtV3zBQ==
## CAMUS-END

## CAMUS-SL
# intent: check if a file already has a camus-sig-1 marker
# input[1]{param,desc}:
#   $1,file path
# output:
#   return[1]{code,desc}:
#     *,"propagated from grep -q"
## CAMUS-END
is_signed() {
    local file="$1"
    grep -q '^\*camus-sig-1\*$' "$file"
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:51:39Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: xQDYsxwRcmygOAkAP740odTBlM/iCxfYm8oQugOt5mNVfCx/nTCMrL5DS3RlycSddymWd/Ojtixj73BuQNM0Dw==
## CAMUS-END

## --- Check helpers ---

## CAMUS-SL
# intent: check that a script has a shebang line
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"shebang line is present"
#     E_NO_SHEBANG,"shebang line is missing"
## CAMUS-END
check_shebang() {
    if head -1 "$1" | grep -q '^#!' 2>/dev/null; then
        echo "  [OK] Shebang present"
        return 0
    else
        echo "  [ERROR] No shebang found (MUST start with #!)"
        return $E_NO_SHEBANG
    fi
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-25T13:45:27Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: wG6R10K2kI6cuEIG9DSf5EnqF3w/eKa2UlxfQ5nENLbxyb6P8EzaZAtYYRU0Yc6L7G7UX4RmnoS8WYFhpTWOCA==
## CAMUS-END

## CAMUS-SL
# intent: check that a script has a CAMUS-LEXICON block
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"CAMUS-LEXICON block is present"
#     1,"CAMUS-LEXICON block is missing"
## CAMUS-END
check_lexicon_block() {
    if grep -q '^## CAMUS-LEXICON$' "$1"; then
        echo "  [OK] CAMUS-LEXICON block present"
        return 0
    else
        echo "  [WARN] No CAMUS-LEXICON block (SHOULD define project terms)"
        return $W_LEXICON_MISSING
    fi
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:51:39Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: tp3mPLxferscofgOPUd3N/j0H6e+y7XbKHNSeQpYxQPBiHeJZ0/k3ZWv00wN31FSng1knmIeDBLjyzWLS8JlDA==
## CAMUS-END

## CAMUS-SL
# intent: check that no 'function' keyword is used
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"only POSIX function syntax used"
#     2,"'function' keyword used, violating Camus.sh grammar"
## CAMUS-END
check_no_function_keyword() {
    if grep -q '^function ' "$1"; then
        echo "  [ERROR] 'function' keyword used (MUST use name() {} syntax)"
        return $E_FUNCTION_KEYWORD
    else
        echo "  [OK] No 'function' keyword"
        return 0
    fi
}
## CAMUS-SIGNATURE
# signatory: Lan Jing
# date: 2026-06-26T16:51:39Z
# fingerprint: sha256:52:69:05:07:66:BD:DE:55:C7:D2:B1:52:9C:8F:ED:7B:05:E3:8E:57:7E:10:98:1E:7C:BD:13:96:85:4E:83:89
# signature: NDC5QXWUmCbrQ73oDAlEwzBRM+Y3Aua2sd2Y2VqVzjGXSG+o0urMTw8cVwPYwGOfPxkWHDT9PgjrzBOWuPk8AQ==
## CAMUS-END

## CAMUS-SL
# intent: check that main() is defined
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"main() function is defined"
#     E_NO_MAIN,"main() function is not defined"
## CAMUS-END
check_main_defined() {
    if grep -q '^main()' "$1" || grep -q '^main ()' "$1"; then
        echo "  [OK] main() defined"
        return 0
    else
        echo "  [ERROR] main() not defined (MUST have a main function)"
        return $E_NO_MAIN
    fi
}

## CAMUS-SL
# intent: check that the script ends with main "$@"
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"script ends with main \"$@\""
#     E_NO_MAIN_CALL,"script does not end with main \"$@\""
## CAMUS-END
check_main_call() {
    if tail -1 "$1" | grep -q '^main "\$@"$' 2>/dev/null; then
        echo "  [OK] Script ends with main \"\$@\""
        return 0
    elif grep -q '^main "\$@"$' "$1"; then
        echo "  [OK] main \"\$@\" present (though not on last line)"
        return 0
    else
        echo "  [ERROR] main \"\$@\" not found (MUST invoke main at end)"
        return $E_NO_MAIN_CALL
    fi
}

## CAMUS-SL
# intent: check for top-level executable code before first function
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"no executable code outside function definitions"
#     E_TOP_LEVEL_CODE,"executable statements found at top level"
## CAMUS-END
check_top_level_code() {
    local first_func_line
    first_func_line=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*() {' "$1" 2>/dev/null \
        | head -1 | cut -d: -f1 || true)
    if [ -n "$first_func_line" ] && [ "$first_func_line" -gt 2 ]; then
        local suspect
        suspect=$(sed -n "2,$((first_func_line - 1))p" "$1" 2>/dev/null \
            | grep -v '^#' | grep -v '^$' \
            | grep -v '^## CAMUS-' | grep -v '^## CAMUS-END$' || true)
        if [ -n "$suspect" ]; then
            echo "  [ERROR] Top-level executable code found before first function"
            return $E_TOP_LEVEL_CODE
        fi
    fi
    echo "  [OK] No top-level executable code"
    return 0
}

## CAMUS-SL
# intent: check that all functions are preceded by CAMUS-SL blocks
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"all functions have a preceding CAMUS-SL block"
#     2,"at least one function is missing a CAMUS-SL block"
## CAMUS-END
check_sl_blocks_present() {
    local func_lines
    func_lines=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*() {' "$1" 2>/dev/null || true)
    if [ -z "$func_lines" ]; then
        echo "  [OK] All functions preceded by CAMUS-SL blocks"
        return 0
    fi
    local missing_sl=0
    while IFS=: read -r line_num _; do
        if [ "$line_num" -le 2 ]; then continue; fi
        local prev_line=$((line_num - 1))
        local block_start
        block_start=$(sed -n '1,'"$prev_line"'p' "$1" \
            | tac | grep -n '^## CAMUS-SL$' -m1 \
            | head -1 | cut -d: -f1 || true)
        if [ -z "$block_start" ]; then
            echo "  [ERROR] Function at line ${line_num} has no preceding CAMUS-SL block"
            missing_sl=$((missing_sl + 1))
        fi
    done <<< "$func_lines"
    if [ "$missing_sl" -eq 0 ]; then
        echo "  [OK] All functions preceded by CAMUS-SL blocks"
        return 0
    fi
    return $E_NO_SL_BLOCK
}

## CAMUS-SL
# intent: check that all CAMUS-SL blocks contain an intent: declaration
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"all CAMUS-SL blocks declare an intent field"
#     2,"at least one CAMUS-SL block is missing intent"
## CAMUS-END
check_sl_intent() {
    local sl_blocks
    sl_blocks=$(grep -n '^## CAMUS-SL$' "$1" 2>/dev/null || true)
    if [ -z "$sl_blocks" ]; then
        echo "  [OK] All CAMUS-SL blocks declare intent:"
        return 0
    fi
    local missing_intent=0
    while IFS=: read -r line_num _; do
        local end_line
        end_line=$(sed -n "$line_num,\$p" "$1" | grep -n '^## CAMUS-END$' \
            | head -1 | cut -d: -f1)
        if [ -z "$end_line" ]; then continue; fi
        end_line=$((line_num + end_line - 1))
        local block_content
        block_content=$(sed -n "$((line_num + 1)),$((end_line - 1))p" "$1" 2>/dev/null)
        if ! echo "$block_content" | grep -q '# intent:'; then
            echo "  [ERROR] CAMUS-SL block at line ${line_num} missing 'intent:'"
            missing_intent=$((missing_intent + 1))
        fi
    done <<< "$sl_blocks"
    if [ "$missing_intent" -eq 0 ]; then
        echo "  [OK] All CAMUS-SL blocks declare intent:"
        return 0
    fi
    return $E_NO_INTENT
}

## CAMUS-SL
# intent: check that all Camus blocks are properly closed
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result
#   return[2]{code,desc}:
#     0,"all Camus blocks are properly closed"
#     2,"at least one Camus block has no matching ## CAMUS-END"
## CAMUS-END
check_blocks_closed() {
    local total_end total_camus open_blocks
    total_end=$(grep -c '^## CAMUS-END$' "$1" 2>/dev/null || true)
    total_camus=$(grep -c '^## CAMUS-' "$1" 2>/dev/null || true)
    open_blocks=$((total_camus - total_end))
    if [ "$open_blocks" -eq "$total_end" ]; then
        echo "  [OK] All Camus blocks properly closed"
        return 0
    else
        echo "  [ERROR] ${open_blocks} opening markers but ${total_end} closing markers"
        return $E_UNCLOSED_BLOCK
    fi
}

## CAMUS-SL
# intent: scan a file and output "name:line_count" for each function
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: "name:line_count" lines
## CAMUS-END
scan_func_lengths() {
    local file="$1"
    local line_num=0 brace_depth=0 func_name="" func_start=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        local func_pat='^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*'
        if [[ "$line" =~ ${func_pat}\{ ]] || [[ "$line" =~ ${func_pat}$ ]]; then
            if [ -n "$func_name" ]; then
                echo "${func_name}:$((line_num - 1 - func_start + 1))"
            fi
            func_name=$(echo "$line" | sed 's/(.*//' | tr -d ' ')
            func_start=$line_num
            brace_depth=0
            local open_br=$(echo "$line" | tr -cd '{' | wc -c)
            local close_br=$(echo "$line" | tr -cd '}' | wc -c)
            brace_depth=$((brace_depth + open_br - close_br))
        elif [ -n "$func_name" ]; then
            brace_depth=$((brace_depth + $(echo "$line" | tr -cd '{' | wc -c)))
            brace_depth=$((brace_depth - $(echo "$line" | tr -cd '}' | wc -c)))
            if [ "$brace_depth" -le 0 ]; then
                echo "${func_name}:$((line_num - func_start + 1))"
                func_name=""
            fi
        fi
    done < "$file"

    if [ -n "$func_name" ]; then
        echo "${func_name}:${line_num}"
    fi
}

## CAMUS-SL
# intent: check that no function exceeds 50 lines (warn above 20)
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check result per oversized function
#   return[3]{code,desc}:
#     0,"all functions within size limits"
#     W_FUNC_SHOULD,"at least one function exceeds SHOULD limit of 20 lines"
#     E_FUNC_EXCEEDS_LIMIT,"at least one function exceeds MUST limit of 50 lines"
## CAMUS-END
check_function_lengths() {
    local file="$1"
    local errors=0 warnings=0
    local results
    results=$(scan_func_lengths "$file")
    if [ -z "$results" ]; then return 0; fi

    while IFS= read -r result; do
        local func_name="${result%%:*}"
        local func_count="${result##*:}"
        report_func_length "$func_name" "$func_count"
        local rc=$?
        [ "$rc" -eq $E_FUNC_EXCEEDS_LIMIT ] && errors=$((errors + 1))
        [ "$rc" -eq $W_FUNC_SHOULD ] && warnings=$((warnings + 1))
    done <<< "$results"

    [ "$errors" -gt 0 ] && return $E_FUNC_EXCEEDS_LIMIT
    [ "$warnings" -gt 0 ] && return $W_FUNC_SHOULD
    return 0
}

## CAMUS-SL
# intent: report a single function's line count against size limits
# input[2]{param,desc}:
#   $1,function name
#   $2,line count
# output:
#   stdout: warning or error message if over limit
#   return[3]{code,desc}:
#     0,"function is within size limits"
#     W_FUNC_SHOULD,"function exceeds SHOULD limit of 20 lines"
#     E_FUNC_EXCEEDS_LIMIT,"function exceeds MUST limit of 50 lines"
## CAMUS-END
report_func_length() {
    local name="$1" count="$2"
    if [ "$count" -gt 50 ]; then
        echo "  [ERROR] Function '${name}' is ${count} lines (MUST <= 50)"
        return $E_FUNC_EXCEEDS_LIMIT
    elif [ "$count" -gt 20 ]; then
        echo "  [WARN] Function '${name}' is ${count} lines (SHOULD <= 20)"
        return $W_FUNC_SHOULD
    fi
    return 0
}

## CAMUS-SL
# intent: check line lengths against limits (MUST <= 120, SHOULD <= 80)
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: check results
#   return[3]{code,desc}:
#     0,"all lines within length limits"
#     W_LINE_SHOULD,"at least one line exceeds SHOULD limit of 80 characters"
#     E_LINE_EXCEEDS_LIMIT,"at least one line exceeds MUST limit of 120 characters"
## CAMUS-END
check_line_lengths() {
    local file="$1"
    local long_lines=0 very_long_lines=0 line_num=0
    while IFS= read -r line_content; do
        line_num=$((line_num + 1))
        local len=${#line_content}
        if [ "$len" -gt 120 ]; then
            very_long_lines=$((very_long_lines + 1))
            echo "  [ERROR] Line ${line_num} is ${len} chars (MUST <= 120)"
        elif [ "$len" -gt 80 ]; then
            long_lines=$((long_lines + 1))
        fi
    done < "$file"
    if [ "$very_long_lines" -gt 0 ]; then return $E_LINE_EXCEEDS_LIMIT; fi
    if [ "$long_lines" -eq 0 ]; then
        echo "  [OK] All lines under 80 characters"
    fi
    [ "$long_lines" -gt 0 ] && return $W_LINE_SHOULD
    return 0
}

## --- Subcommand: list-keys ---

## CAMUS-SL
# intent: list all available public keys in the key directory
# input[1]{param,desc}:
#   $1,key directory
## CAMUS-END
do_list_keys() {
    local key_dir="$1"
    mkdir -p "$key_dir"
    local found=0
    for f in "$key_dir"/public-*.pem; do
        [ -f "$f" ] || continue
        local fpr expiry
        fpr=$(fingerprint_of "$f")
        if head -1 "$f" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
            expiry=$(openssl x509 -in "$f" -noout -enddate 2>/dev/null \
                | cut -d= -f2)
        else
            expiry="-"
        fi
        echo "SHA256:${fpr}  valid until: ${expiry}"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        echo "No keys found in ${key_dir}." >&2
    fi
}

## --- Subcommand: init ---

## CAMUS-SL
# intent: generate an Ed25519 self-signed certificate
# input[4]{param,desc}:
#   $1,output key path
#   $2,output cert path
#   $3,password
#   $4,validity in days
## CAMUS-END
gen_cert() {
    local key_out="$1" cert_out="$2" password="$3" days="$4"
    openssl req -x509 -newkey ed25519 \
        -keyout "$key_out" -out "$cert_out" \
        -days "$days" \
        -passout "pass:${password}" \
        -subj "/CN=Camus.sh Key/O=Camus Project" \
        2>/dev/null
}

## CAMUS-SL
# intent: generate an Ed25519 key pair with password-protected private key
# input[2]{param,desc}:
#   $1,key directory
#   $2,certificate validity in days (default: 365)
# output:
#   return[1]{code,desc}:
#     *,"propagated from prompt_password_twice"
## CAMUS-END
do_gen_key() {
    local key_dir="$1"
    local days="${2:-365}"
    mkdir -p "$key_dir"

    local password
    password=$(prompt_password_twice) || return $?

    local tmp_key tmp_cert
    tmp_key=$(mktemp)
    tmp_cert=$(mktemp)

    gen_cert "$tmp_key" "$tmp_cert" "$password" "$days"

    local fpr clean_fpr
    fpr=$(fingerprint_of "$tmp_cert")
    clean_fpr=$(fingerprint_filepath "$fpr")

    local named_key="${key_dir}/private-${clean_fpr}.pem"
    local named_cert="${key_dir}/public-${clean_fpr}.pem"

    mv "$tmp_key" "$named_key"
    mv "$tmp_cert" "$named_cert"

    ln -sf "private-${clean_fpr}.pem" "${key_dir}/private.pem"
    ln -sf "public-${clean_fpr}.pem"  "${key_dir}/public.pem"

    local expiry
    expiry=$(openssl x509 -in "$named_cert" -noout -enddate 2>/dev/null \
        | cut -d= -f2)

    echo "Key fingerprint: SHA256:${fpr}" >&2
    echo "Valid until: ${expiry}" >&2
    echo "Private key: ${named_key}" >&2
    echo "Public cert: ${named_cert}" >&2
}

## --- Subcommand: check ---

## CAMUS-SL
# intent: check a shell script for compliance with the Camus.sh specification
# input[1]{param,desc}:
#   $1,file path to check
# output:
#   stdout: compliance report
#   return[3]{code,desc}:
#     0,"file passes all checks"
#     W_COMPLIANCE_ONLY,"all MUST checks pass, at least one SHOULD warning"
#     E_CHECK_FAILED,"at least one MUST check fails"
## CAMUS-END
do_check() {
    local file="$1"
    local errors=0 warnings=0 rc

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2
        return $E_FILE_NOT_FOUND
    fi

    echo "Checking: ${file}"
    echo ""

    for check in check_shebang check_lexicon_block \
        check_no_function_keyword check_main_defined check_main_call \
        check_top_level_code check_sl_blocks_present check_sl_intent \
        check_blocks_closed; do
        $check "$file"
        rc=$?
        [ "$rc" -ge 100 ] && errors=$((errors + 1))
        [ "$rc" -ge 50 ] && [ "$rc" -le 99 ] && warnings=$((warnings + 1))
    done

    local fl_result; fl_result=$(check_function_lengths "$file"); rc=$?
    echo "$fl_result"
    errors=$((errors + $(echo "$fl_result" | grep -c '\[ERROR\]' || true)))
    warnings=$((warnings + $(echo "$fl_result" | grep -c '\[WARN\]' || true)))

    local ll_result; ll_result=$(check_line_lengths "$file"); rc=$?
    echo "$ll_result"
    errors=$((errors + $(echo "$ll_result" | grep -c '\[ERROR\]' || true)))
    warnings=$((warnings + $(echo "$ll_result" | grep -c '\[WARN\]' || true)))

    echo ""
    if [ "$errors" -gt 0 ] && [ "$warnings" -gt 0 ]; then
        echo "Result: ${errors} error(s), ${warnings} warning(s)"
        return $E_CHECK_FAILED
    elif [ "$errors" -gt 0 ]; then
        echo "Result: ${errors} error(s)"
        return $E_CHECK_FAILED
    elif [ "$warnings" -gt 0 ]; then
        echo "Result: ${warnings} warning(s)"
        return $W_COMPLIANCE_ONLY
    else
        echo "Result: All checks passed"
        return 0
    fi
}

## --- Sign helpers ---

## CAMUS-SL
# intent: remove stale signature blocks whose cryptographic verification fails
# input[2]{param,desc}:
#   $1,file path
#   $2,public key path
# output:
#   side-effect: modifies file in-place if stale signatures are purged
## CAMUS-END
purge_invalid_signatures() {
    local file="$1" pubkey="$2"
    [ ! -f "$pubkey" ] && return 0
    local my_fpr; my_fpr=$(fingerprint_of "$pubkey")
    local temp_file; temp_file=$(mktemp)
    local line_num=0 in_sig=0 sig_start=0 changed=false
    local -a sig_lines=()

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$in_sig" -eq 0 ] && echo "$line" | grep -q '^## CAMUS-SIGNATURE$'; then
            in_sig=1; sig_start=$line_num
            sig_lines=("$line"); continue
        fi
        if [ "$in_sig" -eq 1 ]; then
            sig_lines+=("$line")
            if echo "$line" | grep -q '^## CAMUS-END$'; then
                in_sig=0
                local stored_fpr
                stored_fpr=$(printf '%s\n' "${sig_lines[@]}" \
                    | grep '^# fingerprint: ' | sed 's/^# fingerprint: sha256://')
                local keep_block=true
                if [ -n "$stored_fpr" ] && [ "$stored_fpr" = "$my_fpr" ]; then
                    local func_def
                    func_def=$(find_func_def_for_sig "$file" "$sig_start")
                    if [ "$func_def" -gt 0 ]; then
                        if ! verify_func_signature "$file" "$sig_start" \
                            "$pubkey" >/dev/null 2>&1; then
                            keep_block=false; changed=true
                        fi
                    fi
                fi
                if [ "$keep_block" = true ]; then
                    printf '%s\n' "${sig_lines[@]}" >> "$temp_file"
                fi
            fi
            continue
        fi
        echo "$line" >> "$temp_file"
    done < "$file"

    if [ "$changed" = true ]; then
        chmod --reference="$file" "$temp_file" 2>/dev/null || true
        mv "$temp_file" "$file"
    else
        rm -f "$temp_file"
    fi
}

## CAMUS-SL
# intent: check whether a function already has a valid signature by a specific signatory
# input[4]{param,desc}:
#   $1,file path
#   $2,function end line
#   $3,signatory name
#   $4,key fingerprint
# output:
#   return[2]{code,desc}:
#     0,"function is signed by the given signatory and key"
#     1,"function is not signed by the given signatory and key"
## CAMUS-END
is_function_signed_by_me() {
    local file="$1" func_end="$2" signatory="$3" fingerprint="$4"
    local check_line=$((func_end + 1))
    local total_lines; total_lines=$(wc -l < "$file")
    while [ "$check_line" -le "$total_lines" ]; do
        local line; line=$(sed -n "${check_line}p" "$file")
        [ -z "$line" ] && { check_line=$((check_line + 1)); continue; }
        break
    done
    [ "$check_line" -gt "$total_lines" ] && return $I_FALSE
    echo "$line" | grep -q '^## CAMUS-SIGNATURE$' || return $I_FALSE

    local sig_data
    sig_data=$(extract_func_sig_data "$file" "$check_line") || return $I_FALSE
    local stored_fpr stored_signatory
    stored_fpr=$(echo "$sig_data" | cut -d'|' -f2)
    stored_signatory=$(echo "$sig_data" | cut -d'|' -f4)
    [ "$stored_signatory" = "$signatory" ] && [ "$stored_fpr" = "$fingerprint" ]
}

## CAMUS-SL
# intent: compute a cryptographic signature for content and format a CAMUS-SIGNATURE block
# input[5]{param,desc}:
#   $1,private key path
#   $2,password for private key
#   $3,signatory name
#   $4,timestamp (ISO 8601)
#   $5,fingerprint (SHA256)
# output:
#   stdout: base64-encoded signature
## CAMUS-END
compute_signature() {
    local privkey="$1" password="$2"
    local content="$3"
    local tmp_content tmp_sig

    tmp_content=$(mktemp)
    tmp_sig=$(mktemp)

    printf '%s' "$content" > "$tmp_content"
    echo "" >> "$tmp_content"

    openssl pkeyutl -sign -inkey "$privkey" -passin "pass:${password}" \
        -rawin -in "$tmp_content" -out "$tmp_sig" 2>/dev/null

    local sig_b64
    sig_b64=$(openssl base64 -in "$tmp_sig" | tr -d '\n')

    rm -f "$tmp_content" "$tmp_sig"
    echo "$sig_b64"
}

## CAMUS-SL
# intent: generate a whole-file signature block for text or markdown files
# input[6]{param,desc}:
#   $1,file path
#   $2,public key fingerprint
#   $3,base64 signature
#   $4,timestamp
#   $5,signatory
#   $6,file type ("txt" or "md")
# output:
#   stdout: signature block to append
## CAMUS-END
format_whole_signature() {
    local file="$1" fpr="$2" sig_b64="$3" timestamp="$4"
    local signatory="$5" file_type="$6"

    echo ""
    echo "---"
    if [ "$file_type" = "md" ]; then
        echo "<pre>"
    fi
    echo "*camus-sig-1*"
    echo "**Signed -- ${signatory}**"
    echo "Date: ${timestamp}"
    echo "Fingerprint: SHA256:${fpr}"
    echo "Signature: ${sig_b64}"
    if [ "$file_type" = "md" ]; then
        echo "</pre>"
    fi
}

## CAMUS-SL
# intent: sign an entire file as a single unit (for .txt and .md)
# input[6]{param,desc}:
#   $1,file path
#   $2,private key path
#   $3,public key path
#   $4,password
#   $5,signatory
#   $6,file type ("txt" or "md")
## CAMUS-END
do_sign_whole_file() {
    local file="$1" privkey="$2" pubkey="$3" password="$4"
    local signatory="$5" file_type="$6"

    local timestamp fpr sig_b64 content
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fpr=$(fingerprint_of "$pubkey")
    content=$(cat "$file")
    sig_b64=$(compute_signature "$privkey" "$password" "$content")

    local sig_block
    sig_block=$(format_whole_signature \
        "$file" "$fpr" "$sig_b64" "$timestamp" "$signatory" "$file_type")

    echo "$sig_block" >> "$file"
    echo "Signed (whole-file): ${file}" >&2
}

## CAMUS-SL
# intent: generate a CAMUS-SIGNATURE block for a shell function
# input[4]{param,desc}:
#   $1,base64 signature
#   $2,fingerprint
#   $3,timestamp
#   $4,signatory
# output:
#   stdout: formatted CAMUS-SIGNATURE block
## CAMUS-END
format_func_signature_block() {
    local sig_b64="$1" fpr="$2" timestamp="$3" signatory="$4"

    echo "## CAMUS-SIGNATURE"
    echo "# signatory: ${signatory}"
    echo "# date: ${timestamp}"
    echo "# fingerprint: sha256:${fpr}"
    echo "# signature: ${sig_b64}"
    echo "## CAMUS-END"
}

## CAMUS-SL
# intent: find the CAMUS-SL block preceding a function definition
# input[2]{param,desc}:
#   $1,file path
#   $2,line number of the function definition
# output:
#   stdout: the SL block content (including markers), or empty string
## CAMUS-END
find_sl_block() {
    local file="$1" func_line="$2"
    local search_end=$((func_line - 1))
    local sl_line
    sl_line=$(sed -n "1,${search_end}p" "$file" \
        | grep -n '^## CAMUS-SL$' | tail -1 | cut -d: -f1)
    if [ -z "$sl_line" ]; then
        echo ""; return
    fi
    local end_line
    end_line=$(sed -n "${sl_line},\$p" "$file" \
        | grep -n '^## CAMUS-END$' | head -1 | cut -d: -f1)
    if [ -z "$end_line" ]; then
        echo ""; return
    fi
    end_line=$((sl_line + end_line - 1))
    if [ "$end_line" -ge "$func_line" ]; then
        end_line=$((func_line - 1))
    fi
    sed -n "${sl_line},${end_line}p" "$file"
}

## CAMUS-SL
# intent: count brace depth for a single line, respecting heredocs
# input[4]{param,desc}:
#   $1,current depth
#   $2,line text
#   $3,in_heredoc flag (0 or 1)
#   $4,heredoc delimiter
# output:
#   stdout: "new_depth in_heredoc delimiter" (space-separated)
## CAMUS-END
track_brace_depth() {
    local depth="$1" line="$2" in_hdoc="$3" delim="$4"

    if [ "$in_hdoc" -eq 0 ]; then
        if echo "$line" | grep -qE '<<\s*[-]?\w+$'; then
            in_hdoc=1
            delim=$(echo "$line" | sed 's/.*<<[-]\?//' | awk '{print $1}')
        elif echo "$line" | grep -qE '<<-\s*\w+$'; then
            in_hdoc=2
            delim=$(echo "$line" | sed 's/.*<<-//' | awk '{print $1}')
        fi
    elif [ "$in_hdoc" -eq 1 ] && echo "$line" | grep -q "^${delim}$"; then
        in_hdoc=0; delim=""
    elif [ "$in_hdoc" -eq 2 ] && echo "$line" \
        | grep -q "^[[:space:]]*${delim}$"; then
        in_hdoc=0; delim=""
    fi

    if [ "$in_hdoc" -eq 0 ]; then
        local open_br=$(echo "$line" | tr -cd '{' | wc -c)
        local close_br=$(echo "$line" | tr -cd '}' | wc -c)
        depth=$((depth + open_br - close_br))
    fi

    echo "${depth} ${in_hdoc} ${delim}"
}

## CAMUS-SL
# intent: get the body of a function (from definition to closing brace)
# input[2]{param,desc}:
#   $1,file path
#   $2,line number of the function definition
# output:
#   stdout: end_line: the last line of the function (on last line)
## CAMUS-END
get_function_body() {
    local file="$1" start_line="$2"
    local line_num=0 brace_depth=0 started=0 content=""
    local end_line=0 in_heredoc=0 heredoc_delim=""
    local state

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [ "$line_num" -lt "$start_line" ] && continue
        [ "$started" -eq 0 ] && started=1

        state=$(track_brace_depth \
            "$brace_depth" "$line" "$in_heredoc" "$heredoc_delim")
        brace_depth=$(echo "$state" | cut -d' ' -f1)
        in_heredoc=$(echo "$state" | cut -d' ' -f2)
        heredoc_delim=$(echo "$state" | cut -d' ' -f3-)

        content="${content}${line}"$'\n'

        if [ "$brace_depth" -le 0 ] \
            && [ "$started" -eq 1 ] \
            && [ "$line_num" -gt "$start_line" ]; then
            printf '%s' "$content"
            echo "END_LINE:${line_num}"
            return
        fi
    done < "$file"

    printf '%s' "$content"
    echo "END_LINE:${line_num}"
}

## CAMUS-SL
# intent: scan a shell script and record function start/end line ranges
# input[1]{param,desc}:
#   $1,file path
# output:
#   stdout: "start:end" pairs, one per line, in order
## CAMUS-END
scan_functions() {
    local file="$1"
    local line_num=0 in_func=0 brace_depth=0 func_start=0
    local in_heredoc=0 heredoc_delim="" state

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$in_func" -eq 0 ]; then
            if echo "$line" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\(\) \{'; then
                in_func=1; func_start=$line_num; brace_depth=0
                state=$(track_brace_depth \
                    "$brace_depth" "$line" "$in_heredoc" "$heredoc_delim")
                brace_depth=$(echo "$state" | cut -d' ' -f1)
                if [ "$brace_depth" -le 0 ]; then
                    in_func=0
                    echo "${func_start}:${line_num}"
                fi
            fi
        else
            state=$(track_brace_depth \
                "$brace_depth" "$line" "$in_heredoc" "$heredoc_delim")
            brace_depth=$(echo "$state" | cut -d' ' -f1)
            in_heredoc=$(echo "$state" | cut -d' ' -f2)
            heredoc_delim=$(echo "$state" | cut -d' ' -f3-)

            if [ "$brace_depth" -le 0 ] && [ "$line_num" -gt "$func_start" ]; then
                in_func=0
                echo "${func_start}:${line_num}"
            fi
        fi
    done < "$file"

    chmod --reference="$file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$file"
    echo "Signed ${idx} function(s) in ${file}" >&2
}

## CAMUS-SL
# intent: insert CAMUS-SIGNATURE blocks for all unsigned functions in a file
# input[6]{param,desc}:
#   $1,file path
#   $2,private key path
#   $3,password
#   $4,fingerprint
#   $5,timestamp
#   $6,signatory
## CAMUS-END
insert_func_sig_blocks() {
    local file="$1" privkey="$2" password="$3"
    local fpr="$4" timestamp="$5" signatory="$6"

    local func_data_str
    func_data_str=$(scan_functions "$file")
    [ -z "$func_data_str" ] && { echo "No functions found" >&2; return; }

    local temp_file func_s func_e line_num=0 idx=0 in_sig=0
    temp_file=$(mktemp)
    local -a func_data
    while IFS=: read -r s e; do
        func_data+=("$s:$e")
    done <<< "$func_data_str"
    local total="${#func_data[@]}"

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$in_sig" -eq 1 ]; then
            echo "$line" | grep -q '^## CAMUS-END$' && in_sig=0
            continue
        fi
        if echo "$line" | grep -q '^## CAMUS-SIGNATURE$'; then
            [ "$idx" -lt "$total" ] && in_sig=1
            continue
        fi
        echo "$line" >> "$temp_file"
        if [ "$idx" -lt "$total" ]; then
            func_s="${func_data[$idx]%%:*}"
            func_e="${func_data[$idx]##*:}"
            if [ "$line_num" -eq "$func_e" ]; then
                sign_one_function "$file" "$func_s" "$func_e" \
                    "$privkey" "$password" "$fpr" "$timestamp" \
                    "$signatory" "$temp_file"
                idx=$((idx + 1))
            fi
        fi
    done < "$file"

    chmod --reference="$file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$file"
    echo "Signed ${idx} function(s) in ${file}" >&2
}


## CAMUS-SL
# intent: sign each unsigned function in a shell script
# input[6]{param,desc}:
#   $1,file path
#   $2,private key path
#   $3,public key path
#   $4,password
#   $5,signatory
#   $6,key directory (for fingerprint lookup)
## CAMUS-END
do_sign_per_function() {
    local file="$1" privkey="$2" pubkey="$3" password="$4"
    local signatory="$5" key_dir="$6"
    local timestamp fpr
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fpr=$(fingerprint_of "$pubkey")
    insert_func_sig_blocks \
        "$file" "$privkey" "$password" "$fpr" "$timestamp" "$signatory"
}

## CAMUS-SL
# intent: compute and append a signature block for one function
# input[9]{param,desc}:
#   $1,file path
#   $2,function start line
#   $3,function end line
#   $4,private key path
#   $5,password
#   $6,fingerprint
#   $7,timestamp
#   $8,signatory
#   $9,temp file to append to
## CAMUS-END
sign_one_function() {
    local file="$1" func_s="$2" func_e="$3" privkey="$4"
    local password="$5" fpr="$6" timestamp="$7" signatory="$8"
    local temp_file="$9"

    local sl_start
    sl_start=$(sed -n '1,'"$func_s"'p' "$file" \
        | grep -n '^## CAMUS-SL$' | tail -1 | cut -d: -f1 || true)
    local sl_content=""
    if [ -n "$sl_start" ]; then
        sl_content=$(sed -n "${sl_start},/^## CAMUS-END\$/p" "$file" 2>/dev/null || true)
    fi

    local func_body
    func_body=$(sed -n "${func_s},${func_e}p" "$file")

    local sign_content
    if [ -n "$sl_content" ]; then
        sign_content="${sl_content}"$'\n'"${func_body}"
    else
        sign_content="${func_body}"
    fi

    local sig_b64
    sig_b64=$(compute_signature "$privkey" "$password" "$sign_content")
    local sig_block
    sig_block=$(format_func_signature_block "$sig_b64" "$fpr" "$timestamp" "$signatory")
    echo "$sig_block" >> "$temp_file"
}

## --- Verify helpers ---

## CAMUS-SL
# intent: extract and decode a signature block from a file
# input[3]{param,desc}:
#   $1,file path
#   $2,sig block start line (*camus-sig-1* line)
#   $3,file type ("txt" or "md")
# output:
#   stdout: "content_file sig_block_file sig_b64 fpr date" (tab-separated)
#   return[2]{code,desc}:
#     0,"signature information extracted successfully"
#     E_MALFORMED_SIG,"malformed or missing signature block"
## CAMUS-END
extract_whole_sig_info() {
    local file="$1" sig_line="$2" file_type="$3"
    local content_end
    if [ "$file_type" = "md" ]; then
        content_end=$((sig_line - 4))
    else
        content_end=$((sig_line - 3))
    fi

    local tmp_content tmp_sig_block
    tmp_content=$(mktemp)
    tmp_sig_block=$(mktemp)

    head -n "$content_end" "$file" > "$tmp_content"
    tail -n "+$((sig_line - 2))" "$file" > "$tmp_sig_block"

    local sig_b64 stored_fpr stored_date
    sig_b64=$(grep '^Signature: ' "$tmp_sig_block" | sed 's/^Signature: //')
    stored_fpr=$(grep '^Fingerprint: ' "$tmp_sig_block" \
        | sed 's/^Fingerprint: SHA256://')
    stored_date=$(grep '^Date: ' "$tmp_sig_block" | sed 's/^Date: //')

    if [ -z "$sig_b64" ]; then
        echo "Error: malformed signature block." >&2
        rm -f "$tmp_content" "$tmp_sig_block"
        return $E_MALFORMED_SIG
    fi

    echo "${tmp_content} ${tmp_sig_block} ${sig_b64} ${stored_fpr} ${stored_date}"
}

## CAMUS-SL
# intent: resolve public key by fingerprint or direct path
# input[3]{param,desc}:
#   $1,fingerprint
#   $2,explicit public key path (optional)
#   $3,key directory for auto-detection
# output:
#   stdout: resolved public key path
#   return[3]{code,desc}:
#     0,"public key resolved successfully"
#     I_FALSE,"no matching public key found"
#     E_FILE_NOT_FOUND,"explicit key path does not exist"
## CAMUS-END
resolve_pubkey() {
    local stored_fpr="$1" pubkey="$2" key_dir="$3"
    if [ -z "$pubkey" ]; then
        pubkey=$(find_key_by_fingerprint "$stored_fpr" "$key_dir" || true)
        if [ -z "$pubkey" ]; then
            echo "Error: no public key found for fingerprint" >&2
            return $I_FALSE
        fi
    elif [ ! -f "$pubkey" ]; then
        echo "Error: public key not found: ${pubkey}" >&2
        return $E_FILE_NOT_FOUND
    fi
    echo "$pubkey"
}

## CAMUS-SL
# intent: prepare public key for verification (extract from cert if needed)
# input[2]{param,desc}:
#   $1,path to public key or certificate
#   $2,date string for expiration check
# output:
#   stdout: path to temp file with raw public key
#   return[2]{code,desc}:
#     0,"public key prepared for verification"
#     E_KEY_INVALID_AT_DATE,"key was already expired at signature date"
## CAMUS-END
prepare_pubkey() {
    local pubkey="$1" sig_date="$2"
    local tmp_pubkey
    tmp_pubkey=$(mktemp)

    if head -1 "$pubkey" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
        if ! cert_valid_at "$pubkey" "$sig_date"; then
            local cert_end
            cert_end=$(openssl x509 -in "$pubkey" -noout -enddate 2>/dev/null \
                | cut -d= -f2)
            echo "FAIL -- key was already expired at signature date." >&2
            echo "  Key valid until: ${cert_end}" >&2
            rm -f "$tmp_pubkey"
            return $E_KEY_INVALID_AT_DATE
        fi
        openssl x509 -in "$pubkey" -noout -pubkey > "$tmp_pubkey" 2>/dev/null
    else
        cat "$pubkey" > "$tmp_pubkey"
    fi
    echo "$tmp_pubkey"
}

## CAMUS-SL
# intent: verify a whole-file signature block
# input[4]{param,desc}:
#   $1,file path
#   $2,"public key path (optional, auto-detect by fingerprint if omitted)"
#   $3,key directory (for auto-detection)
#   $4,"file type (txt or md, for signature offset calculation)"
# output:
#   return[5]{code,desc}:
#     E_NO_SIGNATURE,"no signature found in file"
#     *,"propagated from extract_whole_sig_info"
#     *,"propagated from resolve_pubkey"
#     *,"propagated from prepare_pubkey"
#     *,"propagated from verify_sig_against_content"
## CAMUS-END
do_verify_whole_file() {
    local file="$1" pubkey="${2:-}" key_dir="$3" file_type="$4"

    local sig_line
    sig_line=$(grep -n '^\*camus-sig-1\*$' "$file" 2>/dev/null \
        | tail -1 | cut -d: -f1 || true)

    if [ -z "$sig_line" ]; then
        echo "Error: no signature found in file." >&2; return $E_NO_SIGNATURE
    fi

    local sig_info tmp_content tmp_sig_block sig_b64 stored_fpr stored_date
    sig_info=$(extract_whole_sig_info "$file" "$sig_line" "$file_type") || return $?

    tmp_content=$(echo "$sig_info" | cut -d' ' -f1)
    tmp_sig_block=$(echo "$sig_info" | cut -d' ' -f2)
    sig_b64=$(echo "$sig_info" | cut -d' ' -f3)
    stored_fpr=$(echo "$sig_info" | cut -d' ' -f4)
    stored_date=$(echo "$sig_info" | cut -d' ' -f5)

    pubkey=$(resolve_pubkey "$stored_fpr" "$pubkey" "$key_dir") || {
        rm -f "$tmp_content" "$tmp_sig_block"; return $?
    }

    local tmp_pubkey
    tmp_pubkey=$(prepare_pubkey "$pubkey" "$stored_date") || {
        rm -f "$tmp_content" "$tmp_sig_block"; return $?
    }

    verify_sig_against_content \
        "$tmp_content" "$sig_b64" "$tmp_pubkey" "$stored_date" "$pubkey"
    local rc=$?

    rm -f "$tmp_content" "$tmp_sig_block" "$tmp_pubkey"
    return $rc
}

## CAMUS-SL
# intent: verify a base64 signature against file content with a public key
# input[5]{param,desc}:
#   $1,path to content file
#   $2,base64-encoded signature
#   $3,path to raw public key file
#   $4,signature date (for display)
#   $5,original public key path (for display)
# output:
#   stdout: verification result
#   return[2]{code,desc}:
#     0,"signature matches content"
#     E_INVALID_SIG,"signature does not match content"
## CAMUS-END
verify_sig_against_content() {
    local tmp_content="$1" sig_b64="$2" tmp_pubkey="$3"
    local stored_date="$4" pubkey="$5"
    local tmp_sig_bin

    tmp_sig_bin=$(mktemp)
    echo "$sig_b64" | openssl base64 -d -out "$tmp_sig_bin" 2>/dev/null

    if openssl pkeyutl -verify -pubin -inkey "$tmp_pubkey" \
        -rawin -in "$tmp_content" -sigfile "$tmp_sig_bin" 2>/dev/null; then
        local fpr
        fpr=$(fingerprint_of "$pubkey")
        echo "OK -- valid signature (SHA256:${fpr})" >&2
        echo "Date: ${stored_date}" >&2
        rm -f "$tmp_sig_bin"
        return 0
    else
        echo "FAIL -- invalid signature or wrong public key." >&2
        rm -f "$tmp_sig_bin"
        return $E_INVALID_SIG
    fi
}

## CAMUS-SL
# intent: find the function definition line preceding a signature block
# input[2]{param,desc}:
#   $1,file path
#   $2,line number of the CAMUS-SIGNATURE block
# output:
#   stdout: line number of function definition (or 0 if not found)
## CAMUS-END
find_func_def_for_sig() {
    local file="$1" sig_line="$2"
    local search_line=$((sig_line - 1))
    while [ "$search_line" -gt 0 ]; do
        local line_content
        line_content=$(sed -n "${search_line}p" "$file")
        if echo "$line_content" | grep -q '^## CAMUS-SIGNATURE$'; then
            break
        fi
        if echo "$line_content" \
            | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*\)\s*\{'; then
            echo "$search_line"
            return 0
        fi
        search_line=$((search_line - 1))
    done
    echo "0"
}

## CAMUS-SL
# intent: extract signature metadata from a CAMUS-SIGNATURE block
# input[2]{param,desc}:
#   $1,file path
#   $2,line number of the CAMUS-SIGNATURE block
# output:
#   stdout: "sig_b64 fpr date signatory" (tab-separated) or empty on failure
#   return[2]{code,desc}:
#     0,"signature data extracted"
#     E_MALFORMED_SIG,"malformed signature block"
## CAMUS-END
extract_func_sig_data() {
    local file="$1" sig_line="$2"
    local sig_block
    sig_block=$(sed -n "${sig_line},\$p" "$file" \
        | sed -n '/^## CAMUS-SIGNATURE$/,/^## CAMUS-END$/{p;/^## CAMUS-END$/q}')

    local sig_b64 stored_fpr stored_date signatory
    sig_b64=$(echo "$sig_block" | grep '^# signature: ' \
        | sed 's/^# signature: //')
    stored_fpr=$(echo "$sig_block" | grep '^# fingerprint: ' \
        | sed 's/^# fingerprint: sha256://')
    stored_date=$(echo "$sig_block" | grep '^# date: ' \
        | sed 's/^# date: //')
    signatory=$(echo "$sig_block" | grep '^# signatory: ' \
        | sed 's/^# signatory: //')

    if [ -z "$sig_b64" ]; then
        echo "Error: malformed signature block at line ${sig_line}" >&2
        return $E_MALFORMED_SIG
    fi

    echo "${sig_b64}|${stored_fpr}|${stored_date}|${signatory}"
}

## CAMUS-SL
# intent: reconstruct the content that was signed (SL block + function body)
# input[2]{param,desc}:
#   $1,file path
#   $2,function definition line
# output:
#   stdout: signed content
## CAMUS-END
reconstruct_signed_content() {
    local file="$1" func_def_line="$2"
    local body_result func_content="" func_end=0 reading_content=true

    body_result=$(get_function_body "$file" "$func_def_line")

    while IFS= read -r result_line; do
        if echo "$result_line" | grep -q '^END_LINE:'; then
            func_end=$(echo "$result_line" | cut -d: -f2)
            reading_content=false
        elif [ "$reading_content" = true ]; then
            func_content="${func_content}${result_line}"$'\n'
        fi
    done <<< "$body_result"

    func_content="${func_content%$'\n'}"

    local sl_block
    sl_block=$(find_sl_block "$file" "$func_def_line")

    if [ -n "$sl_block" ]; then
        echo "${sl_block}"
    fi
    echo "${func_content}"
}

## CAMUS-SL
# intent: verify a single CAMUS-SIGNATURE block for a specific function
# input[3]{param,desc}:
#   $1,file path
#   $2,line number of the CAMUS-SIGNATURE block
#   $3,public key path
# output:
#   return[4]{code,desc}:
#     E_NO_FUNC_DEF_FOR_SIG,"could not find function definition for signature"
#     *,"propagated from extract_func_sig_data"
#     *,"propagated from prepare_pubkey"
#     *,"propagated from verify_sig_against_content"
## CAMUS-END
verify_func_signature() {
    local file="$1" sig_line="$2" pubkey="$3"

    local sig_data
    sig_data=$(extract_func_sig_data "$file" "$sig_line") || return $?

    local sig_b64 stored_fpr stored_date signatory
    sig_b64=$(echo "$sig_data" | cut -d'|' -f1)
    stored_fpr=$(echo "$sig_data" | cut -d'|' -f2)
    stored_date=$(echo "$sig_data" | cut -d'|' -f3)
    signatory=$(echo "$sig_data" | cut -d'|' -f4)

    local tmp_pubkey
    tmp_pubkey=$(prepare_pubkey "$pubkey" "$stored_date") || return $?

    local func_def_line
    func_def_line=$(find_func_def_for_sig "$file" "$sig_line")

    if [ "$func_def_line" -eq 0 ]; then
        echo "Error: could not find function definition for signature" >&2
        rm -f "$tmp_pubkey"; return $E_NO_FUNC_DEF_FOR_SIG
    fi

    local signed_content
    signed_content=$(reconstruct_signed_content "$file" "$func_def_line")

    local tmp_content_verify
    tmp_content_verify=$(mktemp)
    printf '%s' "$signed_content" > "$tmp_content_verify"
    echo "" >> "$tmp_content_verify"

    verify_sig_against_content \
        "$tmp_content_verify" "$sig_b64" "$tmp_pubkey" \
        "$stored_date" "$pubkey"
    local rc=$?

    rm -f "$tmp_pubkey" "$tmp_content_verify"
    return $rc
}

## CAMUS-SL
# intent: verify all signatures in a Camus.sh script (per-function and whole-file)
# input[3]{param,desc}:
#   $1,file path
#   $2,public key path (optional)
#   $3,key directory (for auto-detection)
# output:
#   return[2]{code,desc}:
#     E_FILE_NOT_FOUND,"file does not exist"
#     *,"propagated from do_verify_whole_file or verify_per_function_sigs"
## CAMUS-END
do_verify() {
    local file="$1" pubkey="${2:-}" key_dir="$3"

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2; return $E_FILE_NOT_FOUND
    fi

    local file_type
    file_type=$(detect_file_type "$file")

    if grep -q '^\*camus-sig-1\*$' "$file"; then
        echo "Verifying whole-file signature: ${file}"
        do_verify_whole_file "$file" "$pubkey" "$key_dir" "$file_type"
        return $?
    fi

    verify_per_function_sigs "$file" "$pubkey"
}

## CAMUS-SL
# intent: verify per-function CAMUS-SIGNATURE blocks in a script
# input[2]{param,desc}:
#   $1,file path
#   $2,public key path (optional)
# output:
#   return[2]{code,desc}:
#     E_NO_SIGNATURE,"no CAMUS-SIGNATURE blocks found in file"
#     *,"propagated from verify_func_signature"
## CAMUS-END
verify_per_function_sigs() {
    local file="$1" pubkey="$2"

    local sig_blocks
    sig_blocks=$(grep -n '^## CAMUS-SIGNATURE$' "$file" 2>/dev/null || true)
    if [ -z "$sig_blocks" ]; then
        echo "No signatures found in ${file}" >&2; return $E_NO_SIGNATURE
    fi

    local total=0 valid=0 invalid=0
    while IFS=: read -r line_num _; do
        total=$((total + 1))
        echo "  Verifying signature at line ${line_num}..."
        if verify_func_signature "$file" "$line_num" "$pubkey"; then
            valid=$((valid + 1))
        else
            invalid=$((invalid + 1))
        fi
    done <<< "$sig_blocks"

    echo ""
    echo "Result: ${valid} valid, ${invalid} invalid out of ${total} signature(s)"
    [ "$invalid" -eq 0 ]
}

## --- Subcommand: sign (dispatcher) ---

## CAMUS-SL
# intent: sign a single file, dispatching to per-function or whole-file mode
# input[7]{param,desc}:
#   $1,file path
#   $2,private key path
#   $3,public key path
#   $4,password
#   $5,signatory
#   $6,force file type (empty for auto-detect)
#   $7,key directory
# output:
#   return[2]{code,desc}:
#     E_FILE_NOT_FOUND,"file does not exist"
#     *,"propagated from sub-functions"
## CAMUS-END
do_sign_file() {
    local file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5"
    local force_type="${6:-}" key_dir="$7"

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2; return $E_FILE_NOT_FOUND
    fi

    if is_signed "$file" && [ -z "$force_type" ]; then
        local file_type
        file_type=$(detect_file_type "$file")
        if [ "$file_type" != "sh" ]; then
            echo "Skipping (already signed): ${file}" >&2; return 0
        fi
    fi

    local file_type
    if [ -n "$force_type" ]; then
        file_type="$force_type"
    else
        file_type=$(detect_file_type "$file")
    fi

    case "$file_type" in
        sh)
            do_sign_per_function "$file" "$privkey" "$pubkey" \
                "$password" "$signatory" "$key_dir"
            ;;
        txt|md|unknown)
            do_sign_whole_file "$file" "$privkey" "$pubkey" \
                "$password" "$signatory" "$file_type"
            ;;
    esac
}

## CAMUS-SL
# intent: check if a key is expired and print appropriate warning
# input[1]{param,desc}:
#   $1,path to public key or certificate
# output:
#   stdout: remaining days info
#   return[2]{code,desc}:
#     0,"key is still valid"
#     6,"key has expired"
## CAMUS-END
check_key_expiry() {
    local pubkey="$1"
    local key_remaining
    key_remaining=$(key_expiry_info "$pubkey") || {
        echo -e "\033[31mError: key expired $((-key_remaining)) day(s) ago.\033[0m" >&2
        return $E_KEY_EXPIRED
    }
    echo "$key_remaining"
}

## CAMUS-SL
# intent: collect signable elements, filter already-signed by me, interactively review
# input[3]{param,desc}:
#   $1,temp file path for approved elements
#   $2,signatory name (for filtering)
#   $3,key fingerprint (for filtering)
#   $@,files and directories to sign
# output:
#   return[3]{code,desc}:
#     0,"at least one element was approved for signing"
#     E_NO_SIGNABLES,"no signable files found in the provided paths"
#     E_NO_APPROVALS,"no elements were approved during interactive review"
## CAMUS-END
collect_signables_interactive() {
    local outfile="$1" signatory="$2" fingerprint="$3"; shift 3
    local all_elements=()

    while IFS= read -r elem; do
        if [ -n "$signatory" ] && [ -n "$fingerprint" ]; then
            local elem_type elem_file elem_start elem_end elem_name
            IFS='|' read -r elem_type elem_file elem_start elem_end elem_name <<< "$elem"
            if [ "$elem_type" = "func" ] && \
                is_function_signed_by_me "$elem_file" "$elem_end" "$signatory" "$fingerprint"; then
                echo "Skipping (already signed by ${signatory}): ${elem_name} in ${elem_file}" >&2
                continue
            fi
        fi
        all_elements+=("$elem")
    done < <(collect_signables "$@")

    [ ${#all_elements[@]} -eq 0 ] && { echo "No signable files found." >&2; return $E_NO_SIGNABLES; }

    local total=${#all_elements[@]}
    for ((i = 0; i < total; i++)); do
        local elem="${all_elements[$i]}"
        local elem_type elem_file elem_start elem_end elem_name
        IFS='|' read -r elem_type elem_file elem_start elem_end elem_name <<< "$elem"
        review_element "$elem_type" "$elem_file" "$elem_start" "$elem_end" \
            "$elem_name" "$((i+1))" "$total"
        case $? in
            0) echo "$elem" >> "$outfile" ;;
            2) break ;;
        esac
    done
    [ ! -s "$outfile" ] && { echo "No elements approved for signing." >&2; return $E_NO_APPROVALS; }
    return 0
}

## CAMUS-SL
# intent: sign approved elements grouped by file
# input[5]{param,desc}:
#   $1,approved elements file (type|file|start|end|name per line)
#   $2,private key path
#   $3,public key path
#   $4,password
#   $5,signatory
## CAMUS-END
sign_approved_elements() {
    local approved_file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5"
    declare -A file_funcs file_types

    while IFS='|' read -r elem_type elem_file elem_start elem_end elem_name; do
        case "$elem_type" in
            func)
                if [ -z "${file_funcs[$elem_file]+x}" ]; then
                    file_funcs["$elem_file"]="${elem_start}:${elem_end}"
                else
                    file_funcs["$elem_file"]+=$'\n'"${elem_start}:${elem_end}"
                fi
                file_types["$elem_file"]="sh"
                ;;
            whole)
                file_funcs["$elem_file"]=""
                file_types["$elem_file"]="$(detect_file_type "$elem_file")"
                ;;
        esac
    done < "$approved_file"

    for elem_file in "${!file_funcs[@]}"; do
        case "${file_types[$elem_file]}" in
            sh)
                sign_selected_functions "$elem_file" "$privkey" "$pubkey" \
                    "$password" "$signatory" "${file_funcs[$elem_file]}"
                ;;
            txt|md|unknown)
                do_sign_whole_file "$elem_file" "$privkey" "$pubkey" \
                    "$password" "$signatory" "${file_types[$elem_file]}"
                ;;
        esac
    done
}

## CAMUS-SL
# intent: collect signable elements from files and directories
# input[1]{param,desc}:
#   $@,files and directories
# output:
#   stdout: "type|file|start|end|name" lines (type: func or whole)
## CAMUS-END
collect_signables() {
    local items=()
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            while IFS= read -r f; do
                items+=("$f")
            done < <(find "$arg" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.txt' \) | sort)
        elif [ -f "$arg" ]; then
            items+=("$arg")
        else
            echo "[${idx}/${total}] Not found: ${arg}" >&2
        fi
    done
    local item file_type func_name
    for item in "${items[@]}"; do
        file_type=$(detect_file_type "$item")
        case "$file_type" in
            sh)
                while IFS=: read -r func_s func_e; do
                    func_name=$(sed -n "${func_s}p" "$item" | sed 's/() {.*//')
                    echo "func|${item}|${func_s}|${func_e}|${func_name}"
                done < <(scan_functions "$item")
                ;;
            txt|md|unknown)
                echo "whole|${item}|||"
                ;;
        esac
    done
}

## CAMUS-SL
# intent: display a signable element and ask for approval
# input[7]{param,desc}:
#   $1,element type (func or whole)
#   $2,file path
#   $3,function start line
#   $4,function end line
#   $5,function name
#   $6,element index (1-based)
#   $7,total elements
# output:
#   return[4]{code,desc}:
#     0,"user approved the element"
#     E_FILE_NOT_FOUND,"file does not exist"
#     1,"user refused the element"
#     2,"user interrupted the review"
## CAMUS-END
review_element() {
    local elem_type="$1" file="$2" start="$3" end="$4" name="$5" idx="$6" total="$7"
    local PAGER="${PAGER:-less}"
    local answer

    if [ ! -f "$file" ]; then
        echo "[${idx}/${total}] Not found: ${file}" >&2
        return $E_FILE_NOT_FOUND
    fi

    echo "[${idx}/${total}] --- ${file}" >&2
    case "$elem_type" in
        func)
            echo "         Function: ${name} (lines ${start}-${end})" >&2
            local sl_block
            sl_block=$(find_sl_block "$file" "$start" || true)
            local tmp_display; tmp_display=$(mktemp)
            [ -n "$sl_block" ] && echo "$sl_block" >> "$tmp_display"
            sed -n "${start},${end}p" "$file" >> "$tmp_display"
            "$PAGER" "$tmp_display" 2>/dev/null || cat "$tmp_display"
            rm -f "$tmp_display"
            ;;
        whole)
            "$PAGER" "$file" 2>/dev/null || cat "$file"
            ;;
    esac
    echo >&2

    while true; do
        read -r -p "[${idx}/${total}] Sign? [y/n/i(interrupt)] " answer
        echo >&2
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            i|interrupt) return 2 ;;
        esac
    done
}

## CAMUS-SL
# intent: sign one function and insert its signature block into a temp file
# input[10]{param,desc}:
#   $1,file path
#   $2,function start line
#   $3,function end line
#   $4,private key path
#   $5,password
#   $6,fingerprint
#   $7,timestamp
#   $8,signatory
#   $9,output temp file path
#   $10,SL content (pre-extracted)
## CAMUS-END
sign_one_func_to_temp() {
    local file="$1" func_s="$2" func_e="$3" privkey="$4"
    local password="$5" fpr="$6" timestamp="$7" signatory="$8"
    local temp_file="$9" sl_content="${10}"

    local func_body
    func_body=$(sed -n "${func_s},${func_e}p" "$file")

    local sign_content
    if [ -n "$sl_content" ]; then
        sign_content="${sl_content}"$'\n'"${func_body}"
    else
        sign_content="${func_body}"
    fi

    local sig_b64
    sig_b64=$(compute_signature "$privkey" "$password" "$sign_content")
    local sig_block
    sig_block=$(format_func_signature_block "$sig_b64" "$fpr" "$timestamp" "$signatory")
    echo "$sig_block" >> "$temp_file"
}

## CAMUS-SL
# intent: initialize per-function range data arrays from a ranges string
# input[5]{param,desc}:
#   $1,file path
#   $2,newline-separated "start:end" ranges
#   $3,end_lines array name (nameref)
#   $4,func_starts array name (nameref)
#   $5,sl_blocks array name (nameref)
## CAMUS-END
init_sign_range_data() {
    local file="$1" ranges_str="$2"
    local -n _ends="$3" _starts="$4" _sls="$5"
    local range sl_start
    while IFS= read -r range; do
        [ -z "$range" ] && continue
        _ends+=("${range##*:}")
        _starts+=("${range%%:*}")
        sl_start=$(sed -n '1,'"${range%%:*}"'p' "$file" \
            | grep -n '^## CAMUS-SL$' | tail -1 | cut -d: -f1 || true)
        if [ -n "$sl_start" ]; then
            _sls+=("$(sed -n "${sl_start},/^## CAMUS-END\$/p" "$file" 2>/dev/null || true)")
        else
            _sls+=("")
        fi
    done <<< "$ranges_str"
}

## CAMUS-SL
# intent: check if a signature block belongs to a function being signed this pass
# input[1]{param,desc}:
#   $1,line number of ## CAMUS-SIGNATURE
# output:
#   return[1]{code,desc}:
#     0,belongs to a signed function
#     1,does not belong
## CAMUS-END
sig_belongs_to_signed() {
    local line_num="$1"; shift
    local end
    for end in "$@"; do
        [ "$((line_num - 1))" -eq "$end" ] && return 0
        [ "$((line_num - 2))" -eq "$end" ] && return 0
        [ "$((line_num - 3))" -eq "$end" ] && return 0
    done
    return $I_FALSE
}

## CAMUS-SL
# intent: sign selected functions in a .sh file in one pass
# input[6]{param,desc}:
#   $1,file path
#   $2,private key path
#   $3,public key path
#   $4,password
#   $5,signatory
#   $6,newline-separated "start:end" ranges to sign
## CAMUS-END
sign_selected_functions() {
    local file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5"
    local ranges_str="$6"

    local timestamp fpr; timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ"); fpr=$(fingerprint_of "$pubkey")
    local temp_file; temp_file=$(mktemp)
    local line_num=0 in_sig=0 idx=0
    local -a end_lines func_starts sl_blocks

    init_sign_range_data "$file" "$ranges_str" end_lines func_starts sl_blocks

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$in_sig" -eq 1 ]; then
            echo "$line" | grep -q '^## CAMUS-END$' && in_sig=0
            continue
        fi
        if echo "$line" | grep -q '^## CAMUS-SIGNATURE$'; then
            if sig_belongs_to_signed "$line_num" "${end_lines[@]}"; then
                in_sig=1; continue
            fi
            echo "$line" >> "$temp_file"
            continue
        fi
        echo "$line" >> "$temp_file"
        if [ "$idx" -lt "${#end_lines[@]}" ] && [ "$line_num" -eq "${end_lines[$idx]}" ]; then
            sign_one_func_to_temp "$file" "${func_starts[$idx]}" "${end_lines[$idx]}" \
                "$privkey" "$password" "$fpr" "$timestamp" "$signatory" \
                "$temp_file" "${sl_blocks[$idx]}"
            idx=$((idx + 1))
        fi
    done < "$file"

    chmod --reference="$file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$file"
    echo "Signed ${idx} function(s) in ${file}" >&2
}

## CAMUS-SL
# intent: print a color-coded key expiry warning
# input[1]{param,desc}:
#   $1,remaining days
# output:
#   stdout: warning message
## CAMUS-END
print_key_expiry_warning() {
    local remaining="$1"
    if [ "$remaining" -lt 7 ]; then
        echo -e "\033[31mKey expires in ${remaining} day(s).\033[0m"
    elif [ "$remaining" -lt 30 ]; then
        echo -e "\033[33mKey expires in ${remaining} day(s).\033[0m"
    else
        echo "Key expires in ${remaining} day(s)."
    fi
}

## --- Command dispatchers ---

## CAMUS-SL
# intent: handle the init subcommand argument parsing and dispatch
# input[1]{param,desc}:
#   $1,default key directory
## CAMUS-END
cmd_init() {
    local key_dir="$1"; shift
    local days=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --key-dir) shift; key_dir="$1" ;;
            --days) shift; days="$1" ;;
            *)
                die_unknown_option "$1"
                ;;
        esac
        shift
    done
    do_gen_key "$key_dir" "${days:-365}"
}

## CAMUS-SL
# intent: handle the check subcommand
## CAMUS-END
cmd_check() {
    [ $# -ge 1 ] || die_missing_arg
    do_check "$1"
}

## CAMUS-SL
# intent: expand file and directory arguments into a list of signable files
# input[1]{param,desc}:
#   $@,files or directories to expand
# output:
#   stdout: one file path per line (.sh, .md, .txt)
## CAMUS-END
collect_sign_files() {
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            find "$arg" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.txt' \) | sort
        elif [ -f "$arg" ]; then
            echo "$arg"
        else
            echo "Warning: not found: ${arg}" >&2
        fi
    done
}

## CAMUS-SL
# intent: handle the sign subcommand — purge, check, collect, review, then sign
# input[1]{param,desc}:
#   $1,default key directory
## CAMUS-END
cmd_sign() {
    local key_dir="$1"; shift; local signatory=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --key-dir) shift; key_dir="$1"; shift ;;
            --signatory) shift; signatory="$1"; shift ;;
            *) break ;;
        esac
    done
    [ $# -lt 1 ] && die_missing_arg

    local privkey="${key_dir}/private.pem" pubkey="${key_dir}/public.pem"
    [ ! -f "$privkey" ] && { echo "Error: private key not found." >&2; exit $E_KEY_NOT_FOUND; }
    [ ! -f "$pubkey" ] && { echo "Error: public key not found." >&2; exit $E_KEY_NOT_FOUND; }

    local fpr; fpr=$(fingerprint_of "$pubkey")
    [ -z "$signatory" ] && read -r -p "Signatory name: " signatory
    [ -z "$signatory" ] && { echo "Error: signatory cannot be empty." >&2; exit $E_SIGNATORY_EMPTY; }
    local key_remaining;     key_remaining=$(check_key_expiry "$pubkey") || exit $E_KEY_EXPIRED

    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(collect_sign_files "$@")
    for f in "${files[@]}"; do purge_invalid_signatures "$f" "$pubkey"; done
    for f in "${files[@]}"; do
        [ "$(detect_file_type "$f")" != "sh" ] && continue
        echo "--- Running check on ${f} ---" >&2
        do_check "$f"; [ $? -eq $E_CHECK_FAILED ] && { echo "Error: check failed. Aborting." >&2; exit $E_CHECK_FAILED; }
    done

    local temp_approved; temp_approved=$(mktemp)
    collect_signables_interactive "$temp_approved" "$signatory" "$fpr" \
        "${files[@]}" || { rm -f "$temp_approved"; exit 0; }

    local password=""
    while ! password=$(prompt_password "Enter private key password: ") \
        || ! openssl pkey -in "$privkey" -passin "pass:${password}" -noout 2>/dev/null; do
        echo "Incorrect password, try again." >&2
    done

    sign_approved_elements "$temp_approved" "$privkey" "$pubkey" "$password" "$signatory"
    rm -f "$temp_approved"
    print_key_expiry_warning "$key_remaining"
}

## CAMUS-SL
# intent: handle the verify subcommand argument parsing and dispatch
# input[2]{param,desc}:
#   $1,default key directory
#   $2,remaining arguments
## CAMUS-END
cmd_verify() {
    local key_dir="$1"; shift
    local pubkey=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --pubkey) shift; pubkey="$1" ;;
            --key-dir) shift; key_dir="$1" ;;
            *) break ;;
        esac
        shift
    done
    [ $# -ge 1 ] || die_missing_arg

    if [ -z "$pubkey" ]; then
        pubkey="${key_dir}/public.pem"
    fi
    if [ ! -f "$pubkey" ]; then
        pubkey=""
    fi

    do_verify "$1" "$pubkey" "$key_dir"
}

## CAMUS-SL
# intent: handle the list-keys subcommand
# input[1]{param,desc}:
#   $1,default key directory
## CAMUS-END
cmd_list_keys() {
    local key_dir="$1"; shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --key-dir) shift; key_dir="$1" ;;
            *)
                die_unknown_option "$1"
                ;;
        esac
        shift
    done
    do_list_keys "$key_dir"
}

## --- Main ---

## CAMUS-SL
# intent: parse arguments and dispatch to the appropriate subcommand
## CAMUS-END
main() {
    if [ $# -eq 0 ]; then
        usage
        exit $E_MISSING_ARG
    fi

    local key_dir cmd
    key_dir="${CAMUS_KEY_PATH:-$HOME/.config/camus}"

    cmd="$1"
    shift

    case "$cmd" in
        init) cmd_init "$key_dir" "$@" ;;
        check) cmd_check "$@" ;;
        sign) cmd_sign "$key_dir" "$@" ;;
        verify) cmd_verify "$key_dir" "$@" ;;
        list-keys) cmd_list_keys "$key_dir" "$@" ;;
        -h|--help|help) usage ;;
        *)
            echo "Error: unknown command: $cmd" >&2
            usage
            exit $E_UNKNOWN_OPTION
            ;;
    esac
}

main "$@"
