#!/bin/bash
# =============================================================================
# session-start.sh — Session wrapper for homelab journal entries
# =============================================================================
# Called by new-entry.sh with:
#   $1 = FILENAME        — path to the journal .md file
#   $2 = SCRIPT_ABSOLUTE — directory of the calling script (for parser location)
# ==============================================================================
# Flow:
#   1. Open editor for initial context (outside session — editor noise not logged)
#   2. Prompt to start session
#   3. Run `script` session — launches $SHELL normally, no rc injection
#   4. On exit: parse transcript → inject into doc → reopen editor
# =============================================================================
#
################################################################################

FILENAME="$1"
SCRIPT_ABSOLUTE="$2"

if [[ -z "$FILENAME" || ! -f "$FILENAME" ]]; then
    echo "Error: session-start.sh requires a valid file path as first argument." >&2
    exit 1
fi

################################################################################
# Derive paths
################################################################################

BASENAME=$(basename "$FILENAME" .md)
PARENT_DIR=$(dirname "$FILENAME")
# Logs live in journal/logs/, parallel to sysadmin/ and incident-response/
LOGS_DIR=$(cd "$PARENT_DIR/.." && pwd -P)/logs

mkdir -p "$LOGS_DIR"

TYPESCRIPT="$LOGS_DIR/${BASENAME}.log"
TIMING_FILE="$LOGS_DIR/${BASENAME}.timing"

################################################################################
# Step 1:
#         Initial context — editor opens BEFORE the session starts
#         so editor noise is not captured in the transcript.
#         User writes title context, sections 1 & 2 if ready, or just closes.
################################################################################

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  Step 1 of 2: Initial context                               │"
echo "│                                                             │"
echo "│  Your entry is open. Add any initial notes — what you're    │"
echo "│  trying to accomplish and why. Close when ready.            │"
echo "│                                                             │"
echo "│  (It's fine to leave everything blank and come back later)  │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
sleep 1

${EDITOR:-vi} "$FILENAME"

################################################################################
# Step 2: Confirm session start
################################################################################

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  Step 2 of 2: Terminal session                              │"
echo "│                                                             │"
echo "│  Your session will now be recorded.                         │"
echo "│                                                             │"
echo "│  Use 'note' to mark phase boundaries, for example:          │"
echo "│    note \"Phase 1 - installing dependencies\"               │"
echo "│    note \"Phase 2 - configuring nginx\"                     │"
echo "│    note \"Phase 3 - testing and verification\"              │"
echo "│                                                             │"
echo "│  Type 'exit' or Ctrl-D when your work is complete.          │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
read -rp "  Press Enter to begin recording..."
echo ""

################################################################################
# Step 3: Build temp rcfile scoped to this session, then start recording
################################################################################
# The note() function is injected here rather than installed on $PATH.
# It exists only for the duration of the script(1) session.
#
# =============================================================================
# bash: --rcfile replaces normal rc sourcing, so we source ~/.bashrc manually
# =============================================================================
# zsh:  ZDOTDIR redirects rc lookup to our temp dir; our .zshrc sources the
#       real ~/.zshrc first, so the user's environment is fully intact
# =============================================================================
#
################################################################################

SHELL_NAME=$(basename "$SHELL")

NOTE_FUNC=$(cat << 'EOF'
note() {
    if [[ -z "$*" ]]; then
        echo "Usage: note \"Phase description\"" >&2
        return 1
    fi
    echo ""
    echo "########################################"
    echo "### NOTE $(date +%H:%M:%S): $* ###"
    echo "########################################"
    echo ""
}
EOF
)

if [[ "$SHELL_NAME" == "zsh" ]]; then
    TMPRC_DIR=$(mktemp -d /tmp/homelab-rc-XXXXXX)
    trap 'rm -rf "$TMPRC_DIR"' EXIT
    cat > "$TMPRC_DIR/.zshrc" << EOF
[[ -f ~/.zshrc ]] && source ~/.zshrc
$NOTE_FUNC
EOF
    ZDOTDIR="$TMPRC_DIR" script -q --timing="$TIMING_FILE" "$TYPESCRIPT"

else
    TMPRC=$(mktemp /tmp/homelab-rc-XXXXXX.bash)
    trap 'rm -f "$TMPRC"' EXIT
    cat > "$TMPRC" << EOF
[[ -f ~/.bashrc ]] && source ~/.bashrc
$NOTE_FUNC
EOF
    script -q --timing="$TIMING_FILE" "$TYPESCRIPT" bash --rcfile "$TMPRC"
fi
################################################################################
# Step 4: Parse transcript and inject into Section 3
################################################################################
echo ""
echo "  ● Session ended."
echo ""
echo "  Parsing transcript..."

bash "$SCRIPT_ABSOLUTE/session-parse.sh" "$TYPESCRIPT" "$FILENAME"
PARSE_EXIT=$?

################################################################################
# Step 5: Reopen editor — user is now an editor, not a writer
################################################################################
echo ""
if [[ $PARSE_EXIT -eq 0 ]]; then
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  Section 3 has been populated from your session transcript. │"
    echo "│  Review, edit, and complete the remaining sections.         │"
    echo "└─────────────────────────────────────────────────────────────┘"
else
    echo "  Warning: Transcript parsing encountered an issue."
    echo "  Your raw transcript is at: $TYPESCRIPT"
    echo "  Opening entry for manual completion..."
fi
echo ""
sleep 2
${EDITOR:-vi} "$FILENAME"

################################################################################
# Step 6: Offer to commit. Remind otherwise.
################################################################################
echo ""
read -rp "  Commit this entry now? [y/N] " COMMIT_NOW
echo ""

if [[ "${COMMIT_NOW,,}" == "y" ]]; then
    git -C "$PARENT_DIR" add "$FILENAME" "$TYPESCRIPT"
    git -C "$PARENT_DIR" commit -m "journal: $BASENAME"
else
    echo "  Don't forget to commit:"
    echo "    git add \"$FILENAME\""
    echo "    git add \"$TYPESCRIPT\""
    echo "    git commit -m \"journal: $BASENAME\""
fi
