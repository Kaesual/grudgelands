# WP6 Model Port Notes (mob media, T4 output)

Everything the roster tasks (WP6/T5–T7) need to write mob definitions
**without re-opening any upstream repository**: final file names, the source
each model came from, the animation frame ranges translated into mobs_redo
slots, a starting `visual_size`/`collisionbox`, and the per-model quirks.

Licensing/attribution for every file listed here lives in
[`mods/ENTITIES/grug_mobs/LICENSE-media.md`](../../../mods/ENTITIES/grug_mobs/LICENSE-media.md)
— that file, not this one, is the legal record. Roster spec (which mob uses
which model, verbs, drops, spawn rows): [`docs/design/biomes_mobs.md`](../../design/biomes_mobs.md) §3–4.

**No sounds were imported** (deferred, see LICENSE-media.md header), so leave
`sounds = {}` out of the defs or point them at existing engine sounds.

---

## 0. Conventions that apply to every model

### 0.1 Mesh scale (measured, not guessed)

Luanti renders a `.b3d` at **1 model unit = 0.1 node** when
`visual_size = 1`. Reference point: `character.b3d` measures 17.0 units and
is the 1.70-node-tall player.

Every measurement below is the mesh's own bounding box (vertices with node
transforms applied, rotations ignored), so:

```
visual_size ≈ desired_height_in_nodes / (mesh_height_units / 10)
```

⚠ **Cross-check with the two mobs already in the repo before copying their
style**: `grug_mobs_boar.b3d` measures 8.0 units (0.80 nodes at
`visual_size` 1, which already matches its `collisionbox` height 0.86) yet
`boar.lua` sets `visual_size = 2.5`; `grug_mobs_zombie.b3d` measures 18.0
units (1.80 nodes, collisionbox 1.89) yet `zombie.lua` sets 3. Either the
game deliberately runs oversized mobs or those two values are stale — decide
that once in T5 and apply the same rule to all new mobs. The upstream defs
(VoxeLibre) use `visual_size = 1` for both.

### 0.2 Animation slots

mobs_redo reads `<slot>_start` / `<slot>_end` / `<slot>_speed` with
`speed_normal` as the fallback speed (`mods/ENTITIES/mobs/api.lua`,
`set_animation`). Slots we use: `stand`, `walk`, `run`, `punch`, `shoot`,
`die`, `fly`.

⚠ **A missing slot is silent**: `set_animation` returns without changing
anything if `<slot>_start` or `<slot>_end` is nil, so the mob keeps playing
the previous clip. Several sources define no `run` and/or no `punch` — the
tables below say so, and the standard fix is `run = walk range` with a higher
`run_speed`, `punch = walk range` for models without an attack clip (that is
exactly what `boar.lua` and `kraken.lua` already do).

Frame ranges are transcribed verbatim from the upstream mob definitions.
Where upstream ranges obviously overlap (animalworld reuses `die` frames
inside `punch`), that is upstream's own data — noted, not corrected.

### 0.3 Texture slots

A slot is one **mesh buffer** (one `TRIS` chunk in the b3d), and a def must
fill **all** of them: `GenericCAO::addToScene` logs `Model X is missing N more
texture(s), this is deprecated` once per model and then copies the previous
slot's texture into the empty ones. Counts below are measured from the files,
not guessed:

| Mesh | Slots | Meaning |
|------|-------|---------|
| `grug_mobs_boar.b3d` | 2 | 1 = body, 2 = saddle layer → `grug_mobs_blank.png` (see `boar.lua`) |
| `grug_mobs_zombie.b3d` | 2 | 1 = armour overlay → `grug_mobs_blank.png`, 2 = skin (upstream `mobs_mc/zombie.lua` order) |
| `grug_mobs_ram.b3d` | 2 | 1 = fleece (`grug_mobs_ram_fur.png`), 2 = body/face (`grug_mobs_ram.png`) |
| `grug_mobs_bog_ooze.b3d` | 2 | 1 = inner cube, 2 = outer shell — upstream passes the same texture twice |
| `grug_mobs_skeleton.b3d` | 3 | 1 = armour, 2 = bones (`grug_mobs_skeleton.png`), 3 = wielded item — use `grug_mobs_blank.png` for 1 and 3 until a bow texture is sourced |
| `grug_mobs_zebra.b3d` | 12 | ⬐ |
| `grug_mobs_crocodile.b3d` | 15 | the animalworld meshes (§2) are built from |
| `grug_mobs_serpent.b3d` | 15 | one cube per body part, so every part is its |
| `grug_mobs_hyena.b3d` | 16 | own material slot — but all of them are |
| `grug_mobs_panther.b3d` | 17 | UV-mapped into the SAME atlas PNG, so the def |
| `grug_mobs_eagle.b3d` | 18 | repeats that one texture across every slot |
| `grug_mobs_jungle_ape.b3d` | 20 | (`grug_mobs.atlas_textures`, `init.lua`) |
| all others | 1 | bear, gull, kraken, parrot, rabbit, spider, stag, stone_golem, wolf, `character.b3d` |

### 0.4 Runtime tints vs. baked textures

Every per-biome variant listed here is a **baked PNG** (design decision:
`^[multiply` at runtime is reserved for elite/rare flavour). The elite
"Silverback" (Jungle Ape) and "Elder" (Bear) therefore need **no** extra
file — apply a runtime modifier plus the tier scale.

---

## 1. VoxeLibre / mobs_mc models

Source: <https://git.minetest.land/VoxeLibre/VoxeLibre> @
`c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, defs in
`mods/ENTITIES/mobs_mc/*.lua`. mcl_mobs is a mobs_redo fork, so the animation
key names transfer 1:1; sizes/collisionboxes come out of
`initial_properties`.

### 1.1 Rabbit / Hare — `grug_mobs_rabbit.b3d`

* Textures: `grug_mobs_rabbit.png` (Rabbit), `grug_mobs_hare_dust.png` (Dust Hare, mountain/badlands)
* Upstream def: `rabbit.lua` (`mobs_mc:rabbit`)
* Mesh: 4.77 units = **0.48 nodes** at `visual_size` 1 · upstream `visual_size` 1
* `collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.49, 0.2}`
* Animation: `stand 0–0`, `walk 0–20 speed 20`, `run 0–20 speed 30`
* Quirks: stand is a single frame (frame 0); **no punch clip** (critter, `flees` verb — not needed). Frames 21–41 are the baby rabbit, ignore.

### 1.2 Parrot — `grug_mobs_parrot.b3d`

* Texture: `grug_mobs_parrot.png` (red/blue)
* Upstream def: `parrot.lua`
* Mesh: 3.24 units = **0.32 nodes** at 1 · upstream `visual_size` 3 (→ ~0.97 nodes, matches its collisionbox)
* `collisionbox = {-0.25, -0.01, -0.25, 0.25, 0.89, 0.25}`
* Animation: `stand 0–0 speed 50`, `walk 0–20 speed 50`, `fly 60–120 speed 50`
* Quirks: upstream marks the walk range as a placeholder ("TODO: actual walk animation"). For a flying critter map mobs_redo `walk`/`run` onto the **fly** range 60–120 and use `fly = true`, `fly_in = "air"`.

### 1.3 Skeleton (Archer / Raider) — `grug_mobs_skeleton.b3d`

* Textures: `grug_mobs_skeleton.png` (Skeleton Archer), `grug_mobs_skeleton_raider.png` (war-coast Skeleton Raider)
* Upstream def: `skeleton+stray.lua`
* Mesh: 20.1 units = **2.01 nodes** at 1 · upstream `visual_size` 1
* `collisionbox = {-0.3, -0.01, -0.3, 0.3, 1.98, 0.3}`, `walk_velocity 1.2`, `run_velocity 2.0`
* Animation: `stand 0–40 speed 15`, `walk 40–60 speed 15`, `run` = walk range at `speed 30` (upstream only sets `run_speed = 30`), `shoot 70–90`, `die 160–170 speed 15, loop false`
* Quirks: **three texture slots** (§0.3). The `shoot` clip is the one the `dogshoot` verb needs; there is no melee punch clip — reuse `shoot` for `punch`.

### 1.4 Wolf / Blightfang — `grug_mobs_wolf.b3d`

* Textures: `grug_mobs_wolf.png`, `grug_mobs_wolf_blightfang.png`
* Upstream def: `wolf.lua`
* Mesh: 9.27 units = **0.93 nodes** at 1 · upstream `visual_size` 1
* `collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.84, 0.3}`
* Animation: `stand 0–0`, `walk 0–40 speed 50`, `run 0–40 speed 100`, `sit 45–45`
* Quirks: stand is one frame; **no punch clip** — reuse the walk range at run speed. Upstream `spawn_in_group = 8`, which fits the "hunts in packs" verb.

### 1.5 Bear / Plaguehide — `grug_mobs_bear.b3d`

* Textures: `grug_mobs_bear.png` (brown Bear), `grug_mobs_bear_plaguehide.png`
* Upstream def: `polar_bear.lua`
* Mesh: 3.78 units = **0.38 nodes** at 1 · upstream `visual_size` **3.0** (→ ~1.13 nodes)
* `collisionbox = {-0.7, -0.01, -0.7, 0.7, 1.39, 0.7}`, `damage 6`, `reach 2`
* Animation: `speed_normal 25`, `speed_run 50`, `stand 0–0`, `walk 0–40`, `run 0–40`
* Quirks: **no punch clip**; the elite "Elder Bear" is scale ×1.6 on top of whatever `visual_size` T5 settles on, no new texture.

### 1.6 Bog Ooze — `grug_mobs_bog_ooze.b3d`

* Texture: `grug_mobs_bog_ooze.png` (used in **both** slots, see §0.3)
* Upstream def: `slime+magma_cube.lua` (big slime)
* Mesh: 1.52 units = **0.15 nodes** at 1 · upstream `visual_size` **12.5** (→ ~1.9 nodes) for the big slime, 6.25 medium, 3.125 small
* `collisionbox = {-1.02, -0.01, -1.02, 1.02, 2.03, 1.02, rotate = true}` (big)
* Animation: `stand 1–20 speed 17`, `walk 1–20 speed 17`, `jump 1–20 speed 17` (upstream comments "TODO: Fix animations")
* Quirks: cube mesh, no punch clip — the "engulfs" verb is a damage aura, so the walk loop is enough. Upstream splits into smaller slimes on death; we do not port that.

### 1.7 Mountain Ram — `grug_mobs_ram.b3d`

* Textures: **slot 1** `grug_mobs_ram_fur.png`, **slot 2** `grug_mobs_ram.png`
* Upstream def: `sheep.lua` (mesh `mobs_mc_sheepfur.b3d`)
* Mesh: 12.6 units = **1.26 nodes** at 1 · upstream `visual_size` 1
* `collisionbox = {-0.45, -0.01, -0.45, 0.45, 1.29, 0.45}`
* Animation: `stand 0–0`, `walk 0–40 speed 30`, `run 0–40 speed 40`, `eat 40–80 loop false`
* Quirks: **the mesh works standalone** — the sheep is one model with two materials (fleece + body), and VoxeLibre only ever colorises the fleece layer at runtime; our pre-baked `grug_mobs_ram_fur.png` replaces that. Frames 81–161 are the lamb. No punch clip; the ram is a `flees` critter. The model has no horns — if T6 wants a visible ram silhouette, that is a future texture/model task, not a blocker.

---

## 2. animalworld models

Source: <https://github.com/mt-mods/animalworld> @
`ac835da96681774679ace90656812aab67e25b5c`, defs in `<animal>.lua`.
**These are already mobs_redo defs** — animation tables, `collisionbox` and
`visual_size` can be copied verbatim.

Shared quirk: every animalworld def uses `die_start/die_end` ranges that
**overlap the punch range** (e.g. hyena punch 250–350, die 200–300). Copy as
transcribed; if a death animation looks wrong in game, drop the `die_*` keys
(mobs_redo then just despawns the corpse).

| Mob (ours) | Model | Texture(s) | Upstream def |
|---|---|---|---|
| Hyena | `grug_mobs_hyena.b3d` | `grug_mobs_hyena.png` | `hyena.lua` |
| Zebra | `grug_mobs_zebra.b3d` | `grug_mobs_zebra.png` | `zebra.lua` |
| Crag Eagle / Vulture | `grug_mobs_eagle.b3d` | `grug_mobs_eagle.png`, `grug_mobs_vulture.png` | `stellerseagle.lua` |
| Panther / Jungle Lynx | `grug_mobs_panther.b3d` | `grug_mobs_panther.png`, `grug_mobs_jungle_lynx.png` | `snowleopard.lua` |
| Serpent | `grug_mobs_serpent.b3d` | `grug_mobs_serpent.png` | `kobra.lua` |
| Crocodile | `grug_mobs_crocodile.b3d` | `grug_mobs_crocodile.png` | `crocodile.lua` |
| Jungle Ape | `grug_mobs_jungle_ape.b3d` | `grug_mobs_jungle_ape.png` | `monkey.lua` |

### 2.1 Hyena — `grug_mobs_hyena.b3d`

* Mesh 8.89 units = **0.89 nodes** at 1 · upstream `visual_size` 1.0
* `collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5}`
* Animation: `speed_normal 75`, `stand 0–100`, `walk 150–250`, `punch 250–350`, `die 200–300 speed 50 loop false rotate true`
* **No run range** → set `run = 150–250` with a higher `run_speed` (§0.2).

### 2.2 Zebra — `grug_mobs_zebra.b3d`

* Mesh 17.46 units = **1.75 nodes** at 1 · upstream has no `visual_size` (= 1)
* `collisionbox = {-0.5, -0.01, -0.5, 0.5, 1.4, 0.5}`, `stepheight 2`, `jump = false`
* Animation: `speed_normal 30`, `stand 0–50`, `stand1 50–100` (mobs_redo picks randomly between `stand` and `stand1`), `walk 100–200 speed 70`, `run 100–200`, `die 100–200 loop false`
* **No punch clip** — prey mob (`flees`), not needed.

### 2.3 Crag Eagle / Vulture — `grug_mobs_eagle.b3d`

* Mesh 11.43 units = **1.14 nodes** at 1 (wings spread) · upstream `visual_size` 1.0
* `collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.5, 0.3}`, `fly = true`, `fly_in = {"air"}`, `walk_velocity 5`, `run_velocity 5`
* Animation: `speed_normal 100`, `stand 0–100`, `fly 150–250`, `punch 250–350`, `die 200–300 loop false`
* Quirks: **no walk/run range** — a flier only needs `fly`, but mobs_redo's ground states still call `walk`/`run`, so alias both to 150–250. For the "dive-bombs" verb use `attack_type = "dogshoot"`.
* Alternative: animalworld also ships a dedicated **`models/Vulture.b3d`** (+ `texturevulture.png`, same MIT terms) with `stand 150–250`, `fly 0–100`. We took the eagle mesh + a dark retint to keep one model for both continents; if T6 wants a distinct vulture silhouette, that file is the drop-in and needs a new LICENSE-media row.

### 2.4 Panther / Jungle Lynx — `grug_mobs_panther.b3d`

* Mesh 8.41 units = **0.84 nodes** at 1 · upstream `visual_size` 1.0
* `collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5}`, `walk_velocity 3`, `run_velocity 4`
* Animation: `speed_normal 140`, `stand 0–100 speed 50`, `walk 100–200`, `punch 250–350`, `die 200–300 loop false`
* **No run range** → `run = 100–200`, higher speed.
* This mesh carries **two mobs**: Panther (`grug_mobs_panther.png`, "stalks") and the **Jungle Lynx** (`grug_mobs_jungle_lynx.png`), which replaces the Raptor family per biomes_mobs §8.2 — same pack verb and wolf drop table.

### 2.5 Serpent — `grug_mobs_serpent.b3d`

* Mesh 36.5 units = **3.65 nodes** at 1 · upstream `visual_size` **0.3** (→ ~1.1 nodes)
* `collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5}`
* Animation: `speed_normal 60`, `stand 0–100`, `walk 250–350`, `punch 150–200`, `shoot 150–200`, `die 100–200 loop false`
* **No run range** → `run = 250–350`. Upstream also spawns a poison projectile entity (`animalworld_snakepoison.png`) — **not imported**; our "poisons" verb is a melee-applied DoT, so the `punch` clip is all we need.

### 2.6 Crocodile — `grug_mobs_crocodile.b3d`

* Mesh 3.65 units high, 38.6 units long = **0.36 × 3.86 nodes** at 1 · upstream `visual_size` 1.0
* `collisionbox = {-0.6, -0.01, -0.6, 0.6, 0.95, 0.6}`
* Animation: `speed_normal 75`, `stand 0–100`, `walk 250–350`, `fly 400–500` (**= the swim loop**), `punch 100–200`, `die 100–200 loop false`
* Quirks: for the amphibious behaviour upstream sets `fly_in = {water source/flowing}` and swaps in the `fly` clip while submerged — that is exactly the 5.0-in-water speed of the design spec. **No run range** → `run = 250–350`.

### 2.7 Jungle Ape — `grug_mobs_jungle_ape.b3d`

* Mesh 8.58 units = **0.86 nodes** at 1 · upstream def has no `visual_size` (= 1); the design wants it "upscaled", so pick ≥ 1.5 in T6
* `collisionbox = {-0.5, -0.01, -0.5, 0.5, 0.95, 0.5}`, `stepheight 3`, `jump_height 8`
* Animation: `speed_normal 100`, `stand 350–450 speed 75`, `walk 0–100`, `punch 100–200`, `shoot 200–300`, `die 200–300 loop false`
* Quirks: **stand does not start at 0** here. `shoot` is upstream's dung-throwing clip (projectile **not** imported) — the elite "Silverback" is a runtime tint + scale, no extra file.

---

## 3. animalia models (asset harvest)

Source: <https://github.com/ElCeejo/animalia> @
`5895f403fd43a9464e06b3675af3495f50565a3f`, defs in `mobs/*.lua`.
animalia runs on the **creatura** API, which we do not embed — only the mesh
and the texture were taken. Creatura writes ranges as
`animations = { stand = {range = {x = A, y = B}, speed = S} }`; translated
below into mobs_redo slots (`A` → `_start`, `B` → `_end`, `S` → `_speed`).
Creatura's `hitbox = {width = W, height = H}` translates to
`collisionbox = {-W, 0, -W, W, H, W}`.

### 3.1 Stag / Gaunt Stag — `grug_mobs_stag.b3d`

* Textures: `grug_mobs_stag.png`, `grug_mobs_stag_gaunt.png`
* Upstream def: `mobs/reindeer.lua`, mesh `animalia_reindeer.b3d`
* Mesh 2.32 units = **0.23 nodes** at 1 · upstream `visual_size` **10** (→ ~2.3 nodes incl. antlers; animalia mobs are exported at 1/10 the usual scale)
* creatura hitbox `{width = 0.45, height = 0.9}` → `collisionbox = {-0.45, 0, -0.45, 0.45, 0.9, 0.45}`; upstream speed 3
* Animation → mobs_redo: `stand 1–59 speed 10`, `walk 70–89 speed 30`, `run 100–119 speed 40`, (`eat 130–150 speed 20`, loop false — optional idle)
* Quirks: **no punch/attack clip** (prey, `flees` verb). `visual_size` 10 and the 0.9-node hitbox disagree; start at 10 and shrink until the mesh matches the box in-game. Calf texture (`animalia_reindeer_calf.png`) not imported — we have no breeding.

### 3.2 Gull / Carrion Crow — `grug_mobs_gull.b3d`

* Textures: `grug_mobs_gull.png` (Gull, beaches/strait), `grug_mobs_crow.png` (Carrion Crow, war coast)
* Upstream def: `mobs/song_bird.lua`, mesh `animalia_bird.b3d`
* Mesh 0.72 units = **0.07 nodes** at 1 · upstream `visual_size` **10** (→ ~0.72 nodes)
* creatura hitbox `{width = 0.2, height = 0.4}` → `collisionbox = {-0.2, 0, -0.2, 0.2, 0.4, 0.2}`; upstream speed 4
* Animation → mobs_redo: `stand 1–100 speed 30`, `walk 110–130 speed 40`, `fly 140–160 speed 40`
* Quirks: no punch clip (both are `flees` critters). Use `fly = true` + `fly_in = "air"` and alias `run` to the fly range.

---

## 4. mobs_monster models

Source: <https://codeberg.org/tenplus1/mobs_monster> @
`adc76336bf596ea49b86cb45b852848f108e1ebd`. Native mobs_redo — everything is
copy-paste.

### 4.1 Giant Spider — `grug_mobs_spider.b3d`

* Textures: `grug_mobs_spider.png` (forest/cave), `grug_mobs_spider_pale.png` (bone forest), `grug_mobs_spider_jungle.png` (jungle)
* Upstream def: `spider.lua`
* Mesh 5.0 units = **0.50 nodes** at 1 · upstream `visual_size` 1 — the design calls it a *Giant* Spider, so scale up in T5/T6
* `collisionbox = {-0.7, -0.5, -0.7, 0.7, 0, 0.7}` — ⚠ **the mesh hangs below its origin** (measured y range −5.0…0.0 units), hence the negative-y collisionbox. Do not "fix" it to a 0-based box or the spider sinks into the ground.
* Animation: `stand 0–0`, `walk 1–21`, `run 1–21 speed 30`, `punch 25–45 speed 30`, `speed_normal 15`
* Quirks: upstream sets `glow = 1` and `fly_in = "mobs:cobweb"` (climbs webs). `armor = 100`. Our "webs" verb (40 % slow for 3 s on hit) is new code, no asset need.

### 4.2 Stone Golem / Mesa Golem — `grug_mobs_stone_golem.b3d`

* Textures: `grug_mobs_stone_golem.png` (crags), `grug_mobs_mesa_golem.png` (badlands)
* Upstream def: `stone_monster.lua`
* Mesh 17.24 units = **1.72 nodes** at 1 · upstream `visual_size` 1
* `collisionbox = {-0.3, -1, -0.3, 0.3, 0.7, 0.3}` — again a **negative-y box**: the mesh spans −10.0…+7.24 units, i.e. −1.0…+0.72 nodes around the origin
* Animation: `speed_normal 15`, `speed_run 15`, `stand 0–14`, `walk 15–38`, `run 40–63 speed 40`, `punch 40–63`
* Quirks: upstream `jump_height = 0`, `stepheight = 1.1` (it steps, it does not jump) and an `immune_to` table for picks — drop that, our armour comes from the level engine. Elite tier (armor 80) per design.

---

## 5. Humanoids on `character.b3d`

The mesh is the engine/MTG player model — **already in the game's media
namespace** via `mods/BASE/player_api/models/character.b3d` (LGPL 2.1+ code,
CC BY-SA 3.0 media). Do **not** copy it into grug_mobs; just reference
`mesh = "character.b3d"`.

* Skins are 64×32, standard classic layout (head base + hat overlay, body,
  one arm and one leg mirrored).
* Frame ranges from `mods/BASE/player_api/init.lua`:
  `stand 0–79`, `lay 162–166`, `walk 168–187`, `mine 189–198`,
  `walk_mine 200–219`, `sit 81–160`.
  → mobs_redo mapping: `stand 0–79 speed 30`, `walk 168–187 speed 30`,
  `run 168–187 speed 45`, `punch 189–198 speed 30`.
* `collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}`, `visual_size = {x = 1, y = 1}`
  (mesh measures 17.0 units = 1.70 nodes — the player's own size).

| Mob | Texture | Notes |
|-----|---------|-------|
| Bandit (variant 1) | `grug_mobs_bandit_1.png` | camp humanoid, inner+outer, both continents |
| Bandit (variant 2) | `grug_mobs_bandit_2.png` | second skin so a camp is not four clones |
| Accord Guard | `grug_mobs_guard_accord.png` | faction NPC/outpost guard |
| Throng Guard | `grug_mobs_guard_throng.png` | faction NPC/outpost guard |
| Mirefolk | `grug_mobs_mirefolk.png` | swamp fish-folk, spawn at **reduced scale** (design: "character.b3d small scale") — try `visual_size = 0.8` |

⚠ **Verify once in-game**: the four LotT skins were drawn for LotT's
`lottarmor_character.b3d`, which shares the classic layout with MTG's
`character.b3d`. They should map 1:1, but check the head/hat and arm UVs on
the first spawned bandit before building all four defs.

### Mirefolk skin generator (CC0, ours)

`grug_mobs_mirefolk.png` is original work, not derived from any licensed
skin. The generator is kept here so the skin can be regenerated or tweaked:

```python
#!/usr/bin/env python3
# Generates grug_mobs_mirefolk.png - an original 64x32 character.b3d skin
# (Grudgelands project, CC0). Not derived from any existing skin.
import random
from PIL import Image

W, H = 64, 32
SEED = 20260806

SCALE_D = (38, 66, 58, 255)    # dark teal-green
SCALE_M = (58, 94, 76, 255)    # murky green
SCALE_L = (84, 124, 96, 255)   # highlight green
BELLY = (176, 188, 148, 255)   # pale belly
BELLY_D = (150, 162, 124, 255)
FIN = (92, 142, 134, 255)      # teal fin
FIN_D = (60, 104, 100, 255)
EYE_W = (226, 236, 222, 255)
EYE_P = (18, 26, 28, 255)
MOUTH = (30, 44, 40, 255)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()
rng = random.Random(SEED)


def box(x, y, w, h, col):
    for j in range(y, y + h):
        for i in range(x, x + w):
            px[i, j] = col


def scales(x, y, w, h, base=SCALE_M, dark=SCALE_D, light=SCALE_L):
    """Flat fill + deterministic speckle so the skin reads as scaled hide."""
    box(x, y, w, h, base)
    for j in range(y, y + h):
        for i in range(x, x + w):
            r = rng.random()
            if r < 0.18:
                px[i, j] = dark
            elif r < 0.30:
                px[i, j] = light


# ---------------------------------------------------------------- head (base)
scales(8, 0, 8, 8)        # top
scales(16, 0, 8, 8)       # bottom (throat) - paler
box(16, 0, 8, 8, BELLY_D)
scales(0, 8, 8, 8)        # right
scales(8, 8, 8, 8)        # front (face)
scales(16, 8, 8, 8)       # left
scales(24, 8, 8, 8)       # back
# gill slits on both head sides
for gx in (2, 18):
    for k in range(3):
        box(gx + k * 2, 12, 1, 3, FIN_D)
# face: big pale fish eyes + wide mouth
box(9, 11, 2, 2, EYE_W)
box(13, 11, 2, 2, EYE_W)
px[10, 12] = EYE_P
px[13, 12] = EYE_P
box(10, 14, 4, 1, MOUTH)
px[9, 14] = MOUTH
px[14, 14] = MOUTH

# ------------------------------------------------- head overlay = dorsal crest
# The hat layer is a slightly larger cube: a centre strip painted here reads as
# a fin running over the skull, the rest stays transparent.
box(43, 0, 2, 8, FIN)      # crest along the top, front to back
box(43, 0, 2, 1, FIN_D)
box(59, 8, 2, 5, FIN)      # crest continuing down the back of the head
box(59, 8, 2, 1, FIN_D)

# ---------------------------------------------------------------------- body
scales(20, 16, 8, 4)      # top (shoulders)
box(28, 16, 8, 4, BELLY_D)  # bottom
scales(16, 20, 4, 12)     # right side
scales(20, 20, 8, 12)     # front
box(21, 22, 6, 9, BELLY)  # pale belly plate on the chest
for j in range(23, 31, 2):  # belly banding
    box(21, j, 6, 1, BELLY_D)
scales(28, 20, 4, 12)     # left side
scales(32, 20, 8, 12)     # back
box(35, 20, 2, 12, FIN)   # spine fin down the back
box(35, 20, 2, 1, FIN_D)

# ---------------------------------------------------------------------- leg
scales(4, 16, 4, 4)       # top
box(8, 16, 4, 4, BELLY_D)  # bottom (webbed foot)
scales(0, 20, 4, 12)      # right
scales(4, 20, 4, 12)      # front
box(4, 29, 4, 3, BELLY_D)  # webbed foot front
scales(8, 20, 4, 12)      # left
scales(12, 20, 4, 12)     # back

# ---------------------------------------------------------------------- arm
scales(44, 16, 4, 4)      # top
box(48, 16, 4, 4, BELLY_D)  # bottom (webbed hand)
scales(40, 20, 4, 12)     # right
scales(44, 20, 4, 12)     # front
box(44, 29, 4, 3, BELLY_D)  # webbed hand
scales(48, 20, 4, 12)     # left
scales(52, 20, 4, 12)     # back
box(41, 20, 1, 10, FIN)   # forearm fin

img.save("grug_mobs_mirefolk.png")
```

---

## 6. Roster coverage (biomes_mobs §3.1) — what is in the mod

| Biome group | Mob | Model | Texture | Status |
|---|---|---|---|---|
| Settled (all six) | Boar | `grug_mobs_boar.b3d` | `grug_mobs_boar.png` | had it |
| Settled | Plague Boar (blight) | `grug_mobs_boar.b3d` | `grug_mobs_boar_plague.png` | **new** |
| Settled | Jungle Boar (east) | `grug_mobs_boar.b3d` | `grug_mobs_boar_jungle.png` | **new** |
| Settled | Rabbit | `grug_mobs_rabbit.b3d` | `grug_mobs_rabbit.png` | **new** |
| Settled / mountains | Dust Hare | `grug_mobs_rabbit.b3d` | `grug_mobs_hare_dust.png` | **new** |
| Settled | Zombie | `grug_mobs_zombie.b3d` | `grug_mobs_zombie.png` | had it |
| Settled (camps) | Bandit ×2 | `character.b3d` | `grug_mobs_bandit_1/2.png` | **new** |
| Forest pair | Wolf | `grug_mobs_wolf.b3d` | `grug_mobs_wolf.png` | **new** |
| Forest pair | Blightfang Wolf | `grug_mobs_wolf.b3d` | `grug_mobs_wolf_blightfang.png` | **new** |
| Forest pair | Bear (+Elder elite) | `grug_mobs_bear.b3d` | `grug_mobs_bear.png` | **new** |
| Forest pair | Plaguehide Bear | `grug_mobs_bear.b3d` | `grug_mobs_bear_plaguehide.png` | **new** |
| Forest / jungle / caves | Giant Spider ×3 tints | `grug_mobs_spider.b3d` | `grug_mobs_spider{,_pale,_jungle}.png` | **new** |
| Forest pair | Stag | `grug_mobs_stag.b3d` | `grug_mobs_stag.png` | **new** |
| Forest pair | Gaunt Stag | `grug_mobs_stag.b3d` | `grug_mobs_stag_gaunt.png` | **new** |
| Bone forest / war coast | Skeleton Archer | `grug_mobs_skeleton.b3d` | `grug_mobs_skeleton.png` | **new** |
| War coast | Skeleton Raider | `grug_mobs_skeleton.b3d` | `grug_mobs_skeleton_raider.png` | **new** |
| War coast | Carrion Crow | `grug_mobs_gull.b3d` | `grug_mobs_crow.png` | **new** |
| Mountain pair | Crag Eagle | `grug_mobs_eagle.b3d` | `grug_mobs_eagle.png` | **new** |
| Mountain pair | Vulture | `grug_mobs_eagle.b3d` | `grug_mobs_vulture.png` | **new** |
| Mountain pair | Stone Golem (elite) | `grug_mobs_stone_golem.b3d` | `grug_mobs_stone_golem.png` | **new** |
| Mountain pair | Mesa Golem (elite) | `grug_mobs_stone_golem.b3d` | `grug_mobs_mesa_golem.png` | **new** |
| Mountain | Mountain Ram | `grug_mobs_ram.b3d` | `grug_mobs_ram_fur.png` + `grug_mobs_ram.png` | **new** |
| Savanna / badlands | Hyena | `grug_mobs_hyena.b3d` | `grug_mobs_hyena.png` | **new** |
| Savanna | Zebra | `grug_mobs_zebra.b3d` | `grug_mobs_zebra.png` | **new** |
| Jungle | Jungle Lynx (Raptor slot) | `grug_mobs_panther.b3d` | `grug_mobs_jungle_lynx.png` | **new** (§8.2 fallback) |
| Jungle | Panther | `grug_mobs_panther.b3d` | `grug_mobs_panther.png` | **new** |
| Jungle | Serpent | `grug_mobs_serpent.b3d` | `grug_mobs_serpent.png` | **new** |
| Jungle | Jungle Ape (+Silverback elite) | `grug_mobs_jungle_ape.b3d` | `grug_mobs_jungle_ape.png` | **new** |
| Jungle edge | Parrot | `grug_mobs_parrot.b3d` | `grug_mobs_parrot.png` | **new** |
| Swamp | Crocodile | `grug_mobs_crocodile.b3d` | `grug_mobs_crocodile.png` | **new** |
| Swamp | Bog Ooze | `grug_mobs_bog_ooze.b3d` | `grug_mobs_bog_ooze.png` | **new** |
| Swamp (camps) | Mirefolk | `character.b3d` | `grug_mobs_mirefolk.png` | **new** (CC0, ours) |
| Beach / strait | Gull | `grug_mobs_gull.b3d` | `grug_mobs_gull.png` | **new** |
| Beach / coast | **Shore Crab / Reef Lurker** | — | — | **GAP, deferred by design §8.3** |
| Deep sea | Kraken Guard | `grug_mobs_kraken.b3d` | `grug_mobs_kraken.png` | had it |
| Faction outposts | Accord / Throng Guard | `character.b3d` | `grug_mobs_guard_{accord,throng}.png` | **new** |

### Known gaps / follow-ups

1. **Shore Crab** — deferred by biomes_mobs §8.3 (no licensed model sourced);
   the strait launches with the Gull only, and the coast-zone elite "Reef
   Lurker" has no base family yet. animalworld does ship `Crab.b3d` /
   `Hermitcrab.b3d` (MIT, same repo and commit as §2) — the cheapest way to
   close this gap if the design decision is revisited.
2. **Raptor** — replaced by the Jungle Lynx; paleotest media has no usable
   license statement (evidence in LICENSE-media.md §7).
3. **Sounds** — none imported anywhere. Per-file freesound verification is a
   later work package.
4. **Skeleton bow texture** — the mesh's third material is the wielded item;
   `grug_mobs_blank.png` is the placeholder until a bow texture is sourced.
5. **Style mismatch** — animalworld/animalia textures are higher-detail than
   the 16 px VoxeLibre look of boar/zombie (already flagged in
   `docs/research/assets/mobs_animals.md`). Cosmetic only, no blocker.
