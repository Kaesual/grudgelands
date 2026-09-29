# Grudgelands: buff and debuff status icons, complete effect list

Read-only survey of repository `main` at 29e4b6a7, dated 2026-09-29. Line
references are relative to `/home/jan/projects/grudgelands`.

## User decisions (2026-09-29)

These override the proposals and open questions below.

- **Background:** the dark square plate of the Round 18 skill icons. Ability
  buffs may reuse their skill icon.
- **Frames (drawn by code):** green for buffs, red for debuffs, and a third
  **gold** frame for states that are neither clearly buff nor debuff (PvP
  tags, combat state).
- **Shield:** one generic shield icon for all absorb sources.
- **Slows:** one icon for every slow; no variants.
- **PvP icons** (Tagged, Contested): drawn now.
- **Rested XP is removed from the game design entirely**; its row is gone
  from this list and orphaned references are removed from the current docs.
- **Combat state gets an icon:** a red icon with two crossed swords. It
  replaces the "Combat" text next to the health bar.
- **Dragon Scorch** is shown as a short 1.5 s status while standing on the
  patch.
- **No cooldowns as status icons:** only real buffs and debuffs (the potion
  cooldown and similar timers stay off the status bar).
- **Food buffs show the icon of the food that caused them** (the item's own
  inventory image, set by code), when that is straightforward; otherwise one
  generic food icon, since the effect is described in the text. Either way no
  per-role food art is needed from the artist.
- **New: one class icon per class** (Warrior, Mage, Priest, Scout), for
  example in the party UI, so a player's class is clear without knowing the
  colour codes. Same plate and size as the status icons, no frame; each
  class icon should also carry the class colour as an accent.

## 0. Overview

**What the HUD shows today.** `grug_core.set_status` has nine callers. It
renders one top-centre text list, with at most eight lines and buffs sorted
before debuffs (`mods/CORE/grug_core/status.lua:9, 181-195, 240-270, 327-337`).
Many effects that players can see exist in the code but never register a
status entry: Sidestep, all talent windows, poison, slows, roots, stuns and
Dragon Scorch.

| | Effects (rows) | Buff | Debuff | Neutral |
|---|---:|---:|---:|---:|
| **Existing in code**: registered with a status today | 9 | 8 | 1 (potion cooldown) | – |
| **Existing in code**: player-visible but not yet registered | 16 | 8 | 7 | 1 (in combat, optional) |
| **Planned or decided in docs** | 7 | 3 | 1 | 3 |
| **Total** | **32** | **19** | **9** | **4** |

Planned rows break down as 4 decided (PvP Tagged, PvP Contested, Warding
Draught; Rested was listed here and is now removed), 1 deferred (Stealth v2) and 2 optional or undecided (home
travel cooldown, boss lockouts).

**Icon roster after dedup** (§4): **34 core icons**, plus **10 optional
variants**. The core set is 24 buffs, 6 debuffs and 4 planned icons.

### Open questions (for Jan)

1. **Background.** The brief asked for transparent backgrounds. I recommend
   an opaque dark plate identical to the 22 Round-18 skill icons instead (§1).
   It reads better over bright sky or snow, and ability buffs could then reuse
   the skill art. Which do you want?
2. **Shield.** All absorbs merge into one status called `shield`
   (`combat.lua:1601-1610`). There are five sources: Power Word: Shield,
   Glacial Ward, Hold Ground, Recompense and Last Light. Should the icon
   follow the dominant source (5 variants), or stay one generic shield?
3. **Slows.** Every mob slow shares the single modifier key `mob_web`
   (`verbs.lua:125, 145-156`). That key covers spider webs, the Bog Witch hex,
   the treant root aura, Dragon Rime and the dragon gust. One generic "Slowed"
   icon is simplest. Per-source icons would need a code change.
4. **PvP-only debuffs.** Roots, stuns, Hamstring, Frost Nova and Snare Shot
   reach players only through PvP. PvP is live today: faction gate plus
   `enable_pvp` (`combat_stats.md:393-394`). Should these ship icons now or
   with WP41?
5. **Combat state.** The design says "Combat state is not a status entry"
   (`inventory_equipment.md:293-294`); it stays the red "Combat" text. Does it
   need an icon anyway?
6. **Scorch flicker.** Dragon Scorch damages only while you stand on the patch
   (`boss_dragons.lua:172-176`), so a status would flicker. Show a short
   "Scorched" status of about 1.5 s after each tick, or no icon?
7. **Cooldowns as statuses.** The potion cooldown is shown as a debuff today.
   Should other long clocks follow it? Candidates: home travel (30 min),
   Last Light (120 s), talent triggers (120 to 180 s) and the 24 h King and
   dragon loot lockouts. My recommendation is no: they belong on the Map or
   Character page.
8. **Frame colour for neutral states.** The design names only green and red
   frames (`inventory_equipment.md:297-300`). A PvP tag is neither buff nor
   debuff. Use a third, gold frame?
9. **Rested XP (WP21)** has no mechanics yet (`progression.md:17-18`). The
   icon brief below is a placeholder.
10. **Where does the icon row go?** The status list and the target frame both
   anchor top-centre: `hud_layout.lua:111-115` at y=20, and
   `grug_mobs/target_frame.lua:154-161` at y=40. An icon row needs its own
   slot.
11. **Stale WP reference.** `inventory_equipment.md:297` still assigns the icon
    framework to "WP10". Audit decision D10 made it its own UI package
    (`docs/planning/wp-audit-2026-09-29.md:166`). The doc wording should
    follow.

---

## 1. Technical constraints for the artist

Nothing exists yet for status icons. The rules below are proposals, derived
from the Round-18 skill icon precedent.

- **Size.** Deliver **64×64 PNG**, the same as the 22 skill icons
  (`mods/PLAYER/grug_abilities/LICENSE-media.md`, "Round 18 active-skill action
  icons"; `docs/research/round18-art-report.md`). The HUD draws them at
  **32×32** (image `scale` 0.5 × `hud_scaling`). For comparison, a hotbar slot
  is 48 px (`hud_layout.lua:21-26`).
  - Generate large, then downscale with Lanczos filtering, exactly as Round 18
    did.
  - The art must read at **32 px**. The hard floor is 16 px, reached when
    `hud_scaling` is 0.5.
- **Style.** Match the skill icons. The Round-18 prompt preamble in
  `tools/r18_art/manifest.json` specifies:
  - bold, hand-painted, pixel-art-inspired fantasy;
  - chunky shapes, a crisp silhouette, few large shapes and high contrast;
  - one centred emblem;
  - no text, letters or numbers.

  The HUD text draws the countdown and any value (`Shield 12`), so the art
  must never contain digits. Tier numerals stay out of the art as well.
- **Background: recommended opaque.** Use the skill icons' dark charcoal-blue
  square, with the emblem filling **about 75%** of the square instead of the
  skill icons' 85%. That leaves about 4 px at 64 px for the frame overlay.
  - If you want transparent art instead, generate on a flat chroma-key colour
    and key it out. Round 18 did this for `grug_abilities_weapon_ready.png`.
  - Do not mix opaque and transparent icons in one set.
- **Frames.** The code overlays the frame; the image model never draws one.
  The design decided "green/red category frames"
  (`inventory_equipment.md:297-300`). Proposal:
  - `grug_status_frame_buff.png`: 64×64, a transparent centre and a 2 to 3 px
    border in green `#4caf50`, the life-bar colour (`hud_layout.lua:55`).
  - `grug_status_frame_debuff.png`: red `#c41e3a`, the rage colour
    (`hud_layout.lua:57`).
  - Optional `grug_status_frame_neutral.png`: gold `#ffd100`, the XP colour
    (`hud_layout.lua:54`), for PvP tag states.
  - Draw the frames procedurally with Pillow, as was done for the crosshair
    and draw rings.
  - Composite in Luanti as `grug_status_<id>.png^grug_status_frame_buff.png`.
- **Naming and location.** Use `mods/CORE/grug_core/textures/grug_status_<id>.png`,
  since `grug_core` owns the registry. `<id>` is the status id, or
  `<status id>_<variant>` where one status id picks among variants: for
  example `grug_status_elixir_vigor.png` and `grug_status_food_caster.png`.
  - Status definitions gain an `icon` field; the framework itself is out of
    scope here.
  - Add a licence entry in `mods/CORE/grug_core/LICENSE-media.md` and a
    manifest with prompts and SHA-256 hashes, following
    `tools/r18_art/manifest.json`.
- **Distinctness.** Semantics come from shape, not only colour. This was the
  Round-18 rule, and it matters here because red/green frames already carry
  colour meaning. Colour-sensitive pairs:
  - Poisoned (green drop) and Renew (green leaf);
  - Rooted (locked chain) and Move Immune (broken chain);
  - Whitehot (white fireball) and Scorched (orange flame).

---

## 2. Existing effects

Legend: **B** buff, **D** debuff, **N** neutral. "Reg." means registered with
`grug_core.set_status` today.

### 2.1 Consumables (food, alchemy, trader potions)

| id | Display name | B/D | Source | Effect | Status | Icon brief |
|---|---|---|---|---|---|---|
| `food` → variant `food_hearty` | "Food +X% HP…" (dynamic label) | B | Food: hearty dishes | 300 s buff; HP regeneration every 5 s (paused in combat); T3+ adds HP pool % | exists, reg. `grug_food/init.lua:180-200`; tiers `:8-43`; roles `grug_cooking/init.lua:107-135` | A steaming clay bowl of thick brown stew with a small red heart rising in the steam. Warm brown and red. |
| `food` → `food_caster` | same | B | Food: caster dishes | HP + Mana regeneration; T3+ adds Mana pool % | same | A small plate of mash or preserve with a **blue** swirl of steam shaped like a mana wisp. Cream and azure; the bowl is squat, distinct from the stew. |
| `food` → `food_hunter` | same | B | Food: hunter dishes | HP regeneration; T3–4 add HP pool %, T5–6 add +1 Crit | same | A seared steak or fish on a skewer, with a small golden arrowhead glint. Deep brown with a gold accent. |
| `food` → `food_raw` | same | B | Raw or unprocessed food | 2% HP (or Mana, raw mana role) regeneration per tick (`grug_food/init.lua:63-65`) | same | A single raw red apple with a green leaf. No steam or plate, so it reads as "plain". |
| `elixir` → `elixir_vigor` | "Elixir of Vigor III–VI" | B | Alchemy elixir | +5/10/15/20% max HP, 15 min | exists, reg. `grug_alchemy/effects.lua:130-148`; roster `recipes.lua:86-128` | A round-bottomed flask of **crimson** liquid with a bright heart silhouette on the glass. |
| `elixir` → `elixir_focus` | "Elixir of Focus III–VI" | B | Alchemy elixir | +5/10/15/20% max Mana, 15 min | same | A round-bottomed flask of **deep blue** liquid with a four-point star glowing inside. |
| `elixir` → `elixir_precision` | "Elixir of Precision III–VI" | B | Alchemy elixir | +1/2/3/4 Crit, 15 min | same | A round-bottomed flask of **amber** liquid with a white crosshair ring on the glass. |
| `elixir` → `elixir_stoneskin` | "Stoneskin Elixir" | B | Alchemy elixir | +4% armor, 30 min | same (`recipes.lua:105`) | A round-bottomed flask of **grey** liquid whose glass is cracked into stone plates. |
| `elixir` → `elixir_deepwater` | "Deepwater Elixir" | B | Alchemy elixir | Water breathing (breath refilled every 1 s), 10 min | same (`effects.lua:136-145`; `recipes.lua:118`) | A round-bottomed flask of **teal** liquid with three large air bubbles rising out of the neck. |
| `alchemy_swiftness` | "Swiftness +10%" | B | Alchemy draught | +10% move speed, 5 s | exists, reg. `effects.lua:100-105`; `recipes.lua:74` | A tall, narrow **yellow** vial with a small white wing on its side and speed streaks. Must differ from Sprint's boot. |
| `alchemy_cave` | "Cave Draught" | B | Alchemy draught | Night vision, 10 min | exists, reg. `effects.lua:106-112`; `recipes.lua:83` | A tall, narrow **violet** vial with a glowing cat-slit eye in front of it. |
| `potion_cooldown` | "Potion" | D | Trader and alchemy potions (shared clock) | Blocks HP, Mana and utility potions; 60 s (Greater 45 s) | exists, reg. `status.lua:290-306`; clock `grug_traders/potion.lua:44-61`; `effects.lua:3-4` | An **empty**, dull-grey potion bottle lying on its side, with a small sand hourglass in front. Desaturated. |

Antivenom (`effects.lua:92-97`) is instant, a poison cleanse, and needs no
icon.

### 2.2 Class abilities and talent windows

| id | Display name | B/D | Source | Effect | Status | Icon brief |
|---|---|---|---|---|---|---|
| `scout_sprint` | "Sprint (+50% Speed)" | B | Scout: Sprint | +50% speed, 10 s | exists, reg. `grug_abilities/scout.lua:499-521` | A leather boot in a forward running stride with three **gold** speed lines behind it. You can reuse `grug_abilities_skill_sprint.png` if the background stays opaque. |
| `sidestep` *(new status)* | "Sidestep" | B | Scout: Sidestep | +15 dodge percentage points, 4 s | exists, not reg. `scout.lua:488-498`; `grug_classes/scout.lua:19-39` | A pale **teal** ghostly after-image of a figure leaning sideways, with a curved dodge arrow. Reuse candidate: `grug_abilities_skill_sidestep.png`. |
| `renew` | "Renew" | B | Priest: Renew (talent) | Heal every 3 s for 12 s (shown on the target) | exists, reg. `kits.lua:913-919` | A bright **green** sprouting leaf pair cradling a small pink heart, with a circular renewal arrow. |
| `shield` | "Shield N" (value = remaining absorb) | B | Any absorb (see variants) | Absorbs damage until consumed or expired | exists, reg. `grug_core/combat.lua:1601-1610` | Generic: a translucent **golden** bubble dome with a bright rim highlight, empty inside. |
| ↳ variant `shield_power_word` | – | B | Priest: Power Word: Shield | Absorb, 15 s (+talents) | `kits.lua:861-863` | A golden sphere with a small radiant figure inside. Reuse candidate: `grug_abilities_skill_power_word_shield.png`. |
| ↳ variant `shield_glacial_ward` | – | B | Mage: Glacial Ward (talent) | Absorb, 10 s | `kits.lua:1016-1030` | A shell of **pale-blue ice** plates, faceted like a geode. |
| ↳ variant `shield_hold_ground` | – | B | Warrior: Hold Ground (talent) | Absorb, 8 s | `kits.lua:967-984` | A **bronze** tower shield planted upright in cracked earth. |
| ↳ variant `shield_recompense` | – | B | Priest: Recompense (talent; Smite grants an absorb) | Absorb, 15 s | `kits.lua:760-766`; `talents.lua:697-702` | A **violet-gold** shield-shaped glyph with a small lightning spark. |
| ↳ variant `shield_last_light` | – | B | Trinket: Last Light (below 25% HP) | Absorb of 3–10% max HP, up to 120 s | `grug_trinkets/init.lua:118-131`; `items_crafting.md:1861, 1871-1873` | A single candle flame burning inside a thin golden shield outline. |
| `move_immune` *(new status)* | "Unstoppable" (proposed) | B | Hold Ground; Shake Loose (Sidestep) | Cannot be rooted or slowed, 8 s or 4 s | exists, not reg. `kits.lua:979`; `grug_classes/scout.lua:22-24`; `movement.lua:486-497` | A heavy iron shackle **snapped open**, its broken chain links flying apart. Iron grey with a gold glint. Must be clearly the opposite of Rooted. |
| `talent_unbroken` *(new)* | "Unbroken" | B | Warrior talent (below 20% HP, 180 s cooldown) | +15 armor rating, 8 s | exists, not reg. `talents.lua:361-366, 1032` | A dented steel breastplate glowing with a hot **orange** crack that still holds. |
| `talent_ruination` *(new)* | "Ruination" | B | Warrior talent (Mighty Blow landed, 120 s cooldown) | +20 Crit, cap 50%, 10 s | exists, not reg. `kits.lua:372`; `talents.lua:424-430` | A war hammer head wreathed in **blood-red** energy, with a white four-point crit star at the impact point. |
| `talent_whitehot` *(new)* | "Whitehot" | B | Mage talent (Fireball crit, 120 s cooldown) | Fireball costs 3% instead of 6% and deals +6, 8 s | exists, not reg. `kits.lua:502-504, 522`; `talents.lua:487-493` | A fireball with a **white-hot** core and pale yellow corona, hotter-looking than the orange skill fireball. |
| `talent_turn_aside` *(new)* | "Turn Aside" | B | Priest talent (while their shield holds on the target) | +10/15/20 dodge while the shield holds | exists, not reg. `kits.lua:863`; `talents.lua:634-640` | A golden round shield with a bright curved deflection arc glancing off its edge. |
| `talent_last_word` *(new)* | "Last Word" | B | Priest talent (below 25% HP, 180 s cooldown) | Word of Ruin drain heals 150%, 8 s | exists, not reg. `kits.lua:1047`; `talents.lua:676-682` | A **violet** spiral vortex draining into a small red heart. Dark purple. |
| `talent_untouchable` *(new)* | "Untouchable" | B | Scout talent (below 30% HP, 180 s cooldown) | +25 dodge, cap 55%, 6 s | exists, not reg. `grug_classes/scout.lua:48-68`; `scout_talents.lua:119-125` | A hooded shadow silhouette, half-faded, with two arrows passing harmlessly through. Charcoal and teal. |

### 2.3 Hostile effects on the player (mobs, dragons, PvP control)

| id | Display name | B/D | Source | Effect | Status | Icon brief |
|---|---|---|---|---|---|---|
| `poisoned` *(new)* | "Poisoned" | D | Serpent, Scorpion, Viper, Bog Witch | 1 damage every 2 s; 6 s (Serpent), 4–6 s others; cured by Antivenom | exists, not reg. `grug_mobs/verbs.lua:170-260`; `serpent.lua:14-16, 70`; `start_zone_families.lua:231-232`; `bog_witch.lua:12-13` | A single fat **acid-green** venom drop falling from a curved fang. Sickly green on dark. |
| `slowed` *(new; key `mob_web`)* | "Slowed" | D | Giant Spider (40%, 3 s), Spiderling (20%, 2 s), Bog Witch hex (30%, 4 s), Ashen/Gravewood Treant aura (30%), Dragon Rime patch (40%), dragon gust (40%, 2 s) | Movement speed reduced | exists, not reg. `verbs.lua:137-156`; `spider.lua:8-9, 70`; `zero_asset_variants.lua:246-247`; `bog_witch.lua:15`; `night_families.lua:194-207`; `boss_dragons.lua:171, 421` | A leather boot tangled in thick **grey-white sticky web strands**, with a downward drag mark under it. |
| ↳ optional `slowed_chill` | "Chilled" | D | Frost Nova follow-up slow (PvP); could also take Dragon Rime | −50%, root time + 3 s | `kits.lua:651-652` | A boot rimed with **ice-blue** frost and icicles hanging from its sole. |
| ↳ optional `slowed_cripple` | "Crippled" | D | Hamstring (PvP, −50%, 5 s); Snare Shot (PvP, −50%, 4 s) | Movement speed reduced | `kits.lua:417-418`; `scout.lua:95-103, 477-487` | A boot caught in a taut **rope snare loop**, with a thin red slash mark across the ankle. |
| `rooted` *(new)* | "Rooted" | D | Frost Nova (PvP, 4 s+), Pinning Shot, Hamstring with Tendon Cut (PvP) | Cannot move (hard flag) | exists, not reg. `movement.lua:371-387`; `kits.lua:416, 648-649`; `scout.lua:85-91` | A boot locked to the ground by a **closed iron chain** staked into stone, with ice crystals at the stake. Must not resemble the snapped chain of Move Immune. |
| `stunned` *(new)* | "Stunned" | D | Warrior Charge (PvP, 1.5 s) | Cannot act or move | exists, not reg. `movement.lua:418-428`; `kits.lua:319` | A dented helmet with three bright **yellow** stars circling above it. |
| `scorched` *(new)* | "Scorched" | D | Stormscale dragon breath patch | 2 (scaled) damage/s while standing on it; patch lasts 6 s | exists, not reg. `boss_dragons.lua:31-33, 66-80, 172-176` | Orange-red flame tongues rising from **cracked, glowing ground**. Ground-based, so it differs from Whitehot's airborne ball. |
| `in_combat` *(optional; design says no)* | "Combat" | N | Combat state | Blocks eating, mounting and regeneration | exists as HUD text `grug_core/combat_hud.lua:4-21`; rule `combat_stats.md:787-798` | Two clashing gauntleted fists or a red burst. Avoid crossed swords, which are reserved for PvP Tagged. |

### 2.4 System and movement

| id | Display name | B/D | Source | Effect | Status | Icon brief |
|---|---|---|---|---|---|---|
| `mount` → `mount_land` | "T1/T2 Mount, +X% Speed" (untimed) | B | Riding T1/T2 (land) | +60% or +100% speed while mounted | exists, reg. `grug_mounts/entity.lua:3, 478-482`; tiers `catalog.lua:14-17` | A horseshoe with a leather rein loop over it. Warm iron and tan. |
| `mount` → `mount_flight` | "T3/T4 Mount, +X% Speed" | B | Riding T3/T4 (flight) | Flight at +100% or +200% | same (`catalog.lua:20-23`) | A single spread feathered wing above a small saddle. Sky blue and tan. |

---

## 3. Planned (decided, not implemented)

| id | Display name | B/D | Source | Effect | Status | Icon brief |
|---|---|---|---|---|---|---|
| `pvp_tagged` | "PvP 0:SS" | N (debuff-like) | PvP (WP41) | Attackable by enemy players; 60 s tail outside contested zones | planned `world_zones.md:168-195, 1843`; `combat_stats.md:382-400`; `docs/research/wp41-engineering-brief.md:358-360` | **Crossed swords**: two blades in an X, blood-red blade glow. This motif is specified in the docs. |
| `pvp_contested` | "PvP — CONTESTED" | N | Contested zone or y ≤ −701 (forced tag) | Tag forced while inside | planned `wp41-engineering-brief.md:358-360`; `world_zones.md:171-174` | The same crossed swords over a torn **war banner**, with red and black cloth behind the blades, to show that the state is forced. |
| `warding_draught` | "Warding Draught" (+ race) | B | Alchemy T4–T6 | −5%/7.5%/10% incoming damage from one selected race, 5 min; one active | planned `items_crafting.md:1537-1556`; `combat_stats.md:206-212`; `classes.md:150-152` | A stout **silver** flask with a heater-shield emblem embossed on the glass and a faint white ward aura. Use one icon for all six target races (human, dwarf, elf, orc, troll, undead; `grug_classes/init.lua:173-209`) and put the race in the label. Six race-glyph variants are possible if wanted. |
| `stealth` *(deferred v2)* | "Stealth" | B | Scout (deferred) | Hidden from mobs; ×0.6 speed; breaks on combat | deferred `scout.md:401-624`; the doc asks for a "visible status entry at minimum" (`:624-626`) | A hooded cloak with no face, only a dark void and two faint eye glints, half dissolved into smoke. Must differ from Untouchable's arrows. |
| `home_travel_cooldown` *(optional)* | "Return home" | D | Home travel (30 min real time) | Travel home blocked | undecided: `home_travel.md:14-23` shows it on the Map tab | A small cottage with a sand hourglass. |
| `boss_lockout` *(optional)* | "Crown/Dragon lockout" | N | King Crown and dragon loot lockouts (24 h) | No boss reward | undecided: `items_crafting.md:1705-1707`; `world.md:628-631` | Not recommended for the HUD. If used: a crown with a padlock. |

Explicitly **not** planned or not timed (no icon):
- Battle Shout and auras: deferred and undecided (`classes.md:570-572`).
- Cultural and weapon counter finishes: permanent item properties, not timed
  (`items_crafting.md:1393-1420, 1517`).
- Trinket passives Manawell, Battlebeat, Mercy Seal, Apothecary Loop and
  Reclaimer's Mark: passive or instant (`grug_trinkets/init.lua:89-150`).
- "Well Fed I–III" (`design-decisions-2026-08-review.md:122`): superseded by
  the Food v2 role buffs above.

---

## 4. Grouping and dedup recommendations

- **Food.** There is one status id and only one food buff runs at a time
  (`combat_stats.md:840-841`). Use one icon per role: hearty, caster, hunter
  and raw (4 icons). The dynamic label already carries the numbers.
  - Do not draw per-dish icons; there are dozens of dishes.
  - Do not use a single shared icon either: role is what the player needs to
    see.
- **Elixirs.** One status id with 5 families. Use one icon per family; tiers
  III–VI share it, and the tier stays in the label. All five share one flask
  silhouette so they read as a family; colour plus the emblem separate them.
- **Utility draughts** (Swiftness, Cave) use a tall, narrow vial, so they
  never read as an elixir.
- **Shield.** One generic icon is enough for the core set. The 5 source
  variants are optional and need the framework to pick the dominant
  `absorbs[id]`.
- **Slows.** One generic `slowed` icon is the core. Chill and cripple are
  optional PvP variants. Mob sources cannot be told apart without splitting
  the `mob_web` key.
- **Move immunity.** Hold Ground and Shake Loose share one `move_immune` icon.
- **Ability buffs.** Sprint, Sidestep, Renew and Power Word: Shield can reuse
  their Round-18 skill icons, the WoW convention where the aura icon equals
  the spell icon, but only if the opaque background is kept. Otherwise draw
  new ones from the briefs.
- **PvP.** Tagged and Contested share the crossed-swords core; Contested adds
  the banner.

### Final roster for the image model

- **Core (34):**
  - Food: `food_hearty`, `food_caster`, `food_hunter`, `food_raw`.
  - Elixirs: `elixir_vigor`, `elixir_focus`, `elixir_precision`,
    `elixir_stoneskin`, `elixir_deepwater`.
  - Draughts: `alchemy_swiftness`, `alchemy_cave`.
  - Mounts: `mount_land`, `mount_flight`.
  - Ability buffs: `scout_sprint`, `sidestep`, `renew`, `shield`,
    `move_immune`.
  - Talent windows: `talent_unbroken`, `talent_ruination`,
    `talent_whitehot`, `talent_turn_aside`, `talent_last_word`,
    `talent_untouchable`.
  - Debuffs: `potion_cooldown`, `poisoned`, `slowed`, `rooted`, `stunned`,
    `scorched`.
  - Planned: `pvp_tagged`, `pvp_contested`, `warding_draught`.
- **Optional (10):**
  - Shield variants: `shield_power_word`, `shield_glacial_ward`,
    `shield_hold_ground`, `shield_recompense`, `shield_last_light`.
  - Slow variants: `slowed_chill`, `slowed_cripple`.
  - Others: `stealth`, `home_travel_cooldown`, `in_combat`.
- **Frames (3), procedural, not generated:** `frame_buff`, `frame_debuff`,
  optional `frame_neutral`.

**Not iconised:** drowning, lava and suffocation
(`environment_damage.lua:13-14, 111-150`) are covered by the breath bar and
damage feedback. Eating and bow-draw movement stances (`grug_food/init.lua:347`,
`scout.lua:372`), the character-creation hold (`grug_classes/selection.lua:106`)
and the flight-boundary warning (`grug_mounts/entity.lua:170-200`, its own HUD
text) are transient input or UI states, not buffs.

## 5. Class icons (user decision 2026-09-29)

One icon per class for the party UI and similar places. Same 64×64 dark
plate as the status icons, no status frame; the class colour from
`grug_parties/hud.lua:4-9` is the accent.

| id | Class | Colour | Icon brief |
|---|---|---|---|
| `grug_class_warrior` | Warrior | leather brown `#a66a3f` | A notched **broadsword crossed over a round shield**, heavy and blunt, with brown leather wrapping and a steel edge. |
| `grug_class_mage` | Mage | arcane blue `#4a9bd8` | A **spell orb** hovering over an open palm or a short staff tip, with blue sparks and a cool glow. |
| `grug_class_priest` | Priest | white `#f2f2f2` | A **radiant holy symbol** (a simple sunburst or chalice) in white and pale gold, glowing; outline it in darker grey so it reads on the dark plate. |
| `grug_class_scout` | Scout | olive green `#6b7d32` | A **drawn longbow with a nocked arrow**, olive fletching, a hint of a hood edge behind it. |
