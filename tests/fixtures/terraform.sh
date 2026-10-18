#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" > "${TF_TEST_LOG:?}"
test "${AWS_ACCESS_KEY_ID:-}" = "${TF_TEST_ACCESS_KEY:?}"
test "${AWS_SECRET_ACCESS_KEY:-}" = "${TF_TEST_SECRET_KEY:?}"
