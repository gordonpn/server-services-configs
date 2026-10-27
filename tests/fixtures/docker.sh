#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "${DOCKER_TEST_LOG:?}"
printf '%s' "${VPS_TUNNEL_TOKEN:-}" > "${DOCKER_TEST_ENV:?}"
