#!/usr/bin/env bash

set -Eeuo pipefail

readonly base_ref=${1:-upstream/main}
readonly tip_ref=${2:-HEAD}

for command in git grep mktemp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  fi
done

if ! git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null; then
  printf 'Unknown public-stack base: %s\n' "$base_ref" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "$tip_ref^{commit}" >/dev/null; then
  printf 'Unknown public-stack tip: %s\n' "$tip_ref" >&2
  exit 1
fi

if ! git merge-base --is-ancestor "$base_ref" "$tip_ref"; then
  printf '%s is not an ancestor of %s; audit the branch topology first.\n' \
    "$base_ref" "$tip_ref" >&2
  exit 1
fi

readonly audit_dir=$(mktemp -d "${TMPDIR:-/tmp}/t3code-public-stack.XXXXXX")
trap 'rm -rf -- "$audit_dir"' EXIT

readonly paths_file="$audit_dir/paths"
readonly patches_file="$audit_dir/patches"

git diff --name-only --diff-filter=ACMR "$base_ref..$tip_ref" >"$paths_file"
git format-patch --stdout --no-signature "$base_ref..$tip_ref" >"$patches_file"

if grep -Eq '(^|/)(\.env|id_(rsa|ed25519)|credentials?|secrets?)(\.|$)|\.(key|pem|p12|pfx|mobileprovision|provisionprofile)$|(^|/)\.t3(/|$)|(^|/)userdata(/|$)' \
    "$paths_file"; then
  printf '%s\n' 'Public-stack audit failed: a changed path looks private or credential-bearing.' >&2
  exit 1
fi

readonly credential_pattern='(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|gh[pousr]_[0-9A-Za-z]{20,}|github_pat_[0-9A-Za-z_]{20,}|sk-(proj-)?[0-9A-Za-z_-]{20,}|xox[baprs]-[0-9A-Za-z-]{20,}|tskey-[0-9A-Za-z_-]{10,}|npm_[0-9A-Za-z]{20,}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|https?://[^/@[:space:]]+:[^/@[:space:]]+@)'

if LC_ALL=C grep -Eaq "$credential_pattern" "$patches_file"; then
  printf '%s\n' 'Public-stack audit failed: high-confidence credential material was detected.' >&2
  exit 1
fi

git diff --check "$base_ref..$tip_ref"

printf 'Public-stack audit passed for %s patch commit(s).\n' \
  "$(git rev-list --count "$base_ref..$tip_ref")"
