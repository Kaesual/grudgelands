#!/usr/bin/env python3
"""Migrate a stopped Grudgelands world to this checkout's version.

Usage (repository root): python3 tools/migrate.py --world <dir> [--check]
`--help` explains the exit codes and the output; the code lives in
tools/migration/ (cli.py).
"""
import sys

# The tool writes nothing outside the world: no bytecode caches either.
sys.dont_write_bytecode = True

from migration.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
