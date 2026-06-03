# Agent Guide

This guide tells automated agents how to use this repository responsibly.

## Mission

Users have the right not to use oh-my tools.

When a user asks to remove an oh-my tool, your job is to help them leave cleanly: inspect the machine, identify confirmed artifacts, run the appropriate uninstaller in dry-run mode, remove only confirmed artifacts, verify the result through the relevant surfaces, and optionally help unstar the upstream repository when explicitly requested.

## Current Coverage

Agents should discover available removers from the catalog first:

```text
manifests/index.yml
```

This repository currently ships these implemented removers:

```text
scripts/uninstall-oh-my-claudecode.sh
scripts/uninstall-lazycodex.sh
```

They remove only their documented artifact sets. Do not claim that one remover covers Oh My Open Agent, Oh My Codex, or other `oh-my-*` projects until matching scripts are added.

## Discovery Contract

Before executing anything:

1. Read `manifests/index.yml`.
2. Select only entries with `status: available`.
3. Read the per-remover `manifest.yml` under `uninstallers/<slug>/`.
4. Confirm the current platform is listed in `supported_platforms` when possible.
5. Use the manifest `script` and `manual` paths as the source of truth.

If the slug is planned or missing, tell the user it is not implemented yet instead of adapting another remover.

## Agent Workflow

1. Identify the target tool and host.
2. Confirm that this repository has a matching script.
3. Run `--dry-run` first.
4. Inspect the dry-run output for unrelated removals.
5. Run the script with `--yes` only when the dry-run matches the user's intent.
6. Verify through the real surface: command lookup, package manager, plugin registry, MCP list/config, and active file scan.
7. Report what was removed, what was preserved, and what could not be verified.

## Do Not Run From Inside The Session Under Audit

Agents executing inside a Claude Code session that has OMC active **must
not** drive the uninstaller from within that same session in local mode.
OMC's hooks are already loaded into the running session, and Bash tool
calls — including the one invoking this script — are intercepted by those
hooks before the cleanup is observed.

The uninstaller refuses to start in local mode when it detects any of:

- env `CLAUDECODE` is set
- env `CLAUDE_CODE_ENTRYPOINT` is set
- env `CLAUDE_PROJECT_DIR` is set
- the parent process command is `claude` or `claude-code`

If you hit that exit code (`4`), the correct recovery is one of:

1. Instruct the user to exit Claude Code and re-run the script from a plain
   shell.
2. Re-target the work onto a different host that this session is not driving
   (`--target HOST`); the SSH path is never blocked.
3. As a last resort and only with explicit user consent, pass
   `--force-in-session`. Hook-mediated effects in the calling session may
   persist until that session ends, so a follow-up verification pass from a
   fresh shell is required.

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

When the repository is cloned locally, agents may use the dispatcher:

```bash
bin/uninstall --list
bin/uninstall oh-my-claudecode --dry-run
bin/uninstall oh-my-claudecode --yes
bin/uninstall lazycodex --dry-run
bin/uninstall lazycodex --yes
```

## lazycodex Local Usage

Dry-run:

```bash
curl -fsSL https://raw.githubusercontent.com/vyvhouse/oh-my-destructor/main/scripts/uninstall-lazycodex.sh | bash -s -- --dry-run
```

Remove:

```bash
curl -fsSL https://raw.githubusercontent.com/vyvhouse/oh-my-destructor/main/scripts/uninstall-lazycodex.sh | bash -s -- --yes
```

The lazycodex remover also removes Codex OMO/Sisyphus Labs plugin side effects from `~/.codex/config.toml` and `~/.codex/plugins`, including `omo@sisyphuslabs` SessionStart hook trust blocks. It preserves oh-my-codex / OMX, unrelated Codex plugins, unrelated MCP servers, and Codex history by default.

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

When adding a new script, update these in the same commit:

- `README.md`
- `AGENT_GUIDE.md`, if the workflow changes
- `manifests/index.yml`
- `docs/INDEX.md`
- `docs/removers/<slug>.md`
- `uninstallers/<slug>/manifest.yml`

Follow [`docs/REMOVER_SPEC.md`](./docs/REMOVER_SPEC.md) for the required contract.
