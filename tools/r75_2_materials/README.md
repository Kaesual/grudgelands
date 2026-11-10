# Round 75.2 material audit and preview

This package checks the actual engine-exported node definitions introduced by
Round 75: 58 static furnishing sources, 16 paintings, eight functional display
nodes and all 112 city clones. It resolves the shipped texture expressions,
measures their resulting alpha channels, checks solid-surface policy, compares
every clone's visual fields with its source and checks mesh material groups
against tile count and order.

Run the audit after refreshing `tools/building_templates/nodes.json`:

```sh
python3 tools/r75_2_materials/audit.py \
  --report tools/r75_2_materials/report.json
python3 tools/r75_2_materials/test_renderer.py
python3 tools/r75_2_materials/build.py --check
```

Open `index.html` locally. Its five selectable, fully labelled scenes use the
shared building-template renderer and the actual resolved textures. Orbit,
zoom, block inspection and view codes provide close views. The first scene is
the four user-reported cases: the alchemy flask set, writing set, scroll bundle
and tool board. Regenerate the page with `python3 tools/r75_2_materials/build.py`.

To refresh the matching screenshot, set `CHROME` to a local Chromium executable
and run `node tools/r75_2_materials/capture.mjs`. The screenshot and browser
page are authoring evidence; they do not claim desktop or web game acceptance.

`baseline.json` records the pre-fix material-policy failures from the immutable
engine dump at commit `b44507d1`. `test_regression.py` replays that dump through
the same audit, checks the 56 mode and 24 texture-alpha failures (including the
paper, alchemy, ore and brick cases), and then requires the current dump to
pass. It intentionally omits old-dump geometry comparisons because the current
generated meshes had already changed when the old dump was replayed.
