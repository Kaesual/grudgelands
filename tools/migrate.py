#!/usr/bin/env python3
"""Migrate a stopped Grudgelands world to this checkout's version.

Usage (repository root): python3 tools/migrate.py --world <dir> [--check]
`--help` explains the exit codes and the output; the code lives in
tools/migration/ (cli.py).
"""
import sys

from migration.cli import main

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
