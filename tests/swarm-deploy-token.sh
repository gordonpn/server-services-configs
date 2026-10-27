#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ROOT_DIR=$(cd "$(dirname "${SCRIPT_PATH}")/.." && pwd)
TASK_BIN=$(command -v task) || { echo 'task binary not found on PATH' >&2; exit 1; }
BASH_BIN=$(command -v bash)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir "${TMP_DIR}/bin"
cp "${ROOT_DIR}/tests/fixtures/docker.sh" "${TMP_DIR}/bin/docker"
chmod +x "${TMP_DIR}/bin/docker"

cd "${ROOT_DIR}"

LOG="${TMP_DIR}/docker-args"
OUTPUT="${TMP_DIR}/task-output"

fail() {
  echo "$*" >&2
  exit 1
}

mkdir "${TMP_DIR}/no-task"
ln -s "$(command -v dirname)" "${TMP_DIR}/no-task/dirname"
ln -s "$(command -v basename)" "${TMP_DIR}/no-task/basename"
status=0
PATH="${TMP_DIR}/no-task" "${BASH_BIN}" "${SCRIPT_PATH}" > "${TMP_DIR}/missing-task-output" 2>&1 || status=$?
[ "${status}" -ne 0 ] || fail 'test script accepted a missing task binary'
grep -Fq 'task binary not found on PATH' "${TMP_DIR}/missing-task-output" \
  || fail 'test script did not explain the missing task binary'

for scenario in missing empty whitespace tab-newline padded-valid internal-whitespace; do
  rm -f "${LOG}"
  status=0
  test_env=("PATH=${TMP_DIR}/bin:${PATH}" "HOME=${HOME}" "DOCKER_TEST_LOG=${LOG}" "DOCKER_TEST_ENV=${TMP_DIR}/docker-env")
  case "${scenario}" in
    missing) ;;
    empty) test_env+=(VPS_TUNNEL_TOKEN=) ;;
    whitespace) test_env+=(VPS_TUNNEL_TOKEN='     ') ;;
    tab-newline) test_env+=(VPS_TUNNEL_TOKEN=$'\t\n') ;;
    padded-valid) test_env+=(VPS_TUNNEL_TOKEN=' offline-tunnel-token ') ;;
    internal-whitespace) test_env+=(VPS_TUNNEL_TOKEN='offline tunnel token') ;;
    *) fail "Unknown token scenario: ${scenario}" ;;
  esac

  env -i "${test_env[@]}" \
    "${TASK_BIN}" --taskfile "${ROOT_DIR}/Taskfile.yaml" \
    swarm:deploy STACK=caddy > "${OUTPUT}" 2>&1 || status=$?

  [ "${status}" -ne 0 ] || fail "caddy deploy accepted ${scenario} token"
  [ ! -e "${LOG}" ] || fail "caddy deploy invoked Docker with ${scenario} token"
  grep -Fq 'VPS_TUNNEL_TOKEN' "${OUTPUT}" \
    || fail "caddy deploy did not identify the required environment variable"
  grep -Fq 'vps_tunnel_token' "${OUTPUT}" \
    || fail "caddy deploy did not identify the Terraform output"
  if grep -Fq 'offline-tunnel-token' "${OUTPUT}"; then
    fail "caddy deploy exposed a tunnel token in the ${scenario} case"
  fi
done

for stack in caddy traefik; do
  rm -f "${LOG}"
  status=0
  test_env=("PATH=${TMP_DIR}/bin:${PATH}" "HOME=${HOME}" "DOCKER_TEST_LOG=${LOG}" "DOCKER_TEST_ENV=${TMP_DIR}/docker-env")
  if [ "${stack}" = caddy ]; then
    test_env+=(VPS_TUNNEL_TOKEN=offline-tunnel-token)
  fi

  env -i "${test_env[@]}" \
    "${TASK_BIN}" --taskfile "${ROOT_DIR}/Taskfile.yaml" \
    swarm:deploy "STACK=${stack}" > "${OUTPUT}" 2>&1 || status=$?

  [ "${status}" -eq 0 ] || fail "${stack} deploy was rejected with valid credentials"
  [ -f "${LOG}" ] || fail "${stack} deploy did not invoke Docker"
  printf '%s\n' stack deploy -c "docker-swarm/${stack}/docker-compose.yml" "${stack}" \
    > "${TMP_DIR}/expected-args"
  cmp -s "${TMP_DIR}/expected-args" "${LOG}" \
    || fail "${stack} deploy did not preserve its Docker arguments"
  expected_token=''
  if [ "${stack}" = caddy ]; then
    expected_token='offline-tunnel-token'
  fi
  [ "$(cat "${TMP_DIR}/docker-env")" = "${expected_token}" ] \
    || fail "${stack} deploy did not pass its expected tunnel token to Docker"
  if grep -Fq 'offline-tunnel-token' "${OUTPUT}"; then
    fail "${stack} deploy exposed the tunnel token"
  fi
done

echo 'PASS: Caddy requires a non-empty tunnel token; other stacks remain deployable without it'
