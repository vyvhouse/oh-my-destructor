#!/usr/bin/env python3
"""Verify that FINGERPRINTS_JSON inside the uninstaller script matches the
sidecar fingerprints.yml. Exits non-zero on drift.

This intentionally avoids a YAML library dependency by using a tiny subset
parser sufficient for our fingerprints.yml shape:
    - top-level keys
    - scalar string values
    - lists of scalar strings (one per line with '- ' prefix)

It also reads the FINGERPRINTS_JSON block out of the shell script via simple
delimiter matching: a `cat <<'JSON' ... JSON` heredoc.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "uninstall-oh-my-claudecode.sh"
YAML = ROOT / "uninstallers" / "oh-my-claudecode" / "fingerprints.yml"


def extract_json_block(script_text: str) -> dict:
    match = re.search(
        r"FINGERPRINTS_JSON=\$\(cat <<'JSON'\n(?P<body>.*?)\nJSON\n\)",
        script_text,
        re.DOTALL,
    )
    if not match:
        sys.exit("FATAL: could not locate FINGERPRINTS_JSON heredoc in script")
    try:
        return json.loads(match.group("body"))
    except json.JSONDecodeError as exc:
        sys.exit(f"FATAL: FINGERPRINTS_JSON is not valid JSON: {exc}")


def parse_minimal_yaml(text: str) -> dict:
    out: dict = {}
    current_list_key: str | None = None
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        stripped = raw.lstrip()
        indented = raw != stripped
        if stripped.startswith("- "):
            if current_list_key is None:
                sys.exit(f"FATAL: list item without key: {raw!r}")
            out[current_list_key].append(_strip_quotes(stripped[2:].strip()))
            continue
        if indented:
            sys.exit(f"FATAL: malformed YAML line: {raw!r}")
        line = stripped.rstrip()
        if ":" not in line:
            sys.exit(f"FATAL: malformed YAML line: {line!r}")
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if value == "":
            out[key] = []
            current_list_key = key
        else:
            out[key] = _strip_quotes(value)
            current_list_key = None
    return out


def _strip_quotes(s: str) -> str:
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        return s[1:-1]
    return s


def main() -> int:
    if not SCRIPT.exists():
        sys.exit(f"FATAL: missing {SCRIPT}")
    if not YAML.exists():
        sys.exit(f"FATAL: missing {YAML}")

    fp_script = extract_json_block(SCRIPT.read_text())
    fp_yaml = parse_minimal_yaml(YAML.read_text())

    keys_script = set(fp_script.keys())
    keys_yaml = set(fp_yaml.keys())

    drift: list[str] = []

    only_script = keys_script - keys_yaml
    only_yaml = keys_yaml - keys_script
    if only_script:
        drift.append(f"keys only in script: {sorted(only_script)}")
    if only_yaml:
        drift.append(f"keys only in YAML:   {sorted(only_yaml)}")

    for key in sorted(keys_script & keys_yaml):
        s_val = fp_script[key]
        y_val = fp_yaml[key]
        if isinstance(s_val, list) and isinstance(y_val, list):
            if list(s_val) != list(y_val):
                drift.append(f"{key}: script={s_val!r} yaml={y_val!r}")
        elif isinstance(s_val, str) and isinstance(y_val, str):
            if s_val != y_val:
                drift.append(f"{key}: script={s_val!r} yaml={y_val!r}")
        else:
            drift.append(f"{key}: type mismatch script={type(s_val).__name__} yaml={type(y_val).__name__}")

    if drift:
        print("FAIL: fingerprints.yml is out of sync with FINGERPRINTS_JSON.\n")
        for line in drift:
            print(f"  - {line}")
        print("\nUpdate uninstallers/oh-my-claudecode/fingerprints.yml and ")
        print("scripts/uninstall-oh-my-claudecode.sh together.")
        return 1

    print("OK: fingerprints.yml matches FINGERPRINTS_JSON")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
