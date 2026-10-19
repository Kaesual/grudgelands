#!/usr/bin/env python3
"""Round 52 lane SPLIT: the moved-lines proof.

Compares the sorted-line multiset of each split file at a base commit
(read with `git show`, never a checkout) with the concatenation of the files
that replace it in the working tree, and prints every line that is only on
one side. A pure move prints nothing; the split's allowed extras are the
dofile and closure lines, the new file headers and the window glue.

Usage (repo root): python3 tools/r52_split/moved_lines.py [BASE]   (default 7813165e)
"""
import collections
import pathlib
import subprocess
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "7813165e"
ROOT = pathlib.Path(__file__).resolve().parents[2]
GA = "mods/PLAYER/grug_abilities/"
GC = "mods/PLAYER/grug_classes/"
SPLITS = [
	(GA + "kits.lua", [GA + n for n in
		("kits.lua", "kits_warrior.lua", "kits_mage.lua", "kits_priest.lua")]),
	(GC + "talents.lua", [GC + n for n in
		("talents.lua", "talents_warrior.lua", "talents_mage.lua",
			"talents_priest.lua", "talent_windows.lua")]),
]


def lines_of(text):
	return collections.Counter(text.split("\n"))


for old, new in SPLITS:
	before = lines_of(subprocess.run(["git", "show", BASE + ":" + old], cwd=ROOT,
		check=True, capture_output=True, text=True).stdout)
	after = collections.Counter()
	for path in new:
		after += lines_of((ROOT / path).read_text(encoding="utf-8"))
	removed = before - after
	added = after - before
	print("== %s -> %s" % (old, ", ".join(p.rsplit("/", 1)[1] for p in new)))
	for label, diff in (("only before", removed), ("only after", added)):
		count = sum(diff.values())
		print("%s: %d line(s)" % (label, count))
		for line in sorted(diff):
			print("  %dx %r" % (diff[line], line))
