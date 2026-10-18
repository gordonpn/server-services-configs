#!/usr/bin/env bash
set -euo pipefail

TASK_VERSION="${1:-3.52.0}"
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

ARCHIVE_NAME="task_${OS}_${ARCH}.tar.gz"
ARCHIVE="${TMP_DIR}/${ARCHIVE_NAME}"
CHECKSUMS="${TMP_DIR}/task_checksums.txt"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/${ARCHIVE_NAME}" \
  -o "${ARCHIVE}"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_checksums.txt" \
  -o "${CHECKSUMS}"

(
  cd "${TMP_DIR}"
  if command -v sha256sum >/dev/null 2>&1; then
    grep -F "${ARCHIVE_NAME}" "${CHECKSUMS}" | sha256sum -c -
  else
    grep -F "${ARCHIVE_NAME}" "${CHECKSUMS}" | shasum -a 256 -c -
  fi
)

tar -zxf "${ARCHIVE}" -C "${BIN_DIR}" task
chmod +x "${BIN_DIR}/task"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${BIN_DIR}" >> "${GITHUB_PATH}"
fi
