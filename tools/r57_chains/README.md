# tools/r57_chains — the recipe chain depth report (Round 57 CHAINDEPTH)

The first step of ruling 8 of the [Round 57 plan](../../docs/planning/round57-plan.md): per
recipe, how long the chain of crafted ingredients down to raw materials is, how many distinct
crafted steps its tree has and which Basic recipes lie on the way. It changes no recipe. The walk
is also the basis of ruling 6, the recursive Basic unlock (see [Use by CRAFT](#use-by-craft)).

## Files and runs

| File | What it does |
|---|---|
| `run.sh OUT_DIR` | One boot through the shared queue: `dump.sh`, then `generate.lua`. Writes `OUT_DIR/dump.lua`, `report.txt` and `index.html`. `DUMP=<file>` skips the boot. |
| `dump.sh OUT_FILE` | Boots the game headless (`tools/luanti_headless.sh`) with the disposable probe `grug_probe_r57_chains` and copies its dump. The first line names the commit. |
| `grug_probe_r57_chains/` | Never shipped. One second after load it writes what the game registered: `grug_jobs.recipes`, every engine `cooking` route (`core.get_all_craft_recipes`), `grug_smelting.RECIPES`, the station operations, the members of every group token, the items' descriptions and the aliases. The engine's grid routes are only counted: the craft grid has no slots since Round 45. |
| `steps.lua` | The dump as crafted steps: registry rows by their id, `furnace:<output><<input>`, `alloy:<output>`; aliases resolved. |
| `chains.lua` | The walk: pure Lua 5.1, no engine call, no global. |
| `generate.lua DUMP OUT_DIR` | The text report and the page (`page.html` is its template; the page loads nothing from outside). |
| `portable_test.lua` | The fixture (`run_fixtures.sh r57_chains`). |

Example: `~/projects/grudgelands-orchestration/r45/lua_run.sh chains 1 tools/r57_chains/run.sh /tmp/chains`.

## The walk

`chains.analyse(steps, members)`:

- `steps`: a list of `{id, output, count, ingredients = {{item = name, n} | {group = name, n}},
  basic = true|nil}`; ids are unique.
- `members`: group name (no `group:` prefix) → its item names.

Definitions:

- An item is **raw** when no step makes it, or only steps the loop rules remove.
- A step's **depth** is 1 + its deepest ingredient (raw is 0). An item's depth is its shallowest
  step's. Furnace and dual furnace steps count like any recipe.
- A **group** ingredient is its cheapest member: the shallowest, then the fewest steps, then the
  first name.
- **Several steps for one item:** the item's source is the shallowest, then the one with the fewest
  steps, then the first id.
- A step's **steps** are the distinct steps of its tree, itself included. Its **Basic list** is the
  Basic steps of that tree, itself left out.

**Loops** (the item graph's strongly connected components) are broken by `chains.RULES`, in this
order:

1. `unpack`: a loop step that splits one item into several of another (one ingredient, `n = 1`,
   `count > 1`: a block into 9 bars, a sandstone into 4 sand) never counts as a source.
2. `cut_back`: a loop step whose one ingredient is made by a single step from this step's output
   alone (stair or slab back to its block) never counts as a source. If two steps would cut each
   other, neither is cut.
3. `shallower`: the depth fixpoint itself. A loop step is always deeper than the step that enters
   the loop from outside, so it is never the source.
4. `seed`: if a loop is left that nothing outside feeds, its item named most often as an
   ingredient by steps outside the loop (then the first name) counts as raw, and the walk repeats.
   On today's data this happens to White Wool and to Red and Blue Dye.

The result is the same for any order of `steps`. The result holds:

- `steps[id]`: `depth`, `steps`, `basics` (sorted ids), `chosen` (the item each ingredient
  resolves to), `source` (whether the step is its output's source), `broken` (`unpack` or
  `cut_back`), `loop`, `alternatives` (how many steps make the output);
- `items[name]`: `depth`, `raw`, `seeded`, `via` (the source step), `steps`, `tree`;
- `groups[name]`: the member chosen;
- `loops`: each with `items`, `steps` (`{id, rule}`, where `rule` is nil for a source) and `seeds`;
- `seeded` and `order` (every step id, deepest first, then the most steps, then by id).

`chains.path(result, id)` gives the longest chain, following the deepest ingredient.
`chains.consume(result, ingredients)` gives the depth, steps and Basic list of what an enchant or
an upgrade consumes.

## Use by CRAFT

For ruling 6, the Basic recipes a profession tier needs are the union of `steps[id].basics` over
that tier's recipes. An enchant's or upgrade's are `chains.consume(result, op.ingredients).basics`.
The game can build the same input at load from `grug_jobs.recipes`, the furnace routes and
`grug_smelting.RECIPES`; `steps.lua` shows the mapping. The walk over today's 699 steps takes about 4 ms in LuaJIT (measured).

Two points follow from the definitions and are open for CRAFT:

- The Basic list follows the **chosen** tree: one source per item, and a group's cheapest member
  only. Planks from Acacia Bush Stem stand for `group:wood`. Other members' and alternatives'
  Basic recipes are not on the list.
- A loop-back step (for example Coal Lump ×9 from a Coal Block) is never on the way.

## The report

`report.txt` and `index.html` hold the same content:

- the legend and the rules;
- the recipes per depth by area, without the loop-back steps (`unpack`, `cut_back`);
- the ten deepest recipes with their chains;
- every recipe with its ingredients, Basic list, notes (alternatives, loop rule, group → member)
  and longest chain;
- the enchants and upgrades with the depth of what they consume (an upgrade per level, a weapon's
  Stick included);
- the loops with the rule for each step;
- the raw materials.

The page has a sortable table, a filter by area that the operations table follows too, and a
search.
