#!/usr/bin/env bash
set -euo pipefail

echo "precedence ::ffff:0:0/96 100" | sudo tee /etc/gai.conf || true
