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

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE_NAME="tofu_${TOFU_VERSION}_${OS}_${ARCH}.tar.gz"
ARCHIVE="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS="${TMP_DIR}/tofu_${TOFU_VERSION}_SHA256SUMS"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/${ARCHIVE_NAME}" \
  -o "${ARCHIVE}"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_SHA256SUMS" \
  -o "${CHECKSUMS}"

(
  cd "${TMP_DIR}"
  if command -v sha256sum >/dev/null 2>&1; then
    grep -F "${ARCHIVE_NAME}" "${CHECKSUMS}" | sha256sum -c -
  else
    grep -F "${ARCHIVE_NAME}" "${CHECKSUMS}" | shasum -a 256 -c -
  fi
)

tar -zxf "${ARCHIVE}" -C "${BIN_DIR}" tofu
chmod +x "${BIN_DIR}/tofu"
ln -sf "${BIN_DIR}/tofu" "${BIN_DIR}/terraform"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${BIN_DIR}" >> "${GITHUB_PATH}"
fi
