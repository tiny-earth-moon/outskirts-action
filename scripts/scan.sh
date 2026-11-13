#!/usr/bin/env bash
set -euo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

cmd=(outskirts scan --format "${INPUT_FORMAT:-github-actions}")
case "${INPUT_FAIL_ON_RESULTS:-true}" in
  true) cmd+=(--strict) ;;
  false) cmd+=(--no-strict) ;;
  *) echo "::error::fail-on-results must be 'true' or 'false'"; exit 1 ;;
esac

# Splits $1 into words on spaces, tabs and newlines. Single or double quotes
# group a value that contains whitespace; nothing else is interpreted and the
# text is never evaluated.
split_args() {
  local input=$1 word="" quote="" in_word=0 c i
  for ((i = 0; i < ${#input}; i++)); do
    c=${input:i:1}
    if [[ -n "$quote" ]]; then
      if [[ "$c" == "$quote" ]]; then quote=""; else word+=$c; fi
    elif [[ "$c" == "'" || "$c" == '"' ]]; then
      quote=$c
      in_word=1
    elif [[ "$c" == " " || "$c" == $'\t' || "$c" == $'\n' || "$c" == $'\r' ]]; then
      if ((in_word)); then extra+=("$word"); fi
      word=""
      in_word=0
    else
      word+=$c
      in_word=1
    fi
  done
  if [[ -n "$quote" ]]; then
    echo "::error::args has an unterminated $quote quote"
    exit 1
  fi
  if ((in_word)); then extra+=("$word"); fi
}

extra=()
split_args "${INPUT_ARGS:-}"
if ((${#extra[@]})); then
  cmd+=("${extra[@]}")
fi

echo "Running: ${cmd[*]}"
"${cmd[@]}"
