#!/usr/bin/env python3
"""Runs the shipped migration tool (tools/migration/cli.py, the steps as
committed) with the version and declaration of the 0.47.0 release before
lane D writes them: game.conf and upgrade.json are read from DIR instead of
the checkout. Used by tools/r47_ms/e2e.py only while the checkout's own
declaration does not list 0.47.0 yet; afterwards e2e.py runs
tools/migrate.py itself.

Usage (repository root): python3 tools/r47_ms/tool_run.py DIR --world <dir> [--check]
"""

import sys

sys.dont_write_bytecode = True

from pathlib import Path  # noqa: E402

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from migration import cli  # noqa: E402


def main(argv):
    folder, rest = Path(argv[0]), argv[1:]
    cli.GAME_CONF = folder / "game.conf"
    cli.DECLARATION = folder / "upgrade.json"
    return cli.main(rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
