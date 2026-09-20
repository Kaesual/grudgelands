# R10 ART immutable-source licence preflight

## Scope

Independent read-only check of the exact source families named by the current
`tools/r10_art/import_crop_stages.sh` and `build_armor_assets.sh`, plus the
Animalia/animalworld inventory-loot sources visible in ART WIP. Reference
submodules were read at the main checkout's pinned commits; no candidate ledger
claim was accepted without an upstream source statement. No code, media,
reference checkout, or interpreter was changed/run.

Pinned inputs match the repository gitlinks: VoxeLibre `c2dbc520`, Lord of the
Test `f1641401`, farming `1a918c7a`, x_farming `ac5f69d5`, goblins `ce27b15f`,
animalia `5895f403`, animalworld `ac835da9`.

## Fix first / hold

### High — denied and unresolved `farming_spinach_*` imported as Ember Moss

`import_crop_stages.sh:23` copies `farming_spinach_{1,2,3,4}.png`. Upstream
`farming/license.txt:246-262` places `farming_spinach*` in an internally
incoherent block headed `AFL-1.1`: its prose then describes attribution and
ShareAlike, while also saying the license document may not be changed. The
project's immutable `docs/reference_projects.md` consequently deny-lists the
entire spinach family and explicitly says its licence scope is unresolved.

**Required:** replace Ember Moss with a positively cleared source. Do not import
or ship these four files based on the current evidence.

### High — five farming growth-stage families have no per-file licence grant

The script imports these files, but none is named or covered by a matching glob
in the pinned upstream `farming/license.txt`:

- `crops_onion_plant_{1,2,3,5}.png`
- `crops_pepper_plant_{1,3,5,7}.png`
- `farming_pumpkin_{1,3,5,8}.png`
- `farming_grapes_{1,3,5,8}.png`
- `farming_melon_{1,3,5,7}.png`

The ledger instead names only `crops_onion.png` and `farming_grapes.png`
(`license.txt:52-57`) and pumpkin/melon block-face files
(`license.txt:102-110`). Those names do not cover the separate growth-stage
files. Git history identifies TenPlus1 as the introducing committer for several
families, but commit authorship is not a licence grant and does not establish
the upstream art chain.

**Required:** hold these 20 imports unless an immutable upstream statement is
found that explicitly covers their filenames. The safe bounded alternative is
to choose stages from already cleared families rather than infer a licence.

## Cleared source families

### Farming crops

- Wheat stages: VanessaE, CC BY 3.0 (`farming/license.txt:80-92`).
- Carrot stages: Gambit, CC BY 3.0 (`:129-139`).
- Potato stages used as Cassava: Doc, CC BY 3.0 (`:112-122`).
- Blackberry stages: Felfa, CC0 (`:200-205`).
- `ethereal_strawberry_*`: Hugues Ross, CC BY-SA 4.0 (`:45-46`). The
  `alt_textures/` versions are separately TenPlus1 CC0; the script points at
  the root texture family and should credit Hugues Ross.

No NC or ND licence appears among these cleared files. The only NC block in the
upstream ledger is the unrelated five-food SG7997 family at `:228-233`.

### x_farming

The source ledger's texture section identifies SaKeL and CC BY-SA 4.0
(`LICENSE.txt:461-464`). It explicitly lists the imported corn stages at
`:473-482`, salt inventory art at `:650`, and potato stages at `:854-864`.
These three imported families are clear. There is no NC/ND condition.

### Goblins Cave Cap

Pinned `README.md`, “Additional source and content credits,” explicitly names
`goblins_mushroom_brown.png` and stages 2–4 as Francisco Athens, CC BY-SA 3.0
(2020). It separately records an earlier MIT flowers-mod ancestry. The output
must preserve Francisco Athens attribution and CC BY-SA 3.0; the script's
four-file selection is covered.

### VoxeLibre armor and trim

`mcl_armor/README.txt` delegates non-sound media to root `LEGAL.md`.
`LEGAL.md:42-48` identifies the Pixel Perfection/XSSheep texture chain and its
CC BY-SA 4.0 source licence. `LEGAL.md:50-52` identifies armor trim models as
Aeonix_Aeon, CC BY 4.0. The exact armor base and trim files used by
`build_armor_assets.sh` are therefore reusable with those attributions and
adaptation notices. No NC/ND term was found.

The output ledger should distinguish the two layers: base armor inherits the
XSSheep/VoxeLibre chain; `<part>_trim.png` and `<pattern>_<part>.png` add the
Aeonix_Aeon CC BY 4.0 chain. “VoxeLibre CC BY-SA 4.0” alone loses the trim
author and is insufficient for composite leather outputs.

### Lord of the Test cloth

Pinned `mods/lottclothes/license.txt` covers all selected files under CC BY-SA
3.0. It assigns `lottclothes_cloak*` and all `*_elven.png` files to Amaz and
everything else to Flipsels (with two unrelated black felt/flax files credited
to rickmcfarley). Therefore:

- Elven shirt/shoes selections and the Mordor cloak selection involve Amaz.
- The selected hoods, robes, caps, jackets, pants and boots otherwise involve
  Flipsels.

There is no NC/ND term. Because `stormweave` uses `cloak_mordor`, its chest
source must be credited to Amaz; a blanket “Amaz authored Elven, Flipsels all
remaining selected files” statement would be wrong.

### Animalia and animalworld loot

- `animalia/LICENSE` is MIT, copyright ElCeejo (2022), and covers
  `textures/items/animalia_leather.png`; the pinned file's commit is by
  ElCeejo. Light Leather is clear with the MIT notice retained.
- `animalworld/LICENSE` expressly says textures, models and animations are MIT
  by Liil/Wilhelmine/Liil (2022), in addition to its repository MIT notice.
  `textures/abearpelt.png` and `textures/aboarpelt.png` are clear for Heavy
  Leather and Sleek Pelt with that attribution.

No NC/ND condition applies to these three loot sources.

## Additional attribution precision

The three VoxeLibre loot icons in the WIP ledger (rotten flesh, feather,
slimeball) are governed by VoxeLibre's own media/legal chain, but “XSSheep
chain” should be verified per exact file/history in the final review rather
than inferred from the global default. Their current inclusion was outside the
two named build scripts, so this preflight does not certify those three rows.

The generated Boar Tusk is not an immutable reference-project import and is
outside this source preflight.

## Pre-freeze disposition

- **Block freeze:** spinach/Ember Moss and the five unlisted farming stage
  families above.
- **Ledger correction:** credit Amaz for `cloak_mordor`; preserve both base and
  trim author/licence chains on composite leather armor.
- **Cleared:** all other exact families enumerated above, subject to retaining
  licence text/links, authors, pinned commit, exact filenames and modification
  descriptions in the final owning ledgers.

Final ART review must still compare the frozen generated bytes and source hashes
to the scripts and ledgers; this preflight is not candidate acceptance.
