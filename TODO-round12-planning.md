# TODO — Round 12 scope and playtest decisions

Date: 2026-09-20. State: discussion, not implementation approval for new design.
The vegetation pursuit fix has been accepted in the user's GUI playtest.
The user now requests feedback, a current-code audit and the next round's scope.

## Authorized immediate interaction fixes

The current `wp11-interaction-followups` branch, based on `cca8b7ce`, covers:

1. Skill-independent maximum dropped-item pickup distance, including Smite LMB.
2. A/D strafing on ground and flying mounts, preserving total diagonal speed.
3. One right-click action: an NPC interaction takes precedence over the held
   mount activation, preventing simultaneous mounting and opening the NPC UI.

These corrections receive independent review and targeted tests before delivery.
No PUC runtime or broad mapgen/performance run is scheduled under the current
session override. Native Sol implements; root coordinates; no Claude/CLI agents.

## Recipe visibility and onboarding

The accepted visibility choice is now in `items_crafting.md` §2.2 and
`inventory_equipment.md` §4. Still open for the implementation brief: the exact
starter-recipe set and explicit per-recipe main-material attribution. Recommend
treating any normal inventory acquisition (pickup, crafting, trading or container
transfer) consistently; avoid a ground-pickup-only rule that hides recipes for
materials a player crafted. If a full-catalog preview is desirable, it needs a
separate explicit UI decision. Do not silently add it as another default view.

The furnace belongs below the recipe's input-to-output arrow as a required
station indicator. Do not depict a furnace as a consumed ingredient. The UI
must distinguish genuine 3x3 recipes from furnace inputs and other station
layouts. The source audit confirms this indicator can move without changing recipe inputs.

The Help page should begin with a short first-session route: gather materials,
consult Basics, craft/equip a weapon, select a combat skill, fight and recover,
then find city services and professions. Describe only implemented progression;
do not direct beginners toward unimplemented quests or Housing. Explain the approved main-material discovery rule; acquiring material reveals
recipes in the book, rather than granting crafting permission.

## Art, farming and interface quality

- Wand art: current code uses a recolored `default_mese_crystal_fragment.png`.
  Propose 2–3 coherent wand directions, compare inventory-scale icons and held
  silhouettes, then apply the chosen design across the tier ladder. Other
  accepted weapon families are outside this art revision.
- Plants: inspect actual pinned sources rather than assuming VoxeLibre has
  corn. Recommend recognizable growth stages, family-appropriate world shapes,
  and explicitly decided immature/mature harvest drops; tall corn is a bounded
  showcase. Multi-node growth must respect space, protection and whole-plant
  harvesting. A current food/farming report precedes final scope selection.
- UI fixes: audit cramped layouts and overlapping controls; use deliberate
  widths, wrapping and spacing rather than globally scaling every window.
  Talent tooltips need paragraph/line wrapping, with the same check across
  other long tooltips. Verify engine support and actual formspec generation.
- UI/UX Quality: report-only first-session walkthrough, recording concrete
  friction, reproduction, severity and a proposed correction. Findings return
  to the user for selection; the audit does not independently authorize them.

## Candidate next implementation scope

Recommended lanes, subject to user approval after the current audits:

1. Recipe discovery, book presentation and Help onboarding, with the chosen
   visibility contract written into living design first.
2. Inventory/talent layout and tooltip readability corrections.
3. Farming growth/harvest presentation and food discoverability; add missing
   recovery mechanics only if the code audit proves a gap against decided design.
4. Bounded wand/style work with a visual selection checkpoint.
5. WP11's remaining original-class keystone/capstone consumers as the main
   gameplay extension, preserving Scout and delivered tank armor behavior.
6. Separate report-only UI/UX audit whose recommendations are discussed before
   implementation.

Defer full Housing, war fronts and the economy rebase from this round's core
scope. Parties (WP20) are a useful subsequent cooperative milestone. The full
WP21 innkeeper/rest/insurance package should not be silently folded into a food
visibility fix. Parallel work uses explicit file ownership and independent
review; shared talent UI and talent gameplay edits require an integration seam.

When approved, fold decisions into `docs/design/`, publish bounded work packages
and acceptance criteria, and remove this TODO once no open decisions remain.

## Completed baseline audits

- [Food and farming](docs/research/round12-food-farming-audit.md): 47 edible
  items, 18 tiered Cooking dishes and all six Caster dishes already exist. No
  food-specific Creative exclusion was found in source; improve findability.
  All 17 crops have four stages and correct seed-only immature drops, but
  generic single-node geometry. VoxeLibre has no corn in our pinned version;
  x_farming supplies current corn art, Lord of the Test supplies a true stacked
  corn reference. Recommend a visual family pass; true three-node corn is an
  explicit bounded option, not an implicit full farming rewrite.
- [Recipes and UI](docs/research/round12-recipes-ui-audit.md): all six base-gear
  tiers are craftable already. Current discovery requires every input, which
  the approved main-material rule replaces. Character preview/stat overlap,
  unbounded stat labels, talent text crowding and unwrapped group tooltips are
  concrete UI targets. Engine tooltips accept explicit newlines but do not
  automatically wrap. The Help page currently contains combat formulas only.

The user approved the visibility rule, not all candidate Round 12 packages.
Next: present findings and proposed scope, then finish the implementation plan.
