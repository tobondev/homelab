#!/bin/sh

# This script dynamically queries the pkg database for all locked packages, feeds that into the native pkg version check utility, comparing against the repository version, and alerts the administrator when the repository is up to date, thus ensuring manually backported packages don't silently fall out of date.
# This script should live under /usr/local/bin when deployed
# Query the pkg database for currently locked packages: evaluate for status lock, respond with name only. Pipe it into a loop and use the result to populate the PACKAGE variable
pkg update -q
pkg query -e '%k = 1' '%n' | while read -r PACKAGE; do

# Currently ported version, to check against official OPNsense repository
TARGET_VER=$(pkg query "%v" "$PACKAGE")
# Query the official OPNsense repository for the current version of the locked package, and store in REPO_VER variable for comparison
REPO_VER=$(pkg rquery "%v" "$PACKAGE")

# Exit on failed query
[ -z "$REPO_VER" ] && continue

# Use 'pkg version -t' to cleanly compare version strings
COMPARE=$(pkg version -t "$REPO_VER" "$TARGET_VER")

# If REPO_VER is equal (=) or newer (>) than TARGET_VER
if [ "$COMPARE" = "=" ] || [ "$COMPARE" = ">" ]; then
    MESSAGE="ALERT: OPNsense official repo now has ${PACKAGE} v${REPO_VER}. You can run 'pkg unlock -y ${PACKAGE}'."
    logger -p daemon.crit -t "CustomPatch" "$MESSAGE"
fi


done
