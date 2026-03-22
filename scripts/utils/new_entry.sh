#!/bin/bash

# --- Configuration ---
###############################################################
#Find relative location of the script
###############################################################

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
###############################################################
# Create the reports directory if it doesn't exist
###############################################################

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

##############################################################
# --- User Input ---
##############################################################
echo "--- New Entry Generator ---"
echo "| Enter (1) for Journal Entry or | (2) for Incident Report | ^C to exit |"
read REPORT_TYPE


if [[ "$REPORT_TYPE" == 1 ]]; then
echo "--- New Journal Entry Generator ---"
echo "Enter a short, descriptive title for the journal entry: "
read RAW_TITLE
REPORTS_DIR=$JOURNAL_DIR
REPORT_TYPE="sysadmin-journal"

elif [[ "$REPORT_TYPE" == 2 ]]; then
echo "--- New Incident Report Generator ---"
echo "Enter a short, descriptive title for the incident: "
read RAW_TITLE
REPORTS_DIR=$INCIDENT_DIR
REPORT_TYPE="incident-report"

else
    echo "Error: Choose one of the supported entry types" # I actually want this to loop back to New Entry Generator.
    exit 1
fi

if [[ -z "$RAW_TITLE" ]]; then
    echo "Error: Title cannot be empty." # I also want this to loop back to New Entry Generator
    exit 1
fi
###############################################################
# --- Naming and Dating ---
###############################################################

CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=$(date +%H:%M)
# Sanitize title: lowercase, replace spaces with hyphens, remove special characters
SAFE_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
# Define full filename
FILENAME="${REPORTS_DIR}/${CURRENT_DATE}-${SAFE_TITLE}.md"

###############################################################
# --- Generate Template ---
###############################################################

while IFS='' read -r line; do
    # While the line contains a {{VAR}} placeholder
    while [[ $line =~ \{\{([A-Z0-9_]+)\}\} ]]; do
        VAR_NAME=${BASH_REMATCH[1]}
        VALUE=${!VAR_NAME}   # Indirect expansion: get value of $VAR_NAME

        # Replace the first occurrence
        line=${line/"{{${VAR_NAME}}}"/"$VALUE"}
    done

    printf '%s\n' "$line"
done < "$REPORTS_DIR/$REPORT_TYPE-template.md" > "$FILENAME"



echo "File created: $FILENAME"
echo "Opening editor..."
sleep 1

###############################################################
# Open the file in the system-defined editor
###############################################################

$EDITOR "$FILENAME"
