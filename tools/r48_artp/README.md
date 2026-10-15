# Round 48 ARTP — picked plant art

Completed 2026-10-14 by **GPT-6 Astra**: the user picked one of the three
drafts for each of the nine items, with no change requests. All **29 selected
files now ship as byte-identical copies**, with no redraw. The original
**27 alternatives, 87 sprites and nine draft comparison sheets** remain
available. The
[plant art plan](../../docs/planning/plant-art-plan.md) owns the brief.
Change classification: **compatible**; this step replaces art and its
licence records, with no gameplay or saved-state change.

**Round 49:** Wild Onion A stages 3 and 4 sit half in the ground (ruling 9
of the [gameplay plan](../../docs/planning/round49-gameplay-draft.md)): the
painter moves the bulb down until the bottom edge cuts it at about its
widest row, the leaf tips stay. `generate.py` now also writes the picked
drafts to their shipped paths, so one run updates the game and `--check`
still holds every shipped file byte-identical to its draft. The harvest
icon `grug_cooking_wild_onion.png` is unchanged.

## Shipped picks

`grug_farming_*` files ship in `mods/ITEMS/grug_farming/textures/`;
`grug_gathering_*` files ship in `mods/ITEMS/grug_gathering/textures/`.
Each row copies every PNG from `drafts/<item>/<pick>/`. `{1..4}` denotes
four separate stage files.

| Item | Pick | Shipped filenames |
| --- | --- | --- |
| Cassava | C | `grug_farming_cassava_{1..4}.png`, `grug_farming_seed_cassava.png` |
| Wild Onion | A | `grug_farming_wild_onion_{1..4}.png` |
| Pumpkin | A | `grug_farming_pumpkin_4.png` |
| Melon | B | `grug_farming_melon_{1..4}.png`, `grug_farming_melon_seeds.png`, `grug_gathering_melon.png` |
| Mushroom | A | `grug_farming_mushroom_{1..4}.png`, `grug_farming_mushroom_spores.png`, `grug_gathering_mushroom.png` |
| Sunleaf | C | `grug_gathering_sunleaf_plant.png`, `grug_gathering_sunleaf.png` |
| Gravemoss | A | `grug_gathering_gravemoss_plant.png`, `grug_gathering_gravemoss.png` |
| Wild Cocoa | B | `grug_gathering_wild_cocoa_plant.png`, `grug_gathering_wild_cocoa.png` |
| Salt Pan | A | `grug_farming_salt_pan.png` |

[Final comparison](previews/final.png): all 29 installed files beside the
exact textures they replaced, on light, dark and soil grounds. Each tile
appears at 1× on the left and 4× nearest-neighbour on the right. The
**BEFORE** rows include FARM's placeholder PNGs and the previous Cassava,
Wild Onion and Pumpkin stages; **AFTER** rows read the installed files.
The baseline is commit `6295c1d9ea5eecb7c6aab020ff1247b316075f35`.

## Original alternatives

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
only the package's PNGs, manifest and media ledger; existing PNGs whose
pixels match are left byte-for-byte untouched. The README and the two mod
ledgers are edited by hand. Installation copies draft bytes into the mods;
the generator verifies those copies and never writes into `mods/`.

`--check` does not write files. It checks the exact PNG set, every file's
size and mode, every generated pixel, manifest contents and media ledger.
It also verifies all 29 shipped files against their selected draft bytes,
their 16 × 16 RGBA format and the SHA-256 values recorded in the manifest.
All **87 draft PNGs are 16 × 16 RGBA with binary alpha**; all **nine
draft previews and the final comparison are RGBA** at the larger dimensions
recorded in the manifest. The PNGs were also visually inspected on the
three grounds. No fixtures, engine runs, GUI sync, merge or push belong to
this step. The obsolete FARM placeholder generator has been removed;
the presentation file's generator comment now points to this package.

## Coordinator handoff

[drafts/manifest.json](drafts/manifest.json) uses **repository-relative
paths** everywhere. Its `drafts` array contains one entry for every
`item` / `draft` pair, including `files`, matching `roles` and a one-line
`idea`. Filenames are the final names from plan §6; they remain inside
`drafts/<item>/<A|B|C>/`. The gather-only plants all use the split
`*_plant.png` world sprite and the plain item filename. No extra wild
sprite is needed for Melon or Mushroom: their stage 4 is their wild art.

The manifest's `picked` map records the user's nine selections. Each item
also has a `shipped` array with destination, draft path, role, installed
SHA-256 and replaced-file SHA-256. The manifest's `items` array retains
each item's draft-step `current` source paths, `current_views` (labels and
exact runtime colour modifiers), `neighbors` and `preview`.
`reference_sha256` records the historical comparison sources. Existing art
is read with `git show` from `baseline_revision`, so the repository must
retain that commit for regeneration. The nine original comparisons remain
unchanged after installation. Historical source paths are references to
existing art at that revision, not draft assets or new CC0 files.

Each draft comparison places **current / A / B / C** in columns, repeats them
on **light / dark / soil** grounds, and shows **1× then 4× nearest
neighbour** tiles. Stages run left to right, followed by planting and
harvest icons where applicable. The final row repeats the neighbours
on all three grounds at the same scales. Missing current crop stages
are identified in the footer; no invented current stages are substituted.
Salt basin tops show their **first 16 × 16 animation frame**. These are
raw texture comparisons; world scaling, lighting and crossed-quad
rendering remain for the later desktop and web playtest.

Every new sprite is **CC0-1.0**. The two mod ledgers record each installed
file's author, licence, Round 48 generator and selected draft.
Comparison sheets also contain the
repository's licensed existing art, so they retain the appropriate
CC BY-SA licences. [LICENSE-media.md](LICENSE-media.md) lists every PNG,
date, author and source, including the existing comparison inputs.
