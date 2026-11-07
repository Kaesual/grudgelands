"""Claims share their exact wording between the page and the checker's ledger."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WP = 'mods/MAPGEN/grug_mapgen/wp13/'
W40 = 'mods/MAPGEN/grug_mapgen/wp40/'
MOBS = 'mods/ENTITIES/grug_mobs/'
HOME = 'mods/PLAYER/grug_home/'
QUEST = 'mods/PLAYER/grug_quests/'


class Claims:
    def __init__(self):
        self.rows = []

    def add(self, text, refs, status='Read + proposed consequence'):
        sources = []
        for file, needle in refs:
            lines = (ROOT / file).read_text().splitlines()
            matches = [i+1 for i, line in enumerate(lines) if needle in line]
            if not matches:
                raise ValueError(f'Missing citation {file}: {needle}')
            sources.append(dict(file=file, line=matches[0], needle=needle))
        row = dict(id=f'C{len(self.rows)+1:03}', text=text, sources=sources, status=status)
        self.rows.append(row)
        return row

    def write(self, path):
        head = '''# Round 70 DESIGN — cost claims

Base: `55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`. All game-code citations are to that base.
The numbered sentences below are the exact claims rendered on the page, including
its per-place cost cards. The page also links these numbers. Proposal coordinates
are owned by `proposals.py`; the map tables derive the before values from the export.
Measured claims point to the exporter and its committed JSON inputs. Line references
in this ledger are checked while building the page, not an independent review.
**The pass-2 re-check confirmed the layouts and prior fixes; its verdict was
FIX FIRST, text only. Pass 3 corrects the 48/56 comparison and hall-area basis;
see data/design-check.md and REPORT.md. No runtime/3D implementation, independent
acceptance of this revision or GUI acceptance is claimed.**

'''
        lines = []
        for i, c in enumerate(self.rows, 1):
            refs = '; '.join(f"`{s['file']}:{s['line']}` ({s['needle'].strip()})" for s in c['sources'])
            lines.append(f"{i}. **{c['id']} [{c['status']}]** {c['text']} — {refs}")
        path.write_text(head+'\n\n'.join(lines)+'\n')
