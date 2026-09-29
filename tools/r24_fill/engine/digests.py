"""Compare the [r24d] per-chunk content digests of two runs.
Usage: digests.py A/server.log B/server.log"""
import re, sys
def load(path):
    rows = {}
    for line in open(path):
        m = re.search(r"\[r24d\] (-?\d+,-?\d+,-?\d+) (\d+-\d+)", line)
        if m:
            rows[m.group(1)] = m.group(2)
    return rows
a, b = load(sys.argv[1]), load(sys.argv[2])
common = sorted(set(a) & set(b))
diff = [k for k in common if a[k] != b[k]]
print("chunks A %d, B %d, common %d, identical %d, differ %d" % (
    len(a), len(b), len(common), len(common) - len(diff), len(diff)))
for k in diff[:20]:
    print("  differ", k)
