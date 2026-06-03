# OMC shell-init footprint research

Issue: #10
Package checked: `oh-my-claude-sisyphus@4.14.4`
Date: 2026-06-03

## Summary

No shell startup files were modified by a clean `omc setup --force` run in an isolated HOME on macOS.

The observed setup footprint is under `~/.claude/` only:

- `~/.claude/agents/`
- `~/.claude/hooks/`
- `~/.claude/hud/`
- `~/.claude/settings.json`
- `~/.claude/skills/`
- `~/.claude/.omc-config.json`
- `~/.claude/.omc-version.json`
- `~/.claude/CLAUDE.md`

No files were created or edited at these common shell-init locations during the run:

- `~/.zshrc`
- `~/.zprofile`
- `~/.bashrc`
- `~/.bash_profile`
- `~/.profile`
- `~/.config/fish/config.fish`

## Reproduction commands

```sh
WORK=$(mktemp -d)
PREFIX="$WORK/prefix"
HOME_T="$WORK/home"
mkdir -p "$PREFIX" "$HOME_T"

npm install -g --prefix "$PREFIX" oh-my-claude-sisyphus@4.14.4
PATH="$PREFIX/bin:$PATH" HOME="$HOME_T" omc setup --force

find "$HOME_T" -maxdepth 4 -type f -o -type d | sort
for f in .zshrc .zprofile .bashrc .bash_profile .profile .config/fish/config.fish; do
  test -e "$HOME_T/$f" && echo "FOUND $f"
done
```

## Evidence

`omc setup --force` reported OMC installation into Claude Code configuration paths:

```text
Creating directories...
Installing agent definitions...
Installed standalone hook scripts
Installing bundled skills from local package (no enabled OMC plugin detected)...
Created CLAUDE.md
Installing HUD statusline...
Configuring settings.json...
Saved version metadata
Setup complete!
```

The isolated HOME file scan showed `~/.claude` content only. The shell-init check printed no `FOUND` lines.

A source grep across the installed package for common shell startup files and shell-init mutations found no setup-time writer for `.zshrc`, `.bashrc`, `.bash_profile`, `.zprofile`, `.profile`, or fish config. Documentation references to `OMC_PLUGIN_ROOT` exist for users who manually run `claude --plugin-dir <path>`, but the package setup path did not write that export into shell startup files.

## Destructor implication

The current destructor does not need to delete shell-init blocks for the observed `oh-my-claude-sisyphus@4.14.4` setup path.

Recommended behavior:

1. Keep shell startup files out of the default removal path.
2. Do not remove arbitrary `OMC_PLUGIN_ROOT`, aliases, or `PATH` entries without a positively identified managed marker.
3. If future OMC versions add shell-init writes, add fingerprints only for explicit, versioned, OMC-managed markers and cover them with fixtures before removal.

## Notes

This research covers the npm package setup path for `oh-my-claude-sisyphus@4.14.4`. It does not prove that every older OMC release or every manual user customization avoids shell startup files.
