# Oh My Claude Code Remover

## Purpose

Remove Oh My Claude Code (OMC) from Claude Code environments while preserving unrelated Claude plugins, MCP servers, and user history by default.

## Supported Targets

- Local macOS/Linux user environments.
- SSH targets reachable from the current machine.
- Claude Code user-level plugin/config directories.

## Script

```text
scripts/uninstall-oh-my-claudecode.sh
```

## Dry Run

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --dry-run
```

## Local Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --yes
```

## SSH Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-oh-my-claudecode.sh | bash -s -- --target macmini --yes
```

## What It Removes

- `oh-my-claude-sisyphus` global npm package, if present.
- OMC-owned `omc` binary/symlink, if found.
- OMC Claude plugin marketplace/cache directories.
- OMC state/config/HUD directories.
- OMC entries in Claude JSON config files.
- OMC block in `~/.claude/CLAUDE.md`.
- OMC-marked hooks, agents, and skills.

## What It Preserves By Default

- Other Claude plugins.
- Other MCP servers.
- Historical prompt history.
- Backup/cache history files that only mention OMC.
- GitHub stars.

## Optional History Cleanup

```bash
./scripts/uninstall-oh-my-claudecode.sh --yes --remove-history --remove-backups
```

Use this only when the user explicitly wants historical references removed too.

## Verification

The uninstaller runs an automated verification phase after removal. It
also exposes that phase as a standalone read-only check that you can run
any time to ask "is OMC actually gone from this machine?".

```bash
# Standalone — does not modify anything:
scripts/uninstall-oh-my-claudecode.sh --verify-only
```

Exit codes:

| code | meaning |
|---|---|
| 0 | PASS — no OMC residue detected across any check |
| 2 | FAIL — at least one OMC artifact still present |
| 3 | INCONCLUSIVE — at least one check could not be executed (e.g. `npm` missing) with no FAIL outcomes |
| 4 | Refused — invoked from inside an active Claude Code session without `--force-in-session` |

For automation, add `--verify-json` to print a machine-readable result to
stdout:

```bash
scripts/uninstall-oh-my-claudecode.sh --verify-only --verify-json
```

### Manual checklist (fallback)

If you would rather inspect the surfaces by hand, the checks the script
performs are equivalent to:

```bash
command -v omc || true
npm list -g --depth=0 2>/dev/null | grep -Ei 'oh-my-claudecode|oh-my-claude-sisyphus|omc' || true
claude plugin list 2>&1 || true
claude mcp list 2>&1 || true
```

Also inspect active Claude JSON files for OMC references:

```text
~/.claude/settings.json
~/.claude/mcp.json
~/.claude/plugins/installed_plugins.json
~/.claude/plugins/known_marketplaces.json
~/.claude.json
```

## Optional Unstar

```bash
gh auth status
gh repo unstar Yeachan-Heo/oh-my-claudecode
```

Only run this when the user explicitly asks to unstar as part of removal.

## Known Limitations

- The script is intentionally OMC-specific.
- It does not remove Oh My Open Agent, Oh My Codex, or other `oh-my-*` projects.
- Historical prompt files may still mention OMC unless `--remove-history` is used.
