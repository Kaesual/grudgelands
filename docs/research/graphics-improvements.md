# Graphics Improvements — Research

Researched 2026-08-07. Pure research/planning note — **no code was changed**.
Sources: ContentDB API (content.luanti.org), the engine checkout in
`reference_projects/luanti` (5.17.0-dev), blog.luanti.org, gnu.org.

Licence baseline for every verdict below: **our code is GPL-3.0-or-later**
(`LICENSE.txt` in the repo root already contains the full GPLv3 text — the
"we have no LICENSE file yet" assumption is outdated), media stays per file
under its original licence. Compatibility matrix:
[`licensing.md`](licensing.md) §2.

---

## 0. Executive summary

1. **There is no such thing as an "HD texture mod" for Luanti.** Resolution
   comes from *texture packs* (client-side, per player) or from the textures
   a game ships itself. Everything on ContentDB tagged as a graphics
   improvement is one of two things: a texture pack, or a ~15-line Lua mod
   that calls `player:set_lighting()`.
2. **The biggest, cheapest win is server-side and needs no third-party mod
   at all**: Luanti's dynamic shadows, bloom, volumetric light, auto-exposure
   and saturation are all *off by default until the game asks for them* via
   `player:set_lighting()`. That is literally what `enable_shadows`,
   `volumetric_lighting` and `voxelibre_shader_preset_port` do — we should
   implement ~20 lines in `grug_core` instead of vendoring three MIT mods
   (see §3 and §7-A).
3. **A second big win is free**: `<game path>/textures/` (i.e. a `textures/`
   directory in our repo root) overrides *any* mod texture and is sent to
   clients automatically. That is the supported way to ship a higher-resolution
   look with the game — no client-side install, no texture pack. We do not use
   it yet.
4. **Only ~4 texture packs are both licence-clean and stylistically right for
   a WoW-inspired game** (hand-painted, not photorealistic): Hand Painted Pack
   (CC0), Hand Painted Pack Expanded (CC0), Artelhum (MIT), Dungeon Soup
   (CC0-1.0, 32px). CC0/MIT matters here: those we may *vendor and modify*,
   BY-SA ones we may ship but must keep under BY-SA per file.
5. **Client-side shader packs are out of reach for us** (§6) — they replace
   engine GLSL files in the player's installation, cannot be shipped by a
   game or a server, and all known ones predate the 5.15 shader rewrite.
6. **Performance**: everything in §3 is a *client-side* cost that each player
   can already switch off in their own settings. The one cost we would impose
   on everyone is media size if we ship HD textures (§5.3) — currently 378
   PNGs / 351 KB; a 128px set would be roughly 10–30 MB per client download.

---

## 1. The four layers (what "graphics improvement" actually means here)

| Layer | Lives where | Who controls it | Can a *game* ship it? |
|---|---|---|---|
| **A** Engine render features (shadows, bloom, godrays, waving, AA, tone mapping) | Engine C++/GLSL, toggled by client settings | Player's settings — **but many need the game to opt in via Lua** | Defaults yes (`minetest.conf` in the game dir), the toggle itself no |
| **B** Server-side Lua that drives A and adds visual detail (`set_lighting`, `set_sky`, `waving`, drawtypes, particles) | Our mods | Us, fully | **Yes — this is our lever** |
| **C** Texture resolution / art style | `textures/` dirs, texture packs | Game textures = us; texture packs = player | **Yes**, via `<game>/textures/` |
| **D** Custom shaders (GLSL) | `<client install>/client/shaders/` | Player only, manual file copy | **No** |

The practical consequence: almost every "graphics mod" on ContentDB is layer B
glue we can write ourselves in a few lines, and the interesting third-party
material is layer C (art).

---

## 2. Engine features available to us (layer A) — with defaults and cost

From `reference_projects/luanti/builtin/settingtypes.txt` (5.17.0-dev).
"Default" = what a fresh Luanti install uses.

| Feature | Setting | Default | Needs game opt-in? | Performance cost |
|---|---|---|---|---|
| Post-processing pipeline | `enable_post_processing` | **on** | no | small, one fullscreen pass |
| Dynamic shadows | `enable_dynamic_shadows` | **off** | **yes** — invisible unless `set_lighting{shadows={intensity>0}}` | high; scales with `shadow_map_texture_size` (2048), `shadow_filters` (0/1/2), `shadow_map_max_distance` (140) |
| Bloom | `enable_bloom` | **off** | yes (`bloom.intensity`) | moderate (downsample/upsample chain) |
| Volumetric light ("godrays") | `enable_volumetric_lighting` (requires bloom) | **off** | **yes** (`volumetric_light.strength`) | **highest of the post-FX**; explicitly recommended off on weak GPUs |
| Auto exposure | `enable_auto_exposure` | off | yes (`exposure` table) | moderate |
| Filmic tone mapping | `tone_mapping` | off | no | moderate |
| Debanding | `debanding` | on | no | small (higher on GLES) |
| Saturation / colour grading | — | 1.0 | **yes** (`saturation`) | free (already in the post pass) |
| Waving leaves / plants / liquids | `enable_waving_*` | **off** | **yes** — node needs `waving = 1/2/3` | low (vertex shader) |
| Translucent foliage | `enable_translucent_foliage` (requires shadows) | off | no | low, but rides on shadows |
| Liquid reflections | `enable_water_reflections` (requires waving water + shadows) | off | no | moderate |
| Anti-aliasing | `antialiasing` = none/FSAA/SSAA, `fxaa` | none | no | FSAA low, SSAA very high, FXAA cheap |
| View range | `viewing_range` | — | no | **the single biggest FPS factor** |

Engine version notes:

- **5.15.0 (2026-01-24)** introduced **array textures** — reported "up to 10×
  higher FPS in some situations" — and brought dynamic shadows, liquid
  reflections and translucent foliage to **Android** (needs OpenGL ES 3.2).
  Requires OpenGL 3.2+ / GLES 3.0. This meaningfully changes the cost/benefit:
  effects that were "desktop only" in 5.8 are now defensible defaults.
- **5.10** added glTF (`.gltf`/`.glb`) model support, `.glb` recommended —
  relevant if we ever want higher-fidelity mob/NPC models than `.b3d`.
- Textures **smaller than 192px are never bilinear/trilinear filtered** (the
  engine upscales nearest-neighbour first). So our 16px art stays crisp no
  matter what the player sets — but a 128px pack *will* get filtered, which
  changes the look. Documented in `doc/lua_api.md` → "Textures".

### 2.1 Shipping graphics defaults with the game

A game directory may contain a `minetest.conf`. It is loaded into the
`SL_GAME` settings layer, which sits **between** engine defaults (`SL_DEFAULTS`)
and the user's own config (`SL_GLOBAL`) — verified in
`src/content/subgames.cpp:400` and `src/settings.h:52-55`. So we can ship
sensible defaults (e.g. `enable_waving_leaves = true`,
`enable_dynamic_shadows = true`) that a player can still override.

**Caveat:** this only affects the process that has our game installed —
singleplayer and a self-hosted server. Players joining a *remote* Grudgelands
server keep their own client settings; there is no way to push render settings
over the network. Everything in §3 works remotely because it goes through the
Lua API, which the server *does* transmit.

---

## 3. Layer-B mods: lighting/atmosphere ("shader preset" mods)

All three of the popular ones are MIT and are, in full, a
`register_on_joinplayer` calling `player:set_lighting()`. Verified by reading
the sources.

| Mod | Licence (code/media) | GPLv3+ compatible? | What it actually is | Perf |
|---|---|---|---|---|
| [ROllerozxa/enable_shadows](https://content.luanti.org/packages/ROllerozxa/enable_shadows/) | MIT / MIT | ✅ | ~45 lines: sets `shadows.intensity` (default 0.33) on join + a `/shadow_intensity` chatcommand, persisted in mod storage | client-side shadow cost only |
| [ROllerozxa/volumetric_lighting](https://content.luanti.org/packages/ROllerozxa/volumetric_lighting/) | MIT / MIT | ✅ | sets `volumetric_light.strength` | godrays are the most expensive post-FX |
| [QBSteve/voxelibre_shader_preset_port](https://content.luanti.org/packages/QBSteve/voxelibre_shader_preset_port/) | MIT / MIT | ✅ | **14 lines**, reproduced below | as chosen |
| [TestificateMods/lighting_monoid](https://content.luanti.org/packages/TestificateMods/lighting_monoid/) | MIT / MIT | ✅ | compatibility layer so several mods can stack lighting overrides without fighting | negligible |

The complete VoxeLibre preset port, for reference — this is the entire mod:

```lua
core.register_on_joinplayer(function(player)
    player:set_lighting({
        shadows = { intensity = 0.33 },
        volumetric_light = { strength = 0.45 },
        exposure = {
            luminance_min = -3.5, luminance_max = -2.5,
            exposure_correction = 0.35,
            speed_dark_bright = 1500, speed_bright_dark = 700,
        },
        saturation = 1.1,
    })
end)
```

**How we would use this:** not by vendoring. We write
`mods/CORE/grug_core/lighting.lua` with a `grug_core.set_atmosphere(player,
preset)` helper and a table of named presets, then drive it from context we
already have:

- per **biome/region** (`grug_mapgen` knows the 17 biomes) — desaturated cold
  tint on the war coast, warm saturation in the safe core, near-zero
  saturation + strong shadow tint underground;
- per **faction continent** — Kragmar cooler/harsher, Elandor warmer;
- per **combat state** — `grug_core.mark_in_combat` already exists; a short
  saturation/exposure nudge on entering combat is a genuinely WoW-ish cue;
- per **event** (elite telegraph, night truce in WP19) — the WP6 telegraph
  system already has the hooks.

`set_lighting` is per-player and cheap on the server (one packet on change).
The rule is: **only send on change**, never per globalstep.

Related, also usable: `player:set_sky` / `set_sun` / `set_moon` / `set_stars` /
`set_clouds` (`doc/lua_api.md:9387ff`) for per-region skies. Same pattern,
same cost profile.

---

## 4. Layer-B mods: visual detail (third-party, licence-checked)

Sorted by how useful they look for Grudgelands. ✅ = combinable with our
GPL-3.0-or-later code; media licence kept per file.

| Mod | Licence (code / media) | Compat | Use for us | Perf impact |
|---|---|---|---|---|
| [stu/3d_armor](https://content.luanti.org/packages/stu/3d_armor/) | LGPL-2.1-only / CC-BY-SA-3.0 | ✅ (LGPL-2.1 §3 → GPLv3) | **Visible worn armour + wielded item on the player model.** For a gear-driven RPG this is the single largest perceived-quality jump. Note it brings its own armour/inventory system — we'd want the model/attachment half only | one attached entity per player; noticeable at 100+ players, needs measuring |
| [bell07/skinsdb](https://content.luanti.org/packages/bell07/skinsdb/) | GPL-3.0-only / CC0-1.0 | ✅ (combo becomes GPLv3, drops our "or later") | Per-race player skins/models. Media is CC0 → freely modifiable | negligible |
| [TenPlus1/simple_skins](https://content.luanti.org/packages/TenPlus1/simple_skins/) | MIT / CC0-1.0 | ✅ | Lighter alternative to skinsdb; keeps our "or later" | negligible |
| [the_raven_262/skygen](https://content.luanti.org/packages/the_raven_262/skygen/) | LGPL-2.1-only / CC-BY-SA-4.0 | ✅ | Biome-adaptive skybox + server-wide sky events. Good reference even if we write our own on top of `set_sky` | low |
| [TestificateMods/climate_api](https://content.luanti.org/packages/TestificateMods/climate_api/) + [climate](https://content.luanti.org/packages/TestificateMods/climate/) (Regional Weather) | LGPL-3.0-only / CC-BY-3.0 resp. CC-BY-SA-3.0 | ✅ | Biome-aware weather with particle/sky effects — rain on the war coast, snow in the mountain band. Heaviest but most complete weather stack | **highest of this table**: per-player particle spawners + globalsteps; must be throttled and range-limited |
| [paramat/snowdrift](https://content.luanti.org/packages/paramat/snowdrift/) | MIT / MIT | ✅ | Lightweight snow/rain alternative to the above; MIT, small, readable | low |
| [sofar/lightning](https://content.luanti.org/packages/sofar/lightning/) | LGPL-2.1-only / LGPL-2.1-only | ✅ | Thunder/lightning flashes — strong mood tool for storm biomes and boss events | negligible (event-driven) |
| [random_geek/auroras](https://content.luanti.org/packages/random_geek/auroras/) | GPL-3.0-only / GPL-3.0-only | ✅ | Night auroras in cold biomes — fits the northern Kragmar mountain band | low |
| [mt-mods/illumination](https://content.luanti.org/packages/mt-mods/illumination/) / [bell07/wielded_light](https://content.luanti.org/packages/bell07/wielded_light/) | GPL-3.0-only / GPL-3.0-only | ✅ | Held torch/staff emits light. Big for dungeons and caves | **light node churn** — sets/removes real nodes as the player moves; the known perf trap of this mod class |
| [texmex/item_drop](https://content.luanti.org/packages/texmex/item_drop/) | LGPL-2.1-only | ✅ | Dropped loot as rotating 3D items + magnet pickup. Very visible quality cue for an RPG loot loop | one entity per drop — cap lifetime |
| [Just_Visiting/falls](https://content.luanti.org/packages/Just_Visiting/falls/) | GPL-3.0-only | ✅ | Particle waterfalls/lavafalls | ABM-driven, throttle required |
| [karlexceed/leaf_particles](https://content.luanti.org/packages/karlexceed/leaf_particles/) | LGPL-2.1-or-later | ✅ | Falling leaves under foliage — cheap ambience | low if `chance` tuned |
| [epCode/punch_and_place_particles](https://content.luanti.org/packages/epCode/punch_and_place_particles/) | LGPL-3.0-only | ✅ | Dig/place particle feedback | low |
| [Qual/more_particles](https://content.luanti.org/packages/Qual/more_particles/) | LGPL-2.1-only | ✅ | Assorted ambient particles | low–moderate |
| [FaceDeer/footprints](https://content.luanti.org/packages/FaceDeer/footprints/) | MIT / CC-BY-SA-3.0 | ✅ | Footprints in snow/sand | writes nodes on movement — moderate, watch it |
| [RealBadAngel/framedglass](https://content.luanti.org/packages/RealBadAngel/framedglass/) | LGPL-2.1-or-later | ✅ | Connected/framed glass — capital windows | free (drawtype only) |
| [Codiac/mcl_small_3d_plants](https://content.luanti.org/packages/Codiac/mcl_small_3d_plants/) | MIT / MIT | ✅ | Mesh nodes for small plants instead of flat crosses. VoxeLibre-targeted → reference, not drop-in | mesh nodes cost more vertices than `plantlike` |
| [sofar/emote](https://content.luanti.org/packages/sofar/emote/) | LGPL-2.1-only / CC-BY-3.0 | ✅ | Player emotes/animations (`/sit`, `/lay`) — WoW-flavoured social layer | negligible |
| [niwla23/visible_sneak](https://content.luanti.org/packages/niwla23/visible_sneak/) | MIT / MIT | ✅ | Crouch is visible to others | negligible |
| [erlehmann/bushy_leaves](https://content.luanti.org/packages/erlehmann/bushy_leaves/) | AGPL-3.0-or-later | ⚠️ | Bushy instead of boxy leaves — nice, but AGPL adds a **network source-offer obligation** that would attach to a public server. Combinable with GPLv3 per FSF, but it changes our obligations; prefer reimplementing the idea (it is a drawtype/nodebox change) | free |
| [LMD/texgen](https://content.luanti.org/packages/LMD/texgen/) | MIT / "Other (Free/Open)" | ⚠️ media unclear | Dynamically generated texture packs — a *tool*, not a shipped dependency. Interesting next to our own `tools/gen_mob_item_textures.py` | n/a |

**Not usable:**

| Mod | Licence | Why not |
|---|---|---|
| [sofar/skybox](https://content.luanti.org/packages/sofar/skybox/) | **GPL-2.0-only** (code *and* media) | GPLv2-only ✕ GPLv3 — exactly the trap in `licensing.md` §3.1. Use `skygen` or plain `set_sky` instead |

Two things worth stating plainly: several of the mods above (`illumination`,
`footprints`, `falls`) improve looks by **writing nodes**, which is the most
expensive thing a Luanti mod can do and conflicts with the protection rules in
`grug_core/protection.lua`. Any adoption needs a real profiling pass, not a
"looks nice" verdict.

---

## 5. Layer C: resolution and art style

### 5.1 Where we stand

- Every texture in the repo is **16px** (302 of 378 PNGs are exactly 16×16;
  the rest are mob/entity sheets and GUI art). Total payload: **378 files,
  351 KB**.
- Our own node/item art is **procedurally generated** from ASCII maps by
  `tools/gen_mob_item_textures.py` (CC0, deterministic, reviewable in the
  diff). That is a genuinely good pipeline — but it is authored at 16px.
- **241 of the 378 textures are `default_*` from vendored minetest_game**
  (`mods/BASE/default/textures`). That is the bulk of what a player actually
  sees: stone, dirt, grass, wood, ores, tools.

That last point is the important one: **any texture pack made for
minetest_game already covers most of our world**, because we kept the
`default:` namespace and filenames.

### 5.2 The mechanism nobody uses: `<game>/textures/`

From `doc/lua_api.md` → "Loading order" and `src/server.cpp:2742`
(`Server::fillMediaCache`), the priority is, highest last:

```
Client: $path_share/textures/base/pack
Server: mod textures (mods/*/textures/)
Server: game textures            <-- <repo root>/textures/     ← we don't use this
Server: $path_user/textures/server
Server: override.txt in texture_path
Server: override.txt in <game path>/textures    ← we don't use this either
Client: the player's texture pack               ← always wins
```

Two consequences we should act on:

1. A `textures/` directory in our repo root **overrides any mod texture,
   including vendored `default_*` ones, and is transmitted to clients
   automatically**. That is the supported, zero-friction way to ship a
   consistent Grudgelands look over the minetest_game base without patching
   vendored mods — and it fits our VENDOR.md policy of keeping the patch
   surface minimal.
2. `textures/override.txt` lets us retarget textures **per node and per face**
   (`default:dirt_with_grass sides my_grass_side.png^[brighten`) with texture
   modifiers, without touching a single node definition. Good for faction
   retints of shared nodes.
3. There is also a **`server` texture pack** (`$path_user/textures/server`),
   but it lives in the *server operator's* user dir, not in the game — an
   ops-level tool, not something we ship.

### 5.3 Cost of going HD

- **Download/media cache**: game textures are sent to every client on first
  join. 16px → 128px is 64× the pixels; realistically **~10–30 MB** of PNG
  per client instead of the current 351 KB. For a 100+ player server that is
  a one-off per client, but it is a real first-join delay.
- **VRAM**: same factor, permanently resident. Since 5.15 textures go into
  array textures/atlases, so the memory is more contiguous but not smaller.
- **Filtering**: at ≥192px the engine will bilinear-filter if the player
  enabled it → a soft look that fights the voxel aesthetic. 32px and 64px sets
  stay unfiltered and keep the crisp look.
- **Authoring**: our generator produces 16px ASCII art. Going HD means either
  re-authoring by hand (expensive) or upscaling (looks bad on pixel art unless
  hand-touched).

**Recommendation: 32px, not 128px.** It doubles perceived detail, stays under
the 192px filtering threshold, keeps media around 1–2 MB, and is a realistic
authoring target for a generated pipeline. 64px is the ceiling worth
considering.

### 5.4 Texture packs, licence-checked

Verdicts against GPL-3.0-or-later code + per-file media licences. The
"vendor" column is the decisive one: **CC0 and MIT art we may copy into
`<game>/textures/` and modify freely**; CC-BY-SA art we may ship but must keep
under BY-SA with attribution, and adaptations stay BY-SA (3.0) or may go
BY-SA 4.0/GPLv3 one-way (4.0).

| Pack | Res. | Licence | Ship? | Vendor+modify? | Style fit for a WoW-like |
|---|---|---|---|---|---|
| [drummyfish/drummyfish — Hand Painted Pack](https://content.luanti.org/packages/drummyfish/drummyfish/) | 128px | **CC0-1.0** | ✅ | ✅ **free rein** | ★★★ hand-painted, the closest thing to WoW's art direction on ContentDB |
| [shaft/hand_painted_expanded](https://content.luanti.org/packages/shaft/hand_painted_expanded/) | 128px | **CC0-1.0** | ✅ | ✅ | ★★★ extends the above with more mod coverage |
| [AndrOn/artelhum](https://content.luanti.org/packages/AndrOn/artelhum/) | 128px | **MIT** | ✅ | ✅ | ★★☆ cartoon, vibrant, wide mod support |
| [sirrobzeroone/dungeonsoup](https://content.luanti.org/packages/sirrobzeroone/dungeonsoup/) | **32px** | **CC0-1.0** | ✅ | ✅ | ★★★ dungeon/fantasy themed **and** at exactly the resolution we should target |
| [Hugues Ross/rpg16](https://content.luanti.org/packages/Hugues%20Ross/rpg16/) | 16px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★★★ classic-RPG look; no resolution gain, but a strong style reference |
| [Fhelron/realfantasy](https://content.luanti.org/packages/Fhelron/realfantasy/) | 128px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★★☆ "realistic + fantastic" mix |
| [ROllerozxa/macrotex](https://content.luanti.org/packages/ROllerozxa/macrotex/) | 32px | CC-BY-SA-3.0 | ✅ | BY-SA 3.0 (sticky) | ★★☆ 32px in the original MTG idiom — closest to "our art, but sharper" |
| [ROllerozxa/mtg_tiled_32x](https://content.luanti.org/packages/ROllerozxa/mtg_tiled_32x/) | 32px | CC-BY-SA-3.0 | ✅ | BY-SA 3.0 | ★☆☆ MTG textures tiled to 32x — mainly kills tiling repetition |
| [hilol/textures__ — Great Textures](https://content.luanti.org/packages/hilol/textures__/) | 32px | MIT | ✅ | ✅ | ★☆☆ no upstream repo → provenance harder to verify |
| [Pudding/standart_textures](https://content.luanti.org/packages/Pudding/standart_textures/) | 64px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★☆☆ no repo |
| [Lokrates/polygonia](https://content.luanti.org/packages/Lokrates/polygonia/) | 128–256px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★☆☆ Blender-rendered, heavy |
| [CocoMarck/cm_drawtextures](https://content.luanti.org/packages/CocoMarck/cm_drawtextures/) | 128px | GPL-3.0-only | ✅ (code+media both GPL) | ✅ under GPLv3 | ★★☆ drawn from scratch, keeps a hint of pixelation |
| [Sharpik/sharpnet_textures](https://content.luanti.org/packages/Sharpik/sharpnet_textures/) | 64px | GPL-3.0-only | ✅ | ✅ under GPLv3 | ✗ photorealistic — clashes with a stylised RPG |
| [Clemstriangular/realism_512](https://content.luanti.org/packages/Clemstriangular/realism_512/) | 512px | EUPL-1.2 | ⚠️ | relicensable to GPLv3 via the EUPL compatible-licence appendix | ✗ photorealistic, and 512px is far past sane |
| [Zughy/soothing32](https://content.luanti.org/packages/Zughy/soothing32/) | **16px** | CC-BY-SA-4.0 | ✅ | BY-SA only | ★★☆ note: "32" = **32 colours**, not 32 pixels. Highest-rated pack on ContentDB; a palette reference, not a resolution upgrade |
| [MysticTempest/refi_textures](https://content.luanti.org/packages/MysticTempest/refi_textures/) | 16px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★☆☆ readability-focused |
| [sofar/pixelperfection](https://content.luanti.org/packages/sofar/pixelperfection/) | 16px | CC-BY-SA-4.0 | ✅ | BY-SA only | ★☆☆ already the base of VoxeLibre/Mineclonia art |
| [zayuim/isabellaii](https://content.luanti.org/packages/zayuim/isabellaii/) | 16px | CC-BY-3.0 | ✅ | BY only | ★★☆ warm medieval/fantasy tone |
| [jp/pixelbox](https://content.luanti.org/packages/jp/pixelbox/) | 16px | WTFPL | ✅ but ContentDB-discouraged | ✅ | ★☆☆ |

Nothing in the FOSS texture-pack space is NC/ND-licensed at the top of the
list, so the usual trap from `licensing.md` §4 does not bite here. The trap
that *does* bite is provenance: several packs have **no upstream repo**
(`hilol/textures__`, `Pudding/standart_textures`, `Clemstriangular/realism_512`,
`mtvisitor/stg_texturepack_lab`) — per our VENDOR.md rules we need an upstream
commit to record, so those are effectively unusable as vendored assets even
where the licence allows it.

---

## 6. Layer D: client-side shader packs — why we cannot use them

| Pack | Licence | Status |
|---|---|---|
| [GefullteTaubenbrust2/Minetest-Shaderpack](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack) | GPL-3.0 | last push 2024-02; targets pre-5.9 shaders |
| [DragonWrangler1/minetest-shaders-2.0_5.8-edition](https://github.com/DragonWrangler1/minetest-shaders-2.0_5.8-edition) | LGPL-2.1 | explicitly "5.8 edition"; last push 2024-07 |
| [valenciaDev74/vibrant-luanti](https://github.com/valenciaDev74/vibrant-luanti) | **none stated** | all-rights-reserved by default → unusable regardless |

These offer real effects (coloured artificial light, tinted sunlight, glossy
water, colour grading, bumpmaps, FXAA, godrays). But `src/client/shader.cpp:50-70`
shows shaders are resolved only from the client's `shader_path` setting or the
engine's own `client/shaders/` directory — **never from a game, a mod, or the
server**. So a shader pack is a manual, per-player file replacement, it is not
transmitted, and it is tightly coupled to the engine's GLSL, which 5.15
rewrote for array textures and GLES. All three above predate that.

**Verdict:** not a project dependency. At most a README line telling players
that such packs exist. If we ever want an effect from them badly enough, the
route is an upstream engine PR, not a bundled pack.

---

## 7. Recommendation — what to actually do, in order

### A. `grug_core` atmosphere layer (highest value / lowest cost) — new WP

Write ~50 lines instead of vendoring three MIT mods:

- `grug_core.set_atmosphere(player, preset)` wrapping `player:set_lighting()`
  plus `set_sky`/`set_clouds`, sending only on change.
- Presets per biome band, per faction continent, underground, night, and
  in-combat.
- Ship a game-root `minetest.conf` with `enable_dynamic_shadows = true`,
  `enable_waving_leaves/plants/water = true`, `enable_bloom = true` as
  *defaults* (players can still override).
- Cost: zero server cost; client cost is opt-out via each player's own
  settings. Give the whole thing an off-switch in `settingtypes.txt`.

Prior art to read (all MIT, so also safe to copy from):
`voxelibre_shader_preset_port` (the 14 lines above), `enable_shadows`.

### B. Audit our own node definitions for free wins — small WP

Zero-media, zero-performance visual upgrades we are leaving on the table:

- `waving = 1/2/3` on every plant/leaf/liquid we register. Vendored `default`
  already does this, `grug_trees` partially does (`grug_trees` leaves have
  `waving = 1` on `allfaces_optional`, which the engine maps to
  `TILE_MATERIAL_WAVING_LEAVES` — correct). New `grug_nodes` foliage should
  follow.
- `paramtype2 = "color"/"colorfacedir"` + `palette` to get per-biome tinted
  grass/leaves/banners from **one** texture instead of N.
- `glasslike_framed_optional`, `connected` nodeboxes, `plantlike_rooted`,
  `special_tiles` — all pure drawtype changes.
- `use_texture_alpha`, overlay tiles (`^`) and texture modifiers
  (`[colorize`, `[combine`, `[opacity`) for variants without new PNGs — the
  faction banner in `grug_nodes` is a natural first candidate.

### C. Decide the resolution question — design decision, then a WP

Recommendation: **target 32px** for Grudgelands-authored art, shipped through
a new `<repo root>/textures/` directory (§5.2), starting with the most-seen
nodes (grass, stone, dirt, wood, the six capitals' materials). Keep
`tools/gen_mob_item_textures.py` as the pipeline and give it a scale factor —
authoring at 32px in ASCII maps is more work per icon but stays reviewable in
the diff, which is the property we do not want to lose.

Free interim option: recommend [Dungeon Soup](https://content.luanti.org/packages/sirrobzeroone/dungeonsoup/)
(CC0, 32px, dungeon-themed) in the README as a player-installed pack, and
evaluate vendoring parts of it — CC0 means we may take, retint and rename
individual tiles with only a courtesy credit.

### D. Visual detail mods — later, one at a time, each profiled

Ordered by value/risk: `3d_armor` (model half only) → `item_drop` →
`lightning` → `snowdrift` or `climate_api` → `skinsdb`/`simple_skins`.
Everything that writes nodes (`illumination`, `wielded_light`, `footprints`)
goes last and only with a measured globalstep budget, because it collides with
both our performance rules and `grug_core/protection.lua`.

### E. Housekeeping that this research turned up

- `LICENSE.txt` (GPLv3) exists; what is still missing per `licensing.md` §1 is
  the README "Licensing" section and `CREDITS.md`. Any texture-pack adoption
  makes those mandatory, not optional.
- Media provenance rule from VENDOR.md §5 applies to every tile we take from a
  pack: file, author, source URL, upstream commit, licence, modified yes/no.

---

## 8. Sources

- ContentDB API + package pages — <https://content.luanti.org/packages/?type=txp>, <https://content.luanti.org/packages/?type=mod&tag=environment>
- Engine checkout `reference_projects/luanti` (5.17.0-dev): `doc/lua_api.md`
  (Textures/Loading order, `set_lighting`, node `waving`),
  `doc/texture_packs.md` (`override.txt`, `server` pack),
  `builtin/settingtypes.txt` (graphics defaults), `src/server.cpp`
  (`fillMediaCache`), `src/content/subgames.cpp` + `src/settings.h`
  (game `minetest.conf` layer), `src/client/shader.cpp` (shader lookup),
  `src/client/node_visuals.cpp` (waving material selection)
- [Luanti 5.15.0 release notes](https://blog.luanti.org/2026/01/24/5.15.0-released/) — array textures, Android shadows
- [Luanti 5.9.0 release notes](https://blog.luanti.org/2024/08/12/5.9.0-released/) — volumetric lighting
- [Minetest graphics settings guide (Raspberry Pi forum)](https://forums.raspberrypi.com/viewtopic.php?t=391450) — qualitative per-setting cost
- [GNU license list](https://www.gnu.org/licenses/license-list.en.html) — AGPLv3↔GPLv3, EUPL-1.2, CC BY-SA 4.0 one-way
- [EUPL compatible-licence matrix](https://interoperable-europe.ec.europa.eu/collection/eupl/matrix-eupl-compatible-open-source-licences)
- [GefullteTaubenbrust2/Minetest-Shaderpack](https://github.com/GefullteTaubenbrust2/Minetest-Shaderpack), [DragonWrangler1 shaders 2.0](https://github.com/DragonWrangler1/minetest-shaders-2.0_5.8-edition), [vibrant-luanti](https://github.com/valenciaDev74/vibrant-luanti)
- Project-internal: [`licensing.md`](licensing.md), [`../../VENDOR.md`](../../VENDOR.md), [`../../AGENTS.md`](../../AGENTS.md)
