# Round 52, part B — class rework foundation

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 with the user while
Round 51 runs, revised the same day after an independent review
(`r52/plan-review.md`). Status: **built** 2026-10-20 (started 2026-10-19 on the user's "go"; [completion](round52-plan.md#completion-2026-10-20), which also records where the lanes followed C7's amendments over §3). Frame plan:
[round52-plan.md](round52-plan.md) (lanes, waves, file ownership, gates).
Part A is the [ambience plan](round52-ambience-plan.md).

This is round **F** of the [delivery plan](class-redesign/delivery-plan.md).
Every building block of the [skill inventory](class-redesign/skill-inventory.md)
and the new Talents page are built, while **the shipped classes play exactly
as before**. Round K follows later with the four new classes and the
automatic talent reset.

**In short:**
- `kits.lua` and `talents.lua` are split into per-class files, with no
  behaviour change.
- The combat building blocks exist and are tested, but no shipped skill uses
  the new ones yet. The one live change is Mend, which moves onto the status
  system.
- The new talent engine and the new Talents page are built and tested with
  the new trees as data. The page has one inner tab per tree, a background
  image and drawn connection lines. Admins can preview it; players keep
  today's trees until round K.
- The skill list in Talents & Skills scrolls horizontally.
- The art for the rework is drawn and picked: tree backgrounds, element
  overlays, talent icons and skill icons.
- The selected skill shows an animated element overlay on the first-person
  weapon.

## 1. Rulings (the user, 2026-10-19)

Sources:
- [continuation §4a](class-redesign/continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework);
- [skill inventory §3/§3a](class-redesign/skill-inventory.md);
- [delivery plan](class-redesign/delivery-plan.md), confirmed 2026-10-19.

Briefs quote the rulings they implement in full.

- **C1 Maximally simple.**
  - As few new mechanics as possible.
  - The combat system stays simple and performant, especially on the server.
  - A lane that needs a mechanic outside the building-block list stops and
    reports.
- **C2 No cast times and no global cooldown.** A skill may instead occupy a
  longer time *after* the cast. Work mostly with cooldowns.
- **C3 Areas trigger once, without an aiming preview.**
  - A delayed area shows a warning of a few particles at the impact point.
  - Large falling particles are allowed within the particle budget
    (hundreds in total, never thousands).
- **C4 Ground anchor** (inventory §3a, decided in full):
  - A targeted enemy gives its position at the cast; otherwise the terrain
    hit gives the point.
  - From that point the skill searches ground straight down, at most 3
    nodes. Ground is the top of a walkable node with a non-walkable node
    above. Liquids and non-walkable plants do not stop the search.
  - No ground found: the cast is refused before cost and cooldown, with
    "No ground found."
  - Damage volume: radius R, vertical band ±3 around the anchor, line of
    sight from just above the anchor to each target.
  - Areas work in caves. Falling visuals start below the first solid node
    above the anchor.
- **C5 Effects on the target.**
  - Heal-over-time is a status effect, cast once, that ticks on the target.
  - An area heal places that status on every friendly player it hits; the
    status keeps running when they leave the area.
- **C6 Talent trees** are the core of the rework:
  - the candidate graphs;
  - **one inner tab per tree**;
  - a background image per tree, with its connection lines and a few
    fitting graphic elements;
  - **one icon per talent**.
- **C7 Weapon effect.**
  - The selected skill shows an animated `wield_overlay` on the
    first-person weapon, one overlay per element.
  - Third person is unaffected.
  - The web client is 5.17.
  - **Per class and weapon type** (the user, 2026-10-19, after the first
    picks): every family has its own strip for each weapon type its class
    can wield, placed on that type's business end (Warrior rage: sword,
    dagger, greataxe; Scout wild and shadow: bow, sword, dagger, the bow
    with one strip per draw stage; Mage fire and frost and Priest holy:
    staff, wand, dagger). 18 combinations. All strips share one animation
    (8 frames, 0.96 s), because the engine lets the stack meta override
    only the overlay's name; the skin pass picks the strip by weapon type.
  - **One family per talent tree** (the user, 2026-10-19, second overlay
    pass): Ember (fire), Rime (frost), Bulwark (steel, new), Ruin (rage),
    Mercy (warm healing light), Reckoning (hard judgment gold), Quarry
    (wild), Veil (shadow); 24 combinations with the weapon types. Small
    accents in the class's style, no swirling or rotating motion; each
    family has its own tempo (fire as drafted, frost and the Scout's
    slower), shared by all weapon strips of that family. Shipped and
    starter skills take the family of their thematic tree; Strike none.
- **C8 Hotbars.** Talent unlocks place nothing. A transformation replaces
  the old skill in place on every layout, A and B, that holds it (Round 50
  ruling 12).
- **C9 Names (provisional).** "Aimed Shot" becomes **True Draw**, "Ice Armor"
  becomes **Rime Mantle**.
- **C10 Rough targets.** Numbers are guide values; performance is reported,
  never a target.
- **C11 Art scope.**
  - All **44 skill icons** are drawn as one consistent set, the 19 shipped
    ones included, plus **74 talent icons**.
  - **6 overlay families:** fire, frost, holy, rage, wild, shadow. Strike has
    none (node list §4). *Superseded by C7's amendment: 8 families, one per
    tree.*
  - Generic genre words stay as names (Fireball, Blink, Taunt, Smite …).
    Only the Quarry talent "Heavy Rain" is renamed, provisionally **Iron
    Hail**.
- **C12 No conversion; live in round K.**
  - Today's trees are **not** carried over.
  - The new engine and page are built and tested in R52.
  - The live game keeps today's talent engine and page until round K. Round
    K switches over together with the new kits, and **every character gets
    an automatic talent reset**.
- **C13 Skill list.** The skill list in Talents & Skills (the row players
  drag skills from) **scrolls horizontally**, so any number of owned skills
  fits. It goes live in R52.

### Decided by the coordinator (the user may overrule)

- **D1 Round F changes no class.**
  - The new blocks get fixtures and a probe; no shipped skill is rewired.
    Nova, Cinderfall and the splashes keep today's spheres.
  - The one live behaviour difference is **Mend** on `set_status`: its first
    tick comes 3 s after the cast instead of on a shared global 3-s beat.
  - The in-place transformation is a block that nothing shipped triggers
    yet (D8).
  - Today's talent trigger cooldowns (Ruination, Last Word, White-Hot,
    Hamstring's root) keep their `os.time` player-meta clock and survive a
    relog as before. Only the new window API uses the monotonic clock.
- **D2 One action clock, three directions.** Cast → swing, swing → cast and
  cast → cast. Every skill gets an occupied value. The defaults reproduce
  today: a cast pushes the next swing by one weapon interval, a swing
  blocks no cast, and a cast blocks no other cast. A per-skill lock after a
  cast is not a global cooldown (C2 allows it). Round K sets the new values.
- **D3 Admin preview.**
  - A command for the `server` privilege opens the new page with the new
    trees, read-only.
  - The preview data ships inside `grug_classes` as one data file that
    nothing live reads.
  - Node states show one worked example build per tree, held in the form
    context. The preview never writes `grug_classes:talents`.
- **D4 Per-class effect keys** for the **new** registry, so the four class
  lanes of round K do not all edit one table. `EFFECT_KEYS` and
  `WINDOW_KEYS` stay as they are for today's trees.
- **D5 Background geometry.**
  - Fixed before ARTA starts, so art and page agree.
  - Tab content rectangle: **13 × 5.5 formspec units** at x 0.25, y 0.95
    (today's tree area is 13 wide). Confirmed by the coordinator on main
    `713fcf88` (2026-10-19, `r52/d5-geometry.md`): 13 × 6 collides with the
    skill row once it carries its scrollbar (C13), so the tree tabs share the
    header row with the points and the respec control.
  - Drawn at **80 px per unit** (1040 × 440 px, aspect 13 : 5.5).
  - A calm centre for the node grid, decoration at the edges.
  - A rough size guide of 300 KB per PNG: every client, the web build
    included, downloads all media at join.
- **D6 Window runtime.** SPLIT moves the readiness-window runtime out of
  `talents.lua` into its own file, so CORE-B and GRAPH own disjoint files.
  The Unbroken hpchange block stays in `talents.lua`.
- **D7 Art ships as it is picked.**
  - Backgrounds, overlay strips and talent icons ship in R52 once picked:
    the backgrounds and icons are used by the preview, the strips by WFX.
  - Skill icons for skills that do not exist yet wait under `tools/r52_art/`
    for round K. Redrawn icons of shipped skills may replace today's in R52
    once picked.
  - Without a pick, the page uses a plain background with text nodes, and
    the overlay stays off.
- **D8 Transformation field.** A transformation is declared on the
  **ability** definition by a new field (e.g. `transforms = "<ability id>"`,
  with `talent_gated`). The talents' existing `replaces` field is never read:
  seven shipped talents use it with another meaning. No shipped definition
  sets the new field; the probe registers one.
- **D9 Delayed area lifecycle.** The caster leaving cancels a pending
  impact. A caster who dies still lands it, because the spell is already on
  its way. Objects are re-fetched by name at impact.

## 2. Lanes (details in the frame plan §1)

| Lane | Wave | Model | Goal |
|---|---|---|---|
| SPLIT | 1 | Opus / Opus | Per-class kit and talent files, the window runtime in its own file, no behaviour change |
| ARTA | 1 | Astra / the user picks | 8 tree backgrounds, 6 overlay strips |
| ARTB | 1, may run into wave 3 | Astra / the user picks | 74 talent icons, 44 skill icons |
| CORE-A | 2 (after SPLIT) | Opus / Opus | the action clock, the transformation and per-class basic attack, Mend on statuses, the PvE bench |
| CORE-B | 2 (after SPLIT) | Opus / Opus | the area query, the ground anchor, the delayed area, the group helper, the readiness windows, the probe |
| GRAPH | 2 (after SPLIT) | Opus / Opus | the graph talent registry and validator, the new Talents page (preview), the scrolling skill list |
| WFX | 3 (after CORE-A and ARTA's strip picks) | Opus / Opus | the weapon overlay per skill element |

## 3. Lane goals

Code facts with file:line pointers are in the coordinator's study
(`r52/r52-class-file-facts.md`), corrected by `r52/plan-review.md`. Briefs
re-check them at the base commit.

### SPLIT — per-class files (wave 1)

Split `grug_abilities/kits.lua` (1166 lines) and `grug_classes/talents.lua`
(1410 lines) into a shared part plus one file per class. Follow the existing
precedents: `grug_abilities/scout.lua`, and `grug_classes/scout_talents.lua`
dofiled from `talents.lua`.
- **Keep shared:** in `kits.lua` the helpers, the weapon API and Strike; in
  `talents.lua` the registry, audit and runtime, plus the vocabulary tables.
- **Keep two orders:**
  - the ability order per class (`by_class`, which drives the catalogue and
    the initial hotbar);
  - the global `talent_ids` order (serialisation, refunds, UI field names).
- **No new globals.** Per-class files receive the shared locals as a closure
  argument. The dofile chain stays inside `kits.lua` and `talents.lua`,
  because fixtures load those files directly.
- **D6:** the window runtime moves into its own file. The leave handler and
  `get_talent_bonus` keep reaching it through glue.
- **Proof of no behaviour change:**
  - a new dump fixture (`tools/r52_split/`) compares the registered
    abilities and talents before and after (the "before" dump comes from
    main via `git show`, never by a checkout);
  - `git diff --color-moved` shows only moved lines plus the dofile and
    window glue.
- **Fixtures:**
  - the text readers and direct loaders of facts §1.6;
  - not the three Python files, which only cite line numbers in comments.
    They stay untouched, so `r33_ds/build_doc.py --check` stays green.
- Classification: compatible.

### ARTA / ARTB — the art (wave 1, Astra)

**Input:** the final node list (`class-redesign/node-list.md`, step P4) with
each node's name, type and icon motif, and its §4 for the overlays.

- **ARTA:**
  - 8 tree backgrounds at D5's geometry. The page draws the connection
    lines, so a later graph change needs no new art.
  - 6 animated overlay strips (vertical frames, a few frames, for a 16-px
    weapon sprite). Each is placed so it reads at the tip of a diagonal
    weapon sprite.
- **ARTB:**
  - 74 talent icons; an unlock node uses its skill's icon;
  - 44 skill icons as one consistent set (C11);
  - 64 × 64 px like today's skill icons.
- **Process:**
  - Astra delivers files in a numbered drop folder.
  - The coordinator builds the German pick pages with stored ratings, as in
    R51's ART lanes.
  - Three drafts per item where the volume allows (ARTA: 3 per background,
    2 per overlay strip). ARTB runs in two passes: a style sample (12 icons
    in three styles) the user picks from, then the full set of 118 icons in
    the picked style. Redos go through the page again.
- **Picked files:** staged under `tools/r52_art/`. They ship as D7 says:
  GRAPH takes backgrounds and talent icons, WFX takes the strips.

### CORE-A — clock, transformation, Mend, bench (wave 2)

1. **D2 action clock** with an occupied value per skill:
   - the defaults live in `register_ability`;
   - one check in `cast_refusal`, which the input pre-check and `try_cast`
     share;
   - `grug_abilities.delay_strike(player)` keeps its signature as the
     cast → swing entry, so the Scout bow release and the fixture stubs stay
     as they are;
   - held casts do not spam a new refusal notice.
2. **D8 transformation** and the per-class basic attack:
   - `normalize_kit` swaps a stack in place on `main` and the hidden layout
     for a definition with the new field, and deletes nothing it would not
     delete today;
   - a shared cooldown key serves the cooldowns, the cast intervals and the
     cooldown overlay;
   - a class basic attack can replace the universal Strike for its class;
   - a fixture proves `normalize_kit` output unchanged for every shipped kit
     with today's talents.
3. **Mend onto `set_status`** with `on_tick`: same numbers, with the tick
   phase as named in D1. Mend's own globalstep goes away.
4. **PvE bench** (`tools/r52_bench/`), built on `tools/r22_ability_punch`:
   - one engine log per class against a dummy mob: casts, swings, cost paid,
     damage per hit, cooldowns armed;
   - deterministic inside the probe: crit and dodge chance stubbed to 0,
     `math.random` seeded;
   - main and the lane compare per-action records exactly, and cadence
     within one server step; Mend's phase is the named exception; anything
     else is reported, not gated;
   - a few runs of at most about 5 minutes each.

   The `tools/r31_pvp` micro run is reported before and after, as AGENTS.md
   asks for combat-path changes.
- **Fixtures owned:** `r50_hotbar`, and the `delay_strike` and input-API
  stubs (r28_a4, r32_f2, r36_f, r36_f2, r41_sc, r451_sc, r491_drop).
- Classification: compatible.

### CORE-B — areas, windows, group helper, probe (wave 2)

1. **Shared area query** in a new `grug_core` module:
   - radius, the ±3 band, a friendly/hostile filter, a cap and a
     deterministic order;
   - line of sight from just above the anchor, as a **walkable-only**
     raycast, so grass and shallow water do not block it (unlike
     `core.line_of_sight`).
2. **Ground anchor** (C4), with the refusal "No ground found." before cost
   and cooldown.
3. **Delayed one-shot area:**
   - a player-side scheduler with the D9 lifecycle;
   - a particle warning in the dragon lightning pattern (single particles
     whose lifetime equals the delay);
   - impact effects within `grug_core/particles.lua`'s limits;
   - no sound (sound gate).
4. **B8 readiness windows** in the window runtime file:
   - windows keyed by any id;
   - "consume on the next qualifying attack";
   - an ICD on the monotonic clock for the new API only (D1);
   - status icons for windows.
5. **Group-recipient helper:**
   - self plus eligible friendly players in range and line of sight;
   - a cap;
   - lowest HP share first, then a deterministic tie.
- **Proof:**
  - portable fixtures on the pure functions;
  - one engine probe (`tools/r52_core/`) that registers a test ability
    inside the probe mod only, never in `mods/`. It covers stairs, stacked
    floors, a cave, water and a flying mob without ground.
- **Fixtures owned:** `r26_status_icons`.
- Classification: compatible.

### GRAPH — talent engine and Talents page (wave 2)

1. **Registry and validator** for the new trees, beside today's (nothing
   live reads the new one in R52):
   - per-node gate;
   - several prerequisites per node, one rank each (the round-K rule);
   - one-rank ultimates after their gate;
   - modifiers as data;
   - per-class effect keys (D4).

   The audit checks cycles, reachability within 30 points, rank sums and
   the key vocabulary. The gates are enforced on both paths (reading saved
   talents and the spend refusal), with the same texts.
2. **Preview data** (D3): the eight new trees from the node list as one
   shipped data file in `grug_classes`, with nodes, ranks, gates and
   prerequisites, and effects only where keys exist. Fixtures under
   `tools/r52_graph/` prove:
   - the candidates' worked 30-point builds, adapted to the node list (cut
     nodes such as Shelter replaced, each adaptation recorded);
   - illegal spends, refunds and a full reset on the new registry.
3. **Talents page (preview in R52):**
   - one inner tab per tree, following the Character page's mode buttons,
     opened by the D3 command;
   - each tab has a background image at D5's geometry, or a plain one until
     ARTA's picks;
   - orthogonal connection lines made of `box[]` segments, as `layout_tree`
     draws them;
   - nodes with an icon, falling back to text;
   - the tab choice in the form context, never stored;
   - the page byte size reported for a full tree.
4. **Skill list** (C13), live:
   - scrolls horizontally (`scroll_container`);
   - the scroll position kept in the sfinv context, so refreshes do not jump
     back;
   - room for the bar below the row;
   - the assert of at most 8 removed.
- **Background and icon step** after ARTA's and ARTB's picks: a data delta
  (textures plus `grug_classes/LICENSE-media.md`) with its own short review.
- **Proof:**
  - today's registry, gates and bonuses are unchanged (existing fixtures plus
    SPLIT's dump fixture rerun);
  - the live page differs only by the scrolling row (`tools/r44_ts`);
  - the new page gets its own fixture.
- **Fixtures owned:** `r44_ts`, `r44_fr`, `r451_kf`.
- Classification: compatible (nothing saved changes).

### WFX — weapon overlay (wave 3, after CORE-A and ARTA's strip picks)

- Each skill item gets an animated `wield_overlay` from its element family
  and the held weapon type (C7): the definition carries the shared animation,
  the skin pass writes the strip name for the weapon type into the stack meta
  (`wield_overlay` overrides only the name);
  - the animation comes from the item definition;
  - the stack meta keeps only the weapon image;
  - the family mapping is an id-keyed table in `init.lua`, like
    `CAST_SOUNDS`. It also covers shipped skills the node list omits:
    Cinderfall → fire, Glacial Ward → frost, Pinning Shot → wild, Strike →
    none.
- **Empty weapon slot:** the empty-hand skin writes a transparent
  `wield_overlay` override (an empty meta string does not override the
  definition), with a `SKIN_VERSION` bump.
- The Scout's draw stages are unaffected.
- A check confirms the overlay never shows in third person: the holder
  copies only the cosmetic weapon.
- Without picked strips the mapping ships with the overlay off (D7).
- Owns `tools/r52_wfx/`. Classification: compatible.

## 4. GUI checklist (class part)

1. Each class fights a normal mob as before: same cadence, same skills, same
   damage feel.
2. Mend heals four times, every 3 s after the cast; its status icon matches.
3. Talents & Skills (live):
   - today's trees work as before;
   - the skill list scrolls horizontally when it is longer than the row.
4. Admin preview of the new page on desktop and web:
   - one tab per tree;
   - the picked background, or a plain one;
   - readable connection lines;
   - node icons where picked, text otherwise;
   - the sample build's node states.
5. Element overlay:
   - the selected skill shows its overlay in first person;
   - it does not show in third person (F7) or for other players;
   - an empty weapon slot shows no overlay.
6. Desktop and the web client, a few players nearby: no visible load.

## 5. Notes for round K

- **From the node list §5:**
  - Mercy's 31 ranks after the Shelter cut;
  - Mercy's support increments, to be frozen with the calculator;
  - the node-id scheme;
  - Shake Loose clearing roots;
  - Bladecraft kept on a recommendation only;
  - the soft values.
- The calculator's stored values (`tuning`) feed round K's numbers.
