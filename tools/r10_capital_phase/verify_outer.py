"""Require exact pre-CAP authored outer cells and the four frozen gate hashes."""
import argparse
import csv
import hashlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('repo', type=Path)
parser.add_argument('old_output', type=Path)
parser.add_argument('fixed_output', type=Path)
args = parser.parse_args()
print('capital\tlabel\tsha256\tcells\tfrozen_match')
for capital in ('highcourt', 'dur_brannoc', 'gor_drazhak', 'nhal_veyr'):
    for label in ('rampart', 'corner', 'gate'):
        filename = capital + '-' + label + '.tsv'
        old = (args.old_output / filename).read_bytes()
        fixed = (args.fixed_output / filename).read_bytes()
        assert old == fixed, (capital, label, 'outer authored cells changed')
        rows = list(csv.reader(fixed.decode().splitlines(), delimiter='\t'))
        digest = hashlib.sha256('\n'.join(':'.join(row) for row in rows).encode()).hexdigest()
        baseline = args.repo / 'tools/wp13/evidence/20260915-capital-terrain' / capital
        words = (baseline / (label + '-digest-531802985935182545.txt')).read_text().split()
        count = int(next(word.split('=')[1] for word in words if word.startswith('overlay_cells=')))
        matches = digest == words[0] and len(rows) == count
        if label == 'gate':
            assert matches, (capital, 'frozen gate mismatch')
        print(capital, label, digest, len(rows), matches, sep='\t')
