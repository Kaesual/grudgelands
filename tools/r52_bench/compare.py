#!/usr/bin/env python3
"""Compare two Round 52 PvE bench logs (tools/r52_bench/run.sh probe.txt).

Usage: python3 tools/r52_bench/compare.py BEFORE/probe.txt AFTER/probe.txt

Per class, the action records (try, swing, hit, cd, charge, heal, absorb,
flash, phase, start, end) must match exactly in order and content; their
times must agree within one server step (the larger maximum step of the two
runs). Mend's ticks ("tick": a heal outside any cast) are the named exception
of class plan D1: they are compared as a list of amounts, and their times
since the cast are printed. Exits 1 on a content difference; a cadence
outside the tolerance is reported, not gated.
"""
import re
import sys

LINE = re.compile(r"\[r52_bench\] R (\S+) (-?[0-9.]+) (\S+) ?(.*)$")
STEPS = re.compile(r"\[r52_bench\] STEPS n=(\d+) mean=([0-9.]+) max=([0-9.]+)")


def load(path):
    classes, max_step = {}, 0.0
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            m = LINE.search(raw)
            if m:
                cls, t, kind, text = m.group(1), float(m.group(2)), m.group(3), m.group(4)
                classes.setdefault(cls, []).append((t, kind, text))
                continue
            m = STEPS.search(raw)
            if m:
                max_step = float(m.group(3))
    return classes, max_step


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    before, step_a = load(sys.argv[1])
    after, step_b = load(sys.argv[2])
    tolerance = max(step_a, step_b)
    print("max server step: before %.3f s, after %.3f s; cadence tolerance %.3f s"
          % (step_a, step_b, tolerance))
    content_ok, cadence_ok = True, True
    for cls in sorted(set(before) | set(after)):
        a = [r for r in before.get(cls, []) if r[1] != "tick"]
        b = [r for r in after.get(cls, []) if r[1] != "tick"]
        same = [x[1:] for x in a] == [x[1:] for x in b]
        worst = 0.0
        if same:
            for x, y in zip(a, b):
                worst = max(worst, abs(x[0] - y[0]))
        else:
            content_ok = False
            for i in range(max(len(a), len(b))):
                x = a[i][1:] if i < len(a) else None
                y = b[i][1:] if i < len(b) else None
                if x != y:
                    print("  %s: first difference at record %d:\n    before %s\n    after  %s"
                          % (cls, i + 1, x, y))
                    break
        if worst > tolerance:
            cadence_ok = False
        kinds = {}
        for r in a:
            kinds[r[1]] = kinds.get(r[1], 0) + 1
        print("%-8s %3d records %s, max time difference %.3f s (%s)" % (
            cls, len(a), "IDENTICAL" if same else "DIFFERENT", worst,
            ", ".join("%s %d" % kv for kv in sorted(kinds.items()))))
        ticks_a = [r for r in before.get(cls, []) if r[1] == "tick"]
        ticks_b = [r for r in after.get(cls, []) if r[1] == "tick"]
        if ticks_a or ticks_b:
            mend_a = [r[0] for r in a if r[1] == "try" and r[2].startswith("mend ")]
            mend_b = [r[0] for r in b if r[1] == "try" and r[2].startswith("mend ")]

            def since(ticks, casts):
                out = []
                for t, _, _ in ticks:
                    prior = [c for c in casts if c <= t]
                    out.append("%.2f" % (t - prior[-1]) if prior else "?")
                return ", ".join(out)
            amounts_same = [r[2] for r in ticks_a] == [r[2] for r in ticks_b]
            if not amounts_same:
                content_ok = False
            print("         Mend ticks (D1's named exception): %d vs %d, amounts %s"
                  % (len(ticks_a), len(ticks_b), "identical" if amounts_same else "DIFFERENT"))
            print("           before, s after the cast: " + since(ticks_a, mend_a))
            print("           after,  s after the cast: " + since(ticks_b, mend_b))
    print("content: %s; cadence: %s" % ("IDENTICAL" if content_ok else "DIFFERENT",
                                         "within one step" if cadence_ok else "OUTSIDE one step"))
    return 0 if content_ok else 1


if __name__ == "__main__":
    sys.exit(main())
