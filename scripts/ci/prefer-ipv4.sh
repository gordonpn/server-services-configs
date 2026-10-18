#!/usr/bin/env bash
set -euo pipefail

LINE="precedence ::ffff:0:0/96 100"
if ! grep -qxF "${LINE}" /etc/gai.conf 2>/dev/null; then
  echo "${LINE}" | sudo tee -a /etc/gai.conf >/dev/null \
    || echo "WARNING: could not set IPv4 preference in /etc/gai.conf" >&2
fi
