# Round 11 final integration fixes — independent review

Reviewer: native Sol, independent of both production fixes.  
Scope: frozen root-worktree Arrow price/audit correction and planner-source schema correction only.  
Result: **CLEAN — no substantive findings.**

## Trader correction

Reviewed frozen bytes:

- `mods/ENTITIES/grug_traders/init.lua` — `85dd246130686b1fde63c6a7bebeac8478bee16c511eff8158e019f0677e9a90`
- `mods/ENTITIES/grug_traders/stock.lua` — `c8029198af0a323cb2719c3887e18436a4d4349c43dd09f217b95f5e570d3b2a`
- `tools/r11_scout_traders/stock_kat.lua` — `8aae42ebfd227cbcc4441b54748b381914dea9f0b74f7705353ec338386ebc56`

The original engine log correctly identifies the loop: the former 2c Arrow offer discounts to 1c and buys back for 1c. The corrected 3c ordinary offer uses the unchanged ceiling-rounded 20% discount and therefore charges 2c while buy-back remains 1c. No design source fixes Arrow at 2c, and no other Bowyer price changed.

`audit_sell_buy_prices()` is the previous complete startup walk extracted without weakening its coverage: ordinary stock, every profession shelf and every gear bracket still pass through the same discounted-price versus actual sell-price comparison. Startup still invokes it after stock initialization. The focused fixture loads the real `init.lua` and `stock.lua`, proves the old 2c value produces exactly the Arrow failure, proves the corrected 3c value produces none, holds all other Bowyer prices fixed, and retains the real trade path coverage.

Independent targeted LuaJIT result: `r11 scout trader stock KAT: ok`.

## Planner-source correction

Reviewed frozen bytes:

- `mods/MAPGEN/grug_mapgen/wp40/planner.lua` — `f5b275c610bc7f4fb61fd608680018ad642be9648742aac7deba973a54c1a44a`
- `tools/r11_integration/planner_source_kat.lua` — `8aad93c848b0388eb6f3721993f9397a1199416086b045cb8153f8d9686bdc6c`
- the three adjusted fixture-source hashes match `/tmp/grudgelands-r11-planner-evidence.md`.

The production schema now names all four current runtime-zone callbacks and requires each to be a function. Exactness remains intact: unknown fields are still rejected, while omission of each new field and a wrong-typed value are separately rejected. The change does not relax unrelated source fields or alter planner geometry.

The new focused fixture crosses the required real consumer boundary: runtime `zones.lua` source construction → `r5.new_runtime` → production `planner.new` → a bounded one-column `plan_slice`. It also calls the four concrete bridge functions, including a true `hard_row_at` result on authored foundation, and tests missing, wrong-type and unknown-field failures. Only the unrelated VM adapter is stubbed; no population or broad mapgen suite is implied.

Independent targeted LuaJIT result: `r11_planner_source live_constructor one_column four_required_methods PASS`.

`git diff --check` passes. I did not run PUC runtime, a broad suite, a VM population, or duplicate the native engine witness. The retained headless log is valid evidence of the two pre-fix failures; the coordinator's bounded post-fix engine-probe rerun remains the appropriate final runtime gate.
