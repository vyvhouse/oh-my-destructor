#!/usr/bin/env bash
# Fixture-based integration suite. Builds five canonical HOME trees, runs
# the uninstaller against each, then runs --verify-only and additional
# preservation assertions specific to each fixture.
#
# Exit code:
#   0 — every fixture passed both removal and preservation checks
#   non-zero — at least one fixture failed; the failing fixture's name is
#              printed to stderr

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/uninstall-oh-my-claudecode.sh"
FIXTURES="$ROOT/tests/fixtures"

# Tally
PASS=0
FAIL=0
FAILED_FIXTURES=""

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log()  { printf '\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
ok()   { printf '  \033[32mok\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); FAILED_FIXTURES="$FAILED_FIXTURES $current_fixture"; }
note() { printf '       %s\n' "$1" >&2; }

current_fixture="(none)"

if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  STRICT_VERIFY=1
else
  STRICT_VERIFY=0
fi

assert_exit_acceptable() {
  # CI runners are clean. We accept 0 (PASS) and 3 (INCONCLUSIVE — npm
  # unavailable) and fail on anything else.
  #
  # Local dev boxes often have active OMC processes that pollute the
  # verify result (processes-clean / launchagents-clean / omc-binary-absent
  # are system-wide rather than fixture-scoped). The per-fixture assertions
  # below are the source of truth for removal/preservation correctness;
  # in lenient mode the verify exit code is informational only.
  local got=$1
  if [ "$STRICT_VERIFY" = "1" ]; then
    if [ "$got" = "0" ] || [ "$got" = "3" ]; then
      ok "verify exit $got accepted"
    else
      bad "verify exit was $got (expected 0 or 3)"
    fi
  else
    ok "verify exit $got (lenient — set CI=true to enforce strictly)"
  fi
}

assert_exists()    { [ -e "$1" ] && ok "exists $1" || bad "missing $1"; }
assert_missing()   { [ ! -e "$1" ] && ok "missing $1" || bad "unexpectedly present $1"; }
assert_contains()  {
  if grep -qF "$2" "$1" 2>/dev/null; then
    ok "$1 contains $2"
  else
    bad "$1 does not contain $2"
  fi
}
assert_not_contains() {
  if ! grep -qF "$2" "$1" 2>/dev/null; then
    ok "$1 does not contain $2"
  else
    bad "$1 still contains $2"
  fi
}

run_destructor() {
  local home_dir=$1
  shift
  # Strip CLAUDECODE / friends so the in-session guard doesn't fire under
  # GitHub Actions's environment.
  env -i HOME="$home_dir" \
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$SCRIPT" "$@" || true
}

verify() {
  local home_dir=$1
  env -i HOME="$home_dir" \
    PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$SCRIPT" --verify-only
  echo $?
}

new_home() {
  local name=$1
  local d
  d=$(mktemp -d -t "omd-$name-XXXXXX")
  if [ ! -d "$FIXTURES/$name/home" ]; then
    bad "missing fixture directory $FIXTURES/$name/home"
  else
    cp -a "$FIXTURES/$name/home/." "$d/"
  fi
  printf '%s' "$d"
}

# -----------------------------------------------------------------------------
# Fixture 1: npm-only
# Nothing on disk, just check the script tolerates the case where
# OMC is not actually installed globally and reports either PASS or
# INCONCLUSIVE depending on whether npm is on PATH.
# -----------------------------------------------------------------------------
fixture_npm_only() {
  current_fixture="npm-only"
  log "$current_fixture" "build"
  local H
  H=$(new_home npm-only)
  rm -f "$H/.gitkeep"
  log "$current_fixture" "destructor --yes"
  run_destructor "$H" --yes
  log "$current_fixture" "--verify-only"
  local rc
  rc=$(verify "$H") || true
  assert_exit_acceptable "$rc"
  assert_missing "$H/.omc"
  PASS=$((PASS+1))
  rm -rf "$H"
}

# -----------------------------------------------------------------------------
# Fixture 2: json-only
# JSON config files contain OMC entries; no on-disk plugin/state directories.
# -----------------------------------------------------------------------------
fixture_json_only() {
  current_fixture="json-only"
  log "$current_fixture" "build"
  local H
  H=$(new_home json-only)
  rm -f "$H/.gitkeep"
  mkdir -p "$H/.claude/plugins"
  cat > "$H/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {"oh-my-claudecode@omc": true, "user/keep": true},
  "extraKnownMarketplaces": {"omc": {}, "trusted": {}}
}
EOF
  cat > "$H/.claude/mcp.json" <<'EOF'
{"mcpServers": {"plugin_oh-my-claudecode_t__notepad_read": {}, "keep-me": {}}}
EOF
  cat > "$H/.claude.json" <<'EOF'
{"mcpServers": {"plugin_oh-my-claudecode_t__ast_grep_search": {}}, "skillUsage": {"oh-my-claudecode:autopilot": 3, "user:custom": 7}}
EOF
  cat > "$H/.claude/plugins/installed_plugins.json" <<'EOF'
{"plugins": {"oh-my-claudecode@omc": {}, "user/keep": {}}}
EOF
  cat > "$H/.claude/plugins/known_marketplaces.json" <<'EOF'
{"omc": {"source": {"repo": "Yeachan-Heo/oh-my-claudecode"}}, "trusted-other": {"source": {"repo": "anthropic/example"}}}
EOF

  log "$current_fixture" "destructor --yes"
  run_destructor "$H" --yes
  log "$current_fixture" "--verify-only"
  local rc
  rc=$(verify "$H") || true
  assert_exit_acceptable "$rc"
  assert_not_contains "$H/.claude/settings.json" "oh-my-claudecode"
  assert_contains     "$H/.claude/settings.json" "user/keep"
  assert_not_contains "$H/.claude/plugins/installed_plugins.json" "oh-my-claudecode"
  assert_contains     "$H/.claude/plugins/installed_plugins.json" "user/keep"
  assert_not_contains "$H/.claude/plugins/known_marketplaces.json" "Yeachan-Heo"
  assert_contains     "$H/.claude/plugins/known_marketplaces.json" "trusted-other"
  assert_not_contains "$H/.claude/mcp.json" "oh-my-claudecode"
  assert_contains     "$H/.claude/mcp.json" "keep-me"
  assert_not_contains "$H/.claude.json" "oh-my-claudecode"
  assert_contains     "$H/.claude.json" "user:custom"
  PASS=$((PASS+1))
  rm -rf "$H"
}

# -----------------------------------------------------------------------------
# Fixture 3: files-only
# On-disk plugin/state/skill/hook/agent directories; no JSON OMC entries.
# -----------------------------------------------------------------------------
fixture_files_only() {
  current_fixture="files-only"
  log "$current_fixture" "build"
  local H
  H=$(new_home files-only)
  rm -f "$H/.gitkeep"
  mkdir -p "$H/.omc" \
    "$H/.claude/plugins/oh-my-claudecode" \
    "$H/.claude/plugins/marketplaces/omc" \
    "$H/.claude/plugins/cache/omc" \
    "$H/.claude/hud" \
    "$H/.claude/skills/omc-doctor" \
    "$H/.claude/skills/keep-this" \
    "$H/.claude/hooks" \
    "$H/.claude/agents"
  echo "{}" > "$H/.claude/.omc-config.json"
  echo "x"  > "$H/.claude/hooks/omc-hud.sh"
  echo "keep" > "$H/.claude/hooks/unrelated.sh"
  echo "OMC stuff: oh-my-claudecode" > "$H/.claude/agents/omc-setup.md"
  echo "keep me" > "$H/.claude/agents/keep.md"
  echo "OMC skill"     > "$H/.claude/skills/omc-doctor/SKILL.md"
  echo "Unrelated"     > "$H/.claude/skills/keep-this/SKILL.md"

  log "$current_fixture" "destructor --yes"
  run_destructor "$H" --yes
  log "$current_fixture" "--verify-only"
  local rc
  rc=$(verify "$H") || true
  assert_exit_acceptable "$rc"
  assert_missing "$H/.omc"
  assert_missing "$H/.claude/plugins/oh-my-claudecode"
  assert_missing "$H/.claude/plugins/marketplaces/omc"
  assert_missing "$H/.claude/plugins/cache/omc"
  assert_missing "$H/.claude/hud"
  assert_missing "$H/.claude/.omc-config.json"
  assert_missing "$H/.claude/hooks/omc-hud.sh"
  assert_exists  "$H/.claude/hooks/unrelated.sh"
  assert_missing "$H/.claude/agents/omc-setup.md"
  assert_exists  "$H/.claude/agents/keep.md"
  assert_missing "$H/.claude/skills/omc-doctor"
  assert_exists  "$H/.claude/skills/keep-this"
  PASS=$((PASS+1))
  rm -rf "$H"
}

# -----------------------------------------------------------------------------
# Fixture 4: all-three (json + files + claudemd)
# -----------------------------------------------------------------------------
fixture_all_three() {
  current_fixture="all-three"
  log "$current_fixture" "build"
  local H
  H=$(new_home all-three)
  rm -f "$H/.gitkeep"
  mkdir -p "$H/.claude/plugins/marketplaces/omc" "$H/.claude/plugins/cache/omc" "$H/.omc"
  echo "{}" > "$H/.claude/.omc-config.json"
  cat > "$H/.claude/settings.json" <<'EOF'
{"enabledPlugins": {"oh-my-claudecode@omc": true}, "extraKnownMarketplaces": {"omc": {}}}
EOF
  cat > "$H/.claude/CLAUDE.md" <<'EOF'
# user content

<!-- OMC:START -->
injected
<!-- OMC:END -->

footer
EOF

  log "$current_fixture" "destructor --yes"
  run_destructor "$H" --yes
  log "$current_fixture" "--verify-only"
  local rc
  rc=$(verify "$H") || true
  assert_exit_acceptable "$rc"
  assert_missing "$H/.omc"
  assert_missing "$H/.claude/plugins/marketplaces/omc"
  assert_missing "$H/.claude/.omc-config.json"
  assert_not_contains "$H/.claude/settings.json" "oh-my-claudecode"
  assert_not_contains "$H/.claude/CLAUDE.md" "OMC:START"
  assert_contains     "$H/.claude/CLAUDE.md" "user content"
  assert_contains     "$H/.claude/CLAUDE.md" "footer"
  PASS=$((PASS+1))
  rm -rf "$H"
}

# -----------------------------------------------------------------------------
# Fixture 5: mixed (preservation focus)
# OMC + unrelated plugins / MCPs / skills / hooks. Every non-OMC item must
# survive intact.
# -----------------------------------------------------------------------------
fixture_mixed() {
  current_fixture="mixed"
  log "$current_fixture" "build"
  local H
  H=$(new_home mixed)
  rm -f "$H/.gitkeep"
  mkdir -p "$H/.claude/plugins" "$H/.claude/skills/safe-skill" \
    "$H/.claude/plugins/oh-my-claudecode" \
    "$H/.claude/hooks" \
    "$H/.claude/agents"
  cat > "$H/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {"oh-my-claudecode@omc": true, "vendor/safe": true},
  "extraKnownMarketplaces": {"omc": {}, "vendor-mp": {}}
}
EOF
  cat > "$H/.claude/mcp.json" <<'EOF'
{"mcpServers": {"plugin_oh-my-claudecode_t__notepad_read": {}, "safe-mcp": {}}}
EOF
  cat > "$H/.claude/plugins/installed_plugins.json" <<'EOF'
{"plugins": {"oh-my-claudecode@omc": {}, "vendor/safe": {}}}
EOF
  echo "Important user notes" > "$H/.claude/skills/safe-skill/SKILL.md"
  echo "x" > "$H/.claude/hooks/omc-hud.sh"
  echo "keep this hook content" > "$H/.claude/hooks/safe-hook.sh"
  echo "vendor agent content" > "$H/.claude/agents/vendor.md"

  log "$current_fixture" "destructor --yes"
  run_destructor "$H" --yes
  log "$current_fixture" "--verify-only"
  local rc
  rc=$(verify "$H") || true
  assert_exit_acceptable "$rc"

  # Removal assertions
  assert_missing "$H/.claude/plugins/oh-my-claudecode"
  assert_not_contains "$H/.claude/settings.json" "oh-my-claudecode"
  assert_not_contains "$H/.claude/mcp.json" "oh-my-claudecode"
  assert_not_contains "$H/.claude/plugins/installed_plugins.json" "oh-my-claudecode"

  # Preservation assertions
  assert_contains "$H/.claude/settings.json" "vendor/safe"
  assert_contains "$H/.claude/settings.json" "vendor-mp"
  assert_contains "$H/.claude/mcp.json" "safe-mcp"
  assert_contains "$H/.claude/plugins/installed_plugins.json" "vendor/safe"
  assert_exists   "$H/.claude/skills/safe-skill/SKILL.md"
  assert_exists   "$H/.claude/hooks/safe-hook.sh"
  assert_exists   "$H/.claude/agents/vendor.md"

  PASS=$((PASS+1))
  rm -rf "$H"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
fixture_npm_only
fixture_json_only
fixture_files_only
fixture_all_three
fixture_mixed

echo
echo "==== fixture summary ===="
echo "passes: $PASS"
echo "fails : $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed fixtures:$FAILED_FIXTURES" >&2
  exit 1
fi
