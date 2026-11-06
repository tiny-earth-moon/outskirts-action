#!/usr/bin/env bash
set -euo pipefail

repo="tiny-earth-moon/outskirts"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "::error::outskirts-action needs a macOS arm64 runner (got $(uname -s) $(uname -m)); use runs-on: macos-15 or macos-latest."
  exit 1
fi

version="${INPUT_VERSION:-latest}"
if [[ "$version" == "latest" ]]; then
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
curl -fsSL --retry 3 -o "${name}.tar.gz" "${base}/${name}.tar.gz"
curl -fsSL --retry 3 -o "${name}.tar.gz.sha256" "${base}/${name}.tar.gz.sha256"

expected="$(awk '{print $1}' "${name}.tar.gz.sha256")"
actual="$(shasum -a 256 "${name}.tar.gz" | awk '{print $1}')"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "::error::Checksum mismatch for ${name}.tar.gz (expected '${expected}', got '${actual}')"
  exit 1
fi

tar xzf "${name}.tar.gz"
bin="${dest}/${name}"
"${bin}/outskirts" version
if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$bin" >> "$GITHUB_PATH"; fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "version=${version}" >> "$GITHUB_OUTPUT"; fi
echo "Installed outskirts ${version}"
