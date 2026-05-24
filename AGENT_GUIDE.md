# Agent Guide

This guide tells automated agents how to use this repository responsibly.

## Mission

Users have the right not to use oh-my tools.

When a user asks to remove an oh-my tool, your job is to help them leave cleanly: inspect the machine, identify confirmed artifacts, run the appropriate uninstaller in dry-run mode, remove only confirmed artifacts, verify the result through the relevant surfaces, and optionally help unstar the upstream repository when explicitly requested.

## Current Coverage

This repository currently ships one implemented remover:

```text
scripts/uninstall-oh-my-claudecode.sh
```

It removes Oh My Claude Code (OMC) artifacts only. Do not claim that it removes Oh My Open Agent, Oh My Codex, or other `oh-my-*` projects until matching scripts are added.

## Agent Workflow

1. Identify the target tool and host.
2. Confirm that this repository has a matching script.
3. Run `--dry-run` first.
4. Inspect the dry-run output for unrelated removals.
5. Run the script with `--yes` only when the dry-run matches the user's intent.
6. Verify through the real surface: command lookup, package manager, plugin registry, MCP list/config, and active file scan.
7. Report what was removed, what was preserved, and what could not be verified.

## OMC Local Usage

Dry-run:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --dry-run
```

Remove:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --yes
```

Remove history/cache only when the user explicitly asks:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --yes --remove-history --remove-backups
```

## OMC SSH Usage

Dry-run on a host such as `macmini`:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --target macmini --dry-run
```

Remove on `macmini`:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --target macmini --yes
```

## Verification Checklist

After removing OMC, check as many of these surfaces as exist on the host:

```bash
command -v omc || true
npm list -g --depth=0 2>/dev/null | grep -Ei 'oh-my-claudecode|oh-my-claude-sisyphus|omc' || true
claude plugin list 2>&1 || true
claude mcp list 2>&1 || true
```

Also validate active JSON configs when present:

```bash
python3 - <<'PY'
import json
from pathlib import Path
for rel in [
    '.claude.json',
    '.claude/settings.json',
    '.claude/mcp.json',
    '.claude/plugins/installed_plugins.json',
    '.claude/plugins/known_marketplaces.json',
]:
    p = Path.home() / rel
    if p.exists():
        s = p.read_text(errors='replace')
        json.loads(s)
        print(f'{p}: json ok, omc refs={"oh-my-claudecode" in s or "oh-my-claude-sisyphus" in s or "omc-hud" in s}')
PY
```

Historical prompt files may still mention OMC unless `--remove-history` was used. Do not treat historical mentions as active installation.

## Unstar Assistance

If the user wants to remove social/account association too, help them unstar the upstream repository. This must be opt-in.

Manual path:

1. Open the upstream GitHub repository.
2. Click `Unstar`.

GitHub CLI path:

```bash
gh auth status
gh repo unstar Yeachan-Heo/oh-my-claudecode
```

Never unstar a repository unless the user explicitly asks for it or confirms it as part of the removal task.

## Extending This Repository

For each new oh-my tool, add a separate script:

```text
scripts/uninstall-oh-my-openagent.sh
scripts/uninstall-oh-my-codex.sh
scripts/uninstall-oh-my-<tool>.sh
```

Each script should:

- Provide `--dry-run`.
- Provide `--yes`.
- Provide `--target HOST` for SSH cleanup.
- Edit JSON with backups.
- Remove only confirmed artifacts for that tool.
- Preserve unrelated tools, plugins, MCP servers, and histories by default.
- Document optional unstar commands without running them implicitly.

When adding a new script, update `README.md` and this guide in the same commit.
