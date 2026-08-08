# Reference projects

The read-only sources under `reference_projects/`. They are **not part of the
build** — the game runs without them — but nobody can develop this codebase
with agents without them: every design decision, licence verification and
engine-behaviour claim in this repo cites them by file and line.

**They are git submodules** (decided 2026-08-08). That is not a contradiction
of AGENTS.md's "third-party code is vendored, never a submodule": *vendored*
means code we **ship** inside `mods/`, which must stay editable and
patchable in-tree (see VENDOR.md). These are references we **read** and never
change, and a submodule is exactly the right tool for that — it pins the
commit, which is what the per-file licence rows in the mods'
`LICENSE-media.md` cite.

## The rule (why this file exists)

A reference project needed over more than one session **must** be cloned into
`reference_projects/` and listed here. Ad-hoc clones into a scratchpad are
lost the moment the session ends — and then a cleared licence silently costs
a re-download, or worse, an asset gets imported from a source nobody can
check any more. This bit us on 2026-08-08: `animalworld`, `animalia` and
`mobs_monster` had been cloned into a temp directory during WP6, their
licences were verified and recorded, and by the next session the clones were
gone while `LICENSE-media.md` still cited their commits.

## Setup

```sh
git submodule update --init --recursive --depth 1
```

`--depth 1` keeps the checkout small; drop it if you need history (e.g. to
verify when an upstream licence changed). A submodule can be updated
deliberately with `git -C reference_projects/<name> fetch --depth 1 origin
<ref>` followed by a commit of the new pointer — **never** update one as a
side effect of other work: a moved reference invalidates every `file:line`
citation in the design docs.

## The list

| Path | Upstream | Why we need it | Licence (code / media) |
|------|----------|----------------|------------------------|
| `luanti/` | https://github.com/luanti-org/luanti | **The** engine reference: `doc/lua_api.md` (~12,700 lines) plus the C++ whenever the docs are silent — mapgen order, biome selection, noise, nametag rendering, punch handling. Checkout is 5.17.0-dev | LGPL-2.1+ / CC BY-SA |
| `minetest_game/` | https://github.com/luanti-org/minetest_game | Minimal base game; `mods/default` is the origin of our node/tool palette and of the schematics we place | LGPL-2.1+ / CC BY-SA 3.0 |
| `mobs_redo/` | https://codeberg.org/tenplus1/mobs_redo | The mob engine we vendored and patched (`mods/ENTITIES/mobs`, 20 GRUG PATCH sites — VENDOR.md) | MIT |
| `VoxeLibre/` | https://git.minetest.land/VoxeLibre/VoxeLibre | Best architecture reference (XP, villager trading, map rendering, modpack structure) **and** our largest mob-media source via `mods/ENTITIES/mobs_mc` | GPL-3.0+ / CC BY-SA 4.0 |
| `Lord-of-the-Test/` | https://github.com/minetest-LOTR/Lord-of-the-Test | Best faction reference (privileges, ally matrix, faction-aware mob AI, traders); source of the bandit/guard skins | LGPL-2.1 mesh, skins CC BY-SA 3.0 |
| `animalworld/` | https://github.com/mt-mods/animalworld | Mob models: hyena, zebra, eagle, leopard→panther, cobra→serpent, crocodile, monkey→ape. Also holds `Crab.b3d`/`Hermitcrab.b3d`, which would close the deferred Shore Crab (`biomes_mobs.md` §8.3) | MIT code **and** media (`LICENSE` states both) |
| `animalia/` | https://github.com/ElCeejo/animalia | Mob models with the best animation quality: reindeer→stag, song bird→gull/crow, and the un-imported bat/frog/rat/owl/cat/fox roster. Built on the creatura API, so we asset-harvest rather than port | MIT |
| `mobs_monster/` | https://codeberg.org/tenplus1/mobs_monster | Spider (climbing) and stone monster→golem | MIT / spider CC BY-SA 3.0, golem WTFPL |

Rejected sources and the reason are recorded in
[`docs/research/assets/mobs_animals.md`](research/assets/mobs_animals.md) —
notably **paleotest** (code-only GPL, no media statement → the Raptor became
the Jungle Lynx) and **water_life** (CC BY-NC-SA, incompatible).

## Rules when using them

- **Never change anything inside `reference_projects/`.** A dirty submodule
  is a lie about what a citation refers to.
- Before importing any media, verify the licence **in the source repo** per
  file (LICENSE/README/credits), not from ContentDB — ContentDB metadata has
  been wrong in this project's own history. Record the file, the author
  chain, the exact licence and the **upstream commit** in the owning mod's
  `LICENSE-media.md`.
- Imported meshes must be **animated**. A static mesh slides instead of
  moving and reads as broken; if the only available model has no
  `ANIM`/`BONE`/`KEYS` chunks, pick a different source rather than shipping
  it (this is why the Lord-of-the-Test rat was rejected in favour of an
  animalia model).
