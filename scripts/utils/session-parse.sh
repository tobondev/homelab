#!/bin/bash
# =============================================================================
# session-parse.sh — Transcript cleaner and Section 3 injector
# =============================================================================
# Called by session-start.sh with:
#   $1 = TYPESCRIPT  — raw script(1) log file
#   $2 = MD_FILE     — the journal .md entry to inject into
#
# What it does:
#   1. Cleans the raw typescript (strip ANSI, control chars, noise lines)
#   2. If note() markers are present, splits transcript into labelled phases
#   3. Replaces content between <!-- SESSION_LOG_START --> and
#      <!-- SESSION_LOG_END --> sentinels in the Markdown file
#
# If no sentinels are found in the .md file, the clean transcript is saved
# as a .txt alongside the raw log and a warning is printed.
# =============================================================================

TYPESCRIPT="$1"
MD_FILE="$2"

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if [[ -z "$TYPESCRIPT" || -z "$MD_FILE" ]]; then
    echo "Usage: session-parse.sh <typescript> <markdown-file>" >&2
    exit 1
fi

if [[ ! -f "$TYPESCRIPT" ]]; then
    echo "Warning: No transcript found at: $TYPESCRIPT" >&2
    exit 1
fi

if [[ ! -f "$MD_FILE" ]]; then
    echo "Warning: Markdown file not found: $MD_FILE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Clean the raw transcript
#
# Pipeline:
#   col -b          — remove backspace/overstrike sequences (typewriter artifacts)
#   sed (ANSI)      — strip ANSI color/cursor escape sequences
#   sed (OSC)       — strip OSC terminal sequences (e.g. terminal title changes)
#   tr              — remove raw carriage returns
#   grep (script)   — drop the "Script started/done" bookend lines
#   grep (rcfile)   — drop the sourcing of our temp rcfile from the transcript
#   grep (banner)   — drop our own session banner lines
#   grep (note hdr) — drop the ##### separator lines around note markers
#   awk             — collapse 3+ consecutive blank lines into one
# ---------------------------------------------------------------------------
CLEAN=$(col -b < "$TYPESCRIPT" \
    | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
    | sed 's/\x1b\][^\x07]*\x07//g' \
    | sed 's/\x1b(B//g' \
    | tr -d '\r' \
    | grep -v '^Script started' \
    | grep -v '^Script done' \
    | grep -v 'homelab-rc-' \
    | grep -v '^\s*● Recording started' \
    | grep -v '^\s*Entry\s*:' \
    | grep -v '^\s*Log\s*:' \
    | grep -v '^########################################$' \
    | awk '/^$/{blank++; if(blank<=2) print; next} {blank=0; print}')

if [[ -z "$CLEAN" ]]; then
    echo "Warning: Transcript was empty after cleaning. Nothing to inject." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Build the Section 3 content block
#
# Two cases:
#   A) note() markers present → split into labelled phase sections
#   B) No markers             → single block with a timestamp header
# ---------------------------------------------------------------------------
PHASES_FILE=$(mktemp /tmp/homelab-phases-XXXXXX.md)
trap 'rm -f "$PHASES_FILE"' EXIT

NOTE_COUNT=$(echo "$CLEAN" | grep -c '^### NOTE ')

if [[ "$NOTE_COUNT" -gt 0 ]]; then
    # -----------------------------------------------------------------------
    # Case A: Split on note() markers
    #
    # Input markers look like:
    #   ### NOTE 14:32:01: Phase 2 - Configuring nginx ###
    #
    # Produces a fenced code block per phase, labelled with the note text.
    # Commands that appear before the first note go into a "Pre-session" block.
    # -----------------------------------------------------------------------
    echo "> *Session transcript — recorded $(date -r "$TYPESCRIPT" '+%Y-%m-%d'). Edit phases, remove noise, add rationale.*" >> "$PHASES_FILE"
    echo "" >> "$PHASES_FILE"

    echo "$CLEAN" | awk -v outfile="$PHASES_FILE" '
    BEGIN {
        section = "Pre-session commands"
        buf = ""
        has_content = 0
    }

    # Match note marker lines
    /^\#\#\# NOTE [0-9:]+: .* \#\#\#$/ {
        # Flush the current buffer if it has content
        if (has_content) {
            print "* **" section ":**" >> outfile
            print "" >> outfile
            print "```bash" >> outfile
            printf "%s", buf >> outfile
            print "```" >> outfile
            print "" >> outfile
        }
        # Extract the label: strip timestamp prefix and trailing ###
        label = $0
        sub(/^\#\#\# NOTE [0-9:]+: /, "", label)
        sub(/ \#\#\#$/, "", label)
        section = label
        buf = ""
        has_content = 0
        next
    }

    # Skip lines that are purely whitespace — track but do not count as content
    /^[[:space:]]*$/ {
        if (has_content) buf = buf "\n"
        next
    }

    # Regular command/output lines
    {
        buf = buf $0 "\n"
        has_content = 1
    }

    END {
        if (has_content) {
            print "* **" section ":**" >> outfile
            print "" >> outfile
            print "```bash" >> outfile
            printf "%s", buf >> outfile
            print "```" >> outfile
            print "" >> outfile
        }
    }
    '

else
    # -----------------------------------------------------------------------
    # Case B: No markers — single block
    # Annotated with a reminder to add phase structure manually.
    # -----------------------------------------------------------------------
    SESSION_DATE=$(date -r "$TYPESCRIPT" '+%Y-%m-%d %H:%M' 2>/dev/null || date '+%Y-%m-%d %H:%M')

    cat >> "$PHASES_FILE" <<EOF
> *Session transcript — recorded $SESSION_DATE. No phase markers were used.*
> *Tip: use \`note "Phase 1 - description"\` during future sessions to auto-split into phases.*

* **Phase 1 (Preparation):** *(add notes)*

* **Phase 2 (Execution):**

\`\`\`bash
$CLEAN
\`\`\`

* **Phase 3 (Verification):** *(add verification steps and output)*

EOF
fi

# ---------------------------------------------------------------------------
# Step 3: Inject into the Markdown file
#
# Replaces everything between:
#   <!-- SESSION_LOG_START -->
#   <!-- SESSION_LOG_END -->
#
# These sentinels must be present in the template. They are HTML comments
# and are invisible in all Markdown renderers.
# ---------------------------------------------------------------------------
if ! grep -q '<!-- SESSION_LOG_START -->' "$MD_FILE"; then
    echo "" >&2
    echo "  Warning: SESSION_LOG_START sentinel not found in:" >&2
    echo "  $MD_FILE" >&2
    echo "" >&2
    echo "  Add these lines to Section 3 of your template:" >&2
    echo "  <!-- SESSION_LOG_START -->" >&2
    echo "  <!-- SESSION_LOG_END -->" >&2
    echo "" >&2
    # Fallback: save clean transcript alongside the log
    CLEAN_FILE="${TYPESCRIPT%.log}.clean.txt"
    echo "$CLEAN" > "$CLEAN_FILE"
    echo "  Clean transcript saved to: $CLEAN_FILE" >&2
    exit 1
fi

# Use awk to replace between sentinels, reading new content from file
TMPFILE=$(mktemp /tmp/homelab-inject-XXXXXX.md)

awk -v pfile="$PHASES_FILE" '
    /<!-- SESSION_LOG_START -->/ {
        print
        # Inject all lines from phases file
        while ((getline line < pfile) > 0) {
            print line
        }
        close(pfile)
        skip = 1
        next
    }
    /<!-- SESSION_LOG_END -->/ {
        skip = 0
        print
        next
    }
    !skip { print }
' "$MD_FILE" > "$TMPFILE"

# Verify the output file looks sane before overwriting
if [[ ! -s "$TMPFILE" ]]; then
    echo "Error: Injection produced an empty file. Original preserved." >&2
    rm -f "$TMPFILE"
    exit 1
fi

mv "$TMPFILE" "$MD_FILE"
echo "  ✓ Transcript injected into Section 3"
echo "  ✓ Raw log: $(basename "$TYPESCRIPT")"
