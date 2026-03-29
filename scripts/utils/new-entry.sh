#!/bin/bash
# ==============================================================================
# new-entry.sh — Journal & Incident Report Generator
# ==============================================================================
# Creates a new Markdown entry from template, then hands off to session-start.sh
# to begin a recorded terminal session tied to that entry.
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
PARENT_ABSOLUTE=$ROOT_ABSOLUTE/docs
JOURNAL_DIR=$PARENT_ABSOLUTE/sysadmin
INCIDENT_DIR=$PARENT_ABSOLUTE/incident-response

################################################################################
# Create directories if they don't exist
################################################################################
if [[ ! -d "$PARENT_ABSOLUTE" ]]; then
    echo "Creating directories for journal"
    mkdir -p "$PARENT_ABSOLUTE"
fi
if [[ ! -d "$JOURNAL_DIR" ]]; then
    echo "Creating directories for sysadmin entries"
    mkdir -p "$JOURNAL_DIR"
fi
if [[ ! -d "$INCIDENT_DIR" ]]; then
    echo "Creating directories for incident response entries"
    mkdir -p "$INCIDENT_DIR"
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
    echo ""
    echo "  (1) Sysadmin Journal Entry"
    echo "  (2) Incident Response Report"
    echo "  (^C) Exit"
    echo ""
    read -rp "Entry type: " REPORT_TYPE

    if [[ "$REPORT_TYPE" == "1" ]]; then
        REPORTS_DIR=$JOURNAL_DIR
        REPORT_TYPE_LABEL="sysadmin-journal"
        echo ""
        echo "--- New Sysadmin Journal Entry ---"
        break
    elif [[ "$REPORT_TYPE" == "2" ]]; then
        REPORTS_DIR=$INCIDENT_DIR
        REPORT_TYPE_LABEL="incident-report"
        echo ""
        echo "--- New Incident Response Report ---"
        break
    else
        echo "  Invalid choice. Please enter 1 or 2."
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
# Naming and Dating
################################################################################
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=$(date +%H:%M)
SAFE_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
FILENAME="${REPORTS_DIR}/${CURRENT_DATE}-${SAFE_TITLE}.md"

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
done < "$REPORTS_DIR/$REPORT_TYPE_LABEL-template.md" > "$FILENAME"

echo ""
echo "✓ Entry created: $FILENAME"
echo ""

################################################################################
# Hand off to session wrapper
################################################################################
bash "$SCRIPT_ABSOLUTE/session-start.sh" "$FILENAME" "$SCRIPT_ABSOLUTE"
