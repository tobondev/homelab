##=================================================================##
#  Python-Based Docker Compose Migration and deployment Tool       ##
##=================================================================##
#                                                                  ##
# Usage:                                                           ##
# Add this script to your environment for easier use               ##
# alias traefik-compose="python /path/to/traefik-compose.py"       ##
#                                                                  ##
# By default, the configuration file used is the .env file living  ##
# in the script's base directory. Use the --config flag to pass a  ##
# different environment file.                                      ##
#                                                                  ##
# Base Usage:                                                      ##
#  traefik-compose app-compose.yml                                 ##
# Output:
#   ./docker-compose.yml
##=================================================================##

import sys
import argparse
import subprocess
from pathlib import Path
from ruamel.yaml import YAML
from jinja2 import Environment, FileSystemLoader

# Determine the absolute path of the directory where this script lives
SCRIPT_DIR = Path(__file__).parent.resolve()

# Read .env file.

def find_sops_file(search_dir):
    """ Checks for the existence of a .sops.env or .env file"""
    path = search_dir
    possible_files = ['.sops.env', '.env']

    for filename in possible_files:
        # Create the full path object first
        target_file = path / filename

        # Now ask the new object if it exists
        if target_file.exists():
            return filename

    # Safe fallback if nothing is found
    return '.env'

def parse_config_env(filepath):
    """
    Reads a .env file, decrypting it in-memory via SOPS if encrypted.
    Returns a dictionary of the key-value pairs.
    """
    path = Path(filepath)
    # Print error if no .env file is produced.

    if not path.exists():
        print(f"Error: Global config {filepath} not found.")
        sys.exit(1)
    # Read .env file, store value.
    with open(path, 'r') as f:
        content = f.read()

    # Evaluate for SOPS headers and decrypt if necessary.

    if "sops:" in content or "sops_mac=" in content:
        print(f"SOPS encryption detected in {filepath}. Decrypting on the fly...")
        try:
            result = subprocess.run(["sops", "-d", str(path)], capture_output=True, text=True, check=True)
            content = result.stdout
        except subprocess.CalledProcessError as e:
            print(f"SOPS Decryption failed:\n{e.stderr}")
            sys.exit(1)

    # Create a dictionary based on the data in the .env file
    config_data = {}
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' in line:
            # Remove whitespace characters and split at the *first* "="
            # while ignoring the rest.
            k, v = line.split('=', 1)
            config_data[k.strip()] = v.strip().strip('"\'')
    return config_data

def main():
    # Setup CLI Arguments
    custom_vars = find_sops_file(SCRIPT_DIR)
    parser = argparse.ArgumentParser(description="Traefik-Native Docker Compose Generator")
    # Add help  information.
    parser.add_argument("input", help="Path to the input docker-compose.base.yml")
    # Set the config file at the script root as the default argument. Try .sops.env first, .env second
    parser.add_argument("--config", default=SCRIPT_DIR / custom_vars, help="Path to global .env configuration file (SOPS supported)")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()

    # Force the template directory to be relative to the script, not the execution directory
    template_dir = SCRIPT_DIR / "templates"

    # 2. Load Global Configuration
    global_config = parse_config_env(args.config)

    # 3. Load the Base Compose File
    yaml = YAML(typ='safe')
    try:
        with open(input_path, "r") as f:
            base_data = yaml.load(f)
    except FileNotFoundError:
        print(f"Error: {input_path} not found.")
        sys.exit(1)

    # 4. Extract Container Data
    service_name = list(base_data['services'].keys())[0]
    service_data = base_data['services'][service_name]

    raw_image = service_data.get('image', 'unknown/unknown:latest')
    if '/' in raw_image:
        publisher, rest = raw_image.split('/', 1)
    else:
        publisher, rest = "library", raw_image

    if ':' in rest:
        name, version = rest.split(':', 1)
    else:
        name, version = rest, "latest"

    container_name = service_data.get('container_name', service_name)

    parsed_volumes = []
    for vol in service_data.get('volumes', []):
        if ':' in vol:
            host_path, container_path = vol.split(':', 1)
            vol_name = Path(host_path).name
            parsed_volumes.append({
                "name": vol_name,
                "target": container_path
            })

    env_vars = {}
    raw_env = service_data.get('environment', [])
    if isinstance(raw_env, list):
        for e in raw_env:
            if '=' in e:
                k, v = e.split('=', 1)
                env_vars[k] = v
    elif isinstance(raw_env, dict):
        env_vars = raw_env

    # 5. Build the Master Dictionary
    template_data = {
        **global_config,
        "NAME": service_name,
        "CONTAINER_NAME": container_name,
        "PUBLISHER": publisher,
        "VERSION": version,
        "RESTART": service_data.get('restart', 'always'),
        "environment_vars": env_vars,
        "volumes": parsed_volumes
    }

    # 6. Render the Templates
    env = Environment(loader=FileSystemLoader(template_dir))

    # Output to the Current Working Directory (where the user ran the alias)
    output_compose = Path.cwd() / 'docker-compose.yml'
    output_env = Path.cwd() / '.env'

    compose_template = env.get_template('docker-compose.yml.j2')
    with open(output_compose, 'w') as f:
        f.write(compose_template.render(**template_data))

    env_template = env.get_template('env.j2')
    with open(output_env, 'w') as f:
        f.write(env_template.render(**template_data))

    print(f"Deployment files successfully generated for: {service_name}")
    print(f" -> {output_compose}")
    print(f" -> {output_env}")

if __name__ == "__main__":
    main()
