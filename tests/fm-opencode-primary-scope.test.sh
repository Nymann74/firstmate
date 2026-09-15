#!/usr/bin/env bash
# Regression for the OpenCode watch-arm root-eligibility predicate in
# .opencode/plugins/lib/fm-primary-scope.js. That module is the cross-language
# mirror of the authoritative bin/fm-primary-scope-lib.sh, so this suite pins
# both facts: a valid .fm-secondmate-home marker admits a linked worktree as a
# guarded primary, and the JS mirror agrees with the shell owner on every
# fixture. Genuinely foreign or unmarked roots stay rejected.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=bin/fm-primary-scope-lib.sh
. "$ROOT/bin/fm-primary-scope-lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-opencode-primary-scope)
PLUGIN_LIB="$ROOT/.opencode/plugins/lib/fm-primary-scope.js"
export NODE_NO_WARNINGS=1
fm_git_identity

BASE="$TMP_ROOT/base"
mkdir -p "$BASE"
git -C "$BASE" init -q -b main
mkdir -p "$BASE/bin" "$BASE/state"
printf '# primary fixture\n' > "$BASE/AGENTS.md"
printf 'fixture\n' > "$BASE/bin/.keep"
git -C "$BASE" add -A
git -C "$BASE" commit -qm fixture

make_linked() {
  local path=$1
  git -C "$BASE" worktree add -q --detach "$path"
  mkdir -p "$path/state"
}

mark() {
  printf '%s' "$2" > "$1/.fm-secondmate-home"
}

# A plain git clone is a normal primary checkout (git-dir == git-common-dir).
CLONE="$TMP_ROOT/plain-clone"
git clone -q "$BASE" "$CLONE"
mkdir -p "$CLONE/state"

# Each marker variant needs its own linked worktree so every fixture is in its
# final state for the single batched predicate run.
WT_NO_MARKER="$TMP_ROOT/wt-no-marker"
WT_VALID="$TMP_ROOT/wt-valid"
WT_SYMLINK="$TMP_ROOT/wt-symlink"
WT_EMPTY="$TMP_ROOT/wt-empty"
WT_WS="$TMP_ROOT/wt-ws"
WT_SPACE="$TMP_ROOT/wt-space"
WT_BANG="$TMP_ROOT/wt-bang"
WT_SLASH="$TMP_ROOT/wt-slash"
WT_CRLF="$TMP_ROOT/wt-crlf"
WT_UNTERMINATED="$TMP_ROOT/wt-unterminated"
WT_NBSP="$TMP_ROOT/wt-nbsp"
WT_NO_AGENTS="$TMP_ROOT/wt-no-agents"
WT_NO_BIN="$TMP_ROOT/wt-no-bin"
WT_NO_STATE="$TMP_ROOT/wt-no-state"
for wt in "$WT_NO_MARKER" "$WT_VALID" "$WT_SYMLINK" "$WT_EMPTY" "$WT_WS" \
  "$WT_SPACE" "$WT_BANG" "$WT_SLASH" "$WT_CRLF" "$WT_UNTERMINATED" "$WT_NBSP" \
  "$WT_NO_AGENTS" "$WT_NO_BIN" "$WT_NO_STATE"; do
  make_linked "$wt"
done

mark "$WT_VALID" 'coach
'
mark "$WT_SYMLINK" 'coach
'
ln -sfn "$WT_VALID/.fm-secondmate-home" "$WT_SYMLINK/.fm-secondmate-home"
: > "$WT_EMPTY/.fm-secondmate-home"
mark "$WT_WS" '   
'
mark "$WT_SPACE" 'co ach
'
mark "$WT_BANG" 'co!ach
'
mark "$WT_SLASH" 'co/ach
'
printf 'coach\r\n' > "$WT_CRLF/.fm-secondmate-home"
# First line with no terminator: Bash read fails at EOF, so the owner rejects.
printf 'coach' > "$WT_UNTERMINATED/.fm-secondmate-home"
# U+00A0 NBSP is not LC_ALL=C [[:space:]], so the owner keeps it and rejects.
printf 'co\302\240ach\n' > "$WT_NBSP/.fm-secondmate-home"
mark "$WT_NO_AGENTS" 'coach
'
rm -f "$WT_NO_AGENTS/AGENTS.md"
mark "$WT_NO_BIN" 'coach
'
rm -rf "${WT_NO_BIN:?}/bin"
mark "$WT_NO_STATE" 'coach
'
rm -rf "${WT_NO_STATE:?}/state"

# A non-git directory that nevertheless carries a valid marker and every other
# required path: the marker is the identity, so the authoritative owner
# force-includes it and the mirror must agree rather than inventing a stricter
# git requirement.
MARKED_NONGIT="$TMP_ROOT/marked-nongit"
mkdir -p "$MARKED_NONGIT/bin" "$MARKED_NONGIT/state"
printf '# marker-only fixture\n' > "$MARKED_NONGIT/AGENTS.md"
mark "$MARKED_NONGIT" 'coach
'

# A plainly foreign directory: no git, no marker, missing bin.
FOREIGN="$TMP_ROOT/foreign"
mkdir -p "$FOREIGN" "$FOREIGN/state"
printf '# foreign fixture\n' > "$FOREIGN/AGENTS.md"

# name|root|state|expected
CASES=(
  "plain_checkout_no_marker|$BASE|$BASE/state|true"
  "clone_valid_marker|$CLONE|$CLONE/state|true"
  "linked_no_marker|$WT_NO_MARKER|$WT_NO_MARKER/state|false"
  "linked_valid_marker|$WT_VALID|$WT_VALID/state|true"
  "linked_symlink_marker|$WT_SYMLINK|$WT_SYMLINK/state|false"
  "linked_empty_marker|$WT_EMPTY|$WT_EMPTY/state|false"
  "linked_whitespace_marker|$WT_WS|$WT_WS/state|false"
  "linked_collapsed_space_marker|$WT_SPACE|$WT_SPACE/state|true"
  "linked_bang_marker|$WT_BANG|$WT_BANG/state|false"
  "linked_slash_marker|$WT_SLASH|$WT_SLASH/state|false"
  "linked_crlf_marker|$WT_CRLF|$WT_CRLF/state|true"
  "linked_unterminated_marker|$WT_UNTERMINATED|$WT_UNTERMINATED/state|false"
  "linked_nbsp_marker|$WT_NBSP|$WT_NBSP/state|false"
  "linked_missing_agents|$WT_NO_AGENTS|$WT_NO_AGENTS/state|false"
  "linked_missing_bin|$WT_NO_BIN|$WT_NO_BIN/state|false"
  "linked_missing_state|$WT_NO_STATE|$WT_NO_STATE/state|false"
  "marked_non_git_required_present|$MARKED_NONGIT|$MARKED_NONGIT/state|true"
  "foreign_no_git_no_marker|$FOREIGN|$FOREIGN/state|false"
)
mark "$CLONE" 'coach
'

cases_json=$(for entry in "${CASES[@]}"; do
  IFS='|' read -r name root state _ <<< "$entry"
  jq -cn --arg name "$name" --arg root "$root" --arg state "$state" \
    '{name:$name,root:$root,state:$state}'
done | jq -s '.')

js_results=$(PLUGIN_LIB="$PLUGIN_LIB" CASES_JSON="$cases_json" node --input-type=module 2>&1 <<'EOF'
import { pathToFileURL } from "node:url";
const { fmPrimaryScopeMatches } = await import(pathToFileURL(process.env.PLUGIN_LIB).href);
const cases = JSON.parse(process.env.CASES_JSON);
const results = cases.map((c) => [c.name, fmPrimaryScopeMatches(c.root, c.state)]);
process.stdout.write(JSON.stringify(results));
EOF
) || fail "OpenCode predicate module could not run: $js_results"

js_by_name=$js_results
while IFS=$'\t' read -r name actual; do
  [ -n "$name" ] || continue
  root=""; state=""; expected=""
  for entry in "${CASES[@]}"; do
    IFS='|' read -r c_name c_root c_state c_expected <<< "$entry"
    if [ "$c_name" = "$name" ]; then
      root=$c_root; state=$c_state; expected=$c_expected
      break
    fi
  done
  [ -n "$expected" ] || fail "JS predicate reported an unknown case: $name"
  fm_primary_scope_matches "$root" "$state" && shell=true || shell=false
  [ "$actual" = "$expected" ] \
    || fail "OpenCode predicate returned $actual for $name, expected $expected"
  [ "$actual" = "$shell" ] \
    || fail "OpenCode predicate drifted from bin/fm-primary-scope-lib.sh on $name (js=$actual shell=$shell)"
done < <(printf '%s' "$js_by_name" | jq -r '.[] | @tsv')

case_count=$(printf '%s' "$js_by_name" | jq 'length')
[ "$case_count" = "${#CASES[@]}" ] \
  || fail "OpenCode predicate evaluated $case_count of ${#CASES[@]} cases"

pass "OpenCode root predicate admits valid secondmate homes, rejects foreign roots, and mirrors bin/fm-primary-scope-lib.sh"
