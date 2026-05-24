# Remover Specification

Every remover in this repository must follow this contract.

## File Layout

Use one script and one manual per project:

```text
scripts/uninstall-<project-slug>.sh
docs/removers/<project-slug>.md
```

Examples:

```text
scripts/uninstall-oh-my-claudecode.sh
docs/removers/oh-my-claudecode.md
```

## Required Script Options

Each script must support:

```text
--dry-run          Print planned changes without modifying files.
--yes              Skip confirmation after a successful dry-run review.
--target HOST      Run on an SSH host.
--local            Run on this machine. Default.
--remove-history   Optional destructive cleanup of historical references.
--remove-backups   Optional destructive cleanup of backup/cache references.
--help             Print usage.
--version          Print script version.
```

If a project has no history/backups concept, keep the flags and document them as no-ops.

## Required Safety Behavior

- Default mode must preserve unrelated tools and configs.
- `--dry-run` must avoid every filesystem, package-manager, GitHub, and remote mutation.
- JSON/YAML/Markdown edits must create timestamped backups before writing.
- Remote cleanup must use the same script body as local cleanup.
- GitHub star changes must be opt-in and documented separately from filesystem cleanup.
- Scripts must be idempotent: running them twice should not fail or remove unrelated content.

## Required Manual Sections

Each `docs/removers/<project-slug>.md` file must include:

- Purpose
- Supported targets
- What it removes
- What it preserves by default
- Dry-run command
- Local removal command
- SSH removal command
- Verification checklist
- Optional unstar command
- Known limitations

## Verification Before Merge

For every script change, run:

```bash
bash -n scripts/uninstall-<project-slug>.sh
./scripts/uninstall-<project-slug>.sh --help
./scripts/uninstall-<project-slug>.sh --version
./scripts/uninstall-<project-slug>.sh --dry-run
```

When SSH support changes, also run a dry-run against a disposable or trusted host:

```bash
./scripts/uninstall-<project-slug>.sh --target <host> --dry-run
```

## Naming Rules

- Use lowercase slugs.
- Use hyphens, not underscores.
- Keep one project per script.
- Do not build a generic fuzzy deleter. Add explicit project markers and explicit paths.
