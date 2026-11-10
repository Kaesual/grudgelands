#!/usr/bin/env python3
"""Prove the material audit fails the immutable old dump and passes the new."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import audit


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD_COMMIT = "b44507d1"


def policy_errors(errors: list[str]) -> list[str]:
    return [error for error in errors if "mesh groups/tiles differ" not in error
            and "furnishing mesh material order differs" not in error]


def main() -> int:
    old_bytes = subprocess.run(
        ["git", "show", OLD_COMMIT + ":tools/building_templates/nodes.json"],
        cwd=ROOT, check=True, stdout=subprocess.PIPE).stdout
    with tempfile.NamedTemporaryFile(suffix=".json") as handle:
        handle.write(old_bytes)
        handle.flush()
        _, old_all = audit.run(ROOT, Path(handle.name))

    old = policy_errors(old_all)
    baseline = json.loads((HERE / "baseline.json").read_text(encoding="utf-8"))
    if old != baseline["errors"]:
        raise AssertionError("baseline errors differ from the immutable old dump")

    mode = [error for error in old if "not explicitly opaque" in error]
    alpha = [error for error in old if "texture retains alpha" in error]
    assert len(mode) == 56, len(mode)
    assert len(alpha) == 24, len(alpha)
    expected = {
        "grug_decor:writing_set: solid furnishing texture retains alpha: default_paper.png",
        "grug_decor:alchemy_set: solid furnishing texture retains alpha: "
        "default_glass.png^[colorize:#5d9b83:100",
        "grug_decor:material_ore: solid furnishing texture retains alpha: "
        "default_mineral_iron.png",
        "grug_decor:jug: solid furnishing texture retains alpha: default_clay_brick.png",
        "grug_decor:planter: solid furnishing texture retains alpha: default_clay_brick.png",
    }
    assert expected.issubset(old)

    _, current = audit.run(ROOT, ROOT / "tools/building_templates/nodes.json")
    if current:
        raise AssertionError("current engine dump failed:\n" + "\n".join(current))
    print("R75.2 MATERIAL REGRESSION PASS "
          f"old_policy_errors={len(old)} old_mode={len(mode)} "
          f"old_alpha={len(alpha)} current_errors=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
