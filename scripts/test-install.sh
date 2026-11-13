#!/usr/bin/env bash
# Runs install.sh offline against fake uname, sysctl, gh and curl binaries.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

version=3.23.0
name="outskirts-${version}-macos-arm64"
mkdir -p "$tmp/release/$name" "$tmp/fake" "$tmp/gh"
printf '#!/bin/sh\necho %s\n' "$version" > "$tmp/release/$name/outskirts"
chmod +x "$tmp/release/$name/outskirts"
(cd "$tmp/release" && tar czf "$name.tar.gz" "$name" && shasum -a 256 "$name.tar.gz" > "$name.tar.gz.sha256")

cat > "$tmp/fake/uname" <<'FAKE'
#!/bin/sh
case "$1" in -s) echo Darwin ;; -m) echo "${FAKE_MACHINE:-arm64}" ;; esac
FAKE
cat > "$tmp/fake/sysctl" <<'FAKE'
#!/bin/sh
case "$2" in hw.optional.arm64) echo "${FAKE_HW_ARM64:-1}" ;; *) exit 1 ;; esac
FAKE
cat > "$tmp/fake/curl" <<'FAKE'
#!/bin/sh
echo "$*" >> "$FAKE_LOG"
out="" url=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out=$2; shift ;; https://*) url=$1 ;; esac
  shift
done
cp "$FAKE_RELEASE/${url##*/}" "$out"
FAKE
cat > "$tmp/gh/gh" <<'FAKE'
#!/bin/sh
case "$1" in
  release) echo "v3.23.0" ;;
  attestation) [ "${FAKE_ATTESTATION:-ok}" = ok ] ;;
esac
FAKE
chmod +x "$tmp/fake/"* "$tmp/gh/gh"

# The base PATH keeps the system tools install.sh needs, but no gh.
base_path=/usr/bin:/bin:/usr/sbin:/sbin
failures=0

gh_dir="$tmp/gh"

# run <name> <expected status> <expected output pattern> [VAR=value...]
run() {
  local case_name=$1 status=$2 pattern=$3 out code=0
  shift 3
  rm -rf "$tmp/runner" && mkdir "$tmp/runner"
  out=$(env -i HOME="$HOME" PATH="$tmp/fake:$gh_dir:$base_path" RUNNER_TEMP="$tmp/runner" FAKE_RELEASE="$tmp/release" \
    FAKE_LOG="$tmp/runner/curl.log" INPUT_VERSION="$version" "$@" /bin/bash "$root/scripts/install.sh" 2>&1) || code=$?
  if [[ "$code" != "$status" ]] || ! grep -q -- "$pattern" <<< "$out"; then
    echo "FAIL $case_name (exit $code, expected $status, pattern '$pattern'):"
    echo "$out"
    failures=$((failures + 1))
  else
    echo "ok   $case_name"
  fi
}

run "attested install" 0 "Build provenance attestation verified"
run "latest resolved with gh" 0 "Installed outskirts 3.23.0" INPUT_VERSION=latest
run "attestation failure" 1 "::error::Build provenance attestation" FAKE_ATTESTATION=bad
run "skipped attestation" 0 "Attestation check skipped" INPUT_VERIFY_ATTESTATION=false

gh_dir="$tmp/no-gh"
run "latest without gh" 1 "::error::The GitHub CLI (gh) is not installed.*resolve version: latest" INPUT_VERSION=latest
run "attestation without gh" 1 "::error::The GitHub CLI (gh) is not installed.*verify the build provenance"
run "no gh, attestation skipped" 0 "Installed outskirts 3.23.0" INPUT_VERIFY_ATTESTATION=false

if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all install cases passed"
