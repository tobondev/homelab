#!/bin/bash

# --- Configuration ---
# Set the directory where your reports are stored
REPORTS_DIR="./journal/incident-response"
# Set editor according to system config.
EDITOR=("echo $EDITOR")

# Create the reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# --- User Input ---
echo "--- New Incident Report Generator ---"
read -p "Enter a short, descriptive title for the incident: " RAW_TITLE

if [[ -z "$RAW_TITLE" ]]; then
    echo "Error: Title cannot be empty."
    exit 1
fi

# --- Formatting ---
# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
# Sanitize title: lowercase, replace spaces with hyphens, remove special characters
SAFE_TITLE=$(echo "$RAW_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
# Define full filename
FILENAME="${REPORTS_DIR}/${CURRENT_DATE}-${SAFE_TITLE}.md"

# --- Generate Template ---
cat <<EOF > "$FILENAME"
# Incident Report: $RAW_TITLE

**Date of Incident:** $CURRENT_DATE
**Date of Report:** $CURRENT_DATE
**Status:** [Resolved / Mitigated / Ongoing]
**Severity:** [Low / Medium / High / Critical]
**Services Impacted:** ---

## 1. Incident Summary

> *Provide a 2-3 sentence executive summary. What happened, what was the impact, and how was it ultimately resolved?*

## 2. Timeline of Events

* **[00:00]** - Incident occurred or was first detected.
* **[00:00]** - Initial triage and investigation commenced.
* **[00:00]** - System restored to standard operation.

## 3. Root Cause Analysis (RCA)
> *Why did this happen? Focus on the technical failure or process gap.*

## 4. Remediation and Recovery

* **Initial Triage:** * **Data Preservation:** * **System Bootstrap:** * **Final Restoration:**

## 5. Lessons Learned & Action Items

- [ ] **Pending:**
- [x] **Completed:**
EOF

echo "File created: $FILENAME"
echo "Opening editor..."
sleep 1

# Open the file in your preferred editor
$EDITOR "$FILENAME"
