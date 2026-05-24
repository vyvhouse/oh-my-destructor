# How To Add A Remover

Use this flow when adding support for another project.

## 1. Gather Evidence

Before writing deletion logic, identify:

- Official repository URL.
- Install commands and package names.
- Binaries and symlinks.
- Config files and plugin registries.
- State/cache/log directories.
- MCP or agent integration points.
- Verification commands.
- GitHub repo to unstar, if relevant.

Do not infer paths from naming alone. Read docs and inspect real installs when possible.

## 2. Create Files

Copy templates:

```bash
cp templates/uninstall-template.sh scripts/uninstall-<project-slug>.sh
cp templates/manifest-template.yml uninstallers/<project-slug>/manifest.yml
cp templates/remover-doc-template.md docs/removers/<project-slug>.md
chmod +x scripts/uninstall-<project-slug>.sh
```

Add a short `uninstallers/<project-slug>/README.md` that links to the manual and script.

## 3. Update Indexes

Update:

- `manifests/index.yml`
- `docs/INDEX.md`
- `README.md`
- `AGENT_GUIDE.md`, if the workflow changes.

## 4. Implement Safely

The script must:

- Support `--dry-run`, `--yes`, `--target HOST`, `--help`, and `--version`.
- Create backups before editing config files.
- Remove only explicit project artifacts.
- Preserve unrelated tools and histories by default.
- Keep GitHub unstar as an explicit separate step.

## 5. Verify

Run:

```bash
bash -n scripts/uninstall-<project-slug>.sh
./scripts/uninstall-<project-slug>.sh --help
./scripts/uninstall-<project-slug>.sh --version
./scripts/uninstall-<project-slug>.sh --dry-run
bin/uninstall --list
bin/uninstall <project-slug> --dry-run
```

If SSH is supported, also run:

```bash
./scripts/uninstall-<project-slug>.sh --target <host> --dry-run
```

## 6. Commit Checklist

- Script added under `scripts/`.
- Manifest added under `uninstallers/<project-slug>/manifest.yml`.
- Manual added under `docs/removers/`.
- Indexes updated.
- Dry-run output reviewed.
