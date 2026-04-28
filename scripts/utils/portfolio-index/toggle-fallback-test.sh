#!/bin/bash
# ==============================================================================
# toggle-fallback-test.sh  —> Toggles manifestUrl in script.js to test fallbacks
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

################################################################################
# Find absolute location of the script and repo root
################################################################################
SCRIPT_LOCATION=${BASH_SOURCE[0]}
SCRIPT_SOURCE=$(printf '%s\n' "$SCRIPT_LOCATION" | grep -o '^.*/')
if [[ -z "$SCRIPT_SOURCE" ]]; then
    SCRIPT_SOURCE=./
fi
SCRIPT_ABSOLUTE=$(cd "$SCRIPT_SOURCE" && pwd -P)
ROOT_ABSOLUTE=$(cd "$SCRIPT_ABSOLUTE"/../../../ && pwd -P)

# Load Environment files
source "$SCRIPT_ABSOLUTE/.env"

# Target file
SCRIPT_JS_FILE="$WEBSITE_DIR/assets/script.js"

# Sanity check
if [[ ! -f "$SCRIPT_JS_FILE" ]]; then
    echo "Error: script.js not found at $SCRIPT_JS_FILE."
    exit 1
fi

# Define the valid and invalid URLs
VALID_URL="$REMOTE_URL/portfolio-index/index.json"
INVALID_URL="$REMOTE_URL/portfolio-index/INVALID-TEST-URL.json"

echo "Checking script.js state..."

# Toggle logic based on current state
if grep -q "$VALID_URL" "$SCRIPT_JS_FILE"; then
    echo "Current state: Production (Valid URL)"
    echo "Toggling to: Fallback Test (Invalid URL)..."

    sed "s|$VALID_URL|$INVALID_URL|g" "$SCRIPT_JS_FILE" > "${SCRIPT_JS_FILE}.tmp" && mv "${SCRIPT_JS_FILE}.tmp" "$SCRIPT_JS_FILE"

    echo "Toggled: script.js is now configured to FAIL the primary fetch."

elif grep -q "$INVALID_URL" "$SCRIPT_JS_FILE"; then
    echo "Current state: Fallback Test (Invalid URL)"
    echo "Toggling to: Production (Valid URL)..."
 
    sed "s|$INVALID_URL|$VALID_URL|g" "$SCRIPT_JS_FILE" > "${SCRIPT_JS_FILE}.tmp" && mv "${SCRIPT_JS_FILE}.tmp" "$SCRIPT_JS_FILE"

    echo "Toggled: script.js is restored to production state."

else
    echo "Error: Neither the valid nor the specific invalid URL was found in $SCRIPT_JS_FILE."
    echo "Ensure the manifestUrl variable matches what this script expects."
    exit 1
fi
