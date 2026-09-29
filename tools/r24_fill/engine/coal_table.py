"""Coal (and other T1 ores) per denominator, outside towns, per depth band
below the actual ground top; tunnel statistics. Same arithmetic as the
archived analyze.py (host = stone + the five T1 ores)."""
import re, sys, collections
ORES = {"default:stone_with_coal": ("coal", 64), "default:stone_with_iron": ("iron", 128),
        "default:stone_with_copper": ("copper", 96), "default:stone_with_tin": ("tin", 96),
        "grug_materials:stone_with_quartz": ("quartz", 128)}
BANDS = ["01-04", "05-08", "09-16", "17-32", "33-64", "65+"]
for label, log in zip(sys.argv[1::2], sys.argv[2::2]):
    A = collections.defaultdict(collections.Counter)
    tunnels = []
    for line in open(log):
        m = re.search(r"\[coalp\] cnt (.*)\|([^|]+)\|(\S+) (\d+)$", line)
        if m and m.group(1).startswith("none"):
            A[m.group(2)][m.group(3)] += int(m.group(4))
        m = re.search(r"tunnel mode=(\w+) n=\d+ mean_dug=([\d.]+) .*P\(no coal dug\)=([\d.]+)", line)
        if m:
            tunnels.append("%s dug %s P0 %s" % m.groups())
    row = []
    for b in BANDS:
        c = A[b]
        host = c["default:stone"] + sum(c[n] for n in ORES)
        coal = c["default:stone_with_coal"] * 64 / host
        others = [c[n] * d / host for n, (_, d) in ORES.items() if n != "default:stone_with_coal"]
        row.append("%s coal %.2f (others %.2f-%.2f)" % (b, coal, min(others), max(others)))
    print(label + ": " + " | ".join(row))
    print("   tunnels: " + "; ".join(tunnels))
