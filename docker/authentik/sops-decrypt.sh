#!/bin/sh
set -eu

echo "Decrypting .sops.env..."
sops -d .sops.env > .env
echo "Decryption complete. Removing SOPS file"
rm .sops.env
