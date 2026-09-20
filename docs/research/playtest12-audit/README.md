# Playtest 12 design-to-code audit — 2026-09-20

> **Round-10 disposition:** All four decisions below were subsequently settled:
> retain the sole one-in-five expensive Uncommon vendor exception, preserve all
> three Rock Salt endpoints on appropriate rocky support, use functional cave
> footprints rather than broad blend envelopes, and scale falls by
> `ceil(max_hp * native_damage / 20)` before Dwarf reduction and absorb. The
> seven implementation deviations have candidate corrections in EQUIP, GAME
> and WORLD; [round10-closeout.md](../round10-closeout.md) records their exact
> review/integration state. This report remains evidence for the Playtest-12
> baseline and does not itself claim those candidates are delivered on main.

**Discussion inventory, not authorization to implement corrections.** The user
requested independent GPT-5.6 Sol audits because shipped behavior appeared to
diverge from previously decided design. Three fresh read-only reviewers checked
professions/economy, world generation, and combat/creatures respectively. A
fourth bounded Sol task inspected the historical orchestration briefs.

Code and design baseline: `2a3088917b10f047dea9561b9f3fd36717619fff`, the actual
Playtest 12 version. Later user rulings were supplied separately so new wishes
would not be mislabeled historical defects. The reviewed PERF changes preserve
world output and are a separate package. No audit correction was implemented.

The coordinator independently followed the material code paths and checked
the conflicting rules. The accepted inventory contains **seven implementation
deviations (two High, five Medium), four unresolved choices, and two concrete
authority-order defects in historical briefs**. This is a bounded static audit,
not exhaustive game certification or runtime reproduction. The reports state
their coverage and exclusions explicitly.

## Confirmed implementation deviations

| Priority | ID | Player-visible result | Correction boundary to discuss |
|---|---|---|---|
| High | P12-A-REF-01 | Blacksmith weapon/metal-armor and Tailor cloth refinements consume materials, but the terminal quality callback restores the unrefined base state. | Give the transformation one quality owner; verify the final stack and prevent duplicate armor bonus application. |
| High | PT12-C-A01 | Ordinary tool/fist PvP damage can bypass mounted attack refusal. Ability swings/casts and the Grudgelands mob path have separate guards. | Apply the existing mounted refusal to ordinary player-hit settlement without redefining PvP eligibility. |
| Medium | P12-A-BOOK-01 | Group-input profession recipes, including Sweetroot Mash, also appear in General. Actual crafting still requires the profession. | Compare recipe provenance as recipe tokens; keep concrete-item authorization distinct. |
| Medium | P12-A-ROT-01 | Traders choose two physical extras out of six instead of three of four conceptual weapon families. | Restore the decided family-based rotation; define the caster-family sub-selection explicitly. |
| Medium | PT12-C-B01 | Apothecary Loop improves crafted instant potions but misses the weak vendor potion. | Include the vendor potion in the existing effect path before rounding. |
| Medium | PT12-C-A02 | Dragon scorch continues dealing damage without refreshing combat state. Food/recovery can therefore treat the victim as out of combat. | Mark the hostile periodic effect; do not silently redefine every environmental damage source. |
| Medium | LB-A-01 | Mountain-island sand and some high freshwater soil rims remain despite the decided no-sand/stone-or-gravel rule. | Correct material selection while preserving geometry and resolving Rock Salt below. |

Exact requirement dates, code paths, test-coverage gaps, confidence and limits
are in [professions.md](professions.md), [gameplay.md](gameplay.md) and
[world.md](world.md). All seven are source-confirmed; none was newly reproduced
in a live client during this audit.

## Decisions needed before dependent corrections

1. **Vendor quality (P12-D-VENDOR-QUALITY-01).** Several rules say Common-only,
   never refined/enchanted. Other equally explicit rules prescribe occasional
   Uncommon enchanted stock. Current code implements that exception. Decide
   whether to retain it explicitly or make the floor strictly Common-only.
2. **Rock Salt and mountain shores (LB-D-02).** Island Rock Salt currently
   requires sand. Removing sand alone removes two of its three named source
   zones. Proposed: preserve the three endpoints and allow appropriate rocky
   support on the islands. This is not yet a ruling.
3. **Cave exclusion extent (LB-D-01).** The example near Dawnmere lies outside
   the 128-node build square but inside its 256-node fitting/blend exclusion.
   The current cave pass deliberately skips both opening and skin filling
   there. Decide the purpose-specific cave boundary without changing building
   protection or claim exclusions as a side effect. The actual roof still
   needs an engine witness before a mapgen correction is finalized.
4. **Fall danger (PT12-C-D01).** Percentage-based danger was requested, but
   the curve and Dwarf/absorb ordering remain open. Armor already does not
   mitigate fall damage. This is a requested design change, not a breach of a
   previously specified percentage formula.

## Incomplete work versus drift

Universal base equipment plus professional refinement is an old decided rule,
not an idea first introduced by this playtest. However, most missing base
recipes remain under explicitly open WP27/WP29/WP10 work. They are important
unfinished work rather than newly discovered omissions from a closed package.
The present Woodcarver-gated caster-base routes must be reconciled with that
universal-base destination; calling the catalog implemented does not establish
that the intended crafting loop is complete.

The process audit identifies a separate real defect: catalog briefs cited the
universal-base rule but positively assigned base outputs to profession stations
and did not test profession-free reachability. Existing package boundaries
therefore left the intended player loop without a complete acceptance check.

Later-slot affix application, parts of Fine/Masterwork, leather armor, the
Leatherworker yield hook and WP22 durability are already open work. The smith
split, exact VoxeLibre grid quantities, mount usability changes, safe roaming
and the newly specified dragon idle behavior are later decisions. They must
not be counted as seven additional historical bugs.

**Coordinator disposition:** reject question 4 at the end of the professions
report insofar as it reopens mastery versus profession tiers. Their independent
roles are already settled by `items_crafting.md` §2.1/§6b.5. Only the missing
player operation for adding later affixes remains to specify. The earlier
planning draft supplied to the auditors contained that ambiguity; the reviewed
planning record in commit `47b907bc` corrects it.

## Historical process defects and prevention

The [process audit](process.md) verifies two authority inversions:

- `w9/common.md:15` says a generated brief wins over the plan, even though
  that plan contains user rulings.
- `w9/docs/brief.md:101–104` ranks merged code above user decisions and asks
  design docs to match the code.

Neither instruction is valid authority for overriding the user's design. The
pending DOCS lane must not run under that ordering. These are confirmed defects
in written orchestration instructions, not proof of individual agents' motives
or of which files they read.

Proposed prevention: every player-visible deliverable gets a short
requirement/source → code path → acceptance check table. Reviewers first check
the brief against the decided rules, then the code against the brief and those
rules. A departure needs an explicit later user ruling; passing a test derived
from a contradictory brief cannot establish conformance. Documentation must
report divergence rather than normalize it into a new design decision.

## Evidence and next step

The three audit reports preserve their original classifications, including
known open work and stale documentation. This overview provides coordinator
dispositions. `report-hashes.json` records the original returned report hashes;
archived copies normalize local links and whitespace only. Citations to `audit-input/` refer
to the session ruling/planning snapshots supplied alongside the frozen code;
the committed current planning authority is `TODO-round9.md`/`TODO-round10.md`
at `47b907bc` and subsequent explicit user decisions.

Discuss the seven corrections and four decisions with the user before creating
implementation lanes. Suggested first correction batch: refinement state,
book provenance and mounted PvP refusal. Keep mapgen material work separate
until Rock Salt and cave boundaries are resolved. Asset selection proceeds as
an independently authorized visual proposal task; it changes no gameplay.
