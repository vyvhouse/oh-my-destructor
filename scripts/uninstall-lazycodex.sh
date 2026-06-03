#!/usr/bin/env bash
set -u

VERSION="0.1.0"
PROJECT_NAME="lazycodex"
# shellcheck disable=SC2034 # reserved for shared uninstaller metadata
PROJECT_SLUG="lazycodex"
DRY_RUN=0
YES=0
TARGET="local"
REMOVE_HISTORY=0
REMOVE_BACKUPS=0

usage() {
  cat <<'USAGE'
uninstall-lazycodex.sh - remove lazycodex and its Codex/OMO side effects

Usage:
  ./scripts/uninstall-lazycodex.sh [options]

Options:
  --dry-run              Show what would be removed without changing anything.
  --yes                  Do not ask for confirmation.
  --target HOST          Run cleanup on an SSH host, for example: --target macmini.
  --local                Run cleanup on this machine. Default.
  --remove-history       Also scrub lazycodex/OMO lines from ~/.codex/history.jsonl.
  --remove-backups       Also delete lazycodex/OMO backup/cache history files under ~/.codex.
  -h, --help             Show help.
  --version              Show script version.

What it removes:
  - Known lazycodex global npm package names, if installed.
  - lazycodex CLI binaries/symlinks, if present.
  - lazycodex user config/cache/state directories.
  - OMO/Sisyphus Labs Codex plugin entries that lazycodex installations may enable:
    [plugins."omo@sisyphuslabs"], [marketplaces.sisyphuslabs], and
    [hooks.state."omo@sisyphuslabs:..."] blocks in ~/.codex/config.toml.
  - OMO/Sisyphus Labs Codex plugin cache/data directories.

What it does NOT remove by default:
  - oh-my-codex / OMX itself.
  - Other Codex plugins, MCP servers, agents, prompts, or skills.
  - Historical Codex session transcripts and history, unless explicitly requested.
USAGE
}

warn() { printf 'WARN: %s\n' "$*" >&2; }

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
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

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

remove_path() {
  path=$1
  if [ -e "$path" ] || [ -L "$path" ]; then
    do_run "rm -rf \"$path\""
  fi
}

remove_lazycodex_toml_blocks() {
python3 - <<'PY'
import os
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"
stamp = datetime.utcnow().isoformat().replace(":", "-").replace(".", "-")
config = home / ".codex" / "config.toml"
if not config.exists():
    raise SystemExit

original = config.read_text(errors="replace")
text = original
patterns = [
    r'\n?\[plugins\."omo@sisyphuslabs"\]\n(?:[^\[][^\n]*\n?)*?(?=\n\[|\Z)',
    r'\n?\[marketplaces\.sisyphuslabs\]\n(?:[^\[][^\n]*\n?)*?(?=\n\[|\Z)',
    r'\n?\[hooks\.state\."omo@sisyphuslabs:[^"]+"\]\n(?:[^\[][^\n]*\n?)*?(?=\n\[|\Z)',
]
for pattern in patterns:
    text = re.sub(pattern, "\n", text)
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")

if text == original:
    sys.exit(0)

if dry_run:
    print(f"[dry-run] update TOML {config} (remove lazycodex/OMO plugin, marketplace, and hook trust blocks)")
    sys.exit(0)

backup = config.with_name(config.name + f".pre-lazycodex-uninstall-{stamp}.bak")
shutil.copy2(config, backup)
config.write_text(text)
print(f"updated {config}; backup {backup}")
PY
}

say "Scanning lazycodex artifacts under $HOME"

remove_lazycodex_toml_blocks

if command -v npm >/dev/null 2>&1; then
  do_run "npm uninstall -g lazycodex lazy-codex @lazycodex/cli @sisyphuslabs/lazycodex >/dev/null 2>&1 || true"
else
  say "npm not found; skipping npm package uninstall"
fi

for bin in \
  /usr/local/bin/lazycodex \
  /usr/local/bin/lazy-codex \
  /opt/homebrew/bin/lazycodex \
  /opt/homebrew/bin/lazy-codex \
  "$HOME/.local/bin/lazycodex" \
  "$HOME/.local/bin/lazy-codex" \
  "$HOME/bin/lazycodex" \
  "$HOME/bin/lazy-codex"; do
  if [ -L "$bin" ]; then
    target=$(readlink "$bin" 2>/dev/null || true)
    case "$target" in
      *lazycodex*|*lazy-codex*) remove_path "$bin" ;;
    esac
  elif [ -f "$bin" ] && grep -qi "lazycodex\|lazy-codex" "$bin" 2>/dev/null; then
    remove_path "$bin"
  fi
done

for path in \
  "$HOME/.lazycodex" \
  "$HOME/.config/lazycodex" \
  "$HOME/.cache/lazycodex" \
  "$HOME/Library/Application Support/lazycodex" \
  "$HOME/Library/Caches/lazycodex" \
  "$HOME/.codex/plugins/cache/sisyphuslabs" \
  "$HOME/.codex/plugins/data/omo-sisyphuslabs"; do
  remove_path "$path"
done

python3 - <<'PY'
import os
import shutil
from pathlib import Path

home = Path.home()
dry_run = os.environ.get("DRY_RUN") == "1"
remove_history = os.environ.get("REMOVE_HISTORY") == "1"
remove_backups = os.environ.get("REMOVE_BACKUPS") == "1"
terms = ("lazycodex", "lazy-codex", "omo@sisyphuslabs", "sisyphuslabs/omo", "bundled-rules/hephaestus")

if remove_history:
    history = home / ".codex" / "history.jsonl"
    if history.exists():
        lines = history.read_text(errors="replace").splitlines(True)
        kept = [line for line in lines if not any(term in line.lower() for term in terms)]
        if kept != lines:
            if dry_run:
                print(f"[dry-run] scrub lazycodex/OMO entries from {history}")
            else:
                backup = history.with_name(history.name + ".pre-lazycodex-uninstall.bak")
                shutil.copy2(history, backup)
                history.write_text("".join(kept))
                print(f"scrubbed {history}; backup {backup}")

if remove_backups:
    roots = [home / ".codex" / "sessions", home / ".codex" / "cache"]
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            haystack = path.name.lower()
            if not any(term in haystack for term in terms):
                try:
                    sample = path.read_text(errors="ignore")[:20000].lower()
                except Exception:
                    sample = ""
                if not any(term in sample for term in terms):
                    continue
            if dry_run:
                print(f"[dry-run] remove historical lazycodex/OMO file {path}")
            else:
                path.unlink(missing_ok=True)
PY

say "Done."
PAYLOAD
}

if [ "$TARGET" != "local" ]; then
  command -v ssh >/dev/null 2>&1 || { warn 'ssh is required for --target'; exit 1; }
  [ "$YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ] || {
    printf 'Remove %s from SSH host %s? [y/N] ' "$PROJECT_NAME" "$TARGET"
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) printf 'Aborted.\n'; exit 1 ;; esac
  }
  remote_args="--local"
  [ "$DRY_RUN" -eq 1 ] && remote_args="$remote_args --dry-run"
  [ "$YES" -eq 1 ] && remote_args="$remote_args --yes"
  [ "$REMOVE_HISTORY" -eq 1 ] && remote_args="$remote_args --remove-history"
  [ "$REMOVE_BACKUPS" -eq 1 ] && remote_args="$remote_args --remove-backups"
  ssh "$TARGET" "tmp=\$(mktemp); cat > \"\$tmp\"; chmod +x \"\$tmp\"; \"\$tmp\" $remote_args; rc=\$?; rm -f \"\$tmp\"; exit \$rc" < "$0"
  exit $?
fi

[ "$YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ] || {
  printf 'Remove %s from this machine? [y/N] ' "$PROJECT_NAME"
  read -r answer
  case "$answer" in y|Y|yes|YES) ;; *) printf 'Aborted.\n'; exit 1 ;; esac
}

DRY_RUN=$DRY_RUN REMOVE_HISTORY=$REMOVE_HISTORY REMOVE_BACKUPS=$REMOVE_BACKUPS run_payload
