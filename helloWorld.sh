#!/bin/bash

## CAMUS-LEXICON
# message: A text provided by the user, to print on screen
## CAMUS-END

## CAMUS-SL
# intent: print "Hello" followed by message on the screen (standard output)
# input:
#   $1: message (optional, default: world)
# output:
#   print: Hello message
## CAMUS-END
main() {
    local message="${1:-world}"
    echo "Hello $message"
}
## CAMUS-SIGNATURE
# signatory: l4nj1n9@example.org
# date: 2026-06-04T21:02:25Z
# fingerprint: SHA256:11:0E:1B:6E:21:89:66:AF:F0:BF:CD:A5:A8:4D:7E:01:63:82:29:B3:08:6B:70:3F:52:D6:F3:21:23:52:CE:7F
# signature: PU/5qQxDyepR+iZZpkm4lePD21dbmnk1DDeMHfqlKAyPfAOODwmH5cv9aJ4eijS54MDZvyAzRHGrN/84jFV2Aw==
## CAMUS-END

main "$@"
