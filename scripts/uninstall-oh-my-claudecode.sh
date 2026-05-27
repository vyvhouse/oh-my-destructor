#!/usr/bin/env bash
set -u

VERSION="0.1.0"
DRY_RUN=0
YES=0
TARGET="local"
REMOVE_HISTORY=0
REMOVE_BACKUPS=0
FORCE_IN_SESSION=0
VERIFY_ONLY=0
VERIFY_JSON=0

# -----------------------------------------------------------------------------
# FINGERPRINTS_JSON
#
# Single source of truth for every OMC identifier this script touches.
# A human-readable mirror lives at uninstallers/oh-my-claudecode/fingerprints.yml.
# CI enforces that the two stay in sync (scripts/check-fingerprints-sync.py).
#
# All match logic — Python heredocs and shell-side loops — reads from this
# block via the FINGERPRINTS_JSON environment variable. Do not introduce new
# inline marker literals elsewhere in the script; add them here.
# -----------------------------------------------------------------------------
FINGERPRINTS_JSON=$(cat <<'JSON'
{
  "terms": [
    "oh-my-claudecode",
    "plugin_oh-my-claudecode",
    "oh-my-claude-sisyphus",
    "omc-hud",
    "omc-setup"
  ],
  "raw_substrings": ["\"omc\""],
  "marketplace_known_keys": ["omc"],
  "claudemd_block": ["<!-- OMC:START -->", "<!-- OMC:END -->"],
  "npm_packages": ["oh-my-claude-sisyphus"],
  "bin_paths": [
    "/usr/local/bin/omc",
    "/opt/homebrew/bin/omc",
    "$HOME/.local/bin/omc"
  ],
  "bin_link_target_substrings": [
    "oh-my-claude-sisyphus",
    "oh-my-claudecode"
  ],
  "bin_content_grep": "oh-my-claude|oh-my-claudecode",
  "state_dirs": [
    "$HOME/.omc",
    "$HOME/.claude/.omc",
    "$HOME/.claude/.omc-config.json",
    "$HOME/.claude/.omc-version.json",
    "$HOME/.claude/hud",
    "$HOME/.claude/plugins/oh-my-claudecode",
    "$HOME/.claude/plugins/marketplaces/omc",
    "$HOME/.claude/plugins/cache/omc"
  ],
  "json_files": [
    ".claude/settings.json",
    ".claude/plugins/installed_plugins.json",
    ".claude/plugins/known_marketplaces.json",
    ".claude/mcp.json",
    ".claude.json"
  ],
  "hook_scan_dirs": [".claude/hooks", ".claude/agents"],
  "hook_name_substrings": ["omc", "claudecode"],
  "hook_text_markers": [
    "oh-my-claudecode",
    "oh-my-claude-sisyphus",
    "omc-hud",
    "omc-setup"
  ],
  "skill_root": ".claude/skills",
  "skill_name_prefixes": ["omc-"],
  "skill_names_explicit": [
    "omc-reference",
    "omc-setup",
    "omc-doctor",
    "omc-teams",
    "omc-plan"
  ],
  "skill_text_markers": [
    "oh-my-claudecode",
    "oh-my-claude-sisyphus"
  ],
  "history_path": ".claude/history.jsonl",
  "history_grep": "oh-my-claudecode|oh-my-claude-sisyphus|/omc-setup|omc update|omc doctor|setup omc",
  "backup_grep": "oh-my-claudecode|oh-my-claude-sisyphus|omc-hud|omc-setup",
  "backup_path_globs": ["*/backups/*", "*/paste-cache/*", "*/file-history/*"],
  "repo_urls": ["Yeachan-Heo/oh-my-claudecode"]
}
JSON
)
export FINGERPRINTS_JSON

usage() {
  cat <<'USAGE'
uninstall-oh-my-claudecode.sh - remove Oh My Claude Code (OMC) from Claude Code

Usage:
  ./scripts/uninstall-oh-my-claudecode.sh [options]

Options:
  --dry-run              Show what would be removed without changing anything.
  --yes                  Do not ask for confirmation.
  --target HOST          Run cleanup on an SSH host, for example: --target macmini.
  --local                Run cleanup on this machine. Default.
  --remove-history       Also scrub OMC entries from ~/.claude/history.jsonl.
  --remove-backups       Also delete OMC-related backup/history cache files under ~/.claude.
  --force-in-session     Proceed even if an active Claude Code session is
                         detected. Without this flag, local-mode runs abort
                         when CLAUDECODE / CLAUDE_CODE_ENTRYPOINT /
                         CLAUDE_PROJECT_DIR is set, because OMC's already-
                         loaded hooks in the running agent can intercept
                         cleanup. Has no effect with --target.
  --verify-only          Skip removal. Run only the verification phase and
                         exit with a tri-state code: 0 (clean), 2 (residue
                         found), 3 (one or more checks could not be run).
                         Combine with --verify-json for machine output.
  --verify-json          Emit verification results as a JSON document to
                         stdout. Human-readable summary still goes to stderr.
  -h, --help             Show help.
  --version              Show script version.

Exit codes after a normal run or --verify-only:
  0   verify PASS (no residue found across every check)
  2   verify FAIL (at least one OMC artifact remains)
  3   verify INCONCLUSIVE (at least one check could not be executed,
       e.g. npm or claude CLI missing) with no FAIL outcomes
  4   refused to run from inside an active Claude Code session

What it removes:
  - OMC npm package: oh-my-claude-sisyphus, if installed globally.
  - OMC CLI binary/symlink, if present.
  - Claude plugin marketplace/cache entries for oh-my-claudecode.
  - OMC generated config/state/HUD/hooks/agents/skills under ~/.claude and ~/.omc.
  - OMC entries from Claude JSON config files: settings.json, mcp.json,
    installed_plugins.json, known_marketplaces.json, and ~/.claude.json.

What it does NOT remove by default:
  - Unrelated Claude plugins or MCP servers.
  - Historical prompt history and backup files, unless explicitly requested.
USAGE
}

warn() { printf 'WARN: %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# in_session_detect
#
# Return 0 (success / detected) when this process appears to be driven by an
# active Claude Code agent. Such runs cannot rely on JSON edits to
# ~/.claude/settings.json to neutralize OMC hooks: the running session has
# already loaded those hooks into memory, and any Bash call the agent makes
# can be intercepted before our cleanup observes the effect.
#
# Signals (any one is sufficient):
#   - env CLAUDECODE set (Claude Code sets this for tool subprocesses)
#   - env CLAUDE_CODE_ENTRYPOINT set
#   - env CLAUDE_PROJECT_DIR set
#   - parent process command (ps -p $PPID -o comm=) begins with "claude"
#
# This check is only meaningful in local mode. SSH-target runs operate on a
# remote machine that is not driven by the local Claude Code session, so the
# caller bypasses this check.
# -----------------------------------------------------------------------------
in_session_detect() {
  if [ -n "${CLAUDECODE:-}" ]; then
    printf 'CLAUDECODE=%s' "$CLAUDECODE"
    return 0
  fi
  if [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
    printf 'CLAUDE_CODE_ENTRYPOINT=%s' "$CLAUDE_CODE_ENTRYPOINT"
    return 0
  fi
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf 'CLAUDE_PROJECT_DIR=%s' "$CLAUDE_PROJECT_DIR"
    return 0
  fi
  parent_comm=$(ps -p "$PPID" -o comm= 2>/dev/null | tr -d ' ')
  case "$parent_comm" in
    claude|claude-code|*/claude|*/claude-code)
      printf 'parent process: %s' "$parent_comm"
      return 0
      ;;
  esac
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) YES=1 ;;
    --target)
      shift
      TARGET="${1:-}"
      [ -n "$TARGET" ] || { warn '--target requires a host'; exit 2; }
      ;;
    --local) TARGET="local" ;;
    --remove-history) REMOVE_HISTORY=1 ;;
    --remove-backups) REMOVE_BACKUPS=1 ;;
    --force-in-session) FORCE_IN_SESSION=1 ;;
    --verify-only) VERIFY_ONLY=1 ;;
    --verify-json) VERIFY_JSON=1 ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

# In-session guard: only meaningful for local-mode cleanup.
if [ "$TARGET" = "local" ]; then
  if signal=$(in_session_detect); then
    if [ "$FORCE_IN_SESSION" -eq 1 ]; then
      warn "Detected an active Claude Code session ($signal)."
      warn "Proceeding because --force-in-session was passed."
      warn "OMC hooks already loaded into the running agent may continue to"
      warn "fire for the remainder of that session even after this script"
      warn "finishes. For a clean uninstall, exit Claude Code and re-run."
      export DISABLE_OMC=1
      export OMC_SKIP_HOOKS=all
    else
      printf 'ERROR: Detected an active Claude Code session (%s).\n' "$signal" >&2
      printf 'Running this uninstaller from inside Claude Code lets OMC'\''s\n' >&2
      printf 'already-loaded hooks intercept the cleanup. Exit Claude Code and\n' >&2
      printf 're-run from a plain shell, or pass --force-in-session if you\n' >&2
      printf 'understand the risk.\n' >&2
      exit 4
    fi
  fi
fi

run_payload() {
  bash -s <<'PAYLOAD'
set -u

say() { printf '%s\n' "$*"; }
do_run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '[dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

# Helper: emit values from a top-level FINGERPRINTS_JSON array key,
# one per line, with $HOME expanded.
fp_list() {
  python3 - "$1" <<'PY'
import json, os, sys
F = json.loads(os.environ["FINGERPRINTS_JSON"])
for item in F[sys.argv[1]]:
    if isinstance(item, str):
        print(item.replace("$HOME", os.environ["HOME"]))
    else:
        print(item)
PY
}

# Helper: emit a top-level scalar (string) from FINGERPRINTS_JSON.
fp_get() {
  python3 - "$1" <<'PY'
import json, os, sys
F = json.loads(os.environ["FINGERPRINTS_JSON"])
print(F[sys.argv[1]])
PY
}

json_cleanup() {
python3 - <<'PY'
import json
import os
import shutil
from datetime import datetime
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"
stamp = datetime.utcnow().isoformat().replace(":", "-").replace(".", "-")

F = json.loads(os.environ["FINGERPRINTS_JSON"])
omc_terms = tuple(F["terms"])
raw_substrings = tuple(F["raw_substrings"])
marketplace_known_keys = list(F["marketplace_known_keys"])
json_files = list(F["json_files"])

def has_omc(value):
    try:
        text = json.dumps(value).lower()
    except Exception:
        text = str(value).lower()
    if any(term in text for term in omc_terms):
        return True
    return any(raw in text for raw in raw_substrings)

def backup(path: Path):
    if dry_run or not path.exists():
        return
    shutil.copy2(path, path.with_name(path.name + f".pre-omc-uninstall-{stamp}.bak"))

def write_json(path: Path, data):
    if dry_run:
        print(f"[dry-run] update JSON {path}")
        return
    backup(path)
    path.write_text(json.dumps(data, indent=2) + "\n")

for rel in json_files:
    path = home / rel
    if not path.exists():
        continue
    try:
        data = json.loads(path.read_text())
    except Exception as exc:
        print(f"WARN: skip invalid JSON {path}: {exc}")
        continue
    changed = False

    if rel == ".claude/settings.json":
        plugins = data.get("enabledPlugins")
        if isinstance(plugins, dict):
            for key in list(plugins):
                if has_omc(key):
                    del plugins[key]
                    changed = True
            if not plugins:
                data.pop("enabledPlugins", None)
        markets = data.get("extraKnownMarketplaces")
        if isinstance(markets, dict):
            for known in marketplace_known_keys:
                if known in markets:
                    del markets[known]
                    changed = True
            if not markets:
                data.pop("extraKnownMarketplaces", None)
        status = data.get("statusLine")
        if isinstance(status, dict) and has_omc(status):
            data.pop("statusLine", None)
            changed = True
        hooks = data.get("hooks")
        if isinstance(hooks, dict):
            for key in list(hooks):
                if has_omc(hooks[key]):
                    hooks[key] = [] if isinstance(hooks[key], list) else {}
                    changed = True

    elif rel == ".claude/plugins/installed_plugins.json":
        plugins = data.get("plugins")
        if isinstance(plugins, dict):
            for key in list(plugins):
                if has_omc(key) or has_omc(plugins[key]):
                    del plugins[key]
                    changed = True

    elif rel == ".claude/plugins/known_marketplaces.json":
        for known in marketplace_known_keys:
            if known in data:
                del data[known]
                changed = True

    elif rel == ".claude/mcp.json":
        servers = data.get("mcpServers")
        if isinstance(servers, dict):
            for key in list(servers):
                if has_omc(key) or has_omc(servers[key]):
                    del servers[key]
                    changed = True

    elif rel == ".claude.json":
        usage = data.get("skillUsage")
        if isinstance(usage, dict):
            for key in list(usage):
                if has_omc(key):
                    del usage[key]
                    changed = True
        servers = data.get("mcpServers")
        if isinstance(servers, dict):
            for key in list(servers):
                if has_omc(key) or has_omc(servers[key]):
                    del servers[key]
                    changed = True
        projects = data.get("projects")
        if isinstance(projects, dict):
            for key in list(projects):
                if key.endswith("/tmp/omc") or has_omc(projects[key]):
                    del projects[key]
                    changed = True

    if changed:
        write_json(path, data)
PY
}

remove_path() {
  path=$1
  if [ -e "$path" ] || [ -L "$path" ]; then
    do_run "rm -rf \"$path\""
  fi
}

if [ "${VERIFY_ONLY:-0}" != "1" ]; then
say "Scanning Oh My Claude Code artifacts under $HOME"
json_cleanup

if command -v npm >/dev/null 2>&1; then
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    do_run "npm uninstall -g $pkg >/dev/null 2>&1 || true"
  done < <(fp_list npm_packages)
else
  say "npm not found; skipping npm package uninstall"
fi

BIN_CONTENT_GREP=$(fp_get bin_content_grep)
while IFS= read -r bin; do
  [ -n "$bin" ] || continue
  if [ -L "$bin" ]; then
    target=$(readlink "$bin" 2>/dev/null || true)
    match=0
    while IFS= read -r sub; do
      case "$target" in
        *${sub}*) match=1; break ;;
      esac
    done < <(fp_list bin_link_target_substrings)
    [ "$match" = "1" ] && remove_path "$bin"
  elif [ -f "$bin" ] && grep -qiE "$BIN_CONTENT_GREP" "$bin" 2>/dev/null; then
    remove_path "$bin"
  fi
done < <(fp_list bin_paths)

while IFS= read -r path; do
  [ -n "$path" ] || continue
  remove_path "$path"
done < <(fp_list state_dirs)

python3 - <<'PY'
import json
import os
import shutil
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"

F = json.loads(os.environ["FINGERPRINTS_JSON"])
markers = tuple(F["hook_text_markers"])
name_substrings = tuple(F["hook_name_substrings"])
scan_dirs = list(F["hook_scan_dirs"])

def marked(path: Path) -> bool:
    name = path.name.lower()
    if any(sub in name for sub in name_substrings):
        return True
    if path.is_file():
        try:
            text = path.read_text(errors="ignore").lower()
        except Exception:
            return False
        return any(marker in text for marker in markers)
    return False

def remove(path: Path):
    if dry_run:
        print(f"[dry-run] remove {path}")
    elif path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)

for rel in scan_dirs:
    root = home / rel
    if not root.exists():
        continue
    files = [p for p in root.rglob("*") if p.is_file()]
    if files and all(marked(p) for p in files):
        remove(root)
        continue
    for child in sorted(root.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if marked(child):
            remove(child)
    for child in sorted([p for p in root.rglob("*") if p.is_dir()], key=lambda p: len(p.parts), reverse=True):
        try:
            next(child.iterdir())
        except StopIteration:
            remove(child)
PY

python3 - <<'PY'
import json
import os
import shutil
from datetime import datetime
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"

F = json.loads(os.environ["FINGERPRINTS_JSON"])
start_marker, end_marker = F["claudemd_block"]

path = home / ".claude/CLAUDE.md"
if path.exists():
    text = path.read_text(errors="replace")
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start != -1 and end != -1:
        if dry_run:
            print(f"[dry-run] remove OMC block from {path}")
        else:
            stamp = datetime.utcnow().isoformat().replace(":", "-").replace(".", "-")
            shutil.copy2(path, path.with_name(path.name + f".pre-omc-uninstall-{stamp}.bak"))
            end += len(end_marker)
            new = (text[:start] + text[end:]).strip()
            path.write_text(new + ("\n" if new else ""))
PY

python3 - <<'PY'
import json
import os
import shutil
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"

F = json.loads(os.environ["FINGERPRINTS_JSON"])
skills = home / F["skill_root"]
prefixes = tuple(F["skill_name_prefixes"])
explicit_omc_names = set(F["skill_names_explicit"])
text_markers = tuple(F["skill_text_markers"])

if skills.exists():
    for child in skills.iterdir():
        if not child.is_dir():
            continue
        hit = any(child.name.startswith(p) for p in prefixes) or child.name in explicit_omc_names
        if not hit:
            for file in child.rglob("*"):
                if not file.is_file():
                    continue
                try:
                    text = file.read_text(errors="ignore").lower()
                except Exception:
                    continue
                if any(marker in text for marker in text_markers):
                    hit = True
                    break
        if hit:
            if dry_run:
                print(f"[dry-run] remove skill {child}")
            else:
                shutil.rmtree(child)
PY

if [ "${REMOVE_HISTORY:-0}" = "1" ]; then
  HISTORY_REL=$(fp_get history_path)
  HISTORY_GREP=$(fp_get history_grep)
  HISTORY_FILE="$HOME/$HISTORY_REL"
  if [ -f "$HISTORY_FILE" ]; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      printf '[dry-run] scrub OMC lines from %s\n' "$HISTORY_FILE"
    else
      cp "$HISTORY_FILE" "$HISTORY_FILE.pre-omc-uninstall.$(date +%Y%m%d%H%M%S).bak"
      grep -viE "$HISTORY_GREP" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" || true
      mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
  fi
fi

if [ "${REMOVE_BACKUPS:-0}" = "1" ] && [ -d "$HOME/.claude" ]; then
  BACKUP_GREP=$(fp_get backup_grep)
  FIND_EXPR=""
  first=1
  while IFS= read -r glob; do
    [ -n "$glob" ] || continue
    if [ "$first" = "1" ]; then
      FIND_EXPR="-path \"$glob\""
      first=0
    else
      FIND_EXPR="$FIND_EXPR -o -path \"$glob\""
    fi
  done < <(fp_list backup_path_globs)
  eval "find \"$HOME/.claude\" \\( $FIND_EXPR \\) -type f 2>/dev/null" | while IFS= read -r file; do
    if grep -qiE "$BACKUP_GREP" "$file" 2>/dev/null; then
      remove_path "$file"
    fi
  done
fi

say "Done."
fi # end !VERIFY_ONLY removal block

VERIFY_JSON="${VERIFY_JSON:-0}" python3 - <<'PY'
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

home = Path.home()
F = json.loads(os.environ["FINGERPRINTS_JSON"])
json_mode = os.environ.get("VERIFY_JSON") == "1"

results = []  # list of (name, status, detail)


def record(name, status, detail=""):
    results.append((name, status, detail))


# Check 1: `omc` command not resolvable
proc = subprocess.run(["bash", "-c", "command -v omc"], capture_output=True, text=True)
if proc.returncode == 0 and proc.stdout.strip():
    record("omc-binary-absent", "fail", f"resolvable at {proc.stdout.strip()}")
else:
    record("omc-binary-absent", "pass")

# Check 2: npm OMC packages absent
if shutil.which("npm"):
    proc = subprocess.run(
        ["npm", "list", "-g", "--depth=0", "--json"],
        capture_output=True, text=True,
    )
    try:
        data = json.loads(proc.stdout) if proc.stdout else {}
    except json.JSONDecodeError:
        data = {}
    deps = data.get("dependencies", {}) if isinstance(data, dict) else {}
    present = [pkg for pkg in F["npm_packages"] if pkg in deps]
    if present:
        record("npm-packages-absent", "fail", f"globally installed: {present}")
    else:
        record("npm-packages-absent", "pass")
else:
    record("npm-packages-absent", "inconclusive", "npm not available")

# Check 3: state and plugin directories absent
present_state = []
for d in F["state_dirs"]:
    p = Path(d.replace("$HOME", str(home)))
    if p.exists() or p.is_symlink():
        present_state.append(str(p))
if present_state:
    record("state-dirs-absent", "fail", f"present: {present_state}")
else:
    record("state-dirs-absent", "pass")

# Check 4: JSON config files clean of OMC markers
omc_terms = tuple(F["terms"])
raw_subs = tuple(F["raw_substrings"])


def has_omc_text(text):
    lower = text.lower()
    if any(t in lower for t in omc_terms):
        return True
    return any(r in lower for r in raw_subs)


dirty_files = []
unreadable_files = []
for rel in F["json_files"]:
    p = home / rel
    if not p.exists():
        continue
    try:
        text = p.read_text()
    except OSError as exc:
        unreadable_files.append(f"{p}: {exc}")
        continue
    if has_omc_text(text):
        dirty_files.append(str(p))
if dirty_files:
    record("json-configs-clean", "fail", f"OMC markers in: {dirty_files}")
elif unreadable_files:
    record("json-configs-clean", "inconclusive", "; ".join(unreadable_files))
else:
    record("json-configs-clean", "pass")

# Check 5: CLAUDE.md OMC block absent
claudemd = home / ".claude/CLAUDE.md"
start_marker, end_marker = F["claudemd_block"]
if claudemd.exists():
    text = claudemd.read_text(errors="replace")
    if start_marker in text and end_marker in text:
        record("claudemd-block-absent", "fail", "OMC marker block present")
    else:
        record("claudemd-block-absent", "pass")
else:
    record("claudemd-block-absent", "pass", "CLAUDE.md not present")

# Check 6: OMC skill directories absent
skills = home / F["skill_root"]
omc_skills = []
explicit = set(F["skill_names_explicit"])
prefixes = tuple(F["skill_name_prefixes"])
if skills.exists():
    for child in skills.iterdir():
        if not child.is_dir():
            continue
        if child.name in explicit:
            omc_skills.append(child.name)
        elif any(child.name.startswith(p) for p in prefixes):
            omc_skills.append(child.name)
if omc_skills:
    record("skills-clean", "fail", f"OMC skill dirs: {omc_skills}")
else:
    record("skills-clean", "pass")

# Decide exit code
has_fail = any(s == "fail" for _, s, _ in results)
has_inc = any(s == "inconclusive" for _, s, _ in results)
if has_fail:
    exit_code = 2
elif has_inc:
    exit_code = 3
else:
    exit_code = 0

if json_mode:
    out = {
        "checks": [
            {"name": n, "status": s, "detail": d} for n, s, d in results
        ],
        "exit": exit_code,
    }
    print(json.dumps(out, indent=2))
else:
    print("", file=sys.stderr)
    print("verify:", file=sys.stderr)
    width = max(len(n) for n, _, _ in results) if results else 0
    for n, s, d in results:
        marker = {"pass": "PASS", "fail": "FAIL", "inconclusive": "INCO"}[s]
        line = f"  [{marker}] {n.ljust(width)}"
        if d:
            line += f"  {d}"
        print(line, file=sys.stderr)
    summary = {0: "PASS", 2: "FAIL", 3: "INCONCLUSIVE"}[exit_code]
    print(f"  -> {summary} (exit {exit_code})", file=sys.stderr)

sys.exit(exit_code)
PY
verify_exit=$?
exit $verify_exit
PAYLOAD
}

if [ "$TARGET" != "local" ]; then
  command -v ssh >/dev/null 2>&1 || { warn 'ssh is required for --target'; exit 1; }
  [ "$YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ] || {
    printf 'Remove Oh My Claude Code from SSH host %s? [y/N] ' "$TARGET"
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) printf 'Aborted.\n'; exit 1 ;; esac
  }
  remote_args="--local"
  [ "$DRY_RUN" -eq 1 ] && remote_args="$remote_args --dry-run"
  [ "$YES" -eq 1 ] && remote_args="$remote_args --yes"
  [ "$REMOVE_HISTORY" -eq 1 ] && remote_args="$remote_args --remove-history"
  [ "$REMOVE_BACKUPS" -eq 1 ] && remote_args="$remote_args --remove-backups"
  [ "$VERIFY_ONLY" -eq 1 ] && remote_args="$remote_args --verify-only"
  [ "$VERIFY_JSON" -eq 1 ] && remote_args="$remote_args --verify-json"
  ssh "$TARGET" "tmp=\$(mktemp); cat > \"\$tmp\"; chmod +x \"\$tmp\"; \"\$tmp\" $remote_args; rc=\$?; rm -f \"\$tmp\"; exit \$rc" < "$0"
  exit $?
fi

# --verify-only does not write; skip the confirmation prompt.
if [ "$VERIFY_ONLY" -ne 1 ]; then
  [ "$YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ] || {
    printf 'Remove Oh My Claude Code from this machine? [y/N] '
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) printf 'Aborted.\n'; exit 1 ;; esac
  }
fi

DRY_RUN=$DRY_RUN REMOVE_HISTORY=$REMOVE_HISTORY REMOVE_BACKUPS=$REMOVE_BACKUPS \
  VERIFY_ONLY=$VERIFY_ONLY VERIFY_JSON=$VERIFY_JSON \
  run_payload
exit $?
