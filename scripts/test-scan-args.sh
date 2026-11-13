#!/usr/bin/env bash
# Runs scan.sh against a fake outskirts that prints one argument per line.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/work"
cat > "$tmp/bin/outskirts" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@"
FAKE
chmod +x "$tmp/bin/outskirts"

failures=0

# expect <name> <fail-on-results> <args> <expected lines...>
expect() {
  local name=$1 fail=$2 args=$3 expected actual
  shift 3
  expected=$(printf '%s\n' "$@")
  actual=$(cd "$tmp/work" && PATH="$tmp/bin:$PATH" INPUT_FAIL_ON_RESULTS="$fail" \
    INPUT_ARGS="$args" INPUT_FORMAT=xcode "$BASH" "$root/scripts/scan.sh" | sed '1d')
  if [[ "$actual" == "$expected" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    echo "  expected: $(printf '%s|' "$@")"
    echo "  actual:   $(printf '%s' "$actual" | tr '\n' '|')"
    failures=$((failures + 1))
  fi
}

# expect_error <name> <args>
expect_error() {
  if (cd "$tmp/work" && PATH="$tmp/bin:$PATH" INPUT_ARGS="$2" "$BASH" "$root/scripts/scan.sh" >/dev/null 2>&1); then
    echo "FAIL $1 (expected an error)"
    failures=$((failures + 1))
  else
    echo "ok   $1"
  fi
}

base=(scan --format xcode)

expect "strict when fail-on-results is true" true "" "${base[@]}" --strict
expect "no-strict when fail-on-results is false" false "" "${base[@]}" --no-strict
expect "empty args" true "" "${base[@]}" --strict
expect "whitespace-only args" true $'  \t \n ' "${base[@]}" --strict
expect "simple args" true "--schemes App --targets App" "${base[@]}" --strict --schemes App --targets App
expect "multi-line args" true $'--schemes App\n--targets App Kit\n' "${base[@]}" --strict --schemes App --targets App Kit
expect "CRLF args" true $'--schemes App\r\n--quiet' "${base[@]}" --strict --schemes App --quiet
expect "double quotes" true '--schemes "My App" --quiet' "${base[@]}" --strict --schemes "My App" --quiet
expect "single quotes" true "--schemes 'My App'" "${base[@]}" --strict --schemes "My App"
expect "quote inside other quote" true "--a \"it's\" --b 'say \"hi\"'" "${base[@]}" --strict --a "it's" --b 'say "hi"'
expect "empty quoted value" true "--a ''" "${base[@]}" --strict --a ""
expect "adjacent quoted parts" true "--a=\"x y\"z" "${base[@]}" --strict "--a=x yz"
expect "command substitution stays literal" true '$(touch pwned) `touch pwned2`' "${base[@]}" --strict '$(touch' 'pwned)' '`touch' 'pwned2`'
expect "separators stay literal" true '--a ; touch pwned && echo x | cat > out' "${base[@]}" --strict --a ';' touch pwned '&&' echo x '|' cat '>' out
expect "glob stays literal" true '* ?.swift [ab]' "${base[@]}" --strict '*' '?.swift' '[ab]'
expect "variables stay literal" true '$HOME ${PATH} ~' "${base[@]}" --strict '$HOME' '${PATH}' '~'
expect_error "unterminated quote" '--schemes "My App'

touch "$tmp/work/a.swift"
expect "glob stays literal with a matching file" true '*.swift' "${base[@]}" --strict '*.swift'
if ls "$tmp/work" | grep -q pwned; then
  echo "FAIL injected command ran"
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
