# Dialog and typography capture matrix

The driver renders production forms in the real Flatpak Luanti client. It
stages the game through `tools/luanti_headless.sh` into a disposable world,
uses private XDG and Luanti directories, and never opens the user's game data.
Run through the orchestration Lua queue with **two slots** per capture.

```
WIDTH=1035 HEIGHT=696 SETTLE=1 SCENES=dark XVFB=/path/to/Xvfb \
  bash tools/ui_dialogs/capture.sh /tmp/ui-dialogs/1035x696
```

Repeat at 1600×900 and 2560×1440, GUI_SCALE=1 (default). `ONLY` is an optional
comma-separated subset of names from the probe's `pages` list. `SCENES` may
include `bright` for the snow/daylight contrast check. The shell acknowledges
each rendered frame before the probe advances; no screenshot is inferred
from successful Lua execution. `contact_sheets.py INPUT OUTPUT` creates
smaller inspection sheets without replacing original PNGs.

`stage_hooks.py` exposes otherwise private production render functions only
in the staged throwaway copy. Character creation/preparation can thus be
shown deterministically without bypassing the shipped login flow. Service
rows use actual catalogues, prices, tooltips and rule text. Test player data,
mail and claim examples live only in the disposable world. These are visual
checks, not proof of transactional behavior; the portable fixtures test the
real field routes and their validation separately.

Outputs include individual PNGs, the exact shown form strings, a capture
manifest and server/client logs. A missing form, failed scenario or runtime
error fails the capture. The driver requests shutdown after the last view;
cleanup targets only its own temporary paths and Xvfb process.

`gallery.py CAPTURE_ROOT` writes an offline `index.html` over resolution
subdirectories. Extra scenarios accepted by `ONLY` include `quest_ready`
(a real offered kill quest credited through the quest API), `craft_busy`
(real recipe jobs) and `crown_empty`. These alter disposable test state only.
Use `SEED=12345` for comparable backgrounds; the initial audit used fresh
random seeds and is not a performance comparison.
