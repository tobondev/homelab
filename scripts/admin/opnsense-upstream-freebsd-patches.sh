#!/bin/sh
# ==============================================================================
# freebsd-upstream.sh -- Patch Automation & Recovery Toolkit
# ==============================================================================
# Upgrades packages from FreeBSD when OPNsense repositories lag.
# Generates a Markdown artifact for documentation and supports rollbacks.
# ==============================================================================

TMP_DIR="/tmp/freebsd_pkgsite"
REPOURL=""
VISITED=""
TO_INSTALL=""
BEFORE_VERSIONS=""
DRY_RUN=0
ROLLBACK_FILE=""

usage() {
    echo "Usage: $0 [-n] <package> [package2 ...]"
    echo "       $0 -r <artifact_file.md>"
    echo "  -n  Dry run — show changes without installing"
    echo "  -r  Rollback — revert system to versions in the specified artifact"
    exit 1
}

################################################################################
# Logic: Artifact Generation & Rollback
################################################################################

generate_artifact() {
    report_file="patch_artifact_$(date +%Y%m%d_%H%M).md"
    {
        echo "# Patch Remediation Artifact"
        echo "**Date:** $(date)"
        echo "**Host:** $(hostname)"
        echo ""
        echo "| Package | Version (Before) | Version (After) | Status |"
        echo "| :--- | :--- | :--- | :--- |"

        for pkg in $TO_INSTALL; do
            # Extract old version from the capture string
            old_v=$(printf '%b' "$BEFORE_VERSIONS" | grep "^${pkg}:" | cut -d: -f2)
            new_v=$(pkg query "%v" "$pkg")
            echo "| $pkg | $old_v | $new_v | Patched |"
        done
    } > "$report_file"
    echo "==> Artifact saved to: $report_file"
}

rollback_from_artifact() {
    artifact_file="$1"
    if [ ! -f "$artifact_file" ]; then
        echo "ERROR: Artifact file $artifact_file not found." >&2; exit 1
    fi

    echo "==> Parsing artifact for rollback instructions..."
    # Extracts Package and Version (Before) from the MD table
    REVERT_LIST=$(grep "^| " "$artifact_file" | grep -v "Package" | grep -v ":---" | awk -F'|' '{print $2 ":" $3}' | tr -d ' ' | tr -d '`')

    for entry in $REVERT_LIST; do
        pkg_name=$(echo "$entry" | cut -d: -f1)
        old_version=$(echo "$entry" | cut -d: -f2)
        
        printf '  REVERT %-30s to %s\n' "$pkg_name" "$old_version"
        
        if [ "$DRY_RUN" -eq 0 ]; then
            # Force OPNsense to sync back to repo version
            pkg upgrade -y "$pkg_name"
        else
            echo "  [dry-run] pkg upgrade -y $pkg_name"
        fi
    done
}

################################################################################
# Logic: Analysis & Patching
################################################################################

get_freebsd_catalog() {
    freebsd_ver=$(freebsd-version -u | cut -d- -f1 | cut -d. -f1)
    arch=$(uname -m)
    REPOURL="https://pkg.freebsd.org/FreeBSD:${freebsd_ver}:${arch}/latest"
    mkdir -p "$TMP_DIR"
    
    echo "==> Fetching catalog from ${REPOURL}..."
    fetch -q -o "${TMP_DIR}/packagesite.pkg" "${REPOURL}/packagesite.pkg" || {
        echo "ERROR: Failed to fetch catalog" >&2; exit 1
    }
    tar -xf "${TMP_DIR}/packagesite.pkg" -C "$TMP_DIR" packagesite.yaml
    rm -f "${TMP_DIR}/packagesite.pkg"

    echo "==> Parsing catalog..."
    # Replaced flawed EOF block with a clean inline Python execution utilizing JSON Lines
    python3 -c '
import sys, json, os

input_path = sys.argv[1]
output_path = sys.argv[2]

if not os.path.exists(input_path):
    print(f"ERROR: Catalog file not found at {input_path}")
    sys.exit(1)

with open(input_path, "r") as infile, open(output_path, "w") as outfile:
    for line in infile:
        if not line.strip():
            continue
        try:
            pkg_manifest = json.loads(line)
            # separators=(",", ":") removes whitespace to ensure grep/sed logic works downstream
            outfile.write(json.dumps(pkg_manifest, separators=(",", ":")) + "\n")
        except json.JSONDecodeError as e:
            pass # Skip invalid lines silently, just as the original script intended
' "${TMP_DIR}/packagesite.yaml" "${TMP_DIR}/packagesite.parsed"

    # Verify the Python script actually generated the parsed file
    if [ ! -f "${TMP_DIR}/packagesite.parsed" ]; then
        echo "ERROR: Failed to parse packagesite.yaml" >&2; exit 1
    fi
}

catalog_entry() { grep "\"name\":\"${1}\"" "${TMP_DIR}/packagesite.parsed" | head -1; }
parse_field() { printf '%s' "$1" | sed -n "s/.*\"${2}\":\"\([^\"]*\)\".*/\1/p"; }

catalog_deps() {
    printf '%s\n' "$1" | python3 -c \
        "import sys,json; d=json.loads(sys.stdin.read()); [print(k) for k in d.get('deps',{}).keys()]" 2>/dev/null
}

collect_upgrades() {
    pkg_name="$1"
    case " $VISITED " in *" ${pkg_name} "*) return ;; esac
    VISITED="$VISITED $pkg_name"
    
    entry=$(catalog_entry "$pkg_name")
    [ -z "$entry" ] && return
    
    fb_ver=$(parse_field "$entry" "version")

    if ! pkg info -e "$pkg_name" 2>/dev/null; then
        for dep in $(catalog_deps "$entry"); do collect_upgrades "$dep"; done
        return
    fi

    installed_ver=$(pkg query "%v" "$pkg_name")
    cmp=$(pkg version -t "$installed_ver" "$fb_ver")

    for dep in $(catalog_deps "$entry"); do collect_upgrades "$dep"; done
    if [ "$cmp" = "<" ]; then
        printf '  QUEUE %-30s %s -> %s\n' "$pkg_name" "$installed_ver" "$fb_ver"
        TO_INSTALL="$TO_INSTALL $pkg_name"
    fi
}

install_from_freebsd() {
    pkg_name="$1"
    entry=$(catalog_entry "$pkg_name")
    repopath=$(parse_field "$entry" "repopath")
    url="${REPOURL}/${repopath}"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] pkg add ${url}"
    else
        echo "==> Installing $pkg_name..."
        pkg add -f "$url"
    fi
}

################################################################################
# Main
################################################################################

while getopts "nr:" opt; do
    case "$opt" in
        n) DRY_RUN=1 ;;
        r) ROLLBACK_FILE="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# Handle Rollback Mode
if [ -n "$ROLLBACK_FILE" ]; then
    rollback_from_artifact "$ROLLBACK_FILE"
    exit 0
fi

[ $# -eq 0 ] && usage
get_freebsd_catalog

echo "==> Analyzing dependencies..."
for pkg in "$@"; do collect_upgrades "$pkg"; done

if [ -z "$TO_INSTALL" ]; then
    echo "Nothing to upgrade."; exit 0
fi

# Capture "Before" state
for pkg in $TO_INSTALL; do
    v=$(pkg query "%v" "$pkg")
    BEFORE_VERSIONS="${BEFORE_VERSIONS}${pkg}:${v}\n"
done

printf '\nProceed with upgrade? [y/N] '
read -r confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    for pkg in $TO_INSTALL; do install_from_freebsd "$pkg"; done
    [ "$DRY_RUN" -eq 0 ] && generate_artifact
else
    echo "Aborted."
fi
