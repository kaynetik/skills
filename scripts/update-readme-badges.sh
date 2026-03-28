#!/usr/bin/env bash
# Update the Scan column in README.md from Snyk Agent Scan JSON output.
#
# Usage:
#   ./scripts/update-readme-badges.sh scan-results.json
#
# The JSON must be the output of `snyk-agent-scan --json`.
# The script modifies README.md in-place (in the repo root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
README="$REPO_ROOT/README.md"
RESULTS="${1:?Usage: $0 <scan-results.json>}"

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

if [[ ! -f "$RESULTS" ]]; then
  echo "ERROR: $RESULTS not found." >&2
  exit 1
fi

if ! jq empty "$RESULTS" 2>/dev/null; then
  echo "ERROR: $RESULTS is not valid JSON. Skipping badge update." >&2
  exit 0
fi

root_key=$(jq -r 'keys[0]' "$RESULTS")

declare -A skill_urls
declare -A skill_alts

while IFS=$'\t' read -r skill code; do
  case "$code" in
    E*|TF*) color="red";    label="issue" ;;
    W*)     color="orange";  label="warning" ;;
    *)      color="orange";  label="warning" ;;
  esac
  skill_urls["$skill"]="https://img.shields.io/badge/${code}-${label}-${color}?style=for-the-badge&colorA=363a4f"
  skill_alts["$skill"]="${code} ${label}"
done < <(
  jq -r --arg root "$root_key" '
    .[$root] as $r |
    $r.issues[] |
    ($r.servers[.reference[0]].name) as $skill |
    [
      $skill,
      .code
    ] | @tsv
  ' "$RESULTS"
)

CLEAN_URL="https://img.shields.io/badge/clean-pass-brightgreen?style=for-the-badge&colorA=363a4f"
CLEAN_ALT="clean"

perl_assignments=""
for skill in "${!skill_urls[@]}"; do
  url="${skill_urls[$skill]}"
  alt="${skill_alts[$skill]}"
  perl_assignments+='$urls{"'"$skill"'"} = "'"$url"'"; $alts{"'"$skill"'"} = "'"$alt"'"; '
done

perl -i -e '
  BEGIN {
    %urls = ();
    %alts = ();
    '"$perl_assignments"'
    $clean_url = "'"$CLEAN_URL"'";
    $clean_alt = "'"$CLEAN_ALT"'";
    $skill = "";
  }
  while (<>) {
    if (/<code>([a-z0-9-]+)<\/code>/) {
      $skill = $1;
    }
    if ($skill ne "" && /img src="https:\/\/img\.shields\.io\/badge\//) {
      my $url = exists $urls{$skill} ? $urls{$skill} : $clean_url;
      my $alt = exists $alts{$skill} ? $alts{$skill} : $clean_alt;
      my $old = $_;
      s|img src="https://img\.shields\.io/badge/[^"]*"|img src="$url"|;
      s|alt="[^"]*"|alt="$alt"|;
      if ($_ ne $old) {
        print STDERR "Updated $skill\n";
      }
      $skill = "";
    }
    print;
  }
' "$README"
