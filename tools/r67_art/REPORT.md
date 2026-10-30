# Round 67 ART — race icons and container tier textures

Delivered on `r67-art`, from `9fcf8093a24f1642186c62261b5b291071151369`.
**Proposals ready for the user's pick: Race A, Steel A and Abyssal B are
recommended.** No choice has been treated as accepted.

Open the [offline preview](preview/index.html). Quick overviews:
[race contact sheet](preview/race_contact.png) and
[container contact sheet](preview/container_contact.png).

## Delivered art and recommendation

**44 original candidates**, with matching preview copies:

| Package | Variant A | Variant B | Recommendation |
|---|---|---|---|
| Six race icons | Coloured frontal heads: ordinary ears and swept hair for Human, broad beard for Dwarf, long pointed ears for Elf, broad green jaw and short tusks for Orc, tall crest and long tusks for Troll, hollow eyes and exposed teeth for Undead. | Quiet ivory profile signs with broad cutouts and a small faction stroke. | **A:** the anatomical outline and restrained race palette separate the six at small sizes and sit beside the coloured class icons. |
| Steel-Reinforced, T3 | Bright steel straps on warm timber, with a matching rim and crossbar on the shelves. | A fully plated blue-grey case with bright edges and a small number of panel strokes. | **A:** visible wood makes this read as a reinforced wooden container. |
| Abyssal, T6 | Wider violet straps and corners on timber. | Full dark violet plating, chamfered corners and a simple recessed diamond on the top and shelf sides. | **B:** changing the main body material makes the last tier visibly different from T3. |

The recommendation is the progression **wooden → silver-grey straps on
wood → violet plated case**. Both complete A/B alternatives remain
available for each upgraded tier.

The six races are Human, Dwarf and Elf (The Accord), and Orc, Troll and
Undead (The Throng). The faction accents use exactly `#3f6fce` and
`#c41e3a`, limited to the collar or small base stroke. Face and hair
colours follow the local character palettes. The race drawings are
representative icons, not restrictions on character appearance.

## Sizes and files

| Files in `candidates/` | Count | Export |
|---|---:|---|
| `race_{human,dwarf,elf,orc,troll,undead}_{a,b}.png` | 12 | 64 × 64 RGBA; original 32px pixel drawing enlarged 2× with nearest-neighbour sampling; transparent border, binary alpha. |
| `chest_{steel,abyssal}_{top,side,front,lock}_{a,b}.png` | 16 | 16 × 16 RGBA, opaque. |
| `chest_{steel,abyssal}_inside_{a,b}.png` | 4 | 16 × 32 RGBA, opaque; two distinct 16px UV panels. |
| `{bookshelf,vessels,shelf_side}_{steel,abyssal}_{a,b}.png` | 12 | 16 × 16 RGBA, opaque. |

Each tier/variant supplies exactly eight textures: top, side, front,
locked front, inside, bookshelf front, vessels shelf front and shared
shelf side/top. Books and vessels are newly drawn, with subdued colours
so the metal frame remains visible. No texture contains lettering or a
label plate.

The script and candidates are original authored pixel geometry, not
recoloured source rasters. The [media ledger](LICENSE-media.md) records
CC0-1.0 for the candidates, GPL-3.0-or-later for the generator, and the
separate provenance of the existing comparison assets.

## Reference checks and model fit

The brief's source facts were confirmed against the working tree:

- The four class icons are 64 × 64. The existing faction icons are
  100 × 100; the preview compares them at the same displayed sizes as
  the race icons without changing their source files.
- Chest faces, bookshelf front, vessels shelf front and wood side/top
  are 16 × 16. The original chest inside is 16 × 32 and fully opaque.
- The abyssal bar is a texture expression, not a dedicated bar PNG:
  `default_steel_ingot.png^[colorize:#3a245d:135`; steel uses
  `#34404a:75` (`mods/ITEMS/grug_materials/ores.lua`). The preview labels
  its offline bar blends as approximations and includes the existing
  abyssal pick for comparison. No glow or emissive layer is proposed.
- `mods/BASE/default/models/chest_open.obj` has six material groups.
  The renderer reads this unchanged file and its actual UVs. The lid/body
  cut is at 5/16 from the top of a face; the inside's upper half lines
  the lid and its lower half fills the recess. The model places the
  inside floor at the lip, so that lower half stays very dark to preserve
  the impression of depth.
- The two open `TODO-*.md` topics concern other work and do not block
  these proposals. The upstream workaround list contains no workaround
  needed by this art-only lane.

Integration uses the same tile mapping as today:

| Tile position | Candidate |
|---|---|
| Chest top and bottom | `chest_<tier>_top_<variant>.png` |
| Chest right, left and back | `chest_<tier>_side_<variant>.png` |
| Chest front | `chest_<tier>_front_<variant>.png` |
| Locked chest front | `chest_<tier>_lock_<variant>.png` |
| Open chest inside | `chest_<tier>_inside_<variant>.png` |
| Shelf top, bottom and sides | `shelf_side_<tier>_<variant>.png` |
| Bookshelf front/back | `bookshelf_<tier>_<variant>.png` |
| Vessels shelf front/back | `vessels_<tier>_<variant>.png` |

Here `<tier>` is `steel` or `abyssal`, and `<variant>` is `a` or `b`.
For the recommended set, SOCIAL takes `race_*_a.png`; CONTAINERS takes
the eight steel A files and the eight abyssal B files, after the user's
pick. Receiving mods should add the candidate provenance to their media
ledgers. All runtime names and installation remain the receiving lanes'
responsibility.

## Preview

`preview/index.html` contains all its styling and has no JavaScript,
external URLs or network resources. Its images sit beside it, with
relative paths. It can be opened directly from the filesystem or moved
together with that directory.

- Race sets A/B at **16, 32 and 64 px** on the dark UI background,
  beside all four current class icons and both faction icons.
- A six-row mock Online Players table per set: faction, name, class,
  race and level, with native hover titles on the icons.
- Wooden / steel / abyssal projections beside each other for A, B and
  the recommended mixed set: chest, locked chest, bookshelf, vessels
  shelf and open chest. Small companion views help judge recognition
  at reduced size.
- All eight flat textures for the original wooden tier and every
  candidate tier/variant, at **1× and 8×**. The inside keeps its 1:2
  aspect ratio.

The projections are offline illustrations with a shared camera and light,
not engine captures or measurements of an in-game viewing distance.

## Generation and verification

From the repository root:

```sh
python3 tools/r67_art/generate.py
python3 tools/r67_art/generate.py --check
```

Dependencies: Python 3, Pillow and numpy. Verified here with Python 3.14.8,
Pillow 12.3.0 and numpy 2.4.6. No network or generated-image service is
needed. The generator writes only `tools/r67_art/` and can also be invoked
by its absolute path from another directory.

`--check` regenerated and compared **134 outputs** in memory:
44 candidates, 44 matching preview copies, 18 reference/swatches,
25 projections, two contact sheets and one HTML page. It also checked
candidate dimensions, RGBA mode, transparent race borders, binary race
alpha, opaque container tiles, exact candidate/preview copies and local
page references. It rejects missing, differing and unexpected output
files. Python syntax and the new Markdown links were checked; both contact
sheets, the full tile sheet and the open chest were visually inspected.
`git diff --check` passed. No browser rendering claim is made.

**Upgrade classification: compatible.** This package adds development
assets only; no runtime code, saved state, map generation, model, version
or upgrade declaration changes. Nothing under `mods/` was modified.
No Lua, fixtures, game server, engine boot, sync, merge or push was run.

## Commit receipt

- `5e3f7633`: generator, 44 candidates and media provenance.
- **Final art/preview commit:**
  `d0e0f3dab57b70253b21cb36d3c2713e58d704d5` — offline board and the
  single `tools/README.md` entry. At this complete-art checkpoint,
  **`git status --porcelain` was empty**.
- This report is a following documentation-only commit. Its final branch
  hash and the post-report clean-tree check are recorded in the final
  handoff saved by the runner as `last.md`; embedding a commit's own hash
  in its tracked report would be self-referential. Resolve it locally with
  `git log -1 --format=%H -- tools/r67_art/REPORT.md`.

All lane commit messages end with the requested GPT-6 Astra co-author
trailer.

## Blockers / questions

No production blocker. The user's three choices remain open: race A/B,
steel A/B and abyssal A/B. The independent lane review is for the
coordinator before integration; this implementer did not launch a reviewer
or claim review acceptance.

After integration, the user's desktop **and** web GUI check should cover:

1. All six race icons in Social at the normal row size, with the class
   and faction icons and correct hover labels.
2. Wooden, steel and abyssal containers together, nearby and from several
   metres, in daylight and a normally lit interior.
3. Chest lid seams and latches; locked fronts must clearly show a lock.
4. Open both chest types at each upgraded tier; inspect the lid lining,
   dark recess and the join at the lid/body cut.
5. Rotate both shelf types to check the matching side/top and the
   visibility of books and vessels.
