#!/bin/bash
# ==============================================================================
# edit-entry.sh   ——————————>   Journal Helper — Dynamic Documentation Generator
# ==============================================================================
# This cript starts an editing workflow; it echoes a screen selection
# echo a welcome snippet, explaining its function and dependencies, then ask
# the user to choose between three options:
#
# 1) Create new entry
# 2) Edit existing entry
# 3) Exit
#
# --> "Create a new entry" hands over to 'new-entry.sh', and starts the automation
#      flow for entry creation from templates;
#
# --> "Edit existing entry" hands over to 'edit-entry.sh' and allows the user to
#      choose an existing entry, dynamically generating a list by looking for
#      the template directory, and using it to determine which folders may exist
#      given the templates available. It then search for the files within those
#      folders, and add them to an array, creating a second array of equal size
#      containing positive integers 1-X where X is the size of the file array.
#      It displays the list for the user, allowing them to choose a file to edit
#      from said list.
#
# --> "Exit" your guess is as good as mine :)
#
# ==============================================================================

ROOT_ABSOLUTE=$1
TEMPLATE_DIR=$2
#ROOT_ABSOLUTE=/home/wolf/Documents/git/homelab
#TEMPLATE_DIR="$ROOT_ABSOLUTE"/docs/templates
TEMPLATES=("$TEMPLATE_DIR"/*-template.md)
#if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
#    echo "Error: No templates found in $TEMPLATE_DIR"
#    exit 1
#fi

#echo "ROOT_ABSOLUTE = $ROOT_ABSOLUTE"
#echo "TEMPLATE_DIR = $TEMPLATE_DIR"
#echo "TEMPLATES = $TEMPLATES"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Journal Helper  --  Editing Workflow   ║"
echo "║                                          ║"
echo "║                                          ║"
echo "║     Please select the type of entry      ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo ""

# --- Template directory selection (loops until valid) ---
while true; do

        for i in "${!TEMPLATES[@]}"; do
            # Display human-friendly name (e.g., 'adr' or 'incident-report')
        DIR_NAME=$(basename "${TEMPLATES[$i]}" -template.md)
        printf "  (%d) %s\n" "$((i+1))" "$DIR_NAME"
        done

        read -rp "Selection (1-${#TEMPLATES[@]}): " CHOICE
# Check if input is a positive integer
# Check if input is within the bounds of the array
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && \
                (( CHOICE >= 1 && CHOICE <= ${#TEMPLATES[@]})); then
                SELECTED_DIR=$(basename "${TEMPLATES[$((CHOICE-1))]}" -template.md)
                break
            else
                echo "  Please choose a valid entry from the list."
            fi
done

################################################################################
# Ensure there are entries to edit in the chosen directory
################################################################################
TARGET_DIR="$ROOT_ABSOLUTE/docs/$SELECTED_DIR"
ENTRIES=("$TARGET_DIR"/*)

if [[ ${#ENTRIES[@]} -eq 0 ]]; then
    echo "Error: No entries found in $TARGET_DIR"
    exit 1
fi

################################################################################
# Display dynamic list of entries to edit for user to chose from
################################################################################
#echo "$SELECTED_DIR"
#echo "$TARGET_DIR"
#exit


echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Journal Helper  --  Editing Workflow   ║"
echo "║                                          ║"
echo "║                                          ║"
echo "║    Please select the entry to edit       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo ""


# --- Template directory selection (loops until valid) ---
while true; do

        for i in "${!ENTRIES[@]}"; do
            # Display human-friendly name (e.g., 'adr' or 'incident-report')
        DISPLAY_NAME=$(basename "${ENTRIES[$i]}")
        printf "  (%d) %s\n" "$((i+1))" "$DISPLAY_NAME"
        done

        read -rp "Selection (1-${#ENTRIES[@]}): " CHOICE
# Check if input is a positive integer
# Check if input is within the bounds of the array
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && \
                (( CHOICE >= 1 && CHOICE <= ${#ENTRIES[@]})); then
                SELECTED_TEMPLATE="${ENTRIES[$((CHOICE-1))]}"
                break
            else
                echo "  Please choose a valid entry from the list."
            fi
done

echo "We will build the rest soon!"
exit
