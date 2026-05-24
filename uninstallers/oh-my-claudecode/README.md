# Oh My Claude Code

This remover delegates to the canonical script:

```text
../../scripts/uninstall-oh-my-claudecode.sh
```

Use the full manual at [`../../docs/removers/oh-my-claudecode.md`](../../docs/removers/oh-my-claudecode.md).

## Agent Discovery

Agents should discover this remover through:

```text
../../manifests/index.yml
./manifest.yml
```

Run dry-run before destructive cleanup:

```bash
../../scripts/uninstall-oh-my-claudecode.sh --dry-run
```
