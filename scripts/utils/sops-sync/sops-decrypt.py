#!/usr/bin/env python3

import subprocess
import shutil
from pathlib import Path
import os

def get_tracked_directories():
    """Returns a set of all directories currently tracked or staged in Git."""
    try:
        result = subprocess.run(
            ["git", "ls-files"], capture_output=True, text=True, check=True
        )
        # Extract the parent directory of every file Git knows about
        return {Path(f).parent for f in result.stdout.splitlines()}
    except subprocess.CalledProcessError as e:
        print(f"Error querying git for tracked files: {e.stderr}")
        return set()

def ensure_hook_script(target_dir, source_hook_path):
    """Copies the hook script, makes it executable, and stages it for commit."""
    if not source_hook_path.is_file():
        print(f"[WARNING] Master hook script {source_hook_path} not found. Skipping hook sync.")
        return False

    target_hook_path = target_dir / source_hook_path.name
    changed = False

    try:
        # Check if contents match to avoid unnecessary metadata updates
        if target_hook_path.exists() and target_hook_path.read_text() == source_hook_path.read_text():
            # Check if it's already executable
            if not os.access(target_hook_path, os.X_OK):
                target_hook_path.chmod(target_hook_path.stat().st_mode | 0o111)
                changed = True
        else:
            # Copy file and ensure it is executable
            shutil.copy2(source_hook_path, target_hook_path)
            target_hook_path.chmod(target_hook_path.stat().st_mode | 0o111)
            changed = True

        # If we touched the file, we MUST stage it so it catches the current commit
        if changed:
            subprocess.run(["git", "add", str(target_hook_path)], check=True)
            return True

        return False

    except Exception as e:
        print(f"Error syncing hook script to {target_dir}: {e}")
        return False

def main():
    # Resolve the directory where this python script lives to find sops-decrypt.sh
    script_dir = Path(__file__).resolve().parent
    source_hook = script_dir / "sops-decrypt.sh"

    tracked_dirs = get_tracked_directories()

    if not tracked_dirs:
        print("No tracked files found. Is this a Git repository?")
        return

    hooks_synced = 0
    dirs_checked = 0

    # Only iterate through directories that exist in the current branch
    for d in tracked_dirs:
        sops_path = d / '.sops.env'

        # If the directory has a .sops.env file, ensure the deployment hook is present and staged
        if sops_path.exists():
            dirs_checked += 1
            if ensure_hook_script(d, source_hook):
                print(f"[HOOK SYNCED] Placed and staged {source_hook.name} in {d}")
                hooks_synced += 1

    print("\n--- Hook Sync Complete ---")
    print(f"Directories with .sops.env checked: {dirs_checked}")
    print(f"Hooks Placed & Staged: {hooks_synced}")

if __name__ == "__main__":
    main()
