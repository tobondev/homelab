#!/bin/bash
# ==============================================================================
# new-entry.sh — Dynamic Documentation Generator
# ==============================================================================
# Creates a new Markdown entry from template, populate it using variable expansion
# then hands off to session-start.sh if necessary to begin a recorded terminal
# session tied to that entry. Then assists in commiting the changes.
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
ROOT_ABSOLUTE=$(cd "$SCRIPT_ABSOLUTE"/../../ && pwd -P)
#Declare location for the templates
TEMPLATE_DIR=$ROOT_ABSOLUTE/docs/templates

# Sanity check

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Error: Template directory not found. This script requires a tamplate to run"
    exit 1
fi

################################################################################
# Dynamic template discovery
# This assumes that templates are created inside the docs/templates directory
# and that they are named in the convention [type-of-entry]-template.md ;
# it follows that logic to get [type-of-entry] and dynamically creates an array
# with each item, and a corresponding array of numbers, in order to populate a
# selection screen. If no templates are found, the script exits with an error.
################################################################################
TEMPLATES=("$TEMPLATE_DIR"/*-template.md)

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    echo "Error: No templates found in $TEMPLATE_DIR"
    exit 1
fi

################################################################################
# User Input — loops on invalid input rather than exiting
################################################################################
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        Homelab Journal — New Entry       ║"
echo "╚══════════════════════════════════════════╝"

# --- Entry type selection (loops until valid) ---
while true; do

	for i in "${!TEMPLATES[@]}"; do
	    # Display human-friendly name (e.g., 'adr' or 'incident-report')
    	DISPLAY_NAME=$(basename "${TEMPLATES[$i]}" -template.md)
    	printf "  (%d) %s\n" "$((i+1))" "$DISPLAY_NAME"
	done

	read -rp "Selection (1-${#TEMPLATES[@]}): " CHOICE
# Check if input is a positive integer
# Check if input is within the bounds of the array
	    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && \
		(( CHOICE >= 1 && CHOICE <= ${#TEMPLATES[@]})); then
		SELECTED_TEMPLATE="${TEMPLATES[$((CHOICE-1))]}"
	        break
	    else
	        echo "  Please choose a valid entry from the list."
	    fi
done

# --- Title input (loops until non-empty) ---
while true; do
    read -rp "Title: " RAW_TITLE
    if [[ -n "$RAW_TITLE" ]]; then
        break
    else
        echo "  Title cannot be empty."
    fi
done


################################################################################
# Determine directories for the entries based on the template and create them
# if empty (mkdir -p will continue without errors if the folder exists).
# The script assumes that the [type-of-entry] is also the name of the directory
# that the entry will live in.
################################################################################
# Logic: Strip suffix -> mkdir -p
CATEGORY=$(basename "$SELECTED_TEMPLATE" -template.md)
TARGET_DIR="$ROOT_ABSOLUTE/docs/${CATEGORY}"
mkdir -p "$TARGET_DIR"
################################################################################
# Naming and Dating
################################################################################
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=$(date +%H:%M)
SAFE_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
FILENAME="${TARGET_DIR}/${CURRENT_DATE}-${SAFE_TITLE}.md"

################################################################################
# Generate Template
################################################################################
while IFS='' read -r line; do
    while [[ $line =~ \{\{([A-Z0-9_]+)\}\} ]]; do
        VAR_NAME=${BASH_REMATCH[1]}
        VALUE=${!VAR_NAME}
        line=${line/"{{${VAR_NAME}}}"/"$VALUE"}
    done
    printf '%s\n' "$line"
done < "$SELECTED_TEMPLATE" > "$FILENAME"

################################################################################
# Perform a check for whether the template calls for a shell session
# Hand off to session wrapper if so
################################################################################

if grep -q "SESSION_LOG_START" "$FILENAME"; then
    echo "✓ Sentinel found. Starting terminal session..."
    bash "$SCRIPT_ABSOLUTE/session-start.sh" "$FILENAME" "$SCRIPT_ABSOLUTE"
else
    echo "✓ No sentinel. Opening editor..."
    ${EDITOR:-vi} "$FILENAME"
fi

echo ""
echo "✓ Entry created: $FILENAME"
echo ""
