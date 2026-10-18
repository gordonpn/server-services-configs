#!/usr/bin/env bash
set -euo pipefail

TOFU_VERSION="${1:-1.13.1}"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "${ARCH}" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_${OS}_${ARCH}.tar.gz" \
  -o /tmp/tofu.tar.gz

tar -zxf /tmp/tofu.tar.gz -C "${BIN_DIR}" tofu
rm -f /tmp/tofu.tar.gz
chmod +x "${BIN_DIR}/tofu"
ln -sf "${BIN_DIR}/tofu" "${BIN_DIR}/terraform"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${BIN_DIR}" >> "${GITHUB_PATH}"
fi
