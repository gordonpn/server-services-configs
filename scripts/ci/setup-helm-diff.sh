#!/usr/bin/env bash
set -euo pipefail

DIFF_VERSION="${1:-3.15.12}"

HELM_BIN="${HELM_BIN:-${HOME}/.local/bin/helm}"
if [ ! -x "${HELM_BIN}" ]; then
  HELM_BIN="$(command -v helm)"
fi

if "${HELM_BIN}" plugin list | awk -v ver="${DIFF_VERSION}" 'NR > 1 && $1 == "diff" && $2 == ver { found = 1 } END { exit !found }'; then
  exit 0
fi

case "$(uname -s)" in
  Linux)
    OS="linux"
    ;;
  Darwin)
    OS="macos"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

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

case "${DIFF_VERSION}:${OS}:${ARCH}" in
  3.15.12:linux:amd64)
    DIFF_SHA256="977f92cd82269585a3ee7744d646462142333bb0be573fd8be0c983973175fc7"
    ;;
  3.15.12:linux:arm64)
    DIFF_SHA256="c3d240d4b284b57b6ab76bbfe47ac84edbf0de239f15c4ff759152fa2b7777f8"
    ;;
  3.15.12:macos:amd64)
    DIFF_SHA256="b0f836ad0ca146f896d0da16ffd03bde4d414cd2e2920b11455cd551f3adf933"
    ;;
  3.15.12:macos:arm64)
    DIFF_SHA256="cb9e5b6cb157e17bc70ca0f719635914fa9c39e89b82d67a0b78c4538632b580"
    ;;
  *)
    echo "Unsupported helm-diff target or unpinned version: ${DIFF_VERSION} (${OS}/${ARCH})" >&2
    exit 1
    ;;
esac

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE="${TMP_DIR}/helm-diff-${OS}-${ARCH}.tgz"

curl -sSL --retry 5 --retry-delay 3 --retry-connrefused --fail \
  "https://github.com/databus23/helm-diff/releases/download/v${DIFF_VERSION}/helm-diff-${OS}-${ARCH}.tgz" \
  -o "${ARCHIVE}"

if command -v sha256sum >/dev/null 2>&1; then
  echo "${DIFF_SHA256}  ${ARCHIVE}" | sha256sum -c -
else
  echo "${DIFF_SHA256}  ${ARCHIVE}" | shasum -a 256 -c -
fi

PLUGIN_DIR="$("${HELM_BIN}" env HELM_PLUGINS)"
mkdir -p "${PLUGIN_DIR}"
rm -rf "${PLUGIN_DIR}/diff" "${PLUGIN_DIR}/helm-diff"
tar -zxf "${ARCHIVE}" -C "${PLUGIN_DIR}"
