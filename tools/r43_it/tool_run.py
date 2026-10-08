#!/usr/bin/env python3
"""Runs the migration tool with the Round 43 IT test steps (tools/r43_it/
steps.py) through its Python test hook, `migration.cli.main(argv,
test_steps={version: module})`; the shipped command line cannot name a step.

Usage (repository root):
  python3 tools/r43_it/tool_run.py STEPS --world <dir> [--check]
STEPS: comma-separated test steps, each a version of steps.STEPS or
VERSION=NAME to run steps.STEPS[NAME] under VERSION; "-" for none.
"""

import sys

sys.dont_write_bytecode = True

from pathlib import Path  # noqa: E402

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent), str(HERE)]

from migration import cli  # noqa: E402

import steps  # noqa: E402


def main(argv):
    spec, rest = argv[0], argv[1:]
    test_steps = {}
    for item in ([] if spec == "-" else spec.split(",")):
        version, _, name = item.partition("=")
        test_steps[version] = steps.STEPS[name or version]
    return cli.main(rest, test_steps=test_steps)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
