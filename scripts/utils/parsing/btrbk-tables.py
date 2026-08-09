import re
import sys

def convert_btrbk_to_md(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        
        # Skip empty lines
        if not line:
            print()
            continue
            
        # Format Section Headers (e.g., "BACKUP SCHEDULE")
        if line.isupper() and "  " not in line and not line.startswith("-"):
            print(f"\n### {line}")
            continue
            
        # Drop the raw text dashes under section titles
        if set(line) == {'-'}:
            continue
            
        # Split columns by 2 or more spaces
        parts = re.split(r' {2,}', line)
        
        if len(parts) > 1:
            # Build and print the row
            print("| " + " | ".join(parts) + " |")
            
            # If this was the header row, inject the Markdown separator
            if parts[0] in ["ACTION", "LOCALTIME"]:
                separator = ["---"] * len(parts)
                print("| " + " | ".join(separator) + " |")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python btrbk_to_md.py <raw_artifact_file>")
        sys.exit(1)
        
    convert_btrbk_to_md(sys.argv[1])
