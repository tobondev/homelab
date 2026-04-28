n#!/bin/bash
# ==============================================================================
# generate-fallback.sh  ——————————>  Generates fallback-index from current index
# ==============================================================================
# This script takes the index.json found in the repository and creates
# a fallback index as a local copy, and copies it over to the website assets
# ==============================================================================


################################################################################
# Find relative location of the script
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
#Declare location for the templates
INDEX_FILE=$ROOT_ABSOLUTE/portfolio-index/index.json
ASSETS_DOCS_DIR="$WEBSITE_DIR/assets/docs"

# Sanity check

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "Error: Portfolio Index not found. This script requires a working index.json to run"
    exit 1
fi

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting synchronization of fallback documentation..."

# 1. Sync the documentation directories using rsync
DOC_DIRS=("adrs" "architecture" "incidents" "operations" "runbooks")

for dir in "${DOC_DIRS[@]}"; do
    echo "Syncing $dir..."
    mkdir -p "$ASSETS_DOCS_DIR/$dir"
    rsync -a --delete "$ROOT_ABSOLUTE/docs/$dir/" "$ASSETS_DOCS_DIR/$dir/"
done

# 2. Sync the primary index.json
echo "Syncing index.json..."
cp "$ROOT_ABSOLUTE/portfolio-index/index.json" "$WEBSITE_DIR/assets/index.json"

# 3. Generate the local index-fallback.json
# Read the primary index.json, replace the remote URL with the local path using sed,
# and output directly to the fallback file.
echo "Generating index-fallback.json..."
sed "s|$REMOTE_URL|$LOCAL_URL|g" "$WEBSITE_DIR/assets/index.json" > "$WEBSITE_DIR/assets/index-fallback.json"

echo "Fallback index generated from index.json"
