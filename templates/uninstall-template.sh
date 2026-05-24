#!/usr/bin/env bash
set -u

# Copy this file to scripts/uninstall-<project-slug>.sh and replace all
# TEMPLATE markers before publishing.

VERSION="0.1.0"
PROJECT_NAME="TEMPLATE PROJECT NAME"
PROJECT_SLUG="template-project"
DRY_RUN=0
YES=0
TARGET="local"
REMOVE_HISTORY=0
REMOVE_BACKUPS=0

usage() {
  cat <<USAGE
uninstall-$PROJECT_SLUG.sh - remove $PROJECT_NAME artifacts

Usage:
  ./scripts/uninstall-$PROJECT_SLUG.sh [options]

Options:
  --dry-run              Show what would be removed without changing anything.
  --yes                  Do not ask for confirmation.
  --target HOST          Run cleanup on an SSH host.
  --local                Run cleanup on this machine. Default.
  --remove-history       Also remove historical references when supported.
  --remove-backups       Also remove backup/cache references when supported.
  -h, --help             Show help.
  --version              Show script version.
USAGE
}

warn() { printf 'WARN: %s\n' "$*" >&2; }
say() { printf '%s\n' "$*"; }

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

printf 'Scanning TEMPLATE PROJECT NAME artifacts under %s\n' "$HOME"

# TODO: Add explicit package-manager cleanup.
# TODO: Add explicit JSON/YAML/Markdown cleanup with timestamped backups.
# TODO: Add explicit path cleanup via remove_path.
# TODO: Add optional history/backups cleanup only behind flags.

printf 'Done.\n'
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
