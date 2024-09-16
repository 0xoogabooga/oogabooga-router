#!/bin/bash
set -e # exit on error

# generates lcov.info
forge coverage --report lcov

lcov \
    --remove lcov.info \
    --rc branch_coverage=1 \
    --rc derive_function_end_line=0 \
    --output-file filtered-lcov.info \
    "*test*" "*script*"

lcov \
    --rc derive_function_end_line=0 \
    --rc branch_coverage=1 \
    --list filtered-lcov.info

# Open more granular breakdown in browser
if [ "$FOUNDRY_PROFILE" != "ci" ]
then
    genhtml \
        --rc derive_function_end_line=0 \
        --rc branch_coverage=1 \
        --output-directory coverage \
        filtered-lcov.info
    open coverage/index.html
fi