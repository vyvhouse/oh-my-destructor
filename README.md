# oh-my Tool Uninstallers

We have the right not to use oh-my tools.

This repository hosts agent-native uninstall scripts for people who want help removing oh-my toolchains from their machines. The intent is simple: an agent should be able to inspect a machine, run a dry-run, remove known artifacts safely, and explain what changed.

Current coverage is intentionally narrow and truthful: the included script removes [Oh My Claude Code](https://github.com/Yeachan-Heo/oh-my-claudecode) artifacts only. This repository is meant to grow into a home for uninstallers for related tools such as Oh My Open Agent, Oh My Claude Code, Oh My Codex, and other `oh-my-*` projects.

For agent-specific operating instructions, see [AGENT_GUIDE.md](./AGENT_GUIDE.md). For the machine-readable catalog and contributor scaffold, see [`manifests/index.yml`](./manifests/index.yml) and [`docs/`](./docs/).

## Repository Layout

```text
bin/uninstall                         Dispatcher for supported removers.
scripts/uninstall-<project>.sh        Runnable uninstall scripts.
uninstallers/<project>/manifest.yml   Per-project metadata for agents.
docs/removers/<project>.md            Per-project human manual.
templates/                            Starter templates for new removers.
manifests/index.yml                   Catalog of available and planned removers.
```

## Available Scripts

| Script | Status | Purpose |
| --- | --- | --- |
| `scripts/uninstall-oh-my-claudecode.sh` | Available | Remove Oh My Claude Code (OMC) from Claude Code local or SSH targets. |
| `scripts/uninstall-oh-my-openagent.sh` | Planned | Future remover for Oh My Open Agent artifacts. |
| `scripts/uninstall-oh-my-codex.sh` | Planned | Future remover for Oh My Codex artifacts. |

List supported removers through the dispatcher:

```bash
bin/uninstall --list
```

## Quick Start

Preview first:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --dry-run
```

Remove locally:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --yes
```

Remove on an SSH host:

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --target macmini --yes
```

If you cloned the repository, you can use the dispatcher instead:

```bash
bin/uninstall oh-my-claudecode --dry-run
bin/uninstall oh-my-claudecode --yes
```

## What The Current Script Removes

`scripts/uninstall-oh-my-claudecode.sh` removes OMC-only artifacts:

- Global npm package `oh-my-claude-sisyphus`, if installed.
- OMC-owned `omc` binary/symlink, if found.
- Claude plugin marketplace/cache artifacts:
  - `~/.claude/plugins/marketplaces/omc`
  - `~/.claude/plugins/cache/omc`
  - `~/.claude/plugins/oh-my-claudecode`
- OMC generated state/config/HUD files:
  - `~/.omc`
  - `~/.claude/.omc*`
  - `~/.claude/hud`
  - OMC-marked content under `~/.claude/hooks`
  - OMC-marked content under `~/.claude/agents`
- OMC entries from:
  - `~/.claude/settings.json`
  - `~/.claude/mcp.json`
  - `~/.claude/plugins/installed_plugins.json`
  - `~/.claude/plugins/known_marketplaces.json`
  - `~/.claude.json`
- OMC-injected block inside `~/.claude/CLAUDE.md`.
- OMC skill directories under `~/.claude/skills` when they are clearly OMC-owned.

## What It Does Not Remove By Default

- Other Claude plugins.
- Other MCP servers.
- Other oh-my tools that are not OMC.
- Historical prompt history (`~/.claude/history.jsonl`).
- Backup/cache history files that merely mention OMC.

Use these options if you also want history/cache cleanup:

```bash
./scripts/uninstall-oh-my-claudecode.sh --yes --remove-history --remove-backups
```

## Unstar Help

Removal can include unstarring the upstream repository when the user explicitly wants that. This repository does not silently change GitHub stars, but an agent can help you do it:

Manual:

1. Open the GitHub repository page.
2. Click `Unstar`.

CLI:

```bash
gh auth login
gh repo unstar Yeachan-Heo/oh-my-claudecode
```

For future uninstallers, replace `OWNER/REPO` with the target oh-my repository.

## Options

```text
--dry-run          Show planned changes without modifying files.
--yes              Skip confirmation prompt.
--target HOST      Run over SSH on HOST.
--local            Run locally. Default.
--remove-history   Scrub OMC lines from ~/.claude/history.jsonl.
--remove-backups   Delete OMC-related backup/cache history files under ~/.claude.
--help             Show help.
--version          Show version.
```

## Safety

- Run `--dry-run` first, especially on SSH targets.
- The script creates timestamped `.pre-omc-uninstall-*.bak` backups before editing JSON or `CLAUDE.md`.
- JSON edits are targeted to OMC keys/values only.
- `omc` binaries are removed only when their target/content appears OMC-owned.
- Hook and agent directories are removed only when their files are OMC-marked; mixed directories are cleaned selectively.
- Star changes are opt-in and require explicit GitHub CLI authentication.

## Adding More oh-my Removers

Add one script per tool:

```text
scripts/uninstall-oh-my-openagent.sh
scripts/uninstall-oh-my-codex.sh
scripts/uninstall-oh-my-<tool>.sh
```

Each script should follow the same contract:

- Support `--dry-run`.
- Support `--yes` for agent runs.
- Support `--target HOST` for SSH cleanup.
- Add `uninstallers/<project>/manifest.yml`.
- Add `docs/removers/<project>.md`.
- Update `manifests/index.yml`.
- Preserve unrelated tools and configs.
- Document what it removes and what it refuses to remove.
- Mention optional unstar steps separately from filesystem cleanup.

Use [`docs/how-to-add-remover.md`](./docs/how-to-add-remover.md) and the files in [`templates/`](./templates/) when adding support for another project.
