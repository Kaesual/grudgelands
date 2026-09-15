"""How much 4-node sampling understates a relief.

The lot predicate reads the capital probe's 4-node envelope grid; the same
probe's wall dumps sample four lines at ONE node. Both come out of the same
boot, so the two can be compared directly: for every window position along a
wall line, the fall and the rise a 31-column window sees at 1-node resolution
against what the same window sees at 4.
"""
import sys


def load_wall(path):
    values = {}
    handle = open(path)
    handle.readline()
    for line in handle:
        line_id, p, lane, x, z, y, water = line.split()
        values[(int(x), int(z))] = int(y)
    return values


def report(path, label):
    wall = load_wall(path)
    print("== %s (%s)" % (label, path))
    worst_fall = worst_rise = 0
    samples = 0
    for at, axis in ((-256, "z"), (256, "z"), (-256, "x"), (256, "x")):
        column = {}
        for p in range(-264, 265):
            key = (at, p) if axis == "z" else (p, at)
            if key in wall:
                column[p] = wall[key]
        if not column:
            continue
        for centre in range(-230, 231, 4):
            window = [column[centre + i] for i in range(-15, 16)
                      if centre + i in column]
            coarse = [column[centre + i] for i in range(-16, 17, 4)
                      if centre + i in column]
            if len(window) < 31 or centre not in column:
                continue
            reference = column[centre]
            fine_fall = reference - min(window)
            fine_rise = max(window) - reference
            coarse_fall = reference - min(coarse)
            coarse_rise = max(coarse) - reference
            worst_fall = max(worst_fall, fine_fall - coarse_fall)
            worst_rise = max(worst_rise, fine_rise - coarse_rise)
            samples += 1
        print("   line %s %+d: sampled" % (axis, at))
    print("   %d window positions; 4-node sampling understates a fall by at "
          "most %d and a rise by at most %d" % (samples, worst_fall, worst_rise))


for path, label in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    report(path, label)
