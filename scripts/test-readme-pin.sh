#!/usr/bin/env bash
# Checks that the commit SHA pinned in the README is the commit of the tag named in its comment.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
line=$(grep -E 'outskirts-action@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+' "$root/README.md" | head -n 1)
if [[ -z "$line" ]]; then
  echo "README: no pinned SHA with a version comment found"
  exit 1
fi
sha=$(printf '%s\n' "$line" | sed -E 's/.*@([0-9a-f]{40}).*/\1/')
tag=$(printf '%s\n' "$line" | sed -E 's/.*# (v[0-9.]+).*/\1/')
if ! tagged=$(git -C "$root" rev-list -n 1 "refs/tags/$tag" 2>/dev/null); then
  echo "README: tag $tag does not exist (fetch tags with fetch-depth: 0)"
  exit 1
fi
if [[ "$tagged" != "$sha" ]]; then
  echo "README: $sha is not the commit of $tag ($tagged)"
  exit 1
fi
echo "README pin OK: $tag = $sha"
