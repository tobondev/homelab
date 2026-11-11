#!/usr/bin/env python3

import subprocess
from pathlib import Path

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

def get_decrypted_sops(sops_file_path):
    """Decrypts a SOPS file and returns its plaintext string."""
    try:
        result = subprocess.run(
            ["sops", "-d", "--input-type", "dotenv", str(sops_file_path)],
            capture_output=True, text=True, check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting {sops_file_path}: {e.stderr}")
        return None

def encrypt_to_sops(env_path, sops_path):
    """Encrypts a .env file and writes it to a .sops.env file."""
    try:
        with open(sops_path, 'w') as f:
            subprocess.run(
                ["sops", "-e", "--input-type", "dotenv", str(env_path)],
                stdout=f, text=True, check=True
            )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error encrypting {env_path}: {e.stderr}")
        return False

def main():
    tracked_dirs = get_tracked_directories()

    if not tracked_dirs:
        print("No tracked files found. Is this a Git repository?")
        return

    updated = 0
    created = 0
    unchanged = 0

    # Only iterate through directories that exist in the current branch
    for d in tracked_dirs:
        env_path = d / '.env'

        # If the directory doesn't have an .env, skip it
        if not env_path.is_file():
            continue

        sops_path = d / '.sops.env'

        with open(env_path, 'r') as f:
            env_content = f.read()

        if not sops_path.exists():
            print(f"[MISSING] {sops_path} not found. Encrypting...")
            if encrypt_to_sops(env_path, sops_path):
                created += 1
        else:
            sops_content = get_decrypted_sops(sops_path)
            if sops_content is None:
                continue 

            if env_content != sops_content:
                print(f"[OUTDATED] {sops_path} differs from {env_path}. Updating...")
                if encrypt_to_sops(env_path, sops_path):
                    updated += 1
            else:
                unchanged += 1

    print("\n--- SOPS Sync Complete ---")
    print(f"Created: {created} | Updated: {updated} | Unchanged: {unchanged}")

if __name__ == "__main__":
    main()
