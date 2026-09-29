#!/usr/bin/env python3
import re, sys, collections
log = sys.argv[1]
BANDS = ["above", "01-04", "05-08", "09-16", "17-32", "33-64", "65+", "deep60_100", "t2"]
ORES = {"default:stone_with_coal": "coal", "default:stone_with_iron": "iron",
        "default:stone_with_copper": "copper", "default:stone_with_tin": "tin",
        "grug_materials:stone_with_quartz": "quartz"}
DEN = {"coal": 64, "copper": 96, "tin": 96, "iron": 128, "quartz": 128}

def grp(cls):
    return "town" if cls.startswith("exclude:anchor") else ("outside" if cls.startswith("none") else "other")

# A: actual-top based counts from the main env
A = collections.defaultdict(collections.Counter)  # (grp, band) -> name -> n
for line in open(log):
    m = re.search(r"\[coalp\] cnt (.*)\|([^|]+)\|(\S+) (\d+)$", line)
    if m:
        A[(grp(m.group(1)), m.group(2))][m.group(3)] += int(m.group(4))
# B: native>final pairs by planned-terrain depth, from the emerge env
B = collections.defaultdict(collections.Counter)
nchunks = 0
for line in open(log):
    if "[coalg]" not in line:
        continue
    nchunks += 1
    body = line.split(" ", 4)[4].strip() if False else line.strip().split(" result=", 1)[1].split(" ", 1)
    if len(body) < 2:
        continue
    for part in body[1].split(";"):
        k, v = part.rsplit("=", 1)
        cls, band, pair = k.split("|")
        B[(grp(cls), band)][pair] += int(v)
print("coalg chunks:", nchunks)

def row_ores(c, host):
    return "  ".join("%s=%d(%.2f)" % (o, c[n], c[n] * DEN[o] / host if host else 0)
                     for n, o in ORES.items())

for g in ["outside", "town"]:
    print("\n=== A) %s: bands by depth below ACTUAL ground top (final map) ===" % g)
    for b in BANDS:
        c = A.get((g, b))
        if not c:
            continue
        tot = sum(c.values())
        st = c["default:stone"]
        oresum = sum(c[n] for n in ORES)
        host = st + oresum
        print("[%s] nodes=%d stone=%d (%.1f%%) ores: %s   | per-denominator ratio vs 1.0 using host=stone+ores" %
              (b, tot, st, 100.0 * st / tot, row_ores(c, host)))
        top = [(n, v) for n, v in c.most_common(12) if n not in ORES]
        print("     top:", ", ".join("%s %.1f%%" % (n.split(":")[-1], 100.0 * v / tot) for n, v in top))

for g in ["outside", "town"]:
    print("\n=== B) %s: native(v7 VM) > final, by depth below PLANNED terrain_y ===" % g)
    for b in BANDS:
        c = B.get((g, b))
        if not c:
            continue
        tot = sum(c.values())
        nat_stone = sum(v for p, v in c.items() if p.split(">")[0] == "default:stone")
        fin_stone = sum(v for p, v in c.items() if p.split(">")[1] == "default:stone")
        kept = c["default:stone>default:stone"]
        ore_from_stone = {o: c["default:stone>" + n] for n, o in ORES.items()}
        ore_total = {o: sum(v for p, v in c.items() if p.split(">")[1] == n) for n, o in ORES.items()}
        elig = kept + sum(ore_from_stone.values())
        fin_from_other = fin_stone - kept
        print("[%s] nonair=%d nativeStone=%d finalStone=%d keptStone=%d finalStoneNotNative=%d  eligible~=%d" %
              (b, tot, nat_stone, fin_stone, kept, fin_from_other, elig))
        print("     ores(total/from native stone): " + "  ".join(
            "%s=%d/%d per-den-vs-eligible=%.2f" % (o, ore_total[o], ore_from_stone[o],
                                                   ore_from_stone[o] * DEN[o] / elig if elig else 0)
            for o in DEN))
        src = collections.Counter()
        for p, v in c.items():
            a, f = p.split(">")
            if f == "default:stone" and a != "default:stone":
                src[a] += v
        dst = collections.Counter()
        for p, v in c.items():
            a, f = p.split(">")
            if a == "default:stone" and f != "default:stone" and f not in ORES:
                dst[f] += v
        print("     final stone came from: " + ", ".join("%s %d" % kv for kv in src.most_common(5)))
        print("     native stone became: " + ", ".join("%s %d" % kv for kv in dst.most_common(6)))
        natv = collections.Counter()
        for p, v in c.items():
            natv[p.split(">")[0]] += v
        print("     native top: " + ", ".join("%s %d" % kv for kv in natv.most_common(6)))
