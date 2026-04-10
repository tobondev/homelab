#!/bin/bash
# ==============================================================================
# start.sh   ——————————>        Journal Helper — Dynamic Documentation Generator
# ==============================================================================
# This cript starts a Journal Helper Pipeline; its job is fairly simple:
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
#Declare location for the templates
TEMPLATE_DIR=$ROOT_ABSOLUTE/docs/templates

# Sanity check

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Error: Template directory not found. This script requires a template to run"
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
echo "║        Welcome to Journal Helper         ║"
echo "║                                          ║"
echo "║  Do you want to edit an existing entry?  ║"
echo "║                                          ║"
echo "║                   Y/N                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo ""

while true; do
	read -r WORKFLOW_SELECTION
	if [[ "${WORKFLOW_SELECTION,,}" == "y" ]]; then
	echo "Starting Entry Editor Workflow"
	bash "$SCRIPT_ABSOLUTE/edit-entry.sh" "$ROOT_ABSOLUTE" "$TEMPLATE_DIR"
	exit
	elif [[ "${WORKFLOW_SELECTION,,}" == "n" ]]; then
	echo "Starting Entry Creation Workflow"
	bash "$SCRIPT_ABSOLUTE/new-entry.sh"
	exit
	else
	echo " Please choose a valid option or press ^C to exit"
	fi
done
