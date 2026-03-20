#!/bin/bash

# --- Configuration ---
# Set the directory where reports are stored
REPORTS_DIR="./journal/sysadmin"
# Set editor according to system config.
EDITOR="$(echo $EDITOR)"

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

# Engineering Log: [Brief, Clear Title - e.g., Decoupling Docker State and IaC]

**Date:** $CURRENT_DATE
**Category:** [Architecture / Security / Networking / Storage / Maintenance]
**Status:** [Proposed / In Progress / Completed / Deprecated]

---

## 1. Context & Problem Statement
> *What is the current state of the system, and why is it insufficient? Describe the technical debt, security risk, or performance bottleneck you are trying to solve.*

[Insert Context Here]

## 2. Architectural Decisions & Strategy
> *What are the proposed solutions? Document the trade-offs you considered and justify why you chose the final path. This proves you think like an engineer, not just a technician.*

* **Decision 1:** [e.g., Implementing a two-repository split for IaC and secrets.]
    * *Rationale:* [Why is this better than the alternative?]
* **Decision 2:** [e.g., Utilizing BTRFS stack-level subvolumes instead of named volumes.]
    * *Rationale:* [Why is this better than the alternative?]

## 3. Implementation & Execution
> *Detail the specific steps, scripts, and commands used to execute the change. Include sanitized code snippets or configuration blocks where relevant.*

* **Phase 1 (Preparation):** ...
* **Phase 2 (Execution):** ...
* **Phase 3 (Verification):** ...

## 4. Outcome & Future Considerations
> *What was the final result? Did you achieve the goal outlined in Section 1? What technical debt remains, and what are the next steps?*

* **Result:** [e.g., Infrastructure can now be safely pushed to a public portfolio with zero secret leakage.]
* **Result:** [e.g., Rollbacks are now crash-consistent across entire application stacks.]

### Next Steps
- [ ] **Pending:** [e.g., Migrate legacy container data to the new subvolume structure.]
- [x] **Completed:** [e.g., Drafted and tested the `deploy.sh` rsync script.]

EOF

echo "File created: $FILENAME"
echo "Opening editor..."
sleep 1

# Open the file in your preferred editor
$EDITOR "$FILENAME"
