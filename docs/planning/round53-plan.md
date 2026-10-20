# Round 53 — the new classes (round K)

Draft, 2026-10-20, written by Opus on the coordinator's brief (`r53/plan-draft-brief.md`).
The independent review (`r53/plan-review.md`, READY AFTER FIXES) is worked in; see the table
at the end. **Status: started 2026-10-20 on the user's "go"** (questions answered in §8);
**complete 2026-10-20** ([completion](#completion-2026-10-20): what shipped, decisions,
numbers and the GUI checklist).

**Start state:** main at the **0.52.1 release commit, pushed** (§7).

This is round **K** of the [delivery plan](class-redesign/delivery-plan.md) §5: the four new
class kits and the eight talent graphs go live, with one migration. The code facts are in
`r53/r53-file-facts.md`, cited as "facts §n". Routing: Claude coordinates and Opus
implements and reviews. The art is drawn and picked. The cast sounds come from the SKS
listening page, picked before the start.

**In short:**
- The Round 52 graph talents become the live talent engine and page, with
  `<tree>_<name>` ids.
- Four parallel class lanes rebuild the kits, the talent data and the tooltips. The
  Scout's bow draw goes.
- The 25 skill icons, the 65 particle cards and the picked cast sounds ship before the
  class lanes start.
- One migration step for 0.53.0:
  - a talent reset with a full refund;
  - stored windows cleared;
  - retired skills removed;
  - one chat line.
  - The game's own join swaps Strike for the basic attack of a Mage or Priest.
- HP factors: Mage 0.8, Priest 0.8, Scout 1.0, Warrior 1.2.
- Release **0.53.0, migrate**, for the user's one production world.

## 1. Lanes and waves

| Lane | Wave | Implementer / reviewer | Goal (§4) |
|---|---|---|---|
| **LIVE** | 1 | Opus / Opus | The graph becomes the live talent engine and page, with one data file per class |
| **HOOKS** | 1 | Opus / Opus | The shared seams for the class lanes: family keys on cast and swing, the swing callback, the clock seams, the fallback, the cone; table rows, icons, effects and the picked sounds; multi-class fixtures made one-directional |
| **INTEG** | starts in 1; finishes after the class merges | Opus / Opus | The 0.53.0 step and its test, the version, HP factors; then the old-engine removal, Help, the reverse fixture checks |
| **MAGE, WARRIOR, PRIEST, SCOUT** | 2 (after LIVE and HOOKS merged) | Opus / Opus | One class each: kit, talent data file, tooltips, fixture |
| **D** | 3 | Opus / Opus (docs review against the code) | Design docs, planning files, status owners |

**K1, two wave-1 lanes.**
- Nothing a class lane needs exists yet:
  - a graph-rank accessor;
  - family keys;
  - a swing callback;
  - per-player clock values;
  - a cone filter;
  - the table rows a new ability needs before it registers;
  - effect ids, icons and sounds.
- All of it lives in shared files. LIVE (`grug_classes/talents*`, the page, the graph) and
  HOOKS (`grug_abilities/init.lua`, `input.lua`, `kits.lua`, the `grug_core` catalogues,
  `grug_sounds`) share no file.
- Their one contract: `grug_classes.get_talent_bonus(player, "<family>:<param>")` returns the
  summed rank value. HOOKS stubs it until LIVE merges.

**K2, INTEG beside the others.**
- Part 1 (the step, the version, HP factors, its test) touches no LIVE, HOOKS or class
  file and needs nothing from them, so it starts in wave 1. Its branch stays open.
- Removing the old engine must wait, because today's kits call it until their class lane
  replaces them. For example, `kits_priest.lua:198` reads the old registry at load.
- So INTEG merges main after the four class lanes, removes the dead code, restores the
  reverse fixture checks (K14), finishes Help, and reruns its e2e on the integrated code
  before review.

**Merge order:**
1. LIVE and HOOKS, in either order. Main is merged into the second before its review.
2. The class lanes, in any order. Main is merged into each later one.
3. INTEG.
4. D.

### File ownership

| Files | Owner |
|---|---|
| `grug_classes/talents.lua` (accessors, store, spend, respec, level drop, `/talents`), `talents_ui.lua`, `talent_graph.lua`, `talent_graph_ui.lua`, new `talent_graph_{mage,warrior,priest,scout}.lua`, deleting `talent_graph_preview.lua`, `grug_classes/init.lua` (dofiles), `grug_skills/page.lua`; facts §9 group A; `tools/r53_live/` | LIVE |
| `grug_abilities/init.lua`, `input.lua`, `strike_delay.lua`, `kits.lua` (shared part), `mod.conf`; `grug_core/area.lua`, `particle_effects.lua`, `status_icons.lua`; `mods/CORE/grug_sounds/` (the picked cues); the 25 icons and `grug_abilities/LICENSE-media.md`; facts §9 group B; `tools/r53_hooks/` | HOOKS |
| `tools/migration/steps/v0_53_0.py`, `grug_core/migrations.lua`, `game.conf` version, `tools/web_data/upgrade.json`, `grug_classes/stats.lua`, `tools/r33_ds/common.py`, `grug_inventory/help.lua`; `tools/r53_ms/`; after the class merges, the deletions listed in §4 INTEG | INTEG |
| `kits_mage.lua`, `talent_graph_mage.lua`, `tools/r53_mage/` | MAGE |
| `kits_warrior.lua`, `charge.lua`, `talent_graph_warrior.lua`, `tools/r40_ch`, `tools/r53_warrior/` | WARRIOR |
| `kits_priest.lua`, `talent_graph_priest.lua`, `tools/r31_p1b`, `tools/r52_bench` section M, `tools/r53_priest/` | PRIEST |
| `grug_abilities/scout.lua`, **`input.lua`** (from wave 2), `grug_classes/scout.lua`, `talent_graph_scout.lua`, the draw textures and strips; facts §9 group C, `r52_wfx` D, the draw parts of `r40_an1`; `tools/r53_scout/` | SCOUT |
| docs, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the AGENTS.md pointer, `TODO-design-classes.md` (deleted) | D |

Ownership rules:
- In a shared fixture, a class lane edits only its class's section.
- A lane may make the minimal edit its own change forces in another lane's fixture, and
  says so.
- Every other change to another lane's file goes to the coordinator.
- `zone_authority.lua` and `grug_ambience/*` are read-only.

## 2. Rulings

**The user, 2026-10-19 (continuation §4a, skill inventory §3/§3a, Round 52 C1–C13):**
- "**Maximally simple**":
  - as few new mechanics as possible;
  - the combat system simple and performant, especially on the server.
  - "A lane that needs a mechanic outside the building-block list stops and reports."
- No cast times and no global cooldown. "A skill may instead occupy a longer time *after*
  the cast."
- HoT and DoT are a status effect placed once.
- "Every area effect triggers exactly once. No channels, pulses or persistent ground
  areas."
- No aiming preview. "An area with a short fixed delay shows a warning of a few particles
  at the impact point." Particles stay in the hundreds, never thousands.
- The ground anchor (§3a):
  - search H = 3 down;
  - "No ground found." before cost and cooldown;
  - band ±3;
  - line of sight from the anchor;
  - areas work in caves.
- HP factors: Mage 0.8, Priest 0.8, Scout 1.0, Warrior 1.2.
- Same-level elites may be very hard or impossible solo. Mob damage scale 1.5 stays.
- The ten cross-class decisions of skill inventory §3, including:
  - Retort readies on a hit that removed HP;
  - Recover is flat;
  - Parry opens Opening at the cast;
  - Sprint is kept;
  - "one action-clock rule for everyone … in both directions";
  - Word of Ruin is capped by the pool only;
  - Winter Field, not Ice Cage;
  - the retired talents and Shelter are dropped.
- C8 / Round 50 ruling 12: talent unlocks place nothing. A transformation replaces its base
  in place on hotbars A and B.

**The user, 2026-10-20 (node list §5, "alles wie empfohlen"):**
- "**Numbers:** the balance calculator's defaults plus its one stored change
  (`tuning/mage_rime`: Ice Armor absorb 12 % of P, Ice Nova root 2.5 s, Ice Wave slow 50 %)
  are frozen."
- Warding Faith (M5) gets 5 ranks, so Mercy has 33. "The folded Shelter value is part of its
  increments, set with the calculator."
- "M4, M5 and M7 become increments that keep each old end value."
- "Code talent ids are descriptive (`<tree>_<name>`); letter codes stay in the docs only."
- True Draw, Rime Mantle, Iron Hail and Lasting Armor are final. Shake Loose clears roots
  too. Bladecraft stays.
- Winter Field has no stun. Sprint stays innate. Hearten: 20 s, 14 % P.
- "starter hotbar: the basic attack in slot 1, then the skills in unlock order."
- **Migration (first login):**
  - "talent reset with a full refund";
  - stored windows cleared;
  - "retired skill items leave both hotbars" and the bags;
  - "Mage and Priest get their class basic attack in place of Strike";
  - "one short chat message, 'Your talent points have been reset.', and nothing more".
- Release **migrate**, version **0.53.0**.
- The BACKLOG "Round 52 carry-overs" for round K are resolved by the coordinator. §4 turns
  each into a lane goal.
- **The user asked for a listening page** of cast-sound proposals for the new skills. That
  is lane SKS (`tools/r53_sks/`). Nothing ships without a pick (the sound gate).

**Coordinator defaults (the user may overrule):**
- **K1, K2:** the wave shape (§1).
- **K3 Wave 1 never breaks today's kits.**
  - LIVE switches the accessors and the page.
  - Today's registry, its four data files and the old window API stay loaded and inert
    until INTEG's clean-up.
  - Main between the wave-1 merges and INTEG never ships. 0.52.1 is released before the
    first merge (§7).
- **K4 Store:** the same meta key `grug_classes:talents`, in the graph's format.
  - No old id collides with a `<tree>_` id (facts §3.2).
  - Respec keeps its prices. The level-drop reset and `/talents` move to the graph.
  - `/talent_preview` and the preview file go.
- **K5 Talent icons:** `grug_classes_talent_<name part>.png`, the id without its tree
  prefix. No file is renamed.
- **K6 Tables before the class lanes:** HOOKS adds, for the 25 new ids:
  - the `WEAPON_FX` rows (the tree's family, C7);
  - the `SKILL_POSES` rows (casts `cast1`/`cast2` like their family, Broadstroke `swing`);
  - the `CAST_SOUNDS` rows from the user's SKS picks:
    - picked cues ship as new `grug_sounds` entries and declared hooks, with their files
      and licence rows;
    - picked impact cues are played once at the anchor by the class lane;
    - a row without a pick keeps the page's proposal 1, a reuse of a shipped cue;
    - new projectiles reuse a lane-hook pair unless picked: Fiery Spark, Cold Spark and
      Flame Lance use the fireball pair; True Draw, Split Shot and Arrowfall use the arrow
      pair;
  - the `PROC_COLORS` rows and the status and window rows (§3).
  - Class lanes do not edit these tables. They report a needed change.
- **K7 Initial hotbar:** the class basic attack in slot 1, then the other starters in file
  order.
  - Scout: Loose, Sidestep, Sprint, Strike.
  - Only new characters are affected.
- **K8 The held fallback, exactly:**
  - There is no fallback when the refused skill **is** the basic attack, or when the
    refusal is the action clock or the cast interval.
  - Otherwise the player's current basic attack (`current_form` of Strike) fires once,
    silently:
    - a swing basic attack (Strike, Retort) swings;
    - a cast basic attack (Fiery Spark, Cold Spark, Smite) goes through `cast()`.
- **K9 Both clock directions (Q7):** every swing occupies casts for one interval of the
  current melee weapon, as the `register_ability` default for swings. Casts take their
  calculator value on both sides. This is a visible change for the Warrior and the Scout.
- **K10 Retired abilities:** `cinderfall`, `glacial_ward` and `pinning_shot`.
  - Their items leave every list offline.
  - Their rows, effects and icons go in INTEG.
- **K11 The chat line:** once, at the first join after the step, to every character with a
  class, through chat.
- **K12 Draw strips:** SCOUT deletes the six `*_bow_draw{0,1,2}` strips. `quarry_sword` and
  `quarry_dagger` stay unreached.
- **K13 Engine probes:** one short probe per class lane, reported and not gated.
- **K14 Table fixtures one-directional in waves 1–2:**
  - `r34_s1b` A, `r52_wfx` M and `r40_an1` S check only that every registered ability has a
    cue, a family and a valid pose, and that every projectile has lane-hook sounds.
  - There are no exact counts and no check for rows without a registration.
  - INTEG restores the reverse check when it deletes the retired rows.

## 3. Shared conventions

- **Ids:**
  - Nodes are `<tree>_<name>`. Abilities are the node list §3 names in snake_case, the 25
    staged icons.
  - Every gated ability, gated transforms included, sets `talent_gated = true` and
    `talent = "<tree>_<name>"`. The non-gated basic attacks (`fiery_spark` and `smite`,
    transforming `strike`) set neither.
  - Transforms:
    - `cold_spark` → `fiery_spark`;
    - `retort` → `strike`;
    - `bladecraft` → `loose`;
    - `ice_nova` → `ice_wave`;
    - `bellow` → `taunt`;
    - `broadstroke` → `mighty_blow`.
  - A family key that should reach both forms names both ids in the data.
  - The node id `bulwark_unbroken` keeps the old passive in `grug_quality/init.lua:1101`
    (`talent_rank(player, "unbroken")`) inert **because of the prefix**. Do not "fix" the
    id; INTEG deletes that site.
- **Status and window ids:**
  - Windows: `cold_shock`, `retort`, `clear_conscience`, `follow_the_line`, `parry`,
    `ruination`, `close_dance`.
  - Statuses: `rime_mantle`, `unbroken`, `haven`.
  - Absorbs show `shield`.
  - **Reused existing keys**, which keep their entries with new meaning: `PROC_COLORS`
    `ruination` and `unbroken`; STATUS `mend`, `sidestep`, `scout_sprint` and `shield`.
  - HOOKS adds the rest. INTEG's clean-up deletes only by the explicit list in §4.
- **PvP:** every `area.query`, `area.group`, cone and splash filter uses
  `grug_abilities.valid_target(player, obj, "hostile"/"friendly")`, which carries the
  `grug_pvp` seams. No lane calls a raw object scan for targets.
- **Numbers**, in order of precedence:
  1. the rulings;
  2. the calculator's new builds plus `tuning/mage_rime`
     (`r52/calc/data/data-<class>.json`, `<class>_<tree>`), which hold full-build totals;
  3. node list §2 for per-rank values and the skills the calculator omits;
  4. skill inventory §4 for mechanics.
  - A lane derives untalented bases as the total minus the full ranks, and reports any
    mismatch.
  - Per class:
    - **Mage:** Blink 20 s, 8 % P.
    - **Warrior:** Taunt and Bellow from B7/B9; Charge's 0.75 s stun.
    - **Priest:** Heal 25 %, Shield 24 % and Mend 7 % bases; Hearten 20 s, 14 % P,
      ~15 % P × Q. M4/M5/M7 are increments: +2/4/6 pp, +2/4/6 pp (ranks 4–5: §8 Q1),
      +0.5/1.0/1.5 pp.
    - **Scout:** Sidestep 18 s, 6 % P, 3 s, 0.25 s; Loose 0.85 s, 0.95 R.
- **Units in code:**
  - A unit add ("+0.05D") is a class key holding the coefficient, multiplied by the class's
    unit hit in the kit.
  - `damage_pct:<id or tag>` is a percentage of untalented damage.
  - Armor in K becomes a rating: K × `grug_core.armor_k(level)` for status `armor`.
  - Pool shares are % of `base_pool(level)`, × Q for support.
  - Steady Word and Sharpened Word are max-combined in PRIEST's kit.
- **Tooltips:**
  - Abilities: today's `description_for` style, with the current-level number from the same
    `values()` accessor.
  - Node descriptions: short English in player terms, such as "+5 % of a Spark hit". No unit
    letters, no directions and no places.
- **Hand-off:**
  - Icons are `grug_abilities_skill_<id>.png`.
  - Effects are registered under the card's `id` (`tools/r52_pfx`). The class lane plays a
    card where its `hook` says, with its `dynamic` frame fields.
  - Sounds per K6.

## 4. Lane goals

Briefs add the file facts. Every lane re-checks the facts it acts on at its base.

### LIVE — the graph goes live (wave 1)
- One data file per class, split from the preview, with:
  - `<tree>_<name>` ids, codes, gates, prerequisites, columns, types and abilities;
  - Warding Faith at 5 ranks;
  - each class's vocabulary;
  - effects for the shared keys and the families where the node list gives them.
- The Mercy sample build is re-derived for 33 ranks and reported.
- Players store, spend and fully reset ranks through the graph's rules (K4).
- These answer from the graph with unchanged names and contracts:
  - `talent_rank`;
  - `get_talent_bonus` (shared keys including the level-scaled `armor_percent_add`, class
    keys and `<family>:<param>`);
  - the points and tree points;
  - `register_on_talents_changed`.
- The level-drop reset, the "point earned" line and `/talents` read the graph.
- `graph.page_content` replaces today's trees in Talents & Skills: tabs, buy on click,
  respec with its prices, and the scrolling row below. Icons per K5, texts per §3.
- `/talent_preview` and the preview file go. The old registry and data stay inert (K3).
- BACKLOG GRAPH notes: `reach_cost`'s filler pass (fix if cheap, else note), and
  `graph_loader.lua`'s unused parameter.
- Fixtures: facts §9 A. `r35_b` and `r52_split` are retired; `r44_ts` and `r52_graph` are
  rewritten. Plus `tools/r53_live/`.
- Proof:
  - every tree's sample build spends legally;
  - illegal spends refuse with the gate texts on both paths;
  - a 0.52 string reads as zero ranks;
  - `armor_percent_add` at levels 10 and 60 equals the rank's % × `armor_k`;
  - page bytes are reported.
- Classification: **migrate.** The string changes meaning; INTEG's step clears it.

### HOOKS — shared seams, tables, art, effects and sounds (wave 1)
- **Family keys on both paths.** Through the definition's id and `tags` (`fire`, `frost`,
  `paid`, `support`, `bow`, `blade`, …):
  - the cast path applies `cost_pct`, `cooldown_sub` and `range_add`;
  - the swing path applies `cost_pct` and the definition's own cost adjustment (Relentless,
    Deep Focus on Opening) to the proc cost, which today is `cost_for` without an id,
    `init.lua:1536`;
  - the swing path applies `damage_pct` to the plain swing by the swing definition's tags
    (Fine Edge on Bladecraft and Strike).
  - One helper gives a kit `damage_pct`, `radius_add` and `duration_add`.
  - A transformation is read by its own id and tags.
- **The swing callback:** a class file registers, from its own file, what every landed swing
  gains: a damage multiplier or add, a rage add, and an on-landed hook, window or not. Uses:
  - Ruination;
  - Close Dance;
  - Retort's window consumed by a landed Retort.
- **Clock seams:**
  - `cast_interval`, `occupied_cast` and `occupied_swing` may each be a
    `function(player, def)`; the timing line shows the base. This is for Loose's affix
    cadence.
  - `occupied_cast = "weapon"` is the default for swings (K9).
  - The held fallback (K8). A fixture case per class.
  - Basic-attack-first initial order (K7).
- **Areas:**
  - one facing-cone filter (Ice Wave 70° 5 m, Broadstroke 100° 3 m, Flourish 90° 3 m), on
    `valid_target`;
  - `area.fall_height` takes the lowest ceiling over the anchor and four points at 0.6 R.
- **Tables (K6) and the picked sounds:**
  - new `grug_sounds` entries with files and licence rows from `tools/r53_sks`;
  - the `CAST_SOUNDS` rows by pick or proposal 1;
  - the impact cue names published for the class lanes.
- **Art and effects:**
  - the 25 icons (facts §6, three from drop-03) with their licence rows;
  - the 34 new and 7 retinted cards, with `check_limits.lua` passing. Retinted shipped
    skills change colour now.
- `grug_gear` is added to `grug_abilities`' `depends` (it is already used at
  `init.lua:1815`, and `grug_gear` depends only on `default`).
- **Fixtures:** facts §9 group B made content-agnostic:
  - `r36_k`, `r46_cb` and `r33_c5` lose their kit-content sections;
  - `r40_px` checks per site, with no count;
  - `r52_bench` loses N, and C becomes probe-only;
  - `r34_s1b` A, `r52_wfx` M and `r40_an1` S become one-directional (K14).
  - Plus `tools/r53_hooks/`.
- **Proof:**
  - the seams on probe definitions;
  - every shipped skill is unchanged except K8, K9 and the retints;
  - the `r31_pvp` micro run before and after.
- Classification: **compatible.**

### MAGE (wave 2)
- Fiery Spark (free, 1 s, 20 m), registered first.
- Ice Wave: a cone, 0.25D, **50 %** slow for 3 s.
- Fireball, Flame Lance, Meteor, Fire Rain, Cold Spark, Blink (20 s), Ice Nova (root
  **2.5 s**) and Winter Field (no stun).
- **Rime Mantle:** armor **and** a 12 % P absorb (Conflicts 2).
- Meteor, Fire Rain and Winter Field: `area.anchor` plus `area.delayed`, their cards, and
  the picked impact cue at the anchor.
- Nova and Wave: `area.query` around the caster.
- Cold Shock is a window.
- Occupied times per the calculator.
- Delete Cinderfall, Glacial Ward and the old talent hooks.
- Fixture `tools/r53_mage/`. Classification: **migrate** (retired items).

### WARRIOR (wave 2)
- Strike stays.
- Charge in `charge.lua`: 0.75 s stun, Halt's slow, Reach the Fight's +5 rage, Onset.
- Retort transforms Strike: it readies on the settled-hit hook, has a 6 s ICD and a window
  icon, and Recover is a flat heal with no crit.
- Hold Ground: an absorb, with no immunity.
- Taunt and the Bellow circle, both gated.
- Unbroken is active: an armor status plus an absorb for 8 s.
- Mighty Blow, and Broadstroke: at most 2 others in the arc, line of sight, crit allowed.
- Hamstring: an 8 s charge and a 35 % slow; Tendon Cut goes.
- Ruination: +15 % and +2 rage per landed swing for 8 s, through the swing callback.
- Self casts occupy 0.35 s.
- Fixture `tools/r53_warrior/`, plus `r40_ch`'s arrival numbers. **Compatible.**

### PRIEST (wave 2)
- Smite: the free basic attack, transforming Strike, 20 m, 1 s.
- Heal: instant, 25 % P × Q, cd 5, 1.5 s occupied, no crit; the splash goes.
- Shield and Mend.
- Hearten: `area.group`, cap 4, 20 s, 14 % P.
- Haven: an 8 m `haven` HoT status, cap 5.
- Rebuke, Word of Ruin (pool cap) and Final Word.
- Censure: anchor, 0.75 s, r 3, cap 4.
- Clear Conscience is a window.
- The M increments per §3; M1/RK1 max-combined.
- Recompense, Warded Wrath, Last Word and `kits_priest.lua:198`'s old read go.
- Fixture `tools/r53_priest/`. **Compatible.**

### SCOUT (wave 2)
**Delete the bow draw:** `scout.lua`'s draw, `input.lua`'s Loose cases, the stance, the
textures and the strips (K12).
- **Loose:** an LMB bow cast, 0.95 R, 1 arrow, held repeat 0.85 s. It is divided by the
  bow's attack-speed affix (`bow_draw_speed`, `scout.lua:389`) through HOOKS's function
  seam, with a floor of 0.65 s.
- **Bladecraft:** LMB is a melee swing; RMB fires an instant Loose shot through the RMB
  branch, on the action clock.
- Sidestep (18 s, 6 %, 3 s) and Sprint (unchanged).
- True Draw, Snare Shot, Split Shot (2 nearest within 3 m) and Arrowfall (`launch` 4,
  refused below 4 arrows).
- Opening: 1.35 M; 1.80 M from behind or in the Parry window.
- Parry: an absorb plus the window. Flourish: the cone. Close Dance: a window plus an
  absorb through the swing callback.
- Shake Loose, Quiver, and Follow the Line (a window).
- Pinning Shot and Untouchable go.
- Fixtures: facts §9 C (`r41_sc` retired), `r52_wfx` D, the draw parts of `r40_an1`,
  `tools/r53_scout/`. **Migrate** (Pinning Shot).

### INTEG — migration, HP, clean-up (starts in wave 1, merges after the class lanes)
**Part 1 (from wave 1):**
1. The **step 0.53.0**, offline (`v0_53_0.py`), for every character:
   - delete `grug_classes:talents`, every `grug_classes:talent_ready:*`,
     `grug_classes:unbroken_ready` and `grug_classes:untouchable_ready`;
   - delete `grug_classes:respec_used` too if §8 Q3 is yes;
   - remove `grug_abilities:{cinderfall,glacial_ward,pinning_shot}` from `main`,
     `grug_hotbar_store` and the bags;
   - if §8 Q4 chooses the move, put a Priest's Smite into Strike's slot on the same layout;
   - mark the character.
2. **Online:** the chat line (K11). The game's join `normalize_kit` does the swaps.
3. The version 0.53.0 in `game.conf`, `upgrade.json` and the registry.
4. **Test** `tools/r53_ms/` (pattern `r47_ms`/`r48_bags`):
   - unit tests;
   - an e2e from a **0.52.1** world with one character per class, retired items on A, on B
     and in a bag, spent talents, and a Priest holding Smite and Strike;
   - a boot and a join;
   - the join fixture;
   - every declared step's container test.
   - Keep the e2e world as the GUI test world (§6).
5. HP factors 0.8/0.8/1.0/1.2 in `stats.lua`, the Scout explicit, and `r33_ds/common.py`
   (`build_doc.py --check`).

**Part 2 (main merged in after the class lanes):**
- Delete, **by this list only**:
  - the old registry part of `talents.lua`;
  - `talents_{warrior,mage,priest}.lua` and `scout_talents.lua`;
  - the old window API in `talent_windows.lua`;
  - `K.talent_rank_value` (`kits.lua:318-323`);
  - STATUS `talent_*` rows and `TALENT_WINDOWS`;
  - `PROC_COLORS` `whitehot`, `last_word` and `untouchable`;
  - the Unbroken passive in `grug_quality/init.lua:1093-1110`;
  - the old-talent sites in `combat.lua`;
  - the dead `cost_for` cases;
  - `skin_overlay`'s draw `stage` and stale `loose` comments;
  - the rows, effects (`cinderfall`, `glacial_ward`, `pinning_hit`) and icons of the
    retired ids.
- Restore the reverse checks (K14).
- Rewrite `r26_status_icons`'s old check.
- Help's class lines.
- `export.lua --check`.
- The e2e again.

Classification: **migrate.**

### D — docs and status (wave 3)
- Design docs: `classes.md`, `skill_trees.md`, `combat_stats.md`, `ability_targeting.md`
  (§4 → ground anchor), `scout.md` and `progression.md` §2, against the merged code.
- Planning docs: node list R7 (armor plus absorb) and M5 (5 ranks);
  `implementation-design.md` §5/§6/§10 marked superseded; delivery plan progress.
- Delete `TODO-design-classes.md`.
- The module guide.
- This plan's completion with the GUI checklist.
- STATUS, CHANGELOG (short; the newsletter is the user's), BACKLOG, ROADMAP, README and the
  AGENTS pointer.
- The media licence rows.

## 5. Rules

- **Round workflow §3 per lane:**
  - `check_lua`;
  - `check_fresh_server`;
  - the upgrade classification;
  - the lane fixture plus the fixtures that test the changed behaviour, and the full run
    once;
  - one smoke boot;
  - independent review.
  - INTEG adds `check_upgrade` and the migration tests.
  - HOOKS and **every class lane** report the `r31_pvp` micro run before and after
    (AGENTS.md, combat path).
- **The fixture sentence**, verbatim, in **every lane, reviewer and fix-round prompt:**
  "Fixtures: run only your own fixture plus the fixtures that actually test the behaviour
  you change (not every fixture that loads a changed file); the full run once before your
  report; name what you ran and why."
- **Budgets:**
  - 8 Lua processes (`r45/lua_run.sh`);
  - 2 engine runs (`r45/engine_run.sh`), each a few minutes;
  - headless only via `tools/luanti_headless.sh`;
  - particles in the hundreds;
  - the sound gate;
  - the terrain guard (no lane writes nodes).
- **Stop and report:**
  - a mechanic outside the blocks (facts §2 plus HOOKS);
  - a number no source in §3 gives;
  - a shared-file change outside the lane.
  - These go to `## Blockers / questions` with the lane's proposal.
- No pushes, merges or syncs by lanes.

## 6. Verification

- **Class fixtures,** per skill:
  - damage, cost, cooldown and occupied time at levels 10, 30 and 60 against the
    calculator;
  - each talent at rank 1 and full;
  - the transforms on both layouts;
  - window open, consume and ICD;
  - area refusals;
  - an unflagged player and a same-faction player are never area targets.
- **Probes (K13):** one run of at most about 5 minutes per class. Each skill cast once on a
  dummy mob is logged beside the calculator. Areas also on stairs and in a cave.
- **Round end on main:**
  - `check_fresh_server`, `check_upgrade` and the full fixtures;
  - INTEG's step test;
  - one boot and the sync;
  - the user's GUI test.

**GUI checklist** (desktop and the web build, on the synced game). Worlds:
- a **copy of the production world**;
- INTEG's e2e world (one 0.52.1 character per class, for the classes production lacks);
- a fresh world.

1. **Migration (first):**
   1. Start the 0.52.1 copy under 0.53.0 without the tool: refused, naming the step and the
      command.
   2. Server stopped: `python3 tools/migrate.py --world <copy> --check`, then without
      `--check`, then start.
   3. Join each character:
      - the chat line once, and only it;
      - all points free;
      - Cinderfall, Glacial Ward and Pinning Shot gone from A, B and the bags;
      - Mage: Strike → Fiery Spark and Ice Nova → Ice Wave, on layout A **and B**;
      - Priest: Strike's slot per §8 Q4;
      - locked skills gone from the hotbars;
      - Mage and Priest max HP lower, and current HP clamped to it.
2. **New character** per class: the basic attack in slot 1, then the starters (Scout:
   Loose, Sidestep, Sprint, Strike).
3. **Talents page** per class:
   - tabs, backgrounds, icons and lines;
   - gate and prerequisite refusals;
   - an unlock adds to the row, not the hotbar;
   - a transform in place on A and B;
   - respec price per §8 Q3;
   - 30 points reach one ultimate;
   - node texts without unit letters.
4. **Mage:**
   - Spark cadence;
   - the Wave cone and slow;
   - the Fireball splash;
   - Meteor and Fire Rain warning, fall, impact and sound, also in a cave and on a slope;
   - "No ground found." at the sky;
   - Cold Spark;
   - the 2.5 s Nova root;
   - Cold Shock;
   - Rime Mantle's armor and shield;
   - Blink;
   - Winter Field.
5. **Warrior:**
   - Charge;
   - Retort;
   - Hold Ground;
   - Taunt and Bellow;
   - Unbroken;
   - Mighty Blow and Broadstroke;
   - Hamstring;
   - Ruination;
   - a cast right after a swing waits at most one swing (K9).
6. **Priest:**
   - Smite;
   - Heal on self and an ally;
   - Shield;
   - Mend;
   - Hearten and Haven on a few players, skipping hostile ones, with Haven ticking outside
     the circle;
   - Rebuke;
   - Word of Ruin;
   - Censure;
   - Final Word;
   - Clear Conscience.
7. **Scout:**
   - Loose held, no draw;
   - an empty quiver → Strike;
   - Bladecraft LMB and RMB;
   - Sidestep and Shake Loose;
   - True Draw;
   - Split Shot;
   - Arrowfall;
   - Opening from behind and after Parry;
   - Flourish;
   - Close Dance.
8. **Every class:**
   - occupied times after heavy casts;
   - no "You are still busy." spam;
   - a refused paid cast falls back once to the basic attack (K8);
   - areas never hit an unflagged player;
   - tooltips show current-level numbers;
   - overlays, icons and cast sounds;
   - the Help lines read right.
9. **Load:** a few players fighting, desktop and web.

## 7. Orchestration notes

- **Start state:**
  - main at the **0.52.1 release commit, pushed**. The coordinator releases 0.52.1
    (version bump, docs, gates) and the user pushes before round 53 starts. That way no
    wave-1 state can reach production.
  - The SKS picks are read back from the page.
  - This plan is committed as `docs/planning/round53-plan.md` on the user's "go".
  - Worktrees `r53-<lane>`, with `tools/bin/` copied in.
- **Wave 1:** LIVE, HOOKS and INTEG part 1. **Wave 2** starts when LIVE and HOOKS are merged
  and synced; the class briefs carry their merged APIs, re-checked.
- **Peak:** four class implementers and their reviewers, plus INTEG waiting. Lua and engine
  work queue through the two scripts.
- **Hand-overs:**
  - `input.lua`: HOOKS → SCOUT;
  - the data files: LIVE → their class lane;
  - the group B fixtures: HOOKS → class sections, then INTEG for the reverse checks.
- **Decided during the round (recorded in the completion):**
  - the exact poses;
  - the window ICDs;
  - per-rank values derived from totals;
  - `reach_cost`;
  - any SKS row the user left without a pick.
- **Accepted notes:** reopening a window plays the proc flash again. `clear_line` passes a
  hidden door node, which is theoretical.
- **Later:** a balance fix round after the user's first playtest.

## Conflicts found

| # | Where | Conflict | Resolution |
|---|---|---|---|
| 1 | delivery plan §5/§7 | "Class lanes touch only their files; INTEG owns the rest" | LIVE and HOOKS first (K1); INTEG beside them (K2) |
| 2 | node list R7 ("armor only") vs the stored change | A 12 % P absorb is added, and the armor is kept | The ruling freezes the stored change: armor and absorb. D fixes R7 |
| 3 | node list R9, the Ice Wave starter | Root 1.75 s and slow 35 % vs the stored 2.5 s and 50 % | The stored values |
| 4 | "skills in unlock order" vs C8 | It could read as auto-placing | C8 stands; it means the starter order (K7) |
| 5 | "basic attack in slot 1" vs the grant code | Universal Strike comes first, so a Scout gets Strike in slot 1 | K7 |
| 6 | `<tree>_<name>` vs the shipped icons | 74 icons are named by bare ids | K5 |
| 7 | M5's ranks 4–5 | No number in any source | §8 Q1 |
| 8 | "keep each old end value" | Absolute shares or increments? | Increments, which the frozen calculator builds use (Heal 31, Shield 30, Mend 8.5 at 3 ranks) |
| 9 | per-class `kits_<class>.lua` | The Scout's kit is `scout.lua` | SCOUT owns it; no rename |
| 10 | the draw deletion vs ownership | It spans `input.lua`, the strips and the poses | `input.lua` → SCOUT in wave 2; K12; INTEG removes `skin_overlay`'s stage |
| 11 | the inventory's "telegraph cone helper" | It is inline mob code | HOOKS adds one cone filter |
| 12 | Censure ±2 (inventory table) vs §3a | — | §3a: ±3 |
| 13 | implementation-design §5/§6/§10 | Preparations, previews, installments | Superseded by §4a; D marks them |
| 14 | INTEG's "web data export" | The export carries no skills or talents | `--check` only |
| 15 | "Priest gets Smite in place of Strike" | Nearly every Priest already holds Smite, so Strike's slot empties | §8 Q4 |
| 16 | Q7 "both directions" vs the clock | A swing cannot occupy casts today | K9 as the swing default |

## 8. Questions for the user

**Answered (the user, 2026-10-20: "Ja, alle 3 wie empfohlen"):** Q1 +8/+10 pp; Q3 yes, the
step clears `respec_used`; Q4 the empty slot is accepted (no Smite move). 0.52.1 pushed
(`e4d5c9d5`) before the start.

*(Q2, cast sounds, moved to the SKS listening page.)*

1. **Warding Faith ranks 4 and 5.** Ranks 1–3 keep the old end value (+6 pp); ranks 4–5
   carry Shelter's folded share, which no source quantifies.
   - *Recommendation:* +8/+10 pp, so Shield is 34 % P × Q at 5/5 instead of 30 %. This values
     Shelter at about +4 pp. Set or adjust it on the calculator page, as the ruling says.
3. **A free respec after the reset?** Today the first respec per character is free
   (`grug_classes:respec_used`).
   - *Recommendation:* yes; the step clears it.
4. **The Priest's Strike slot.** Smite is a shipped Priest starter, so practically every
   existing Priest already holds it. The one-copy rule then **empties** Strike's slot for
   nearly every Priest.
   - *Recommendation:* accept the empty slot. The Priest keeps Smite where they put it.
   - Alternative: the step moves the held Smite into Strike's slot on the same layout (a few
     lines in the offline step).

## Review worked in

Every finding was re-checked against main (now `f3a251db`: 0.52.1's ambience merged,
`game.conf` still 0.52.0, `origin/main` `67941764`).

| # | Re-check | Verdict | Change |
|---|---|---|---|
| H1 | `game.conf:8` is 0.52.0; origin is `67941764` | confirmed | §7 start state: 0.52.1 released and pushed first (coordinator); old push text dropped; K3 |
| H2 | `r34_s1b:192-208`, `r52_wfx:297-302`, `r40_an1:209-222` | confirmed | K14; HOOKS fixtures; INTEG restores; facts §9 B |
| M1 | `init.lua:1536` `cost_for(player, selected.cost)`; 1525-1527 | confirmed | HOOKS: family keys and cost adjustments on the swing path; the swing callback for every landed swing |
| M2 | `init.lua:877`, `896` asserts | confirmed | HOOKS function seam; SCOUT supplies Loose's |
| M3 | `input.lua:414/419`; `init.lua:1640` interval refusal | confirmed | K8 rewritten exactly, with a fixture case per class |
| M4 | `kits_priest.lua:17-18` not gated; `init.lua:2233-2280` | confirmed | §8 Q4 (accept the empty slot); conflict 15; GUI 1 |
| M5 | AGENTS.md PvP rule | confirmed | §3 PvP filters; §5 micro run per class lane; GUI and fixture lines |
| M6 | round45-plan:722-733; `migrate.py --check` exists | confirmed | GUI 1 upgrade procedure; worlds named |
| M7 | `particle_effects.lua:211-212`; `grug_quality:1101` | confirmed | §3 reused keys and the prefix note; INTEG deletes by list |
| L1 | `init.lua:895` | confirmed | K9 as the `register_ability` swing default |
| L2 | `init.lua:2125/2140` | confirmed | §3 id wording |
| L3 | `talents.lua:179-193`, 656-659 | confirmed | LIVE proof |
| L4 | `kits.lua:318-323`; `init.lua:845-851` | confirmed | INTEG part 2 list |
| L5 | calculator `priest_mercy` points note | confirmed | LIVE re-derives the Mercy build |
| L6 | — | confirmed | INTEG step: `respec_used` per Q3 |
| L7 | INTEG part 1 files are disjoint from LIVE and HOOKS | confirmed | **Decided:** INTEG part 1 starts in wave 1 (K2) |
| L8 | `mod.conf:4` lacks `grug_gear`; `grug_gear` depends only on `default` | confirmed | HOOKS adds it; proc-flash repeat accepted (§7) |
| L9 | `tools/r48_bags/{run.sh,e2e.py}` exist | confirmed | e2e from 0.52.1; facts §9 F fixed |
| L10 | lane-start checklist | confirmed | §5 |
| L11 | — | confirmed | GUI 1, 3, 8 lines |
| L12 | `r34_s1b:200-202` lane hooks | confirmed | K6 projectile pairs |
| Q2 | coordinator: SKS page under way | changed | K6 fills `CAST_SOUNDS` from the picks; Q2 removed |

## Completion (2026-10-20)

Every planned lane and the prep lane SKS are merged on main; this lane D
(this section, the design docs and the status owners) follows on main
`73b5ca40` (INTEG, merged last). **0.53.0 is migrate, one declared step**
(`tools/migration/steps/v0_53_0.py`): the talent string changes meaning, the
stored talent windows go, three skills are retired. Nothing in world
generation changes and nothing writes world nodes. **Push:** not pushed;
origin/main stays at `e4d5c9d5` (0.52.1) until the user's word.

### Lanes

Main's first-parent merges from `84ea20f0` (this plan), in order. Every code
lane was reviewed independently by Opus; the sounds were picked by the user
on two pages.

| Lane | Merge (lane tip) | What | Review |
|---|---|---|---|
| SKS | `681913a9` (`482b1ef9`) | cast-sound candidates for the new skills: 24 rows, 96 candidates, the listening page (`tools/r53_sks`) | the user rated it (54 notes) |
| LIVE | `927e2ae3` (`31249e32`) | the graph goes live: one data file per class, `<tree>_<name>` ids, the store, the accessors, spend, respec, level drop, `/talents`, the page; `/talent_preview` and the preview file gone; `reach_cost` fixed | MERGE (backlog notes) |
| SKS round 2 | `357683f3` (`6b37cbb0`) | the user's assignments, 17 rejections, 25 annotations, the control page; the user's confirmation (Blink and Flame Lance redone) | the user: all 24 rows and 5 questions keep, 2 redo |
| HOOKS | `937a1df0` (`088b92dc`) | family keys on both paths, the swing callback, clock seams, K8, K9, K7, `area.cone`, `fall_height` at 0.6 R, the K6 rows, 25 icons, 34 new and 7 retinted effects, the window rows, 20 new sound events, the projectile launch seam | MERGE (F1 K9 lock and F3 fixed; delta MERGE) |
| PRIEST | `cfdfc25f` (`05263176`) | the Priest kit (Smite, Heal, Shield, Mend, Hearten, Haven, Rebuke, Word of Ruin, Censure, Final Word), its class keys | MERGE (backlog notes) |
| MAGE | `20abd7bc` (`8f12ed5b`) | the Mage kit (Fiery Spark, Ice Wave, Fireball, Flame Lance, Meteor, Fire Rain, Cold Spark, Blink, Rime Mantle, Ice Nova, Winter Field), its class keys; `no_crit` on areas | MERGE (no fixes) |
| WARRIOR | `b3b1fb92` (`979e124e`) | the Warrior kit (Charge, Retort, Hold Ground, Taunt, Bellow, Unbroken, Mighty Blow, Broadstroke, Hamstring, Ruination), `charge.lua`'s arrival, its class keys | MERGE (F1 Ruination's rage by the weapon interval fixed; delta MERGE) |
| SCOUT | `f14b69b5` (`feb20acb`) | the Scout kit without the bow draw (Loose, Sidestep, Sprint, True Draw, Snare Shot, Split Shot, Arrowfall, Bladecraft, Opening, Parry, Flourish, Close Dance), `secondary_cast`, the draw art deleted | MERGE (backlog notes) |
| INTEG | `73b5ca40` (`97e818a1`, part 1 `9e16a0a1`) | part 1: the step 0.53.0, the chat line, the version, the HP factors, `tools/r53_ms`; part 2: the old talent engine, the retired rows, effects and icons removed, `opts.no_crit`, the held cast's catch-up, the reverse checks, Help | part 1 MERGE (two nits, fixed `eaefcb05`); part 2 MERGE |
| D | this section | the design docs, the module guide, the planning files, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the AGENTS pointer; `TODO-design-classes.md` deleted | independent docs review |

Main has 225 portable fixtures (7 new: `r53_live`, `r53_hooks`, `r53_ms`,
`r53_mage`, `r53_warrior`, `r53_priest`, `r53_scout`; 3 retired: `r35_b`,
`r52_split`, `r41_sc`). `mods/` against 0.52.1: +3,960 −3,678 lines in 48
text files; 4 new Lua files (`talent_graph_{mage,warrior,priest,scout}.lua`),
5 removed (`talents_{warrior,mage,priest}.lua`, `scout_talents.lua`,
`talent_graph_preview.lua`); 45 media files added (25 skill icons, 20
sounds) and 19 removed (the icons of the three retired skills, the three
draw sprites, the six draw strips, the draw ring's full frame, six old
talent-window emblems).

### Decisions during the round

**The user** (plan §8 and the two sound pages):

1. Warding Faith ranks 4–5: +8/+10 points (Shield 34 % P × Q at 5/5).
2. A free respec after the reset: the step clears `respec_used`.
3. The Priest's emptied Strike slot is accepted (no Smite move).
4. The reset's chat line is only "Your talent points have been reset."
5. **Sounds:** 20 new cues from the SKS page and the control page
   (`tools/r53_sks/assignments.md`): casts of their own for Blink (no
   longer silent), Ice Wave, Rime Mantle, Winter Field, Fire Rain,
   Unbroken, Ruination, Haven, Final Word, Arrowfall, Parry, Flourish and
   Close Dance; launch cues for Cold Spark and Flame Lance; impacts for
   Meteor, Fire Rain, Winter Field and Censure (once at the anchor) and
   Arrowfall (once per hitting arrow, at most four). Meteor, Bellow,
   Hearten, Rebuke and Censure keep a shipped cast cue, Broadstroke the
   swing. 17 sounds rejected (`rejected.md`), 25 annotations kept for later
   (`annotations.md`).

**The coordinator** (HANDOVER, answers to lane questions):

- Areas never crit: `opts.no_crit` on `deal_ability_damage` (INTEG), passed
  by Ice Wave, Ice Nova, Meteor, Fire Rain, Winter Field, Fireball's
  splash, Censure, Flourish and Split Shot's splash; Broadstroke's other
  targets and Arrowfall's arrows may crit.
- Held basic-attack casts carry bounded lateness (`CLOCK_CATCHUP`, 0.1 s and
  half the clock) into their interval **and** their occupied time.
- Ruination's +2 rage scales with the weapon interval (Round 46 ruling 9).
- Fiery Spark and Smite are Strike transforms without a talent, not
  `basic_attack = true` (the registration assert; plan §3); the Scout's
  Loose is `basic_attack = true`.
- Ground areas are offensive self casts (a hostile cast never fires at
  terrain), so the crosshair shows no colour for them.
- Rime Mantle: a flat 12 % P shield plus the armor, without the support
  factor. No internal cooldown on Cold Shock (the Nova's cooldown spaces
  it).
- Hard Faith raises only the untalented damage of Rebuke, Word of Ruin and
  Final Word, not Censure (the frozen calculator); Rebuke and Final Word
  then sit 1.3 % and 0.9 % under the calculator at level 60.
- Bellow's line of sight starts at the feet + 0.5; arrows fly 40 m/s (the
  shipped speed); Opening's "from behind" is the shipped rear half-plane;
  Close Dance's bonus does not reach Opening's charged hit.
- K8/K9 as built: a cast within one swing interval says "You are still
  busy."; a support skill held at a hostile falls back to the basic attack.
- Kept ids and art: the `glacial_ward` effect id (Rime Mantle plays it),
  `PROC_COLORS` `unbroken` and `ruination` (no caller), the
  `cast_frost_ward` cue (a hook without a call site), the `bow` pose clip
  (unused until the next model regeneration). The poses: Unbroken `block`;
  Bellow, Ruination, Parry, Flourish and Close Dance none.
- The icon comparison page (https://claude.ai/artifact/1H3qCwSvudKN8gXShJs2X8):
  the user marked 36 icons (26 skills, 10 talents) for a redraw (too detailed
  at small size; weapons tinted instead of natural colours); an Astra redraw
  round with 3 variants each runs after the round (`r53/astra-icons/`).

### Deviations from the plan

- **HOOKS** added a one-line seam outside its files on the coordinator's
  word: a projectile spawn's `params.sound_launch` (`grug_projectiles`).
  MAGE then registered Cold Spark and Flame Lance as projectiles of their
  own (own sprite and launch cue) instead of using it; Arrowfall's volley
  uses it to sound once.
- **MAGE and PRIEST** refuted their briefs' "`basic_attack = true`" on
  Fiery Spark and Smite (an assert forbids it on a transform, plan §3 says
  neither is set); both are Strike transforms and K7 still puts them in
  slot 1.
- **PRIEST** fixed `r46_cb` late (the base-hit add's caster-weapon ratio
  over `spell_base(L, L)`, numerically identical).
- **INTEG** deleted beyond its list what the new kits made dead: Affront's
  threat sites, `armor_rating_add_low_hp`, the Unbroken ×1.65 armor in
  `grug_quality` and `equipment.lua`, Turn Aside's status source and
  `PROTECTION_ARMOR_MULTIPLIER`, the `smite` and `heal_splash` effects and
  `cost_for`'s Smite case; it kept what the coordinator named (above). The
  scout review's crash-saved Loose stack needs no `SKIN_VERSION` bump: the
  join's `normalize_kit` repairs it (refuted, `r52_wfx` S proves it).
- **SKS** added rows the brief did not name (Censure's impact, Cold Spark's
  launch); the user kept them.

### Numbers worth keeping

- **Probes (K13, measured, one run per class):** every coefficient equals the
  calculator's. Mage (level 60, D = 42.2): Fiery Spark 1.0 (1.2 full),
  Ice Wave 0.25, Fireball 2.10 with splash 0.36, Flame Lance 2.97, Meteor
  1.68, Fire Rain 3.0, Cold Spark 1.09 (1.84 in Cold Shock), Ice Nova 0.65,
  Winter Field 1.0; Rime Mantle 0.320 K and 0.120 P for 7.5 s; Meteor at the
  sky refused "No ground found." with nothing paid; in a cave both mobs hit
  (fall height 2.5); on stairs a mob one step up behind the riser not hit.
  Warrior (level 60, a bracket-1 sword): Retort 1.00 S, 1.40 S readied,
  Recover 0.02 P; Hold Ground 0.21 P with a 21 s cooldown at full ranks;
  Unbroken +0.5 K and 0.15 P for 9.5 s; Charge 40 damage (12 % of a base
  hit), a 0.75 s stun, +15 rage (+20 and an 8.5 s cooldown in the Ruin
  build); Broadstroke 1.65
  S and 2 × 0.50 S, a third capped; Hamstring ×0.65 for 4.5 s; Ruination
  ×1.15 and +13 rage per swing (8 + 3 + 2); Bellow 6 m; stairs and a cave
  taunted. Priest (level 31, `r53/reports/priest-probe.txt`): Smite 88,
  Rebuke 160, Word of Ruin 142 healing 48, Final Word 249, Heal 202.25,
  Shield 194.16, Mend 4 × 56.63, Hearten 121.35, Haven 6 × 56.63, Censure
  106 on a stair and in a cave. Scout (`scout-probe.txt`): Loose 0.95,
  True Draw 2.20, Snare Shot 0.45, Split Shot 0.90 and 0.55, Arrowfall 4 ×
  1.40, Bladecraft 1.00 and 0.95, Opening 1.80, Flourish 2 × 0.80, Close
  Dance swings 1.35, shields 10 and 15 % P.
- **The held cadence** (fixture clock, INTEG, measured): a held Fiery Spark
  (1 s interval and occupied) on 0.09 s passes fires every 0.99 s instead of
  1.08 s; Loose in the scout probe before the catch-up 0.906 s instead of
  0.85 s (about 6 % less damage per second, the reason for the carry).
- **Page bytes** (LIVE, measured with the real sfinv frame): the level-30
  Scout page with 15 ranks and a node selected 7,138 → 7,110; level 60 with
  a sample build 6,498–6,895; one tree's content 4,617–5,297.
- **`r31_pvp` micro run** (best µs, before → after per lane, measured on a
  loaded machine): within noise on every path; for example HOOKS
  `valid_target` on a mob 0.133 → 0.119, the player punch chain 17.89 →
  18.79; WARRIOR the mob punch chain 15.99 → 16.82 (Retort's hook); no lane
  touched a measured path beyond a few table reads.
- **HP** (measured in the e2e): Mage and Priest at level 30 from 688 and
  764 to 611, clamped at the join; Warrior 917, Scout 764.
- **e2e** of the step from a real 0.52.1 world: 29/29 (6 characters, 16
  meta deletions, 3 inventories, 6 markers; the kit swaps active).
- **Particles:** at most 76 per occurrence (Fire Rain's impact), Ice Nova 64;
  the 62 cards pass `check_limits.lua`.

### Classification

**Migrate**, one declared step, 0.53.0:
`{"schema": 3, "version": "0.53.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
A world on 0.52.1 needs the tool before the start (the guard refuses it,
naming the step and the command). Saved state the step changes offline,
for every character: it deletes `grug_classes:talents`,
`grug_classes:respec_used`, every `grug_classes:talent_ready:<id>`,
`grug_classes:unbroken_ready` and `grug_classes:untouchable_ready`; it
removes `grug_abilities:{cinderfall,glacial_ward,pinning_shot}` from
`main`, `grug_hotbar_store` and the bags; it sets the marker
`grug_core:migrate:0.53.0`. Online, the marker's handler sends the one chat
line; the join's `normalize_kit` swaps Strike for Fiery Spark and Ice Nova
for Ice Wave (Mage) and removes skills that are now locked; `apply_stats`
clamps HP to the new factors. `grug_classes:talents` keeps its key and holds
`<tree>_<name>=rank`; the readiness windows and their internal cooldowns
live in memory only. HOOKS, PRIEST and WARRIOR were compatible on their
own, MAGE and SCOUT migrate (retired items), LIVE migrate (the string's
meaning).

### Open notes

The reviews' and reports' notes, the dead reads INTEG listed and the
balance fix round after the user's playtest are in the
[Round 53 carry-overs](../../BACKLOG.md#round-53-carry-overs). The
[delivery plan](class-redesign/delivery-plan.md) marks round K done.

### GUI checklist (Round 53)

Desktop and the web build, on the synced game. Worlds: a **copy of the
production world**; INTEG's e2e world
`~/projects/grudgelands-orchestration/r53/worlds/r53_ms_0.52.1` (a 0.52.1
world copied before the tool; logins `warrior`, `mage`, `priest`,
`scout`, `sleeper` (an offline Mage) and `walker` (no class), password
`it-<name>`); and a fresh world.

1. **Migration (first):**
   1. Start the 0.52.1 copy under 0.53.0 without the tool: refused, naming
      the step 0.53.0 and the command.
   2. Server stopped: `python3 tools/migrate.py --world <copy> --check`,
      then without `--check`, then start.
   3. Join each character:
      - the chat line "Your talent points have been reset." once, and
        nothing else (walker: none; a second join: none);
      - all points free (15 at level 30); the first respec is free again;
      - Cinderfall, Glacial Ward and Pinning Shot gone from A, B and the
        bags;
      - Mage: Strike → Fiery Spark and Ice Nova → Ice Wave, on layout A
        **and B**; Fireball and Blink gone until bought;
      - Priest: Strike's slot empty, Smite kept where it was;
      - locked skills gone from the hotbars (Mighty Blow, Taunt, Hamstring,
        Hold Ground, Snare Shot, Opening, Mend …);
      - Mage and Priest max HP lower (611 at level 30), current HP clamped.
2. **New character** per class: the basic attack in slot 1, then the
   starters (Warrior Strike, Charge; Mage Fiery Spark, Ice Wave; Priest
   Smite, Heal; Scout Loose, Sidestep, Sprint, Strike).
3. **Talents page** per class:
   - two tabs with points, background, icons (every node, the new skill
     icons too) and lines;
   - a click buys; a locked click shows the gate or prerequisite reason in
     the strip;
   - an unlock lands in the skill row, not the hotbar;
   - a transform swaps in place on A and B; a respec swaps it back;
   - respec Free, then the bracket price, Confirm and Cancel;
   - 30 points reach one ultimate;
   - node texts without unit letters; Ironbound, Weathered and the mana
     nodes show amounts at your level;
   - `/talents` lists node ids; the page fits above the skill row (web
     too).
4. **Mage:** a held Fiery Spark fires about every second, other casts wait
   1 s; the Ice Wave cone and its 50 % slow; the Fireball splash hits others,
   never the target; Flame Lance's white-hot trail and 1.5 s busy; Meteor,
   Fire Rain and Winter Field: warning, fall, impact and impact sound, also
   in a cave and on a slope; **on stairs** a target one step up behind the
   riser is not hit (the line of sight from the anchor; acceptable?); "No
   ground found." at the sky; aimed at ground within hand reach a tap casts
   and holding digs; Cold Spark's own launch sound and light slow; the 2.5 s
   Nova root, Cold Shock's icon and proc ring, then a harder Cold Spark;
   Rime Mantle's armor and the Shield icon; Blink (20 s, now with a sound);
   Winter Field.
5. **Warrior:** Charge (0.75 s stun, Halt's slow, +5 rage with Reach the
   Fight); Retort: a hit that costs HP gives a grey flash and an icon for
   4 s, the next Retort hits harder and heals, dodged or absorbed hits
   ready nothing, at most every 6 s; Hold Ground and Unbroken: armor and a
   shield, no immunity; Taunt (gated) and Bellow's 6 m ring; Mighty Blow and
   Broadstroke (at most 2 others in front, never an unflagged player);
   Hamstring's 35 % slow; Ruination +15 % with an icon, and **with a dagger
   and with a battle axe** about the same rage per second; **a cast within
   one swing interval after a swing says "You are still busy."** and waits at
   most one swing (K9).
6. **Priest:** Smite once a second, free; Heal on self and an ally; Shield;
   Mend; Hearten and Haven with several players (an enemy and a flagged ally
   skipped), Haven ticking outside the circle; Rebuke; Word of Ruin's
   self-heal; Censure: warning, seal, ring, sound, "No ground found." at the
   sky, a cave, a slope; Final Word; Clear Conscience: a flash, then a harder
   Smite; Heal held at a mob → Smite.
7. **Scout:** Loose held shoots every ~0.85 s with **no draw, no draw ring
   and no slowdown**; an empty quiver → Strike at a foe in reach;
   Bladecraft replaces Loose on A and B: LMB swings, RMB shoots (also held),
   a swing right after a shot waits one interval; Sidestep 3 s, with Shake
   Loose it frees from slows and roots; True Draw keeps you busy 1.35 s;
   Snare Shot slows; Split Shot splinters to 2 others (also when the
   primary dodges); Arrowfall plays one sound and up to 4 thuds and is
   refused with 3 arrows; Opening from behind and after Parry; Flourish hits
   3; Close Dance's shield and its swing marks.
8. **Every class:**
   - the held cadence of Fiery Spark, Smite and Loose at about the
     calculator's pace;
   - occupied times after heavy casts, and no "You are still busy." spam;
   - a refused paid cast falls back once to the basic attack (K8);
   - **areas never crit**: Meteor, Fire Rain, Winter Field, Ice Wave, Ice
     Nova, Fireball's splash, Censure, Flourish, Split Shot's splash;
   - areas never hit an unflagged player or an ally;
   - tooltips show current-level numbers;
   - overlays, icons and cast sounds; Taunt, Bellow, Hold Ground, Blink,
     Heal, Mend and Word of Ruin in their new colours;
   - **no bow-draw ring**, and no Whitehot, Last Word or Untouchable icons;
   - the Help lines ("Skills and combat") read right.
9. **Load:** a few players fighting, desktop and web.

### Round-end gates

On main `7c314b1d` (every lane merged, lane D included): the full
`run_fixtures.sh` 225 passed, 0 failed; `check_upgrade.py` (0.53.0 against
origin/main) and `check_fresh_server.py` PASS; one headless boot PASS
(150 s); synced to Luanti. INTEG's step test (`tools/r53_ms/run.sh`): e2e
29/29 on INTEG's final branch, unchanged since. Earlier, on main `73b5ca40`
(INTEG merged, before lane D): full fixtures 224/1 (only `r37_dc`, waiting
for the CHANGELOG entry), `check_upgrade.py` and `check_fresh_server.py`
PASS, boot PASS. Lane D: `r37_dc` PASS, `check_upgrade.py` and
`check_fresh_server.py` PASS, the docs link check (the lane report). Open:
the user's GUI test.