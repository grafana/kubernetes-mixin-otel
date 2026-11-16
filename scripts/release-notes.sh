#!/usr/bin/env bash
set -euo pipefail

tag=${1:?usage: release-notes.sh <tag>}
previous=$(git describe --tags --abbrev=0 "$tag^" 2>/dev/null || true)

git log --format=%s "${previous:+$previous..}$tag" | awk '
  BEGIN { n = split("Security|Features|Bug fixes|Documentation|Dependencies", order, "|") }
  {
    if ($0 ~ /^[a-z]+\(security\)!?: /) section = "Security"
    else if ($0 ~ /^[a-z]+\(deps\)!?: /) section = "Dependencies"
    else if ($0 ~ /^feat(\([^)]*\))?!?: /) section = "Features"
    else if ($0 ~ /^fix(\([^)]*\))?!?: /) section = "Bug fixes"
    else if ($0 ~ /^docs(\([^)]*\))?!?: /) section = "Documentation"
    else next
    sub(/^[^:]*: /, "")
    notes[section] = notes[section] "- " $0 "\n"
  }
  END {
    for (i = 1; i <= n; i++)
      if (notes[order[i]] != "") printf "## %s\n\n%s\n", order[i], notes[order[i]]
  }
'
