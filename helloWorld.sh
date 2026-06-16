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

main "$@"
