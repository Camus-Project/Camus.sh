#!/bin/bash

## CAMUS-LEXICON
# key-pair: Ed25519 cryptographic key pair (private + public)
# fingerprint: SHA256 digest of the public key, used as identifier
# signature-block: metadata block appended after a function or at end-of-file
# camus-block: a metadata block delimited by ## CAMUS- and ## CAMUS-END
# compliance-check: validation of a script against the Camus.sh specification
# whole-file-signature: signature covering an entire non-shell file (.txt, .md)
# per-function-signature: signature covering a single function + its CAMUS-SL block
## CAMUS-END

## CAMUS-SL
# intent: print usage information and exit
# output:
#   stdout: usage message
## CAMUS-END
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options] [<file>...]

Commands:
  init       [--key-dir <path>]    Generate Ed25519 key pair
  check      <file>                Check script compliance with Camus.sh
  sign       [options] <file>...   Sign file(s)
  verify     [options] <file>      Verify signature(s)
  list-keys  [--key-dir <path>]    List available public keys

Sign options:
  --txt, --text            Force whole-file text mode (--- separator)
  --md, --markdown         Force whole-file markdown mode (--- + <pre>)
  --pubkey <path>          Use specific public key for verification

Init options:
  --key-dir <path>         Key storage directory (default: .secrets/)

Verify options:
  --pubkey <path>          Use specific public key for verification
EOF
    exit 1
}
## CAMUS-SL
# intent: get the directory where the script resides
# output:
#   stdout: absolute path to the script's directory
## CAMUS-END
kiss_dir() {
    cd "$(dirname "$0")" || exit
    pwd -P
}
## CAMUS-SL
# intent: prompt the user for a password (hidden input)
# input:
#   $1: prompt message (optional, default: "Enter password: ")
# output:
#   stdout: the entered password
## CAMUS-END
prompt_password() {
    local prompt="${1:-Enter password: }"
    if [ -n "${PASSWORD:-}" ]; then
        echo "$PASSWORD"
        return
    fi
    local password
    read -r -s -p "$prompt" password
    echo >&2
    if [ -z "$password" ]; then
        echo "Error: password cannot be empty." >&2
        exit 1
    fi
    echo "$password"
}
## CAMUS-SL
# intent: prompt the user for a password twice to confirm
# input:
#   $1: prompt message (optional)
# output:
#   stdout: the confirmed password
## CAMUS-END
prompt_password_twice() {
    local prompt="${1:-Enter password: }"
    local p1 p2
    p1=$(prompt_password "$prompt")
    p2=$(prompt_password "Confirm password: ")
    if [ "$p1" != "$p2" ]; then
        echo "Error: passwords do not match." >&2
        exit 1
    fi
    echo "$p1"
}
## CAMUS-SL
# intent: compute the SHA256 fingerprint of a certificate or public key
# input:
#   $1: path to public key file
# output:
#   stdout: colon-formatted SHA256 fingerprint
## CAMUS-END
fingerprint_of() {
    local key="$1"
    if head -1 "$key" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
        openssl x509 -in "$key" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2
    else
        openssl pkey -in "$key" -pubin -outform DER 2>/dev/null | openssl dgst -sha256 | cut -d' ' -f2
    fi
}
## CAMUS-SL
# intent: normalize a fingerprint string for use as a filename
# input:
#   $1: fingerprint string
# output:
#   stdout: fingerprint with all spaces and colons removed
## CAMUS-END
fingerprint_filepath() {
    echo "$1" | tr -d ' :'
}
## CAMUS-SL
# intent: find a public key file by its fingerprint
# input:
#   $1: fingerprint to search for
#   $2: key directory to search in
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
    return 1
}
## CAMUS-SL
# intent: check certificate expiration status at a given date
# input:
#   $1: path to certificate
#   $2: ISO 8601 date string to check against
# output:
#   return 0 if valid, 1 if expired
## CAMUS-END
cert_valid_at() {
    local pubkey="$1" sig_date="$2"
    local cert_end
    cert_end=$(openssl x509 -in "$pubkey" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$cert_end" ]; then
        return 0
    fi
    local cert_epoch sig_epoch
    cert_epoch=$(date -d "$cert_end" +%s 2>/dev/null || echo 0)
    sig_epoch=$(date -d "$sig_date" +%s 2>/dev/null || echo 0)
    if [ "$sig_epoch" -le "$cert_epoch" ] 2>/dev/null; then
        return 0
    fi
    return 1
}
## CAMUS-SL
# intent: extract remaining validity days of a certificate
# input:
#   $1: path to certificate
# output:
#   stdout: number of remaining days (negative if expired)
## CAMUS-END
key_expiry_info() {
    local cert="$1"
    local end_date
    end_date=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2) || { echo ""; return 1; }
    local end_epoch now_epoch
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null) || { echo ""; return 1; }
    now_epoch=$(date +%s)
    local remaining=$(( (end_epoch - now_epoch) / 86400 ))
    echo "$remaining"
    [ "$remaining" -ge 0 ]
}
## CAMUS-SL
# intent: extract raw public key from an X.509 certificate
# input:
#   $1: path to certificate
# output:
#   stdout: PEM-encoded public key
## CAMUS-END
extract_pubkey_from_cert() {
    openssl x509 -in "$1" -noout -pubkey 2>/dev/null
}
## CAMUS-SL
# intent: detect file type for signing mode
# input:
#   $1: file path
# output:
#   stdout: "sh", "txt", "md", or "unknown"
## CAMUS-END
detect_file_type() {
    local file="$1"
    case "${file,,}" in
        *.sh) echo "sh" ;;
        *.txt) echo "txt" ;;
        *.md|*.markdown) echo "md" ;;
        *) echo "unknown" ;;
    esac
}
## CAMUS-SL
# intent: check if a file already has a camus-sig-1 marker
# input:
#   $1: file path
# output:
#   return 0 if signed, 1 if not
## CAMUS-END
is_signed() {
    local file="$1"
    grep -qs '^\*camus-sig-1\*$' "$file"
}
## --- Subcommand: list-keys ---

## CAMUS-SL
# intent: list all available public keys in the key directory
# input:
#   $1: key directory
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
            expiry=$(openssl x509 -in "$f" -noout -enddate 2>/dev/null | cut -d= -f2)
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
# intent: generate an Ed25519 key pair with password-protected private key
# input:
#   $1: key directory
#   $2: certificate validity in days (default: 365)
## CAMUS-END
do_gen_key() {
    local key_dir="$1"
    local days="${2:-365}"

    mkdir -p "$key_dir"

    local password
    password=$(prompt_password_twice "Enter new private key password: ")

    local tmp_key tmp_cert
    tmp_key=$(mktemp)
    tmp_cert=$(mktemp)

    openssl req -x509 -newkey ed25519 \
        -keyout "$tmp_key" -out "$tmp_cert" \
        -days "$days" \
        -passout "pass:${password}" \
        -subj "/CN=Camus.sh Key/O=Camus Project" \
        2>/dev/null

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
    expiry=$(openssl x509 -in "$named_cert" -noout -enddate 2>/dev/null | cut -d= -f2)

    echo "Key fingerprint: SHA256:${fpr}" >&2
    echo "Valid until: ${expiry}" >&2
    echo "Private key: ${named_key}" >&2
    echo "Public cert: ${named_cert}" >&2
}
## --- Subcommand: check ---

## CAMUS-SL
# intent: check a shell script for compliance with the Camus.sh specification
# input:
#   $1: file path to check
# output:
#   stdout: compliance report
#   return: 0 if fully compliant, 1 if warnings, 2 if errors
## CAMUS-END
do_check() {
    local file="$1"
    local errors=0
    local warnings=0

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2
        return 2
    fi

    echo "Checking: ${file}"
    echo ""

    # 1. Shebang
    if head -1 "$file" | grep -q '^#!' 2>/dev/null; then
        echo "  [OK] Shebang present"
    else
        echo "  [ERROR] No shebang found (MUST start with #!)"
        errors=$((errors + 1))
    fi

    # 2. CAMUS-LEXICON (SHOULD)
    if grep -qs '^## CAMUS-LEXICON$' "$file"; then
        echo "  [OK] CAMUS-LEXICON block present"
    else
        echo "  [WARN] No CAMUS-LEXICON block (SHOULD define project terms)"
        warnings=$((warnings + 1))
    fi

    # 3. No function keyword (MUST use name() {} syntax)
    if grep -qs '^function ' "$file"; then
        echo "  [ERROR] 'function' keyword used (MUST use name() {} syntax)"
        errors=$((errors + 1))
    else
        echo "  [OK] No 'function' keyword"
    fi

    # 4. main() defined (MUST)
    if grep -qs '^main()' "$file" || grep -qs '^main ()' "$file"; then
        echo "  [OK] main() defined"
    else
        echo "  [ERROR] main() not defined (MUST have a main function)"
        errors=$((errors + 1))
    fi

    # 5. main "$@" at end (MUST)
    if tail -1 "$file" | grep -q '^main "\$@"$' 2>/dev/null; then
        echo "  [OK] Script ends with main \"\$@\""
    elif grep -q '^main "\$@"$' "$file"; then
        echo "  [OK] main \"\$@\" present (though not on last line)"
    else
        echo "  [ERROR] main \"\$@\" not found (MUST invoke main at end)"
        errors=$((errors + 1))
    fi

    # Check for top-level executable code before main()
    # We find the line of the first function definition
    local first_func_line
    first_func_line=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*() {' "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)
    if [ -n "$first_func_line" ] && [ "$first_func_line" -gt 2 ]; then
        # Check lines between shebang (line 1) and first function
        local suspect
        suspect=$(sed -n "2,$((first_func_line - 1))p" "$file" 2>/dev/null \
            | grep -v '^#' | grep -v '^$' \
            | grep -v '^## CAMUS-' | grep -v '^## CAMUS-END$' || true)
        if [ -n "$suspect" ]; then
            echo "  [ERROR] Top-level executable code found before first function"
            errors=$((errors + 1))
        else
            echo "  [OK] No top-level executable code"
        fi
    else
        echo "  [OK] No top-level executable code"
    fi

    # 6. Functions preceded by CAMUS-SL
    local func_lines
    func_lines=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*() {' "$file" 2>/dev/null || true)
    if [ -n "$func_lines" ]; then
        local missing_sl=0
        while IFS=: read -r line_num line_content; do
            if [ "$line_num" -le 2 ]; then
                continue
            fi
            local prev_line=$((line_num - 1))
            local block_start
            block_start=$(sed -n '1,'"$prev_line"'p' "$file" \
                | tac | grep -n '^## CAMUS-SL$' -m1 \
                | head -1 | cut -d: -f1 || true)
            if [ -z "$block_start" ]; then
                echo "  [ERROR] Function at line ${line_num} has no preceding CAMUS-SL block"
                missing_sl=$((missing_sl + 1))
            fi
        done <<< "$func_lines"
        if [ "$missing_sl" -eq 0 ]; then
            echo "  [OK] All functions preceded by CAMUS-SL blocks"
        else
            errors=$((errors + missing_sl))
        fi
    fi

    # 7. Check that CAMUS-SL blocks contain intent:
    local sl_blocks
    sl_blocks=$(grep -n '^## CAMUS-SL$' "$file" 2>/dev/null || true)
    if [ -n "$sl_blocks" ]; then
        local missing_intent=0
        while IFS=: read -r line_num line_content; do
            local end_line
            end_line=$(sed -n "$line_num,\$p" "$file" | grep -n '^## CAMUS-END$' | head -1 | cut -d: -f1)
            if [ -n "$end_line" ]; then
                end_line=$((line_num + end_line - 1))
                local block_content
                block_content=$(sed -n "$((line_num + 1)),$((end_line - 1))p" "$file" 2>/dev/null)
                if ! echo "$block_content" | grep -qs '# intent:'; then
                    echo "  [ERROR] CAMUS-SL block at line ${line_num} missing 'intent:'"
                    missing_intent=$((missing_intent + 1))
                fi
            fi
        done <<< "$sl_blocks"
        if [ "$missing_intent" -eq 0 ]; then
            echo "  [OK] All CAMUS-SL blocks declare intent:"
        else
            errors=$((errors + missing_intent))
        fi
    fi

    # 8. Camus blocks properly closed
    local total_end
    total_end=$(grep -c '^## CAMUS-END$' "$file" 2>/dev/null || true)
    local total_camus
    total_camus=$(grep -c '^## CAMUS-' "$file" 2>/dev/null || true)
    local open_blocks=$((total_camus - total_end))
    if [ "$open_blocks" -eq "$total_end" ]; then
        echo "  [OK] All Camus blocks properly closed"
    else
        echo "  [ERROR] ${open_blocks} opening markers but ${total_end} closing markers"
        errors=$((errors + 1))
    fi

    # 9. Function length (MUST ≤ 50, SHOULD ≤ 20)
    local long_funcs=0
    local very_long_funcs=0
    local current_func_name=""
    local brace_depth=0
    local in_func=0
    local func_line_count=0
    local prev_line_num=0
    while IFS= read -r line_content; do
        prev_line_num=$((prev_line_num + 1))
        local func_pat='^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*'
        if [[ "$line_content" =~ ${func_pat}\{ ]] \
            || [[ "$line_content" =~ ${func_pat}$ ]]; then
            if [ $in_func -eq 1 ]; then
                if [ "$func_line_count" -gt 50 ]; then
                    very_long_funcs=$((very_long_funcs + 1))
                    errors=$((errors + 1))
                    echo "  [ERROR] Function '${current_func_name}' is ${func_line_count} lines (MUST ≤ 50)"
                elif [ "$func_line_count" -gt 20 ]; then
                    long_funcs=$((long_funcs + 1))
                    warnings=$((warnings + 1))
                    echo "  [WARN] Function '${current_func_name}' is ${func_line_count} lines (SHOULD ≤ 20)"
                fi
            fi
            current_func_name=$(echo "$line_content" | sed 's/(.*//' | tr -d ' ')
            in_func=1
            func_line_count=1
            brace_depth=0
            local open_br
            open_br=$(echo "$line_content" | tr -cd '{' | wc -c)
            brace_depth=$((brace_depth + open_br))
            local close_br
            close_br=$(echo "$line_content" | tr -cd '}' | wc -c)
            brace_depth=$((brace_depth - close_br))
        elif [ $in_func -eq 1 ]; then
            func_line_count=$((func_line_count + 1))
            local open_br close_br
            open_br=$(echo "$line_content" | tr -cd '{' | wc -c)
            close_br=$(echo "$line_content" | tr -cd '}' | wc -c)
            if [ "$brace_depth" -gt 0 ] || echo "$line_content" | grep -q '{'; then
                brace_depth=$((brace_depth + open_br - close_br))
                if [ "$brace_depth" -le 0 ]; then
                    if [ "$func_line_count" -gt 50 ]; then
                        very_long_funcs=$((very_long_funcs + 1))
                        errors=$((errors + 1))
                        echo "  [ERROR] Function '${current_func_name}' is ${func_line_count} lines (MUST ≤ 50)"
                    elif [ "$func_line_count" -gt 20 ]; then
                        long_funcs=$((long_funcs + 1))
                        warnings=$((warnings + 1))
                        echo "  [WARN] Function '${current_func_name}' is ${func_line_count} lines (SHOULD ≤ 20)"
                    fi
                    in_func=0
                fi
            fi
            if echo "$line_content" | grep -q '^## CAMUS-SIGNATURE$'; then
                if [ "$func_line_count" -gt 50 ]; then
                    very_long_funcs=$((very_long_funcs + 1))
                    errors=$((errors + 1))
                    echo "  [ERROR] Function '${current_func_name}' is ${func_line_count} lines (MUST ≤ 50)"
                elif [ "$func_line_count" -gt 20 ]; then
                    long_funcs=$((long_funcs + 1))
                    warnings=$((warnings + 1))
                    echo "  [WARN] Function '${current_func_name}' is ${func_line_count} lines (SHOULD ≤ 20)"
                fi
                in_func=0
            fi
        fi
    done < "$file"

    if [ $in_func -eq 1 ]; then
        if [ "$func_line_count" -gt 50 ]; then
            very_long_funcs=$((very_long_funcs + 1))
            errors=$((errors + 1))
            echo "  [ERROR] Function '${current_func_name}' is ${func_line_count} lines (MUST ≤ 50)"
        elif [ "$func_line_count" -gt 20 ]; then
            long_funcs=$((long_funcs + 1))
            warnings=$((warnings + 1))
            echo "  [WARN] Function '${current_func_name}' is ${func_line_count} lines (SHOULD ≤ 20)"
        fi
    fi

    # 10. Line length (MUST ≤ 120, SHOULD ≤ 80)
    local long_lines=0
    local very_long_lines=0
    local line_num=0
    while IFS= read -r line_content; do
        line_num=$((line_num + 1))
        local len=${#line_content}
        if [ "$len" -gt 120 ]; then
            very_long_lines=$((very_long_lines + 1))
            echo "  [ERROR] Line ${line_num} is ${len} chars (MUST ≤ 120)"
            errors=$((errors + 1))
        elif [ "$len" -gt 80 ]; then
            long_lines=$((long_lines + 1))
        fi
    done < "$file"
    if [ "$very_long_lines" -eq 0 ]; then
        echo "  [OK] No lines exceed 120 characters"
    fi
    if [ "$long_lines" -gt 0 ]; then
        if [ "$very_long_lines" -eq 0 ]; then
            echo "  [WARN] ${long_lines} line(s) exceed 80 characters (SHOULD ≤ 80)"
            warnings=$((warnings + 1))
        fi
    else
        echo "  [OK] All lines under 80 characters"
    fi

    echo ""
    if [ "$errors" -gt 0 ] && [ "$warnings" -gt 0 ]; then
        echo "Result: ${errors} error(s), ${warnings} warning(s)"
        return 2
    elif [ "$errors" -gt 0 ]; then
        echo "Result: ${errors} error(s)"
        return 2
    elif [ "$warnings" -gt 0 ]; then
        echo "Result: ${warnings} warning(s)"
        return 1
    else
        echo "Result: All checks passed"
        return 0
    fi
}
## --- Subcommand: sign ---

## CAMUS-SL
# intent: compute a cryptographic signature for content and format a CAMUS-SIGNATURE block
# input:
#   $1: private key path
#   $2: password for private key
#   $3: signatory name
#   $4: timestamp (ISO 8601)
#   $5: fingerprint (SHA256)
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
# input:
#   $1: file path
#   $2: public key fingerprint
#   $3: base64 signature
#   $4: timestamp
#   $5: signatory
#   $6: file type ("txt" or "md")
# output:
#   stdout: signature block to append
## CAMUS-END
format_whole_signature() {
    local file="$1" fpr="$2" sig_b64="$3" timestamp="$4" signatory="$5" file_type="$6"

    echo ""
    echo "---"
    if [ "$file_type" = "md" ]; then
        echo "<pre>"
    fi
    echo "*camus-sig-1*"
    echo "**Signed — ${signatory}**"
    echo "Date: ${timestamp}"
    echo "Fingerprint: SHA256:${fpr}"
    echo "Signature: ${sig_b64}"
    if [ "$file_type" = "md" ]; then
        echo "</pre>"
    fi
}
## CAMUS-SL
# intent: sign an entire file as a single unit (for .txt and .md)
# input:
#   $1: file path
#   $2: private key path
#   $3: public key path
#   $4: password
#   $5: signatory
#   $6: file type ("txt" or "md")
## CAMUS-END
do_sign_whole_file() {
    local file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5" file_type="$6"

    local timestamp fpr sig_b64
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fpr=$(fingerprint_of "$pubkey")

    local content
    content=$(cat "$file")

    sig_b64=$(compute_signature "$privkey" "$password" "$content")

    local sig_block
    sig_block=$(format_whole_signature "$file" "$fpr" "$sig_b64" "$timestamp" "$signatory" "$file_type")

    echo "$sig_block" >> "$file"

    echo "Signed (whole-file): ${file}" >&2
}
## CAMUS-SL
# intent: generate a CAMUS-SIGNATURE block for a shell function
# input:
#   $1: base64 signature
#   $2: fingerprint
#   $3: timestamp
#   $4: signatory
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
# input:
#   $1: file path
#   $2: line number of the function definition
# output:
#   stdout: the SL block content (including markers), or empty string
## CAMUS-END
find_sl_block() {
    local file="$1" func_line="$2"
    local search_end=$((func_line - 1))
    # Search backwards from the function line for a CAMUS-SL marker
    local sl_line
    sl_line=$(sed -n "1,${search_end}p" "$file" | grep -n '^## CAMUS-SL$' | tail -1 | cut -d: -f1)
    if [ -z "$sl_line" ]; then
        echo ""
        return
    fi
    # Find the matching CAMUS-END after the SL marker
    local end_line
    end_line=$(sed -n "${sl_line},\$p" "$file" | grep -n '^## CAMUS-END$' | head -1 | cut -d: -f1)
    if [ -z "$end_line" ]; then
        echo ""
        return
    fi
    end_line=$((sl_line + end_line - 1))
    # But don't go past the function definition
    if [ "$end_line" -ge "$func_line" ]; then
        end_line=$((func_line - 1))
    fi
    sed -n "${sl_line},${end_line}p" "$file"
}
## CAMUS-SL
# intent: get the body of a function (from definition to closing brace)
# input:
#   $1: file path
#   $2: line number of the function definition
# output:
#   stdout: function content (definition + body)
#   stdout: end_line: the last line of the function
## CAMUS-END
get_function_body() {
    local file="$1" start_line="$2"
    local line_num=0
    local brace_depth=0
    local started=0
    local content=""
    local end_line=0
    local in_heredoc=0
    local heredoc_delim=""

    while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$line_num" -lt "$start_line" ]; then
            continue
        fi
        if [ "$started" -eq 0 ]; then
            started=1
        fi

        # Track heredocs to avoid counting braces inside them
        if [ "$in_heredoc" -eq 0 ]; then
            if echo "$line" | grep -qE '<<\s*[-]?\w+$'; then
                in_heredoc=1
                heredoc_delim=$(echo "$line" | sed 's/.*<<[-]\?//' | awk '{print $1}')
            elif echo "$line" | grep -qE '<<-\s*\w+$'; then
                in_heredoc=2
                heredoc_delim=$(echo "$line" | sed 's/.*<<-//' | awk '{print $1}')
            elif echo "$line" | grep -qE '<<<'; then
                : # here-string, no brace issue
            fi
        elif [ "$in_heredoc" -eq 1 ] && echo "$line" | grep -q "^${heredoc_delim}$"; then
            in_heredoc=0
        elif [ "$in_heredoc" -eq 2 ] && echo "$line" | grep -q "^[[:space:]]*${heredoc_delim}$"; then
            in_heredoc=0
        fi

        if [ "$in_heredoc" -eq 0 ]; then
            local open_br close_br
            open_br=$(echo "$line" | tr -cd '{' | wc -c)
            close_br=$(echo "$line" | tr -cd '}' | wc -c)
            brace_depth=$((brace_depth + open_br - close_br))
        fi

        content="${content}${line}"$'\n'

        if [ "$brace_depth" -le 0 ] && [ "$started" -eq 1 ] && [ "$line_num" -gt "$start_line" ]; then
            end_line=$line_num
            printf '%s' "$content"
            echo "END_LINE:${end_line}"
            return
        fi
    done < "$file"

    printf '%s' "$content"
    echo "END_LINE:${line_num}"
}
## CAMUS-SL
# intent: sign each unsigned function in a shell script
# input:
#   $1: file path
#   $2: private key path
#   $3: public key path
#   $4: password
#   $5: signatory
#   $6: key directory (for fingerprint lookup)
## CAMUS-END
do_sign_per_function() {
    local file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5" key_dir="$6"
    local timestamp fpr
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fpr=$(fingerprint_of "$pubkey")

    # First pass: find all functions and their boundaries
    local -a func_data
    func_data=()
    local line_num=0
    local in_func=0
    local brace_depth=0
    local func_start=0
    local func_line_start=0
    local in_heredoc=0
    local heredoc_delim=""

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        if [ "$in_func" -eq 0 ]; then
            if echo "$line" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\(\) \{'; then
                in_func=1
                func_start=$line_num
                brace_depth=0
                local open_br
                open_br=$(echo "$line" | tr -cd '{' | wc -c)
                local close_br
                close_br=$(echo "$line" | tr -cd '}' | wc -c)
                brace_depth=$((brace_depth + open_br - close_br))
                if [ "$brace_depth" -le 0 ]; then
                    in_func=0
                    func_data+=("${func_start}:${line_num}")
                fi
            fi
        else
            if [ "$in_heredoc" -eq 0 ]; then
                if echo "$line" | grep -qE '<<[[:space:]]*[-]?\w+$' || \
                   echo "$line" | grep -qE '<<-[-]?\w+$'; then
                    in_heredoc=1
                    heredoc_delim=$(echo "$line" | sed 's/.*<<[-]\?//' | sed 's/[[:space:]]*//' | awk '{print $1}')
                fi
            elif [ "$in_heredoc" -eq 1 ]; then
                local trimmed
                trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
                if [ "$trimmed" = "$heredoc_delim" ]; then
                    in_heredoc=0
                fi
            fi

            if [ "$in_heredoc" -eq 0 ]; then
                local open_br2 close_br2
                open_br2=$(echo "$line" | tr -cd '{' | wc -c)
                close_br2=$(echo "$line" | tr -cd '}' | wc -c)
                brace_depth=$((brace_depth + open_br2 - close_br2))
            fi

            if [ "$brace_depth" -le 0 ] && [ "$line_num" -gt "$func_start" ]; then
                in_func=0
                func_data+=("${func_start}:${line_num}")
            fi
        fi
    done < "$file"

    local total="${#func_data[@]}"
    if [ "$total" -eq 0 ]; then
        echo "No functions found in ${file}" >&2
        return
    fi

    # Second pass: read file and insert signatures
    local temp_file
    temp_file=$(mktemp)

    local current_func_idx=0
    local processing_sig=0
    local sig_end_line=0

    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        local processed=0

        # Skip existing signature blocks (they will be replaced)
        if [ "$processing_sig" -eq 1 ]; then
            if echo "$line" | grep -q '^## CAMUS-END$'; then
                processing_sig=0
            fi
            continue
        fi
        if echo "$line" | grep -q '^## CAMUS-SIGNATURE$'; then
            if [ "$current_func_idx" -lt "$total" ]; then
                # Found an existing signature — skip until CAMUS-END
                processing_sig=1
                continue
            else
                # Bare placeholder after last function — remove it
                continue
            fi
        fi

        # Write line to output
        echo "$line" >> "$temp_file"

        # Check if this line ends a function that needs signing
        if [ "$current_func_idx" -lt "$total" ]; then
            local func_info="${func_data[$current_func_idx]}"
            local func_s="${func_info%%:*}"
            local func_e="${func_info##*:}"
            if [ "$line_num" -eq "$func_e" ]; then
                # Find the SL block for this function
                local sl_start
                sl_start=$(sed -n '1,'"$func_s"'p' "$file" \
                    | grep -n '^## CAMUS-SL$' | tail -1 | cut -d: -f1 || true)
                local sl_content=""
                if [ -n "$sl_start" ]; then
                    sl_content=$(sed -n "${sl_start},/^## CAMUS-END\$/p" "$file" 2>/dev/null || true)
                fi

                # Extract function body from original file
                local func_body
                func_body=$(sed -n "${func_s},${func_e}p" "$file")

                # Build content to sign
                local sign_content
                if [ -n "$sl_content" ]; then
                    sign_content="${sl_content}"$'\n'"${func_body}"
                else
                    sign_content="${func_body}"
                fi

                # Compute and insert signature
                local sig_b64
                sig_b64=$(compute_signature "$privkey" "$password" "$sign_content")
                local sig_block
                sig_block=$(format_func_signature_block "$sig_b64" "$fpr" "$timestamp" "$signatory")
                echo "$sig_block" >> "$temp_file"

                current_func_idx=$((current_func_idx + 1))
            fi
        fi
    done < "$file"

    mv "$temp_file" "$file"
    echo "Signed ${current_func_idx} function(s) in ${file}" >&2
}
## --- Subcommand: verify ---

## CAMUS-SL
# intent: verify a whole-file signature block
# input:
#   $1: file path
#   $2: public key path (optional, auto-detect by fingerprint if omitted)
#   $3: key directory (for auto-detection)
#   $4: file type (txt or md, for signature offset calculation)
# output:
#   return 0 on valid, 1 on invalid
## CAMUS-END
do_verify_whole_file() {
    local file="$1" pubkey="${2:-}" key_dir="$3" file_type="$4"

    local sig_line
    sig_line=$(grep -n '^\*camus-sig-1\*$' "$file" 2>/dev/null | tail -1 | cut -d: -f1 || true)

    if [ -z "$sig_line" ]; then
        echo "Error: no signature found in file." >&2
        return 1
    fi

    # The signature block layout differs by type:
    #   .txt: blank, ---, *camus-sig-1*   → offset = 3
    #   .md:  blank, ---, <pre>, *camus-sig-1* → offset = 4
    local content_end
    if [ "$file_type" = "md" ]; then
        content_end=$((sig_line - 4))
    else
        content_end=$((sig_line - 3))
    fi

    local tmp_content tmp_sig_block tmp_sig_bin tmp_pubkey
    tmp_content=$(mktemp)
    tmp_sig_block=$(mktemp)
    tmp_sig_bin=$(mktemp)
    tmp_pubkey=$(mktemp)

    head -n "$content_end" "$file" > "$tmp_content"
    tail -n "+$((sig_line - 2))" "$file" > "$tmp_sig_block"

    local sig_b64 stored_fpr stored_date
    sig_b64=$(grep '^Signature: ' "$tmp_sig_block" | sed 's/^Signature: //')
    stored_fpr=$(grep '^Fingerprint: ' "$tmp_sig_block" | sed 's/^Fingerprint: SHA256://')
    stored_date=$(grep '^Date: ' "$tmp_sig_block" | sed 's/^Date: //')

    if [ -z "$sig_b64" ]; then
        echo "Error: malformed signature block." >&2
        rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi

    # Resolve public key
    if [ -z "$pubkey" ]; then
        pubkey=$(find_key_by_fingerprint "$stored_fpr" "$key_dir" || true)
        if [ -z "$pubkey" ]; then
            echo "Error: no public key found for fingerprint SHA256:${stored_fpr}" >&2
            rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
            return 1
        fi
    elif [ ! -f "$pubkey" ]; then
        echo "Error: public key not found: ${pubkey}" >&2
        rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi

    # Check certificate expiration
    if head -1 "$pubkey" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
        if ! cert_valid_at "$pubkey" "$stored_date"; then
            local cert_end
            cert_end=$(openssl x509 -in "$pubkey" -noout -enddate 2>/dev/null | cut -d= -f2)
            echo "FAIL — key was already expired at signature date (${stored_date})." >&2
            echo "  Key valid until: ${cert_end}" >&2
            rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
            return 1
        fi
        extract_pubkey_from_cert "$pubkey" > "$tmp_pubkey"
    else
        cat "$pubkey" > "$tmp_pubkey"
    fi

    echo "$sig_b64" | openssl base64 -d -out "$tmp_sig_bin" 2>/dev/null

    if openssl pkeyutl -verify -pubin -inkey "$tmp_pubkey" \
        -rawin -in "$tmp_content" -sigfile "$tmp_sig_bin" 2>/dev/null; then
        local fpr
        fpr=$(fingerprint_of "$pubkey")
        echo "OK — valid signature (SHA256:${fpr})" >&2
        echo "Date: ${stored_date}" >&2
        rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
        return 0
    else
        echo "FAIL — invalid signature or wrong public key." >&2
        rm -f "$tmp_content" "$tmp_sig_block" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi
}
## CAMUS-SL
# intent: verify a single CAMUS-SIGNATURE block for a specific function
# input:
#   $1: file path
#   $2: line number of the CAMUS-SIGNATURE block
#   $3: public key path
# output:
#   return 0 on valid, 1 on invalid
## CAMUS-END
verify_func_signature() {
    local file="$1" sig_line="$2" pubkey="$3"

    local tmp_content tmp_sig_bin tmp_pubkey
    tmp_content=$(mktemp)
    tmp_sig_bin=$(mktemp)
    tmp_pubkey=$(mktemp)

    # Extract signature block details
    local sig_block
    sig_block=$(sed -n "${sig_line},\$p" "$file" | sed -n '/^## CAMUS-SIGNATURE$/,/^## CAMUS-END$/p')

    local sig_b64 stored_fpr stored_date signatory
    sig_b64=$(echo "$sig_block" | grep '^# signature: ' | sed 's/^# signature: //')
    stored_fpr=$(echo "$sig_block" | grep '^# fingerprint: ' | sed 's/^# fingerprint: sha256://')
    stored_date=$(echo "$sig_block" | grep '^# date: ' | sed 's/^# date: //')
    signatory=$(echo "$sig_block" | grep '^# signatory: ' | sed 's/^# signatory: //')

    if [ -z "$sig_b64" ]; then
        echo "Error: malformed signature block at line ${sig_line}" >&2
        rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi

    # Check certificate expiration
    if [ -f "$pubkey" ] && head -1 "$pubkey" 2>/dev/null | grep -q 'BEGIN CERTIFICATE'; then
        if ! cert_valid_at "$pubkey" "$stored_date"; then
            local cert_end
            cert_end=$(openssl x509 -in "$pubkey" -noout -enddate 2>/dev/null | cut -d= -f2)
            echo "FAIL — key expired at signature date (${stored_date})." >&2
            echo "  Key valid until: ${cert_end}" >&2
            rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey"
            return 1
        fi
        extract_pubkey_from_cert "$pubkey" > "$tmp_pubkey"
    elif [ -f "$pubkey" ]; then
        cat "$pubkey" > "$tmp_pubkey"
    else
        echo "Error: public key not found." >&2
        rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi

    # Find the content that was signed: the function definition + body + SL block
    # The signed content is everything between the previous CAMUS-END (or start of file)
    # and the CAMUS-SIGNATURE block, minus the CAMUS-SL block markers and signature
    # Actually, the signed content is: SL block + function body
    # We need to find the function and its SL block

    # Walk backwards from sig_line to find the function definition
    local func_def_line=0
    local search_line=$((sig_line - 1))
    while [ "$search_line" -gt 0 ]; do
        local line_content
        line_content=$(sed -n "${search_line}p" "$file")
        if echo "$line_content" | grep -q '^## CAMUS-SIGNATURE$'; then
            break
        fi
        if echo "$line_content" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*\)\s*\{'; then
            func_def_line=$search_line
            break
        fi
        search_line=$((search_line - 1))
    done

    if [ "$func_def_line" -eq 0 ]; then
        echo "Error: could not find function definition for signature at line ${sig_line}" >&2
        rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey"
        return 1
    fi

    # Get function body
    local body_result
    body_result=$(get_function_body "$file" "$func_def_line")
    local func_content=""
    local func_end=0
    local reading_content=true

    while IFS= read -r result_line; do
        if echo "$result_line" | grep -q '^END_LINE:'; then
            func_end=$(echo "$result_line" | cut -d: -f2)
            reading_content=false
        elif [ "$reading_content" = true ]; then
            func_content="${func_content}${result_line}"$'\n'
        fi
    done <<< "$body_result"

    func_content="${func_content%$'\n'}"

    # Find SL block
    local sl_block
    sl_block=$(find_sl_block "$file" "$func_def_line")

    # Reconstruct signed content
    local signed_content
    if [ -n "$sl_block" ]; then
        signed_content="${sl_block}"$'\n'"${func_content}"
    else
        signed_content="${func_content}"
    fi

    # Verify
    local tmp_content_verify
    tmp_content_verify=$(mktemp)
    printf '%s' "$signed_content" > "$tmp_content_verify"
    echo "" >> "$tmp_content_verify"

    echo "$sig_b64" | openssl base64 -d -out "$tmp_sig_bin" 2>/dev/null

    if openssl pkeyutl -verify -pubin -inkey "$tmp_pubkey" \
        -rawin -in "$tmp_content_verify" -sigfile "$tmp_sig_bin" 2>/dev/null; then
        local fpr
        fpr=$(fingerprint_of "$pubkey")
        echo "OK — function at line ${func_def_line}: valid (${signatory}, ${stored_date})"
        rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey" "$tmp_content_verify"
        return 0
    else
        echo "FAIL — function at line ${func_def_line}: invalid signature."
        rm -f "$tmp_content" "$tmp_sig_bin" "$tmp_pubkey" "$tmp_content_verify"
        return 1
    fi
}
## CAMUS-SL
# intent: verify all signatures in a Camus.sh script (per-function and whole-file)
# input:
#   $1: file path
#   $2: public key path (optional)
#   $3: key directory (for auto-detection)
# output:
#   return 0 if all valid, 1 otherwise
## CAMUS-END
do_verify() {
    local file="$1" pubkey="${2:-}" key_dir="$3"

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2
        return 1
    fi

    local file_type
    file_type=$(detect_file_type "$file")

    # Check if this is a whole-file signature (has camus-sig-1 marker)
    if grep -qs '^\*camus-sig-1\*$' "$file"; then
        echo "Verifying whole-file signature: ${file}"
        do_verify_whole_file "$file" "$pubkey" "$key_dir" "$file_type"
        return $?
    fi

    # Otherwise check for per-function CAMUS-SIGNATURE blocks
    local sig_blocks
    sig_blocks=$(grep -n '^## CAMUS-SIGNATURE$' "$file" 2>/dev/null || true)

    if [ -z "$sig_blocks" ]; then
        echo "No signatures found in ${file}" >&2
        return 1
    fi

    local total=0 valid=0 invalid=0

    while IFS=: read -r line_num line_content; do
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
# input:
#   $1: file path
#   $2: private key path
#   $3: public key path
#   $4: password
#   $5: signatory
#   $6: force file type (empty for auto-detect)
#   $7: key directory
## CAMUS-END
do_sign_file() {
    local file="$1" privkey="$2" pubkey="$3" password="$4" signatory="$5"
    local force_type="${6:-}" key_dir="$7"

    if [ ! -f "$file" ]; then
        echo "Error: file not found: ${file}" >&2
        return 1
    fi

    if is_signed "$file" && [ -z "$force_type" ]; then
        local file_type
        file_type=$(detect_file_type "$file")
        if [ "$file_type" != "sh" ]; then
            echo "Skipping (already signed): ${file}" >&2
            return 0
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
            do_sign_per_function "$file" "$privkey" "$pubkey" "$password" "$signatory" "$key_dir"
            ;;
        txt|md|unknown)
            do_sign_whole_file "$file" "$privkey" "$pubkey" "$password" "$signatory" "$file_type"
            ;;
    esac
}
## CAMUS-SL
# intent: review and sign multiple files interactively
# input:
#   $1: private key path
#   $2: public key path
#   $3: signatory
#   $4: force file type (empty for auto-detect)
#   $5: key directory
#   $@: files to sign
## CAMUS-END
do_sign_files() {
    local privkey="$1" pubkey="$2" signatory="$3" force_type="$4" key_dir="$5"
    shift 5
    local files=("$@")
    local PAGER="${PAGER:-less}"
    local approved=()
    local file answer password
    local i

    local key_remaining
    key_remaining=$(key_expiry_info "$pubkey") || {
        echo -e "\033[31mError: key expired $((-key_remaining)) day(s) ago.\033[0m" >&2
        exit 1
    }

    echo "Reviewing ${#files[@]} file(s) for signing." >&2
    echo >&2

    for ((i = 0; i < ${#files[@]}; i++)); do
        file="${files[$i]}"

        if [ ! -f "$file" ]; then
            echo "[$((i+1))/${#files[@]}] Skipping (not found): ${file}" >&2
            continue
        fi

        if grep -qs '^\*camus-sig-1\*$' "$file"; then
            echo "[$((i+1))/${#files[@]}] Skipping (already signed): ${file}" >&2
            continue
        fi

        echo "[$((i+1))/${#files[@]}] --- ${file} ---" >&2
        "$PAGER" "$file" 2>/dev/null || cat "$file"

        echo >&2
        read -r -p "Sign this file? [y/N] " answer
        case "${answer,,}" in
            y|yes)
                approved+=("$file")
                echo "  Approved." >&2
                ;;
            *)
                echo "  Skipped." >&2
                ;;
        esac
        echo >&2
    done

    if [ ${#approved[@]} -eq 0 ]; then
        echo "No files to sign." >&2
        exit 0
    fi

    password=$(prompt_password "Enter private key password: ")

    for file in "${approved[@]}"; do
        do_sign_file "$file" "$privkey" "$pubkey" "$password" "$signatory" "$force_type" "$key_dir"
    done

    if [ "$key_remaining" -lt 7 ]; then
        echo -e "\033[31mKey expires in ${key_remaining} day(s).\033[0m"
    elif [ "$key_remaining" -lt 30 ]; then
        echo -e "\033[33mKey expires in ${key_remaining} day(s).\033[0m"
    else
        echo "Key expires in ${key_remaining} day(s)."
    fi
}
## --- Main ---

## CAMUS-SL
# intent: parse arguments and dispatch to the appropriate subcommand
# input:
#   $@: command-line arguments
## CAMUS-END
main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    local script_dir
    script_dir=$(kiss_dir)
    local key_dir="${script_dir}/.secrets"

    local cmd="$1"
    shift

    case "$cmd" in
        init)
            local days=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --key-dir)
                        shift
                        key_dir="$1"
                        ;;
                    --days)
                        shift
                        days="$1"
                        ;;
                    *)
                        echo "Error: unknown option: $1" >&2
                        usage
                        ;;
                esac
                shift
            done
            do_gen_key "$key_dir" "${days:-365}"
            ;;

        check)
            [ $# -lt 1 ] && usage
            do_check "$1"
            ;;

        sign)
            local force_type=""
            local pubkey=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --txt|--text)
                        force_type="txt"
                        shift
                        ;;
                    --md|--markdown)
                        force_type="md"
                        shift
                        ;;
                    --pubkey)
                        shift
                        pubkey="$1"
                        shift
                        ;;
                    --key-dir)
                        shift
                        key_dir="$1"
                        shift
                        ;;
                    --signatory)
                        shift
                        SIGNATORY="$1"
                        shift
                        ;;
                    *)
                        break
                        ;;
                esac
            done
            [ $# -lt 1 ] && usage

            if [ -z "$pubkey" ]; then
                pubkey="${key_dir}/public.pem"
            fi
            local privkey="${key_dir}/private.pem"

            if [ ! -f "$privkey" ]; then
                echo "Error: private key not found at ${privkey}. Run init first." >&2
                exit 1
            fi
            if [ ! -f "$pubkey" ]; then
                echo "Error: public key not found at ${pubkey}." >&2
                exit 1
            fi

            local signatory="${SIGNATORY:-}"
            if [ -z "$signatory" ]; then
                read -r -p "Signatory name: " signatory
                if [ -z "$signatory" ]; then
                    echo "Error: signatory cannot be empty." >&2
                    exit 1
                fi
            fi

            do_sign_files "$privkey" "$pubkey" "$signatory" "$force_type" "$key_dir" "$@"
            ;;

        verify)
            local pubkey=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --pubkey)
                        shift
                        pubkey="$1"
                        ;;
                    --key-dir)
                        shift
                        key_dir="$1"
                        ;;
                    *)
                        break
                        ;;
                esac
                shift
            done
            [ $# -lt 1 ] && usage

            if [ -z "$pubkey" ]; then
                pubkey="${key_dir}/public.pem"
            fi
            if [ ! -f "$pubkey" ]; then
                pubkey=""
            fi

            do_verify "$1" "$pubkey" "$key_dir"
            ;;

        list-keys)
            while [ $# -gt 0 ]; do
                case "$1" in
                    --key-dir)
                        shift
                        key_dir="$1"
                        ;;
                    *)
                        echo "Error: unknown option: $1" >&2
                        usage
                        ;;
                esac
                shift
            done
            do_list_keys "$key_dir"
            ;;

        -h|--help|help)
            usage
            ;;

        *)
            echo "Error: unknown command: $cmd" >&2
            usage
            ;;
    esac
}

main "$@"
