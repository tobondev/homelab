#!/bin/bash

# --- Configuration ---
#Find relative location of the script
SCRIPT_LOCATION=${BASH_SOURCE[0]}
#Remove the script name and keep directory name.
SCRIPT_SOURCE=$(printf '%s\n' "$SCRIPT_LOCATION" | grep -o '^.*/')
#Handle exceptions when the script is run directly, such as "bash script.sh"
if [[ -z "$SCRIPT_SOURCE" ]]; then
    SCRIPT_SOURCE=./
fi
#Find absolute path of script source based on relative path.
SCRIPT_ABSOLUTE=$(cd "$SCRIPT_SOURCE" && pwd -P)
#Set the root directory for the journal directory
ROOT_ABSOLUTE=$(cd "$SCRIPT_ABSOLUTE"/../../ && pwd -P)
#Set the journal directory
PARENT_ABSOLUTE=$ROOT_ABSOLUTE/journal
# Set the directory where your reports are stored
JOURNAL_DIR=$PARENT_ABSOLUTE/sysadmin
# Set the directory where your reports are stored
INCIDENT_DIR=$PARENT_ABSOLUTE/incident-response
# Create the reports directory if it doesn't exist
###############################################################
echo "Creating directories for joural entries"
mkdir -p $JOURNAL_DIR $INCIDENT_DIR
##############################################################
# --- User Input ---
echo "--- New Entry Generator ---"
read -p "Enter (1) for Journal Entry or (2) for Incident Report | ^C to exit" REPORT_TYPE


if [[ "$REPORT_TYPE" == 1 ]]; then
echo "--- New Journal Entry Generator ---"
read -p "Enter a short, descriptive title for the incident: " RAW_TITLE
REPORTS_DIR=$JOURNAL_DIR

elif [[ "$REPORT_TYPE" == 2 ]]; then
echo "--- New Incident Report Generator ---"
read -p "Enter a short, descriptive title for the incident: " RAW_TITLE
REPORTS_DIR=$INCIDENT_DIR

else
    echo "Error: Choose one of the supported entry types" # I actually want this to loop back to New Entry Generator.
    exit 1
fi

if [[ -z "$RAW_TITLE" ]]; then
    echo "Error: Title cannot be empty." # I also want this to loop back to New Entry Generator
    exit 1
fi

# --- Formatting ---
# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=(date +%H:%M)
# Sanitize title: lowercase, replace spaces with hyphens, remove special characters
SAFE_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
# Define full filename
FILENAME="${REPORTS_DIR}/${CURRENT_DATE}-${SAFE_TITLE}.md"

# --- Generate Template ---

cat "$REPORTS_DIR"/template.md > "$FILENAME"


echo "File created: $FILENAME"
echo "Opening editor..."
sleep 1

# Open the file in the system-defined editor

$EDITOR "$FILENAME"
