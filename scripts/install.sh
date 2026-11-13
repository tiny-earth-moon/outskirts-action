#!/usr/bin/env bash
set -euo pipefail

repo="tiny-earth-moon/outskirts"

# Under Rosetta uname -m reports x86_64; hw.optional.arm64 still tells an Apple silicon machine apart.
machine="$(uname -m)"
if [[ "$machine" != "arm64" && "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
  machine="arm64"
fi
if [[ "$(uname -s)" != "Darwin" || "$machine" != "arm64" ]]; then
  echo "::error::outskirts-action needs a macOS arm64 runner (got $(uname -s) $(uname -m)); use runs-on: macos-15 or macos-latest."
  exit 1
fi

require_gh() {
  if ! command -v gh > /dev/null 2>&1; then
    echo "::error::The GitHub CLI (gh) is not installed on this runner; it is needed $1. Install gh, or $2."
    exit 1
  fi
}

version="${INPUT_VERSION:-latest}"
if [[ "$version" == "latest" ]]; then
  require_gh "to resolve version: latest" "set version to an exact release"
  version="$(gh release view -R "$repo" --json tagName -q .tagName)"
fi
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Invalid outskirts version: '$version'"
  exit 1
fi

name="outskirts-${version}-macos-arm64"
base="https://github.com/${repo}/releases/download/${version}"
dest="${RUNNER_TEMP:-$(mktemp -d)}/outskirts-${version}"
mkdir -p "$dest"
cd "$dest"
curl --proto "=https" --tlsv1.2 -fsSL --retry 3 -o "${name}.tar.gz" "${base}/${name}.tar.gz"
curl --proto "=https" --tlsv1.2 -fsSL --retry 3 -o "${name}.tar.gz.sha256" "${base}/${name}.tar.gz.sha256"

expected="$(awk '{print $1}' "${name}.tar.gz.sha256")"
actual="$(shasum -a 256 "${name}.tar.gz" | awk '{print $1}')"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "::error::Checksum mismatch for ${name}.tar.gz (expected '${expected}', got '${actual}')"
  exit 1
fi

# Releases from 3.22.0 carry a build provenance attestation: the archive must have been built by the release
# workflow of the outskirts repository. Older releases have none and are only checked against their checksum.
first_attested="3.22.0"
if [[ "${INPUT_VERIFY_ATTESTATION:-true}" != "true" ]]; then
  echo "Attestation check skipped (verify-attestation: false)"
elif [[ "$(printf '%s\n%s\n' "$first_attested" "$version" | sort -V | head -n 1)" != "$first_attested" ]]; then
  echo "::notice::outskirts ${version} predates build provenance attestations (${first_attested}); only the checksum was verified."
else
  require_gh "to verify the build provenance attestation" "set verify-attestation: false to skip that check"
  if ! gh attestation verify "${name}.tar.gz" -R "$repo" \
    --signer-workflow "${repo}/.github/workflows/bottle.yml" > attestation.log 2>&1; then
    cat attestation.log
    echo "::error::Build provenance attestation of ${name}.tar.gz could not be verified. Set verify-attestation: false to skip this check."
    exit 1
  fi
  echo "Build provenance attestation verified"
fi

tar xzf "${name}.tar.gz"
bin="${dest}/${name}"
"${bin}/outskirts" version
if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$bin" >> "$GITHUB_PATH"; fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "version=${version}" >> "$GITHUB_OUTPUT"; fi
echo "Installed outskirts ${version}"
