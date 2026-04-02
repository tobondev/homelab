#!/bin/bash
# =============================================================================
# session-start.sh — Session wrapper for homelab journal entries
# =============================================================================
# Called by new-entry.sh with:
#   $1 = FILENAME        — path to the journal .md file
#   $2 = SCRIPT_ABSOLUTE — directory of the calling script (for parser location)
# =============================================================================
# Flow:
#   1. Open editor for initial context (outside session — editor noise not logged)
#   2. Prompt to start session
#   3. Build temp rcfile:
#        a. Stub out blacklisted commands (they run as no-ops during rc sourcing)
#        b. Source the user's real rc (~/.zshrc or ~/.bashrc) — environment intact
#        c. Unset stubs so they are available normally during the session
#        d. Inject note() function for phase annotation
#      Then launch script(1) recording.
#   4. On exit: parse transcript → inject into doc → reopen editor
#   5. Offer to commit
# =============================================================================

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
# Logs live in docs/logs/, parallel to sysadmin/ and incident-response/
LOGS_DIR=$(cd "$PARENT_DIR/.." && pwd -P)/logs

mkdir -p "$LOGS_DIR"

TYPESCRIPT="$LOGS_DIR/${BASENAME}.log"
TIMING_FILE="$LOGS_DIR/${BASENAME}.timing"

################################################################################
# Step 1: Initial context
#         Editor opens BEFORE the session starts so editor noise is not
#         captured in the transcript. Write title context, sections 1 & 2
#         if ready, or just close and come back after the session.
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
echo "│  Run 'note' at any time to mark a phase boundary.           │"
echo "│  You will be prompted to type the label — all characters    │"
echo "│  are safe, including quotes, ! and special characters.      │"
echo "│                                                             │"
echo "│  Type 'exit' or Ctrl-D when your work is complete.          │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
read -rp "  Press Enter to begin recording..."
echo ""

################################################################################
# Step 3: Build temp rcfile scoped to this session, then start recording
################################################################################
#
# note() is injected into the session rather than installed on $PATH.
# It exists only for the duration of the script(1) session.
#
# -----------------------------------------------------------------------------
# Blacklist: commands listed in the blacklist files are stubbed out as no-ops
# *before* the user's rc is sourced. This suppresses startup noise (neofetch,
# fastfetch, etc.) without modifying any user files. Stubs are unset immediately
# after sourcing, so the real commands are available normally in the session.
#
# Two blacklist files are merged:
#   Default  — $SCRIPT_ABSOLUTE/../config/session-blacklist  (ships with repo)
#   User     — ~/.config/homelab/session-blacklist           (user extensions)
#
# Format: one command name per line. Lines starting with # are ignored.
#
# -----------------------------------------------------------------------------
# Shell compatibility:
#   bash — --rcfile replaces normal rc sourcing; we source ~/.bashrc manually
#   zsh  — ZDOTDIR redirects all rc lookup to a temp dir; our .zshrc sources
#          the real ~/.zshrc first, so the user's environment is fully intact
# -----------------------------------------------------------------------------

SHELL_NAME=$(basename "$SHELL")

NOTE_FUNC=$(cat << 'NOTEEOF'
note() {
    local msg
    printf "\n  Phase label: " >&2
    IFS= read -r msg
    if [[ -z "$msg" ]]; then
        echo "  Cancelled." >&2
        return 1
    fi
    echo ""
    echo "########################################"
    echo "### NOTE $(date +%H:%M:%S): $msg ###"
    echo "########################################"
    echo ""
}
NOTEEOF
)

# --- Build stub and unset blocks from blacklist files ---

DEFAULT_BLACKLIST="$SCRIPT_ABSOLUTE/../config/session-blacklist"
USER_BLACKLIST="$HOME/.config/homelab/session-blacklist"

STUB_BLOCK=""
UNSTUB_BLOCK=""

_add_stubs_from_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return
    while IFS= read -r cmd; do
        # Skip empty lines and comments
        [[ -z "$cmd" || "$cmd" == \#* ]] && continue
        # Deduplicate: skip if already added
        [[ "$STUB_BLOCK" == *"${cmd}() { :; }"* ]] && continue
        STUB_BLOCK+="${cmd}() { :; }"$'\n'
        UNSTUB_BLOCK+="unset -f ${cmd} 2>/dev/null"$'\n'
    done < "$file"
}

_add_stubs_from_file "$DEFAULT_BLACKLIST"
_add_stubs_from_file "$USER_BLACKLIST"

# --- Launch recorded session ---

if [[ "$SHELL_NAME" == "zsh" ]]; then
    TMPRC_DIR=$(mktemp -d /tmp/homelab-rc-XXXXXX)
    trap 'rm -rf "$TMPRC_DIR"' EXIT
    cat > "$TMPRC_DIR/.zshrc" << EOF
# --- Stub blacklisted startup commands ---
$STUB_BLOCK
# --- Source real user rc ---
[[ -f ~/.zshrc ]] && source ~/.zshrc

# --- Unset stubs: real commands are now available ---
$UNSTUB_BLOCK
# --- Session tooling ---
$NOTE_FUNC
EOF
    ZDOTDIR="$TMPRC_DIR" script -q --timing="$TIMING_FILE" "$TYPESCRIPT"

else
    TMPRC=$(mktemp /tmp/homelab-rc-XXXXXX.bash)
    trap 'rm -f "$TMPRC"' EXIT
    cat > "$TMPRC" << EOF
# --- Stub blacklisted startup commands ---
$STUB_BLOCK
# --- Source real user rc ---
[[ -f ~/.bashrc ]] && source ~/.bashrc

# --- Unset stubs: real commands are now available ---
$UNSTUB_BLOCK
# --- Session tooling ---
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

# Resolve repo root explicitly rather than relying on -C traversal,
# so that paths outside $PARENT_DIR (e.g. the typescript in docs/logs/)
# are always staged correctly.
REPO_ROOT=$(git -C "$PARENT_DIR" rev-parse --show-toplevel 2>/dev/null)

echo ""
read -rp "  Commit this entry now? [y/N] " COMMIT_NOW
echo ""

if [[ "${COMMIT_NOW,,}" == "y" ]]; then
    if [[ -z "$REPO_ROOT" ]]; then
        echo "  Warning: Could not determine git repository root." >&2
        echo "  Commit manually:" >&2
        echo "    git add \"$FILENAME\"" >&2
        echo "    git add \"$TYPESCRIPT\"" >&2
        echo "    git commit -m \"journal: $BASENAME\"" >&2
    else
        git -C "$REPO_ROOT" add "$FILENAME" "$TYPESCRIPT"
        git -C "$REPO_ROOT" commit -m "journal: $BASENAME"
    fi
else
    echo "  Don't forget to commit:"
    echo "    git add \"$FILENAME\""
    echo "    git add \"$TYPESCRIPT\""
    echo "    git commit -m \"journal: $BASENAME\""
fi
