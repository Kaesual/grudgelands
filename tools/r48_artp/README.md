# Round 48 ARTP — plant art drafts

Step 1, 2026-10-14, by **GPT-6 Astra**: **27 alternatives, 87 original
16 × 16 RGBA sprites and nine comparison sheets**. These are proposals for
the user's pick, with no selection assumed. The
[plant art plan](../../docs/planning/plant-art-plan.md) owns the brief.
Change classification: **compatible**; this package adds only design artifacts
under `tools/r48_artp/`. It changes no runtime files or saved state.

**Cassava.** A: one woody trunk with a high crown of five-fingered leaves,
and one budded stem cutting. B: a forked shrub with two spreading leaf
crowns, and a tied bundle of cuttings. C: three splayed woody canes with
narrow hand-shaped leaves, and a forked sprouting cutting. Each has stages
1–4 plus its planting icon; visible stems and divided leaves distinguish
all three from the existing Potato. [Comparison](previews/cassava.png).

**Wild Onion.** A: one broad golden bulb below a straight leaf fan. B: two
small cream-gold bulbs with arching leaves at unequal heights. C: one
slender golden bulb with a long neck and bent, curling leaves. All three
have stages 1–4 and warm copper, peach and cream bulb shading guided by
the current harvest icon. [Comparison](previews/wild_onion.png).

**Pumpkin.** A: one squat, wide fruit with deep ribs. B: two smaller
pumpkins on a branching vine. C: one tall oval fruit beside a trailing
vine. Only stage 4 is delivered. The comparison repeats the retained
stages 1–3 in every column, labelled `KEPT`; the new vine palette follows
their yellow-olive leaves. [Comparison](previews/pumpkin.png).

**Melon.** A: a tan oval fruit with broken diamond netting. B: a long pale
honeydew with shallow lengthwise seams. C: a narrow green fruit with
tapered ends and interrupted golden stripes. Each has stages 1–4, pale
seeds and a whole-fruit item icon. Ground-hugging fruits and horizontal
item silhouettes separate them from the upright Apple, orange Pumpkin
and red Frost Melon slice. [Comparison](previews/melon.png).

**Mushroom.** A: an ivory parasol with gills and a small pin beside it;
the spores icon shows a radial underside print. B: an ochre trumpet with
a flared rim; the spores icon is a gill fan shedding powder. C: lilac
bell caps on pale stems; the spores icon is loose lilac powder. Each
has four growth stages and a separate harvest icon. Tall stems and clear
cap outlines separate them from the brown Cave Cap clusters.
[Comparison](previews/mushroom.png).

**Sunleaf.** A: a low rosette of broad gold leaves with a green basal
leaf. B: a curved spice sprig with separated pairs of oval leaves.
C: a fan of three broad serrated leaves with gold veins. Each has a
grounded world sprite and a slightly raised or trimmed inventory sprite;
the broad blades remain distinct beside meadow grass.
[Comparison](previews/sunleaf.png).

**Gravemoss.** A: a low grey-green star-moss mat with a few dry spore
capsules. B: pale string moss draped over a dark twig, with a gathered
hanging tuft for the inventory. C: a creeping silver-green mat of small
antler-shaped fronds. All three have separate world and item sprites;
their porous outlines avoid a solid leafy head.
[Comparison](previews/gravemoss.png).

**Wild Cocoa.** A: a stout stem carrying golden ribbed pods, with a
whole pod as the item. B: an arching branch bearing unequal russet pods,
with a pod pair as the item. C: a low spreading branch carrying a broad
plum-coloured pod, with an opened pod, cream pulp and two loose beans
as the item. Every world sprite exposes the fruit below its leaves.
[Comparison](previews/wild_cocoa.png).

**Salt Pan.** A: a shallow rectangular tray with chamfered corners.
B: a shallow oval pan with two small side lugs. C: a square tray viewed
corner-first with a folded rim. All hold pale crystalline salt, a little
brine and warm brown-grey metal shading that relates to the existing
basin rim. Only item icons are delivered; basin tops and a side tile
provide the comparison. [Comparison](previews/salt_pan.png).

## Reproduction and checks

The one generator is [generate.py](generate.py). It uses **Python 3 and
the already installed Pillow 12.3.0**, as the previous art lane did.
These commands run from the repository root:

```sh
python3 tools/r48_artp/generate.py
python3 tools/r48_artp/generate.py --check
```

All draft geometry, palettes, pixel stamps and the comparison label font
are authored in that file. The draft pass starts with transparent canvases
and never reads existing textures. No downloads, external fonts, random
input, antialiasing or image-generation service are needed. Preview-only
reads occur after all new sprites have been drawn. Regeneration writes
only the package's PNGs, manifest and media ledger. The README is edited
by hand.

`--check` does not write files. It checks the exact PNG set, every file's
size and mode, every generated pixel, manifest contents and media ledger.
All **87 draft PNGs are 16 × 16 RGBA with binary alpha**; all **nine
previews are RGBA** at the larger dimensions recorded in the manifest.
The PNGs were also visually inspected on the three grounds. No Lua,
fixtures, engine runs, GUI sync, merge or push belong to this step.
The user's selections and any correction requests remain the next step.

## Coordinator handoff

[drafts/manifest.json](drafts/manifest.json) uses **repository-relative
paths** everywhere. Its `drafts` array contains one entry for every
`item` / `draft` pair, including `files`, matching `roles` and a one-line
`idea`. Filenames are the final names from plan §6; they remain inside
`drafts/<item>/<A|B|C>/`. The gather-only plants all use the split
`*_plant.png` world sprite and the plain item filename. No extra wild
sprite is needed for Melon or Mushroom: their stage 4 is their wild art.

The manifest's `items` array holds each item's `current` source paths,
`current_views` (labels and exact runtime colour modifiers), `neighbors`
and `preview`. `reference_sha256` records every source file read by the
comparison pass, so changes to the baseline are reviewable. These paths
are references to existing art, not draft assets or new CC0 files.

Each comparison places **current / A / B / C** in columns, repeats them
on **light / dark / soil** grounds, and shows **1× then 4× nearest
neighbour** tiles. Stages run left to right, followed by planting and
harvest icons where applicable. The final row repeats the neighbours
on all three grounds at the same scales. Missing current crop stages
are identified in the footer; no invented current stages are substituted.
Salt basin tops show their **first 16 × 16 animation frame**. These are
raw texture comparisons; world scaling, lighting and crossed-quad
rendering remain for the later desktop and web playtest.

Every new sprite is **CC0-1.0**. Comparison sheets also contain the
repository's licensed existing art, so they retain the appropriate
CC BY-SA licences. [LICENSE-media.md](LICENSE-media.md) lists every PNG,
date, author and source, including the existing comparison inputs.
