#!/bin/sh
set -eu ; install -m 600 /dev/null .env ; sops -d .sops.env > .env
