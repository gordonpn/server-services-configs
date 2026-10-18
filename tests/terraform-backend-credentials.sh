#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TASK_BIN=$(command -v task)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir "${TMP_DIR}/bin"
cp "${ROOT_DIR}/tests/fixtures/terraform.sh" "${TMP_DIR}/bin/terraform"
chmod +x "${TMP_DIR}/bin/terraform"

TEST_ACCESS_KEY='offline-access-key'
TEST_SECRET_KEY="offline-secret-with-'quote-and-\$dollar"
TEST_ENDPOINT='http://backend.example.test:9000'
LOG="${TMP_DIR}/terraform-args"
OUTPUT="${TMP_DIR}/task-output"

fail() {
  echo "$*" >&2
  exit 1
}

for operation in init plan apply destroy; do
  for scenario in missing-both missing-access missing-secret empty-access empty-secret valid; do
    credentials=("TF_TEST_ACCESS_KEY=${TEST_ACCESS_KEY}" "TF_TEST_SECRET_KEY=${TEST_SECRET_KEY}")
    case "${scenario}" in
      missing-both) ;;
      missing-access) credentials+=("AWS_SECRET_ACCESS_KEY=${TEST_SECRET_KEY}") ;;
      missing-secret) credentials+=("AWS_ACCESS_KEY_ID=${TEST_ACCESS_KEY}") ;;
      empty-access) credentials+=("AWS_ACCESS_KEY_ID=" "AWS_SECRET_ACCESS_KEY=${TEST_SECRET_KEY}") ;;
      empty-secret) credentials+=("AWS_ACCESS_KEY_ID=${TEST_ACCESS_KEY}" "AWS_SECRET_ACCESS_KEY=") ;;
      valid) credentials+=("AWS_ACCESS_KEY_ID=${TEST_ACCESS_KEY}" "AWS_SECRET_ACCESS_KEY=${TEST_SECRET_KEY}") ;;
      *) fail "Unknown credential scenario: ${scenario}" ;;
    esac

    rm -f "${LOG}"
    status=0
    env -i PATH="${TMP_DIR}/bin:${PATH}" HOME="${HOME}" \
      TF_TEST_LOG="${LOG}" TF_BACKEND_ENDPOINT="${TEST_ENDPOINT}" \
      "${credentials[@]}" "${TASK_BIN}" --taskfile "${ROOT_DIR}/Taskfile.yaml" \
      "tf:${operation}" -- -input=false > "${OUTPUT}" 2>&1 || status=$?

    if grep -Fq "${TEST_SECRET_KEY}" "${OUTPUT}"; then
      fail "tf:${operation} exposed a credential in ${scenario} output"
    fi

    if [ "${scenario}" != valid ]; then
      [ "${status}" -ne 0 ] || fail "tf:${operation} accepted ${scenario} credentials"
      [ ! -e "${LOG}" ] || fail "tf:${operation} invoked Terraform with ${scenario} credentials"
      grep -Eq 'Export AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY)' "${OUTPUT}" \
        || fail "tf:${operation} did not identify the missing credential"
      continue
    fi

    [ "${status}" -eq 0 ] || fail "tf:${operation} rejected valid credentials"
    [ -f "${LOG}" ] || fail "tf:${operation} did not invoke Terraform"
    expected=("${operation}")
    if [ "${operation}" = init ]; then
      expected+=("-backend-config=endpoint=${TEST_ENDPOINT}")
    fi
    expected+=(-input=false)
    printf '%s\n' "${expected[@]}" > "${TMP_DIR}/expected-args"
    cmp -s "${TMP_DIR}/expected-args" "${LOG}" \
      || fail "tf:${operation} did not preserve its arguments"
  done
done

echo 'PASS: all four backend tasks reject missing/empty credentials and preserve valid credentials and arguments'
