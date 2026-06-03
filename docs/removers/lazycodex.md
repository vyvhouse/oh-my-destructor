# lazycodex Remover

## Purpose

Remove lazycodex from Codex environments while preserving oh-my-codex / OMX itself and unrelated Codex plugins by default.

This remover also handles the observed lazycodex side effect where `omo@sisyphuslabs` enables Codex plugin hooks that inject the Hephaestus/OMO prompt through `SessionStart`.

## Supported Targets

- Local macOS/Linux user environments.
- SSH targets reachable from the current machine.
- Codex user-level config under `~/.codex`.

## Script

```text
scripts/uninstall-lazycodex.sh
```

## Dry Run

```bash
curl -fsSL https://raw.githubusercontent.com/vyvhouse/oh-my-destructor/main/scripts/uninstall-lazycodex.sh | bash -s -- --dry-run
```

## Local Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyvhouse/oh-my-destructor/main/scripts/uninstall-lazycodex.sh | bash -s -- --yes
```

## SSH Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyvhouse/oh-my-destructor/main/scripts/uninstall-lazycodex.sh | bash -s -- --target macmini --yes
```

## What It Removes

- Known lazycodex global npm package names, if present:
  - `lazycodex`
  - `lazy-codex`
  - `@lazycodex/cli`
  - `@sisyphuslabs/lazycodex`
- lazycodex CLI binaries/symlinks, if found.
- lazycodex user config/cache/state directories.
- OMO/Sisyphus Labs Codex plugin cache/data directories:
  - `~/.codex/plugins/cache/sisyphuslabs`
  - `~/.codex/plugins/data/omo-sisyphuslabs`
- OMO/Sisyphus Labs blocks from `~/.codex/config.toml`:
  - `[plugins."omo@sisyphuslabs"]`
  - `[marketplaces.sisyphuslabs]`
  - `[hooks.state."omo@sisyphuslabs:..."]`

## What It Preserves By Default

- oh-my-codex / OMX.
- Other Codex plugins.
- Other MCP servers.
- Codex agents, prompts, skills, and trusted project entries.
- Historical Codex prompt history and session transcripts.

## Optional History Cleanup

```bash
./scripts/uninstall-lazycodex.sh --yes --remove-history --remove-backups
```

Use this only when the user explicitly wants historical `lazycodex`/OMO references removed too.

## Verification Checklist

```bash
command -v lazycodex || true
npm list -g --depth=0 2>/dev/null | grep -Ei 'lazycodex|lazy-codex' || true
grep -E 'omo@sisyphuslabs|sisyphuslabs|hephaestus|bundled-rules' ~/.codex/config.toml || true
```

Expected result after removal: the commands above print no active lazycodex/OMO installation references, except command-not-found or empty grep output.

## Known Limitations

- This remover intentionally does not remove `oh-my-codex` / OMX itself.
- It does not remove unrelated `codex_apps` MCP auth/cache artifacts by default; those may be first-party Codex connector state rather than lazycodex state.
- Historical session files may still mention lazycodex/OMO unless `--remove-history` or `--remove-backups` is used.
