# <Project Name> Remover

## Purpose

Describe what this remover deletes and why users may want it.

## Supported Targets

- Local user environments.
- SSH targets, if supported.
- Any project-specific plugin or config surfaces.

## Script

```text
scripts/uninstall-<project-slug>.sh
```

## Dry Run

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-<project-slug>.sh | bash -s -- --dry-run
```

## Local Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-<project-slug>.sh | bash -s -- --yes
```

## SSH Removal

```bash
curl -fsSL https://raw.githubusercontent.com/vyv-house/oh-my-destructor/main/scripts/uninstall-<project-slug>.sh | bash -s -- --target <host> --yes
```

## What It Removes

- List explicit packages, binaries, config keys, directories, and plugin entries.

## What It Preserves By Default

- List unrelated tools, history, backups, stars, or other preserved state.

## Optional History Cleanup

```bash
./scripts/uninstall-<project-slug>.sh --yes --remove-history --remove-backups
```

## Verification Checklist

```bash
# Add command/package/plugin/MCP/config checks here.
```

## Optional Unstar

```bash
gh auth status
gh repo unstar OWNER/REPO
```

Only run this when the user explicitly asks to unstar as part of removal.

## Known Limitations

- List unsupported install modes or platforms.
