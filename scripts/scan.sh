#!/usr/bin/env bash
set -euo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

cmd=(outskirts scan --format "${INPUT_FORMAT:-github-actions}")
case "${INPUT_FAIL_ON_RESULTS:-true}" in
  true) cmd+=(--strict) ;;
  false) ;;
  *) echo "::error::fail-on-results must be 'true' or 'false'"; exit 1 ;;
esac

if [[ -n "${INPUT_ARGS:-}" ]]; then
  read -r -a extra <<< "$INPUT_ARGS"
  cmd+=("${extra[@]}")
fi

echo "Running: ${cmd[*]}"
"${cmd[@]}"
