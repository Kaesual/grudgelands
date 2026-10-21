# Offhand contract and tools (Round 55)

The offhand look's contract ([docs/technical/offhand-format.md](../../docs/technical/offhand-format.md), the
source of truth; [plan](../../docs/planning/round55-plan.md)). `params.json`, `offhand.py` and
`data/atlas.json` change only through the round's coordinator or the finish step.

| File | What |
|---|---|
| `params.json` | every number of the look (shapes, placements, bone pivots and per-clip keys), exported by the preview page |
| `offhand.py` | the contract in code: validation, the rotation convention, the shapes, the atlas packing, the file names; `--check` |
| `data/atlas.json` | the offhand atlas layout (generated) |
| `make_test_art.py`, `test_art/` | flat-colour test art with zones and orientation glyphs; baked only into a test-only mod, never shipped |

```sh
python3 tools/r55_offhand/offhand.py            # validate params.json, rewrite data/atlas.json
python3 tools/r55_offhand/offhand.py --check    # exit 1 if invalid or stale
python3 tools/r55_offhand/make_test_art.py      # rewrite test_art/
```

Python 3; Pillow for the test art and `--png`.
