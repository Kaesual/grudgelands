# Round 40 — Combat feel: cooldowns, animations, Charge, particles

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the user's four
suggestions (taken from a friend's experimental build), a read-only
research pass and the user's answers of the same day; revised after an
independent Opus review (verdict "ready after fixes", every finding checked
at the cited lines); a focused re-review (fresh Opus context, "ready after
fixes", no High) is folded in; approved and started on the user's "go"
(2026-10-06). Status: **complete locally on 2026-10-06, not pushed; GUI
test open** ([completion and GUI checklist](#completion-2026-10-06)).

The round makes combat read better: a cooldown overlay on the skill icons,
better character animations, Charge as a real dash, and particle effects
for player skills, bosses and mob specials. **Wave 1 builds no game
feature**: it prepares pages and a GUI probe the user accepts first; wave 2
implements what the user picked. Sounds are not part of this round (§2.7).

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| V1 | Cooldown overlay preview page | 1 | page | — |
| V2 | Animation preview page (three.js on the R39 glb, pose table) | 1 | page + data | — |
| V3 | Particle proposal page: player skills, bosses, mob specials, server cost per effect | 1 | page | — |
| V4 | GUI probe mod: Charge variants, cooldown overlay on the real hotbar | 1 | probe (tools only) | — |
| R | `character_anim` as a read-only reference project | 1 | docs (coordinator) | — |
| CD | Cooldown overlay in game | 2 | code | V1 and V4 accepted |
| PX | Particle helper, `grug_particle_scale`, player-skill effects | 2 | code | V3 accepted |
| PM | Boss and mob-special effects | 2 | code | PX merged |
| CH | Charge as a dash | 2 | code | V4 accepted |
| AN1 | Animations: baked pose clips and their triggers | 2 | code + model | V2 accepted |
| AN2 | Head look | 2 | code | V2 accepted, AN1 merged |
| D | Round documentation | 3 | docs | last merge |

Wave 2 starts per topic when the user has accepted that topic's page or
probe; topics without acceptance do not start. Merge order in wave 2: CD,
PX, PM, CH, AN1, AN2, then D (shared files in §7).

Estimates (unmeasured, for planning only): V1 2–3 h, V2 4–6 h, V3 4–6 h,
V4 3–4 h, R under 1 h; CD 3–4 h, PX 4–6 h, PM 4–6 h, CH 4–6 h, AN1
6–8 h, AN2 2–3 h, D 2 h; each code lane plus its review.

## 2. Rulings

The user (2026-10-06):

1. **Cooldown display:** a skill on cooldown is covered with 50 % black;
   the cover clears clockwise like a clock hand; the remaining time sits in
   the middle of the icon, without decimals and without a unit: above
   60 s the minutes rounded up (`5m` from 5:00 down to 4:01, `2m` at 1:01),
   from 60 s down the seconds rounded up (`60`, `59` … `1`). The cover is
   drawn from pre-rendered frames in **5° steps (72 frames)**; the number
   of frames is fixed by the angle step, never by the cooldown's length
   (§3.1).
2. **Animations:** `character_anim` (appgurueu, MIT) goes into the
   reference projects; the animations that fit are picked on a preview
   page and rebuilt in our own code; missing ones are added. The proposal
   list (§4.1 V2) is accepted. The website does not need the new clips
   (it shows one pose and the assets must stay small); a website head that
   follows the mouse is optional and done only if it is nearly free.
3. **Charge:** damage, stun and the 15 rage land **on arrival**, not at
   the cast; a dash that ends without reaching the target (a miss) still
   spends the cooldown and gives nothing (Charge has no cost). The warrior
   may move at a fast, constant speed; an accelerating camera is not
   required. Whether the `Body` lead (model ahead, camera following) ships
   at all, and under which conditions (for example a minimum charge
   distance, none when an obstacle stops the dash), is decided by lane CH
   after the V4 probe, by how it looks; first person must look good too.
4. **The requested player-skill effects:** Ice Nova shoots a fast ring of
   particles out around the mage; Fireball splashes fiery particles on
   impact; Smite shows no projectile — yellow-white "holy" particles appear
   above the mob and slam down onto it; Mighty Blow leaves a trail of red
   particles diagonally in front of the warrior that does not move and
   vanishes after a short moment; an arrow shot by a skill trails
   particles. Later web tests use the scale below to find the web limit.
   For every other skill the coordinator designs the proposal on the V3
   page; the user accepts it before PX implements it. **Strike gets no
   particle effect.** A skill's effect fires only when the real skill
   fires — a cast that succeeded, a proc that fired — **never on the
   Strike fallback** a skill on cooldown or without charge falls back to
   (`grug_abilities/init.lua:1344-1347, 1442, 2215-2218`); PX's fixture
   checks it.
   **Particles, one system for everyone:** one server-wide scale,
   `grug_particle_scale`, applies to every client; **no per-player
   amounts, no per-player toggle, no web-client detection**. The scale
   exists to correct the amounts later if web tests show problems.
5. **Particle cost is explained per effect:** the proposal page states the
   expected server cost of each effect (for example twenty players in PvP
   in one zone); every complex effect comes with at least one simpler
   variant, with why it is simpler and its estimated saving. **Measured
   numbers are server-side only**, never client frame rates (too much
   client variance; server performance is what counts now).
6. **Particle art:** this round uses simple single-colour particles. The
   coordinator proposes shape, colour and style per effect, and where art
   would clearly look better adds an optional art proposal (e.g. a
   snowflake for ice) for a later art order. Suitable reference-project
   sprites with a clean licence (§3.5) may be used already this round,
   each with its licence row and `CREDITS.md` entry. Bosses and mobs with
   special skills get proposals too.
7. **Sounds are out of this round** (Smite's sound included): the round is
   big enough and sounds are easy to replace later.
8. **Routing:** Claude coordinates; Opus implements and reviews; textures
   as an art order later.

9. **The overlay covers the hotbar only.** Skills are cast from the hotbar,
   so a skill in a bag or in the open inventory shows no cooldown; the
   wear bar is removed everywhere (no second display path).
10. **Charge distances:** the cast range stays 12 m (`kits.lua:324`, plus
    the elves' ranged bonus, because Charge is not a melee skill). The hit
    on arrival counts within the existing `CHARGE_REACH` of 3 m from the
    target (`grug_abilities/blink.lua:214-216`: melee reach, the Strike
    range; the destination is already chosen within it, preferably 1.3 m
    in front of the target).
11. **Hits during the Charge dash** reach the warrior: the carrier
    forwards a punch to its rider, so the dash grants no immunity
    (coordinator default after the re-review; the user may overrule).
12. **Particle cost is a deterministic model** (§8 answer 1): counts ×
    serializations × receivers, packet sizes derived from the engine's
    serialization format, the Lua call cost measured headless, every
    number marked as an estimate. A measurement with real clients under
    Xvfb runs only if a number later looks critical.

### Wave 1 picks (the user, 2026-10-06)

13. **Cooldown overlay (V1):** `N3 B1 P1 F0 U1`: the number as image digits
    that scale with the icon; the cover darkens the whole square (P1); no
    ready signal; the update pass every 0.1 s, writing only on a visible
    change (frame or number).
14. **Poses (V2):** `cast1=A cast2=B swing=B bow=A block=B charge=B
    flinch=A head=H1` from `tools/r40_an/poses.json` (reviewed: the frame
    conversion is exact). H1 is the pitch-only head look (one Head override,
    5° steps, a rate cap of about four updates per second per player); the
    user preferred H2 at first, then dropped it as not worth its extra
    overrides. Every pose switch blends over about 0.1–0.15 s (the arms would
    otherwise start in the wrong place); keeping the walk phase with
    `play_animation`'s `start_frame` on top is AN1's call by look. The web
    build is Luanti 5.17.0 as well.
15. **Particles (V3):** take all, the main proposal of every card, single
    colour, no art sprite yet. The accepted catalogue is
    `tools/r40_v3/effects.py` (emitters in engine terms; `data.json` its
    costs). Its review fixed the model: an `attract` strength is a rate (speed
    = strength × distance, set at birth; with `die_on_contact` the life is at
    most 1/strength), a spawner's `radius` gives a disc denser at the edge,
    not a ring, so exact rings that mark a radius are single particles placed
    by Lua; a spawner costs about 0.67 KB per receiver whatever its amount,
    single particles 10–40 B each compressed; `grug_particle_scale` lowers
    spawner amounts (what clients draw) but not their bytes.

16. **Charge after the probe (V4):** carrier A with the planned path at
    **24 m/s**; every course worked except `uphill`, where the dash stops
    about two nodes short of the target on the last stair (a bug for CH).
    Before a self-built wall with a one-node hole the warrior stops cleanly.
    **Holes** (the user, 2026-10-06): a hole is jumped over in one hop when
    the hop is at most **4 nodes** wide and the landing lies at most one node
    above the takeoff; the hole's depth does not matter, only the hop's
    width; shallow dips are jumped too. Liquids count as air: the hop may
    cross them, but it never lands in a liquid. Otherwise the warrior stops
    at the rim, which counts as a miss (the cooldown is spent, §2.3).

17. **Charge, after lane CH** (the user, 2026-10-06): a dip wider than four
    nodes whose ground is in reach is followed (down, run, up), like
    terrain; only a real hole stops the dash at the rim. The hole width is
    measured along the dash line (a hole crossed diagonally is wider). The
    hold of about 0.34 s after the arrival (it lets the client's drawn
    carrier catch up, which fixed the uphill stop short) is accepted, if a
    short check finds nothing shorter that keeps the uphill fix.

## 3. Research results (2026-10-06, verified at the cited lines)

### 3.1 Cooldown overlay

- Today the cooldown is the skill item's **wear bar**: the helper
  `grug_abilities/init.lua:889-924` and the ticker `init.lua:2325-2410`
  (32 steps, one shared 0.5 s pass). Every step is an inventory write; the
  engine re-sends the modified lists (incremental per list,
  `reference_projects/luanti/src/inventory.cpp:941`).
- The hotbar's slot geometry is fixed engine arithmetic: slot size
  `floor(48 × density + 0.5) × hud_scaling`, padding `size / 12`, pitch
  `size + 2 × padding` (`src/client/hud.cpp:138-145, 235-296`); HUD
  offsets and image scales use `hud_scaling × density`
  (`hud.cpp:496-506`). `grug_core.hud_layout` already anchors the bar
  column on it (`HOTBAR_TOP = -62`).
- So each hotbar slot carries two HUD elements: an image (a pie frame at
  50 % black, z above the hotbar) and a centred number. A `hud_change` is
  a small packet with no inventory involved; a write happens only when the
  frame or the number changes. Whether this is cheaper than the wear bar
  overall is **unmeasured**: CD reports before/after numbers.
- **Frames:** the frame shows the elapsed *fraction*, so one set serves
  2 s and 10 min alike. 72 frames: at a 48 px icon a 5° step moves the
  hand's tip about 2 px; short cooldowns are capped by the update pass
  (about 10 writes per second at most). 72 small two-colour PNGs are a few
  tens of KB of media, sent once. Precedent: the bow's draw ring
  (`grug_abilities_draw_ring_00..15.png`).
- **Number** (§2.1): `s = ceil(remaining seconds)`; `s > 60` shows
  `ceil(s / 60)` and `m`, otherwise `s`.
- **Layout risks** (V4 tests them): rounding drift between the integer slot
  size and the float HUD scale at odd `hud_scaling` values; the engine
  splits the hotbar into two rows when it is wider than
  `hud_hotbar_max_width` (`hud.cpp:806-821`), which depends on the window
  width (the server can read it with `core.get_player_window_information`,
  already used in `grug_map/minimap.lua:307`); a hotbar item count other
  than 8; **HUD text follows the font size, not `hud_scaling`**
  (`hud.cpp:387-391`), so a text number does not grow with the icon —
  image digits are the alternative; HUD text has no outline (a shadow
  needs a second element). Cooldowns run from 2 s to 300 s.

### 3.2 Animations — reimplement selected ideas, do not vendor

- `character_anim` (commit `61b62ae`): code MIT per its Readme (no LICENSE
  file in the repo), hard dependency on `modlib` (MIT). It freezes the
  engine animation and **re-poses every bone in Lua every server step for
  every player** with the deprecated `set_bone_position`
  (`init.lua:366-379`); the engine then re-sends all of the object's bone
  overrides (`src/server/unit_sao.cpp:138-144`). It also swaps any
  `*character*` model through `dynamic_add_media` and monkeypatches
  `PlayerRef`. Against the 100-player target and our "no pass handles
  every player in one step" rule, it is not vendored.
- What it shows well: the head follows the look pitch (and yaw relative to
  the body, clamped), the body turns with a lag, the right arm points
  along the look while acting.
- **Our model** `grug_visuals_character.b3d` is **generated** by
  `tools/r33_c3/gen_cloak_model.py` (`--check`) from player_api's
  `character.b3d`: it adds the Cloak bone, keys the cloak's swing per
  named range and runs a leg/cloak clearance check over all frames. Root
  bone `Body`, children Head, Arm_Left/Right, Leg_Left/Right, Cloak.
  Animations: stand, sit, lay, walk, mine, walk_mine
  (`player_api/init.lua:4-21`), copied into our registration at
  `grug_visuals/apply.lua:296-305`; no cast, swing, block or draw pose.
- **Clips are whole-body:** one animation track per object, so a cast clip
  played while walking freezes the legs. Each pose needs a walking variant
  (precedent `walk_mine`) or must be an arm bone override instead.
- **The pose hook:** player_api's GRUG PATCH hook is polled every step and
  the first answer wins (`player_api/api.lua:181-196, 227-228`); the Scout's
  bow draw already uses it (`grug_abilities/scout.lua:28-34`). A pose is
  therefore "the state the hook returns while the action runs". The hook
  returns only a name: `set_animation` then loops (`loop = nil` becomes
  true) and ignores a repeated name (`api.lua:124-134`). Held poses (cast,
  bow draw, block, Charge lean) fit; **one-shots** (overhead swing, flinch)
  would loop while held and not restart on a second Mighty Blow, so they
  need a return to the base pose in between or a GRUG PATCH that lets the
  hook pass loop and restart.
- Cheap paths: (a) **new clips** baked into the generated model, appended
  after frame 219 so every existing range stays put; they play on the
  client at no per-step cost; (b) **one relative bone override** on Head
  for the look (`set_bone_override` with `interpolation`), written only on
  a real change, spread over slots.
- **Website:** the glb keeps its two clips (`build_glb.py` exports only
  its `CLIPS` list), so the asset does not grow; appending frames leaves
  stand and walk unchanged. A mouse-following head needs no asset: the
  website rotates the glb's `Head` node itself. AN2 only documents the
  bone, its clamp angles and the axis convention in
  `tools/web_data/model/README.md` (the glb mirrors z).

### 3.3 Charge dash — possible with a stock client

- Today: `kits.lua:298-353` computes a destination 1.3–3 m in front of the
  target (`blink.lua:213-258`, line of sight required), calls `set_pos`,
  and deals damage and the 1.5 s stun at the cast. Casting while mounted
  is refused (`init.lua:1473`).
- **Two ways to move the warrior:**
  - **(A) A carrier:** the player is attached to an entity that the
    server moves at constant speed to the destination, then detached.
    Constant, fast speed and an exact stop (§2.3); the server owns the
    path; the player cannot steer; the engine skips the movement anticheat
    while attached (`src/server/player_sao.cpp:643-646`); the client
    smooths the entity's motion (`content_cao.cpp:81-93, 1115-1117`) and
    the camera follows the parent (`camera.cpp:325-326`). No physics
    override is needed. The carrier's contract (precedent: the mount
    attach and dismount in `grug_mounts/entity.lua:148-190`):
    - **Visible with a blank texture, never `is_visible = false`:** an
      invisible object gets no scene node on the client
      (`content_cao.cpp:583-584`), so the rider would not follow it (the
      mounts' visual entity uses `grug_mobs_blank.png`,
      `grug_mounts/entity.lua:573`). `static_save = false`,
      `pointable = false`; it removes itself without a rider (pattern:
      the orphan check in `grug_visuals/apply.lua:63-71`), so a logout or
      crash leaves nothing behind; if it vanishes, the engine detaches the
      player at the last good position (`player_sao.cpp:235-241`).
    - **The stop is clamped in the carrier's own `on_step`** (one server
      step at dash speed covers metres); the arrival check runs there too.
    - **Terrain:** a non-physical carrier passes through nodes
      (`luaentity_sao.cpp:188-190`) and the destination ray runs eye to
      eye (`blink.lua:224-227`), so on a slope the feet path can cut the
      ground; a physical one collides but stops at a one-node step. CH
      picks the mode (or a path check) after V4's uphill, step and ledge
      cases.
    - **Option: a planned path** (the user's idea, 2026-10-06). The server
      samples the ground along the line once at the cast and plans the
      carrier's path as segments: straight runs on level ground, a
      ballistic hop over a step, a slope or a low obstacle (uphill the
      Charge then looks like a leap, which the user likes), refused or cut
      short where no path fits. Each segment is one velocity and one
      acceleration on a non-physical carrier: the client extrapolates
      exactly `pos += v·dt + ½·a·dt²` (`content_cao.cpp:1122-1123`), so an
      arc is smooth on every client without per-step updates; VoxeLibre's
      arrows fly this way (`vl_projectile/init.lua:51-52`). The carrier's
      `on_step` switches segments and clamps the end. This also answers
      the terrain point above. Limits for V4 to show: the longest hop and
      the highest step the path accepts, how a hop reads in first person,
      and the planning cost (one bounded sample per cast).
    - **Hits during the dash:** mobs_redo's melee and the Kraken's drag
      act on the parent (`mobs/api.lua:3119`, `kraken.lua:128`); the
      carrier forwards them to the rider (§2.11). While attached the
      engine ignores `set_pos` (`player_sao.cpp:357-360`), so knockback
      and pulls do nothing, and the dash is cancelled before any travel's
      `set_pos` (`grug_home/travel.lua`).
    - **No mount state:** the carrier never sets `_grug_rider`, which the
      mounted checks key on (`grug_core/combat.lua:37-58`,
      `combat_ray.lua:395-401`), so the arrival hit is not refused; it
      never sets player_api's `player_attached`, which would skip the pose
      hook and the Charge lean (`player_api/api.lua:209-213`).
    - Fall damage comes from the client's collision speed change, and the
      attached client holds zero speed (`localplayer.cpp:545-548`), so the
      dash adds none. Unverified: a visible snap on detach (the client
      keeps its smoothed position).
  - **(B) A push:** `add_velocity` raises the anticheat allowance and sends
    the speed at once (`l_object.cpp:1243-1246`, `player_sao.cpp:625-635`);
    the client brakes linearly toward the input velocity, scaled by the
    physics override's `acceleration_*`, its `speed` and the ground's slip
    (`localplayer.cpp:700-731`), so the player starts fast and slows down.
    Stopping at the destination needs a high braking override for about a
    second, but `grug_core/movement.lua` (the one physics writer) has no
    acceleration axis: modifiers carry speed and jump, `write` sets every
    `acceleration_*` to 1 (or to the hard-stop value while speed is 0) and
    its skip test compares only speed, jump and gravity
    (`movement.lua:200-225`). B would need that axis and a `v0`
    from the effective braking; a held key or a slow changes the distance.
  - (A) is the proposed default; V4 shows both.
- **"Model first, camera follows" (third person and other players):** the
  camera sits at the player's (or carrier's) real position; nothing
  server-side lags it. A relative position override on the `Body` bone
  moves only the drawn model (the player's own third-person model too,
  `content_cao.cpp:716-731`). The first override of a bone snaps
  (`content_cao.cpp:1774-1781`), so it starts from an epsilon (an
  upstream-workarounds entry if it ships); overrides go out once per server
  step (`unit_sao.cpp:138-144`), so stages are one step apart. Optional
  (§2.3).
- **First person:** the engine does not draw the local player's own model
  in first person (`content_cao.cpp:1935-1945`), so the `Body` lead is
  seen only in third person and by others. First person feels the dash as
  the camera's own motion; a short FOV kick (`set_fov(mult, true,
  transition_time)`, server-controlled and blended by the client,
  `lua_api.md:9213-9220`) is the proposed first-person accent.
- **Arrival:** a throttled check over dashing players only. Within
  `CHARGE_REACH` of the target → the target's ObjectRef is re-fetched,
  `grug_pvp.can_harm` asked again, then damage, stun and rage; the dash
  ends without reach (wall, ledge, a target that moved) → a miss (§2.3).
  The dash is cancelled by a stun or root on the warrior, death, logout or
  travel.

### 3.4 Particles — one system, cost per effect

- Smite already has no projectile: it draws a line of single particles
  and a burst (`kits.lua:793-794`); the new effect replaces both.
- Hooks: Fireball `on_hit` (`kits.lua:529`), Ice Nova's burst
  (`kits.lua:698`), Mighty Blow's landed-swing callback (`kits.lua:392`),
  skill arrows in `grug_projectiles` (`spawn_one` after `add_entity`,
  opt-in per skill).
- Engine (5.17.0-dev): spawners take tweens, `attract` (point, line, plane;
  negative strength pushes out; `die_on_contact`), `radius`, `drag`,
  `jitter`, blend modes. The repo comments claiming "`radius` is not a
  particlespawner field" (`kits.lua:165`, `combat.lua:1016,1530`,
  `telegraph.lua:60`) are wrong for this engine (`l_particles.cpp:233`).
- **Server cost model** (`src/server.cpp:1656-1784`):
  - *A spawner* is serialized and sent once **per receiving client**,
    synchronously inside the Lua call; the client creates the particles.
    Spawners with `0 < time ≤ 1 s` that are not attached go only to
    players within `max_block_send_distance`; **attached spawners,
    spawners longer than 1 s and endless ones (`time = 0`) go to every
    player on the server** (`server.cpp:1739`).
  - *Single particles* (`add_particle`) are queued; in the server step,
    for **every player on the server**, every queued particle gets a
    distance check, every particle in range is serialized for that player,
    and each player's batch is zstd-compressed (clients from protocol 50
    on; older ones get one packet per particle, `server.cpp:1675-1680`).
  - So a ring of 32 single particles costs about 32 serializations per
    receiver against one for a spawner; a skill arrow's trail as an
    attached spawner reaches every player of the server, as a short
    unattached spawner along the flight path only the nearby ones. Packet
    sizes are **unmeasured** (derived from the serialization format).
- **Measuring on the server is hard:** with no connected player the server
  sends nothing (`server.cpp:1716-1718`), and the stock client refuses to
  start without a video driver (`src/client/renderingengine.cpp:143`), so
  a headless run cannot have receivers; the cost is a model (§2.12).
- **The budget "hundreds, never thousands" was never measured.**
- **`grug_particle_scale` semantics** (PX defines and documents them):
  spawner amounts and single-particle loops (rings) both scale, with a
  floor of one particle per effect; lifetimes and shapes stay.

### 3.5 Reference textures and boss/mob gaps (research pass, 2026-10-06)

- **Usable sprites:** VoxeLibre's snowflakes
  `textures/weather_pack_snow_snowflake1.png` and `…2.png` (5×5, white,
  tintable) — CC BY-SA 3.0 by TeddyDesTodes as the exception recorded in
  `VoxeLibre/mods/ENVIRONMENT/mcl_weather/README.md:32-36` (the licence row
  cites that exception, not the folder default) — for the mage's ice
  skills and the Ice Dragon; draconis's ice motes
  (`draconis_ice_particle_{1,2,3}.png`, 3×3), fire mote, smoke strip (8×32,
  4 frames) and animated fire (16×128, 8 frames), MIT like the draconis
  assets we already ship; LOTT's `lottfarming_smoke_ring.png` (fishyWET,
  CC BY-SA 3.0, `lottfarming/license.txt` "Everything else") for ring
  shapes. We already ship tintable `default_item_smoke` (CC0) and the
  mobs_redo particles, enough for a single-colour first pass.
- **Not used:** VoxeLibre's crit, totem, effect and smoke sprites come
  from a resource pack made for a commercial game; using them would copy
  that game's particle look (AGENTS.md "never copy assets 1:1"). The V3
  page lists them as rejected.
- **Weakest feedback today, in order:** every King/General signature move
  (no particles at all; `royal_signature`, `grug_mobs/bosses.lua:438-476`);
  the elite cone hit itself (`telegraph.lua:95-148`: the wind-up has
  smoke, the hit nothing); the rift pulse wind-up, which marks r1.5 for an
  r6 blast (`rift.lua:306-358`); the dragon breath projectile, still a
  tinted rock sprite (`boss_dragons.lua:403-446`); web, poison, root and
  ooze auras (`verbs.lua:149, 257, 559-583`, `night_families.lua:205-221`);
  pounces and the Kraken's drag; Oerkki's blink origin and summon puffs.
  The storm dragon's lightning ring and gust ring are 32–40 single
  particles each (`boss_dragons.lua:617-629, 774-786`), candidates for one
  spawner.

### 3.6 A refuted side finding

The research suspected that Mighty Blow's cleave gets the swing context
instead of an action id (`kits.lua:392`, `init.lua:1210-1211`). Refuted:
the swing context **is** the swing's action id by design
(`init.lua:1180`; the contract at `grug_core/combat.lua:1383-1386`: one id
per action, consumers deduplicate on it). Nothing to fix.

## 4. Lanes (goals; the briefs add file facts)

### 4.1 Wave 1 — acceptance material

- **V1 Cooldown page:** a mock hotbar with the real skill icons
  (`grug_abilities_skill_*.png`) at 1×, 1.5× and 2× scale; the overlay
  running live with the 72 frames and the §2.1 number for short and long
  cooldowns; variants: number as text (plain, with shadow) or as image
  digits that scale with the icon, a short flash when ready; a charge
  skill (Hamstring, `charge = 6`) with the same overlay. The page names the
  pick ids.
- **V2 Animation page:** loads `grug_visuals_character.glb`; a pose table
  (`tools/r40_an/poses.json`) in the engine's b3d frame (the page converts
  through the glb's z-mirror), which the page plays and AN1 later bakes,
  so what the user accepts is what ships. Proposals: head look (pitch and
  yaw follow), cast one hand, cast two hands (heal, Ice Nova), overhead
  swing (Mighty Blow), bow draw and hold, block (Hold Ground, shields),
  Charge lean, a light hit flinch; each standing and walking (§3.2), next
  to the current stand/walk and with a sample of `character_anim`'s head
  and arm behaviour for comparison. One pick per pose (take, variant,
  drop).
- **V3 Particle page:** one animated sketch per effect (canvas, side and
  top view), for the five requested player skills (Ice Nova ring,
  Fireball splash, Smite holy fall, Mighty Blow slash trail, skill arrow
  trail), further player skills where an effect clearly helps, every boss
  skill and every mob special skill (§3.5). Per effect: shape, colour and
  style, count, lifetime, how it is built (spawner or single particles,
  who receives it), the server cost per §2.12 for one cast and for twenty
  players in one zone, and the effect at a reduced `grug_particle_scale`.
  **Every complex effect has a simpler variant** with why it is simpler
  and its estimated saving. Optional art proposals with the matching
  reference textures and licences; where a §3.5 sprite fits, the sketch
  uses it.
- **V4 Probe:** a probe mod under `tools/r40_probe/` (tools only, merged to
  main like Round 39's glTF probe; the user copies it into a test world),
  never shipped. Chat commands: the Charge variants on a target dummy
  (today's teleport; carrier A, non-physical and physical, and with the
  planned path of §3.3; push B with a
  temporary override written by the probe only; each with and without the
  `Body` lead and the FOV kick; a short and a long distance; into a wall,
  uphill, over a one-node step, off a ledge; a mob hitting the warrior
  mid-dash), each printing when the server saw the arrival; the cooldown overlay on the real hotbar (two
  `hud_scaling` values, a resized window, text and image-digit numbers).
  Server-side timings only. Its report form lists what the user looks at,
  desktop and web.
- **R Reference:** `character_anim` as a submodule under
  `reference_projects/` with its row in `docs/reference_projects.md`
  (licence: MIT by its Readme, no LICENSE file).

### 4.2 Wave 2 — implementation of the picks

- **CD:** the overlay per §2.1, §2.9 and the V1/V4 picks, in
  `grug_abilities`: a generator for the 72 pie frames (`--check`; image
  digits if picked), per-slot HUD elements on the hotbar following the
  item count and the two-row split, updates only on a visible change from
  a throttled pass that spreads players over slots and only visits
  players with a running cooldown, slots tracked when skills move; the
  wear bar is removed for cooldowns and charges. Fixture for the frame and
  number arithmetic and the slot tracking; before/after numbers for the
  ticker.
- **PX:** one helper in `grug_core` that every effect uses: it applies
  `grug_particle_scale` (`settingtypes.txt`, default 1.0) per §3.4, keeps
  lifetimes, sends to everyone in range the engine's way, and is the one
  place reviews check the budget. The player-skill effects per the V3
  picks with single-colour particles or §3.5 sprites (licence rows,
  `CREDITS.md`); the stale `radius` comments fixed; existing effects moved
  onto the helper where that is a one-line change. Reports the per-effect
  and busy-fight totals.
- **PM:** the boss and mob-special effects per the V3 picks, on PX's
  helper, in the priority order of §3.5; the dragons' ring loops become
  spawners where V3's variant is picked.
- **CH:** Charge as a dash per the V4 pick and §2.3: the movement (A, or B
  with an acceleration axis in `movement.lua` through its combine, write
  and skip paths; A per the carrier contract in §3.3), the arrival check
  and cancellations per §3.3, damage,
  stun and rage on arrival, the miss rule; the `Body` lead and the FOV
  kick as decided after V4; refusals otherwise unchanged; fixture for the
  arrival and miss rules.
- **AN1:** the accepted poses baked from `poses.json` as a stage of
  `tools/r33_c3/gen_cloak_model.py` (players only), each new range with a
  cloak rule and through the clearance check, appended after frame 219;
  the ranges registered in `grug_visuals/apply.lua` (not in vendored
  player_api, whose table NPCs use); held poses through the player_api
  pose hook while the action runs, alongside the Scout's bow draw;
  one-shots per §3.2 (a return to the base pose, or a GRUG PATCH passing
  loop and restart, recorded in VENDOR.md).
  `gen_cloak_model.py --check`, `build_glb.py --check`, `check_glb.py`
  and the exporter's `--check` pass with an unchanged glb.
- **AN2:** the head look as one relative Head override, written only when
  the quantized look angle changes (a step of a few degrees, so a steady
  look sends nothing), from a pass spread over slots; before/after numbers; the
  website head note in the model README.

### 4.3 Wave 3 — D

The plan's completion, STATUS, AGENTS pointer, ROADMAP/BACKLOG (Smite's
sound and the particle art order as carry-overs), README, CHANGELOG
0.40.0, and `grug_particle_scale` where settings are documented.

## 5. Rules

- Stock clients only; no client mod; all logic server-side.
- Particle budget: every spawner bounded in amount and lifetime; every
  effect through the helper; performance numbers are server-side.
- `grug_core/movement.lua` stays the only physics writer in the game (the
  V4 probe's temporary override is a tools-only exception for the test).
- **No pass handles every player in one step:** the CD overlay pass, the
  AN2 head-look pass and the CH arrival check visit only players with
  something running and spread them over slots.
- A change to the player model or its animations reruns
  `tools/r33_c3/gen_cloak_model.py --check`,
  `tools/web_data/model/build_glb.py --check`, `check_glb.py` and the
  exporter's `--check`.
- A new engine workaround (the bone-override epsilon) gets its entry in
  `docs/technical/upstream-workarounds.md`.
- Every new sprite: a `LICENSE-media.md` row; attribution licences also in
  `CREDITS.md`.
- No world-generation change: no seed fleet.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates);
CD, CH, PX and AN2 report server-side before/after numbers for the
touched hot paths (the cooldown pass, the ability cast and arrival check,
a busy fight's particle sends, the head-look pass). GUI checklist (desktop
and web): the overlay at two `hud_scaling` values, in a narrow window and
with skills moved between slots; each new animation standing and walking,
in first and third person and from a second client; Charge on flat
ground, uphill, against a wall, off a ledge, in PvP, short and long, in
first and third person; each particle effect, and `grug_particle_scale`
at 1.0 and reduced.

## 7. Orchestration notes

- Start state: main `d018d866`, equal to origin/main: the user has pushed
  Rounds 36–39. STATUS and the AGENTS pointer still say "not pushed"; the
  post-push status step (round workflow §4) runs before wave 1 starts, as
  a small coordinator docs commit.
- Process budget: at most 8 Lua processes at once across all lanes and
  reviews (AGENTS.md); engine runs only through `tools/luanti_headless.sh`
  with its isolation; no seed fleet.
- Shared files: `grug_abilities/init.lua` (CD, CH), `kits.lua` (PX, CH,
  AN1), `scout.lua` (AN1, the bow-draw hook), `grug_projectiles/init.lua`
  (PX), `grug_core/combat.lua` and `grug_mobs/telegraph.lua` (PX for the
  stale `radius` comments, PM for the elite cone hit), the other
  `grug_mobs` boss and mob files (PM), `grug_core/movement.lua` (CH, only
  if B), the generated model and `grug_visuals/apply.lua` (AN1, AN2). Merge order CD, PX, PM, CH, AN1,
  AN2; each later lane merges main before its review.
- The V4 probe reaches the user through main (tools only) and the user's
  test world; the coordinator syncs main as usual.
- Decided during the round: the V1–V4 picks (the user, on the pages and
  after the probe); A or B and the `Body` lead (lane CH after V4, §2.3).
- Routing per §2.8. The coordinator builds V1–V3 itself; the user's
  acceptance decides their look. Two parts carry numbers or data that
  ship and get an independent Opus review before the page goes to the
  user: V3's server-cost model (against `server.cpp`) and V2's frame
  conversion between `poses.json` and the glb. V4 is an implementer lane
  with review.

## 8. Open questions for the user

None. Answered on 2026-10-06: the particle cost model (a) over a client
measurement (§2.12); the overlay on the hotbar only (§2.9); the Charge
distances clarified (§2.10). §2.11 is a coordinator default.

## Completion (2026-10-06)

Every lane is merged on main; lane D (this section and the status
documents) follows. Nothing of Round 40 is pushed (origin/main is
`d018d866`, the round's start). Main's first-parent line: the plan
(`e3527ea1`), the post-push status step (`93371711`), lane R (`19782f49`),
V2's pose table (`a7adb884`), V4 (`b93b3222`), the wave 1 picks with the
accepted particle catalogue (`5e7539db`), the Charge rulings after the
probe (`44859742`), PX (`a8b3f51e`), AN1 (`d96b615e`), CD (`9ecd7882`), PM
(`92f861d8`), CH (`4c3fbd5a`), the Charge rulings after CH (`0a74b347`),
CH's hold replay (`ec9e423b`) and AN2 (`bd52bbf4`).

Reviews, each by an independent Opus: V2's frame conversion OK after fixes
(exact); V3's cost model OK after fixes; V4 MERGE AFTER FIXES (one Medium,
the course restore on unloaded blocks, and Lows; fixed in `e60770cd`); PX
MERGE (wording fixes); AN1 MERGE AFTER FIXES (one Medium, the posing
player's own third-person view, one Low, where the swing starts); CD MERGE;
PM MERGE; CH MERGE AFTER FIXES (one Medium, where a cancelled dash lets the
warrior go, and Lows; fixed in `e748d1d7`); AN2 MERGE (its Medium, the
integration with CH's `Body` lead, done after CH's merge in `ef204ded`).
Every code lane ended with a smoke boot (PASS) and a full fixture run (the
last lanes 116 of 116 before their final main merge); main's tree has
**119 portable fixtures** (112 at the start; new: `r40_probe`, `r40_px`,
`r40_an1`, `r40_cd`, `r40_pm`, `r40_ch`, `r40_an2`). No world generation
changed: no seed fleet, and an existing world is enough for the GUI test
(one check wants a new character, checklist item 1).

Round end: …

### Shipped, by lane

Wave 1 built no game feature; its pages and probe went to the user first.

- **V1 cooldown page** ([page](https://claude.ai/artifact/DrcQecqfPty3vbff2q59cB),
  coordinator): a mock hotbar with the real skill icons at three scales,
  the 72-frame overlay live with the §2.1 number, text and image-digit
  numbers, a ready flash, a charge skill. Pick in §2.13.
- **V2 animation page** ([page](https://claude.ai/artifact/Xnwi6XiKvbYiEvinsgZVD4),
  coordinator) and `tools/r40_an` (`make_poses.py`, `poses.json`,
  `--check`): twelve pose variants, the head looks H1 and H2 and a
  `character_anim` sample on the Round 39 glb, each standing and walking.
  Its review found the conversion exact (engine against page within 9e-15)
  and fixed the walking one-shots (they run to the walk cycle's end) and the
  held loop period (19 frames).
- **V3 particle page** ([page](https://claude.ai/artifact/FAqUhYazhHGvsHnaA5cJF8),
  coordinator) and `tools/r40_v3`: 46 effect cards (the five requested, 18
  further player-skill and proc cards, 14 boss and 9 mob cards), a simpler
  variant for every complex one, the ten existing looks it keeps, art
  proposals with their sprites and the rejected sprites; per card the
  server cost of one use and of twenty players in one zone from the model
  of §2.12 (a spawner
  about 671 B per receiver whatever its amount, a single particle 10–40 B
  compressed; headless Lua calls: a spawner 1.88 µs, 2.26 µs with
  `attract`, `add_particle` 0.60 µs).
- **V4 GUI probe** (`tools/r40_probe`, tools only, never shipped; its
  README holds the install steps and the report form): test courses, the
  Charge variants (teleport, ghost and physical carrier, the planned path,
  push) with the `Body` lead and FOV options, the overlay on the real
  hotbar; fixture 110 checks. Server-side numbers: the path planner 30–84
  µs on a table world, 136–469 µs on the courses (median 195 µs on natural
  terrain); the destination search 3–9 µs; the carrier 9–16 µs per step on
  average (worst 77 µs); the overlay pass with 8 cooldowns 1.1–1.3 µs
  (about 40 writes/s). The user's test fed §2.16; the overlay was accepted
  provisionally.
- **R** (`19782f49`): `character_anim` at `61b62ae` as a read-only
  reference project with its row in
  [reference_projects.md](../reference_projects.md) (MIT by its Readme).
- **PX particle helper and player-skill effects** (`a8b3f51e`;
  [combat_stats.md "Skill particle effects"](../design/combat_stats.md#skill-particle-effects)):
  `grug_core/particles.lua` (plays a catalogue effect, applies the scale,
  places exact rings, checks every registered effect's budget at load) and
  the catalogue `grug_core/particle_effects.lua`; the setting
  `grug_particle_scale` (*Combat*, default 1.0, 0–2, read at server start,
  at least one particle per emitter, 0 turns the helper's effects off);
  every player skill but Strike per its V3 card, one proc flash in a
  colour per proc, the critical-hit, absorb and level-up particles on the
  helper with their look; the stale `radius` comments fixed. Particles per
  use at 1.0: Ice Nova 64 (the most), Fireball 38, Smite 36, skill arrow 30,
  Mighty Blow 26, every other effect at most 40. Fixture 1,189 checks,
  among them the fallback rule on the real kits (Strike, a refused cast, a
  skill on cooldown, a prepared proc, a missed proc and a rolled-back arrow
  batch play nothing). Lua per use, headless (before → after): Ice Nova
  1.77 → 52.9 µs, Smite 11.0 → 4.8, Mighty Blow 1.75 → 4.1, Fireball's
  impact 0 → 4.8, Heal 1.76 → 2.15, a skill arrow 0 → 2.2, a crit 1.71 →
  1.89. **Busy fight** (`tools/r40_px/costs.py`, 20 players near, 100 on
  the server, estimates): at scale 1.0 401 KB/s out of the server, **20.1
  KB/s into each nearby player**, **about 2.6 ms/s main thread** (2.6–3.1
  run to run), 556 particles/s; at 0.5 19.6 KB/s and 279 particles/s; at
  0.25 19.3 KB/s and 147 particles/s (the scale cuts what clients draw, not
  the bytes, §2.15); before the round 8.3 KB/s per player for the skills
  that had particles.
- **AN1 poses** (`d96b615e`;
  [character_visuals.md §5c](../design/character_visuals.md#5c-poses-round-40)):
  `tools/r33_c3/gen_cloak_model.py` bakes the seven picked poses, each
  standing and walking, as 14 ranges after the base frames (engine frames
  221–484), each with its cloak rule and through the clearance check (the
  closest leg gap of a pose clip 0.43 model units, the base clips' 0.40);
  frames up to 220 byte-identical, the model 84 → 166 KB, the website's glb
  unchanged. `grug_visuals/poses.lua` and the pose clips in
  `grug_visuals/apply.lua`; a player_api GRUG PATCH: every switch blends
  over 0.12 s, the hook may pass loop and restart, walking clips keep the
  walk phase. Casts hold 0.6 s, Hold Ground's guard 1.0 s, the flinch at
  most once per 1.5 s. The pose hook's cost (`bench_hook.lua`, 100
  stand-ins, ns per player per step, before → after): standing 11.0 →
  11.3–12.1, walking 34.6 → 35.3–37.0, ten Scouts drawing 41.2 → 41.5–43.4,
  **within run-to-run noise**; ten in a held pose 42.3–44.5; no new
  globalstep.
- **CD cooldown overlay** (`9ecd7882`;
  [classes.md "The cooldown overlay"](../design/classes.md#the-cooldown-overlay)):
  `tools/r40_cd/gen_cooldown_textures.py` (`--check`) draws the 72 cover
  frames and the image digits (19 KB, own work, CC0);
  `grug_abilities/cooldown_hud.lua` and `cooldown_math.lua` put two HUD
  images per running slot on the engine's slot rectangles (the item count
  and the two-row split followed); one pass every 0.1 s over players with
  a running timer only, at most 100 per pass, writes only on a visible
  change; the wear bar no longer shows cooldowns or charges. Fixture 233
  checks. **Overlay against the wear bar** (Lua per pass, headless bench):
  one player with 8 cooldowns 17 → 2.6 µs; 100 players with one cooldown
  each 178 µs and 250 inventory writes/s → 161 µs (worst 417) and 1,196
  HUD writes/s; 100 players with four each 942 µs (about 1.9 ms/s) and 790
  inventory writes/s → 176 µs (worst 365, about 1.8 ms/s) and 3,533 HUD
  writes/s. A wear write re-sent the whole main list (about 4.7 KB); a HUD
  change is 40–100 B (estimate); the overlay writes no inventory.
- **PM boss and mob-special effects** (`92f861d8`;
  [biomes_mobs.md §3.1](../design/biomes_mobs.md)): every boss and mob card
  on PX's helper at its moment (the kings' signatures, the elite cone hit,
  the dragons, the Kraken, webs, poison, pounces, ambushes, auras, blinks,
  projectile impacts); fixture 453 checks. Per fight
  (`tools/r40_pm/costs.py`, 20 near, 100 on the server, scale 1.0,
  estimates): the ice dragon 23.2 KB/s out, 1.16 KB/s into each nearby
  player (1.21 before), 420 µs/s main thread; the storm dragon 16.9 KB/s,
  0.84 KB/s (0.79 before), 305 µs/s; the kings 0.35–0.89 KB/s per player
  (the Orc king's Cleave the most); an elite 0.13; the Kraken 0.35; the mob
  specials at most 0.27. Lua per occurrence, e.g. the lightning strike
  1.69 → 5.37 µs, the gust's release 1.95 → 44.8, the dive's slam 1.96 →
  55.2, Shatter's ring (new) 62.5.
- **CH Charge as a dash** (`4c3fbd5a`, review fixes `e748d1d7`;
  [classes.md §3, Charge](../design/classes.md#3-warrior-rage)):
  `grug_abilities/charge_path.lua` (the pure planner: runs and ballistic
  hops, the hole rule, liquids as air, never refuses, cut short at a rim)
  and `charge.lua` (the carrier, the arrival or miss in its own `on_step`,
  the cancellations through `grug_core.cancel_dash`, punches forwarded to
  the warrior, the 0.5 m `Body` lead on dashes of 3 m or more, the FOV kick
  ×1.1, the charge pose, the dust); refusals unchanged,
  `grug_core/movement.lua` untouched. Fixture 158 checks. Numbers (seed
  4242, 32 targets at 6 and 11 m, headless): the destination search median
  8 → 7 µs; the path plan median 148 µs (p90 243, max 273); the whole cast
  start median 294 µs (max 548); the carrier per step mean 22.6 µs (median
  17, max 84).
- **CH hold replay** (`ec9e423b`, `tools/r40_ch/lag_replay.py`, no game
  change): the uphill fix comes from the detach and the `set_pos` on the
  stop, not from the hold; the hold only sizes the forward snap at the
  release: on a 10.7 m dash 2.36 m with no hold, 0.47 m at 0.17 s, 0.25 m
  at 0.23 s, **0.08 m at 0.34 s**.
- **AN2 head look** (`bd52bbf4`;
  [character_visuals.md §5d](../design/character_visuals.md#5d-head-look-round-40)):
  `grug_visuals/head_look.lua`, H1: one relative `Head` override from the
  look pitch in 5° steps, clamped 50° down to 60° up, blended over 0.15 s,
  written only on a change by a round-robin pass that visits each player
  about every 0.25 s; the 0.001 rad epsilon
  ([upstream-workarounds.md](../technical/upstream-workarounds.md) §3);
  no write during the charge pose and 0.2 s after it; the website head note
  in [tools/web_data/model/README.md](../../tools/web_data/model/README.md).
  Fixture 71 checks. Numbers: the pass for 100 stand-ins 0.26 µs per step
  standing, 1.15 µs per step all looking around (400 writes/s); **3.7
  writes/s per player looking around continuously, none standing still**;
  about 60 B per write and observer, so twenty players in one zone all
  looking around send about 89 KB/s, about 4.4 KB/s into each client
  (estimates).
- **D** (this lane): this section, STATUS, the AGENTS.md pointer, ROADMAP,
  BACKLOG, README, CHANGELOG 0.40.0 and `game.conf` 0.40.0, the tools
  README.

### The user's picks and rulings during the round

All on 2026-10-06 (§2.13–§2.17):

1. **Overlay** `N3 B1 P1 F0 U1` (U2 first, U1 after the cost answer):
   image digits, the whole square darkened, no ready signal, the 0.1 s
   pass writing only a visible change. After the probe the user accepted
   the overlay **only provisionally**; the GUI test decides.
2. **Poses** `cast1=A cast2=B swing=B bow=A block=B charge=B flinch=A`,
   the head **H1 instead of H2** (H2 was the first choice, dropped as not
   worth its extra overrides); every pose switch blends.
3. **Particles: take all**, the main proposal of every card, single
   colour, no art sprite yet.
4. **Charge after the probe:** carrier A on the planned path at **24
   m/s**; the hole rule (a hop of at most 4 nodes, the landing at most one
   node up, depth irrelevant, liquids as air, otherwise a stop at the rim,
   a miss).
5. **Charge after CH:** a dip wider than four nodes with ground in reach
   is followed like terrain; the hole width is measured along the dash
   line, so a hole crossed diagonally is wider; the 0.34 s hold after the
   arrival stays **for now** after the hold replay; the user decides at
   the GUI test.

Coordinator defaults the user may overrule: hits during the dash reach the
warrior (§2.11); Battlebeat gets no proc flash (below).

### Deviations from the plan

- **Merge order:** PX and AN1 merged before CD, PM and CH (plan §1: CD, PX,
  PM, CH, AN1, AN2), because CD and CH waited for the user's probe test;
  each later lane merged main before its review.
- **The cost model** (§3.4) was corrected by V3's review before the picks
  (§2.15): an `attract` strength is a rate; a spawner's `radius` gives a
  disc, so rings that mark a radius are single particles placed by Lua; a
  spawner's bytes do not shrink with its amount.
- **Cleave** covers its real **120°** cone; the V3 card's 60° was a mistake.
- **Battlebeat gets no proc flash:** it is not a proc (rage on every hit).
- **AN1's resume clips:** a 5.17.0 client ignores a server animation with
  its own stand, walk or punch range for the local player, so a pose's end
  plays a `<base>_resume` clip for one step (the review's Medium); a landed
  Mighty Blow's swing starts at its frame 4, the top of the swing; Hold
  Ground's guard holds 1.0 s, not the whole 8 s buff.
- **CH's hold:** the probe's uphill stop short was the client's drawn lag
  (it draws the carrier about 2.7 m behind at 24 m/s and keeps that
  position on detach), not the planner; the fix holds about 0.34 s, then
  detaches and puts the warrior on the stop. A warrior rooted at the cast
  does not move (a miss).
- **CD** visits at most 100 players per pass (25 in its first version), so
  the 0.1 s cadence holds up to 100 players; the bow keeps its draw-stage
  wear (the draw's progress, not a cooldown).
- **PX:** an arrow's trail plays after its launch batch commits (a
  rolled-back shot leaves none); the Ice Nova and Bellow rings fly at the
  speed that lands on the real radius.
- **PM:** the web effect plays from spider and spiderling bites only (the
  slow hook is shared with other slows); the treant aura's effect every
  second tick; the dragon's 8 s return warning is played as eight 1 s
  pieces, so only players near the lair receive it.
- **V4 corrected §3:** the slot size is truncated (`s32(round(48 × density)
  × hud_scaling)`); the hotbar splits into two rows only when wider than
  the whole window; a moving entity's position is re-sent every server
  step anyway; the client erases an identity bone override, so a lead
  ends at the epsilon, which AN2 shares (a new §3 in upstream-workarounds).

### Open notes

In the [BACKLOG](../../BACKLOG.md#round-40-carry-overs); none blocks the
GUI test.

### GUI playtest checklist

Desktop and the web build, both Luanti 5.17.0, on the synced game. No
world generation changed: an existing world works; the last check of item
1 wants a new character. Use a second client for what others see. Say what
looks wrong.

1. **Cooldown overlay** (accepted provisionally; this test decides): cast
   skills: the cover appears at once over the whole icon, 50 % black,
   clearing clockwise from twelve o'clock, the number in the middle; at
   `hud_scaling` 1, 1.5 and an odd value such as 1.3 it sits exactly on
   the icons; Sprint's five minutes read `5m` … `2m`, then `60` … `1`; a
   short cooldown (Smite) runs smoothly; in a window narrower than the
   hotbar (two rows) it follows within about half a second; a skill moved
   to another slot, past slot 8 and back follows (a bag shows nothing);
   Hamstring's and Opening's charges show the same way and a full charge
   shows nothing; Last Word's reset of Word of Ruin clears its cover. **No
   wear bar** on a skill item: check it with a **new character** (a skill
   item an older character already carries may keep its old bar).
2. **Poses**, each standing and walking, in your own third person and on a
   second client: `cast1` (Fireball, Smite, Word of Ruin, Cinderfall) and
   `cast2` (Ice Nova, Glacial Ward, Heal, Mend, Shield) for about 0.6 s;
   Mighty Blow's diagonal cut once per landed blow, from the top of the
   swing, again on a second blow; the drawn bow; Hold Ground's raised
   shield arm for 1 s; the charge pose during the dash; the flinch on a hit
   (at most every 1.5 s, never over another pose). The arms blend in, the
   legs keep their stride, the pose ends and stand or walk returns in your
   own third person; the cloak stays clear of the legs; a refused cast, a
   dodged swing and the Strike fallback show no pose.
3. **Head look** in third person and on a second client (also one that
   joins later): the head follows the look up and down in steps with a
   blend, stops at the clamps, sits right with every pose and while
   mounted; nothing odd in first person; a dead player's head is level and
   follows again after respawn; the cloak against the back of the head
   looking up.
4. **Charge**, in first and third person: long and short on flat ground;
   uphill onto the last stair (arrives on top); over a step, off a ledge,
   into a wall; trenches of 4 nodes (jumped) and 5 (stop at the rim, a
   miss), a wide dip (followed down and up), a hole crossed diagonally,
   water (crossed; a target in water: the dash ends on the shore); no line
   of sight (refused, nothing spent); a mob hitting you mid-dash; the model
   running ahead of the camera in third person and the FOV kick in first
   person; the pose and the dust; PvP (flagged and unflagged targets); a
   stun, root, logout or travel mid-dash; a miss (no notice); **the hold
   on arrival** (about 0.34 s without control on the stop): keep it or ask
   for a shorter one (the user's pick; the replay's snap sizes above).
5. **Player-skill particles** at `grug_particle_scale` 1.0 and 0.5 (the
   game's settings, section *Combat*; restart the server): every skill's
   effect (Ice Nova's ring, Fireball's splash, Smite's holy fall, Mighty
   Blow's slash, arrow trails, Charge's dust, and the rest per
   combat_stats.md), the proc flashes; Strike shows nothing, and a skill
   falling back to Strike
   (on cooldown, no charge, no resource) shows nothing; on the web build
   whether the amounts stay smooth.
6. **Boss and mob effects** at 1.0 and 0.5: each king's signature, an
   elite's cone hit, both dragons (breath wind-up and bolts, lightning,
   gust, dive, enrage and whelps, the return warning near the lair), the
   Kraken's drag, spider webs, poison, pounces, ambushes, the ooze and
   treant auras, Oerkki and Wisp blinks, projectile impacts.
