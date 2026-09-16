# WP26 evidence — 2026-09-16 (WP13 wave 3, lane C)

Everything here was produced from the lane worktree on branch
`wp13-w3-wp26-furnace`, with `LC_ALL=C`, every engine run through
`tools/luanti_headless.sh` under `nice -n 19` on ports 31401–31406.
`files.sha256` pins the sources these results belong to.

## What was run

| Gate | Command | Result |
|---|---|---|
| KAT, LuaJIT | `luajit -e 'io.write(dofile("tools/wp26/smelting_kat.lua")("."))'` | `kat.luajit.txt`, sha256 `42a9b1490b0294fda25792ac96a8899fdb5656d9e469db4e905ca012e7e4e3d9` |
| KAT, PUC 5.1 | `tools/bin/lua51 -e 'io.write(dofile("tools/wp26/smelting_kat.lua")("."))'` | `kat.puc51.txt`, **same** sha256 |
| KAT mutation gate | `mutations.txt` | eight deliberate breaks, eight red KATs, green again after restore |
| Static gates | `bash tools/wp26/evidence/20260916/static.sh` | `static.out.txt`, exit 0 |
| Fresh-server audit | `python3 tools/check_fresh_server.py` | PASS (inside `static.out.txt`) |
| In-engine smelt probe | `PROBE=tools/wp26/smelt_probe PORT=31401 tools/luanti_headless.sh 110` | `logs/probe.31401.log` — PROBE PASS |
| Clean boot, user seed | `SEED=15912857179583385436 PORT=31402 tools/luanti_headless.sh 60` | `logs/boot.userseed.with-smelting.log` — PASS, 0 errors (re-run on the rebased tree; warning set still identical to the no-mod baseline) |
| Same boot without the mod | `SEED=15912857179583385436 PORT=31405 …` | `logs/boot.userseed.without-smelting.log` — PASS, 0 errors |
| WP13 start identities | `luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua . \| sha256sum` | `0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`, unchanged from main |
| Highcourt blueprint digests | `luajit tools/wp13/highcourt_identities.lua .` | output sha256 `66e2ed00fc77d1c422d1a03428481114705a6b29a44b3aa241ada42cb9998f79`, unchanged from main |
| WP13 final micro pair | `tools/wp13/final_micro.lua . <out> luajit\|puc51` | both `5bb22bb88bd0d10a616d00d70675d0cfa45bd8dbab477b37e82c0ee8e1778f82` |
| WP40 R7 unit | `bash tools/wp40/r7/run.sh unit` | PASS |

## The numbers this lane measured

**Cook times are WP26 calibration, not frozen design numbers** (task card §1,
"No number freezing"). What was chosen, and what the engine then actually did:

| Recipe | Station | Chosen time | Measured in the engine |
|---|---|---|---|
| lump → bar (all five) | normal furnace | 3 s | `default:copper_lump` → `grug_materials:copper_bar` in 3 s |
| Copper + Tin → Bronze | dual furnace | 4 s | first Bronze Bar after **4 s** wall clock |
| Iron + mined Coal → Steel | dual furnace | 6 s | first Steel Bar after **6 s** wall clock |
| Steel + Silver → Silversteel | dual furnace | 8 s | KAT only (10 alloy runs, both slot orders) |
| Silversteel + Emberglass → Embersteel | dual furnace | 10 s | KAT only |
| Embersteel + Abyssal Crystal → Abyssal Steel | dual furnace | 12 s | KAT only |

The ladder is monotone and starts one second above the normal furnace, so the
first station upgrade never feels slower than the station it replaces. No other
work package reads these literals.

**The recipe surface**: 5 cooking + 5 `dualfurn` + 12 storage pack/unpack pairs
+ 1 station recipe = 23 registrations, and the server says so at every start:

    ACTION[Main]: [grug_smelting] recipe audit passed: 5 cooking, 5 dualfurn,
                  12 storage pairs, 1 station

**Reachability**: from mined items alone the forward closure needs 2 rounds and
reaches every tier bar — Iron at depth 1, Bronze and Steel at 2, Silversteel 3,
Embersteel 4, Abyssal Steel 5 (`kat.luajit.txt`, `wp26_reachable` rows).

**The audits did not move.** On the user's world seed the boot log with the new
mod and the boot log without it carry the **same 60 warnings** and **zero
error lines**; the only new line is `grug_smelting`'s own informational
`action`. Diff:

    grep -o 'WARNING\[Main\]:.*' logs/boot.userseed.with-smelting.log    | sort >a
    grep -o 'WARNING\[Main\]:.*' logs/boot.userseed.without-smelting.log | sort >b
    diff a b   # empty

## The in-engine probe, verbatim

`logs/probe.31401.log` (full server log in `probe.31401.full.log`). Three dual
furnaces in one forceloaded mapblock:

    [probe] case A_bronze: first output after 4 s -- grug_materials:bronze_bar x1,
            inputs left 2/2, node grug_smelting:dual_furnace_active
    [probe] case C_coal_is_a_material: first output after 6 s -- grug_materials:steel_bar x1,
            inputs left 2/2, node grug_smelting:dual_furnace_active
    [probe] case B_coal_is_only_fuel PASS: nothing after 45 s, 3 Iron Bar(s) still in slot 1
    [probe] D_midcook_swap: swapped both material slots at t+4 s; output held 0 item(s)
    [probe] D_midcook_swap PASS: nothing new for 3 s after the swap
    [probe] D_midcook_swap: 3 grug_materials:bronze_bar after the swap, inputs left 0/0
    [probe] audit negative test: 'grug_materials:iron_bar' x9 is worth 27c at the vendor
            but its dualfurn recipe consumes only 4c worth of priced inputs
            (mobs:leather, mobs:meat_raw) — items_crafting.md §3.8 anti-loop rule
    [probe] PROBE PASS

Case B is task-card gate 2 in the engine: Coal burning in the **fuel** slot
never stands in for the Coal a Steel Bar consumes. Case D is the review's
finding 1 in the engine: four seconds into a six-second Steel both material
slots become a four-second Bronze, and nothing new may come out until that
Bronze has had its own cook time. The assertion is "no NEW output within three
seconds of the swap" rather than "no output at second N", because the probe
polls at one-second granularity and whether the Steel itself finished first is
a coin toss — while the property under test holds either way.

## The mutation gate

`mutations.txt`. Each line below is a rule broken on purpose, and the message
the KAT then produced:

| Broken rule | KAT says |
|---|---|
| an alloy consumes a regional gem (gate 5) | `grug_materials:steel_bar consumes … grug_materials:rough_garnet, not … default:coal_lump` |
| one storage pair missing (§3.4) | `nine grug_materials:gold_bar do not pack into grug_materials:gold_block` |
| the timer consumes only slot 1 (gate 3) | `grug_materials:bronze_bar did not consume exactly one of each input` |
| the fuel slot accepts a non-fuel (gate 2) | `the fuel slot accepted an Iron Bar` |
| an alloy output missing (§3.3) | `4 dualfurn recipes, not 5` |
| `src_time` carried into a shorter recipe (review finding 1) | `the swapped-in Bronze finished instantly on 5 s of SOMEONE ELSE'S progress: grug_materials:bronze_bar` |
| a non-fuel leftover written back into the fuel slot (finding 6) | `the burnt flask's leftover is sitting in the fuel slot, where it blocks every future refuel` |
| the refuel does not consume the fuel stack (finding 3 coverage) | `30 bars burnt 0 Coal, not the 3 that 120 s of cooking costs` |

## The fix round (independent review, 2026-09-16)

The reviewer's SHOULD-FIX 1 and NITs 3 and 6 are taken; the KAT grew three
cases that go red without each of them (rows `wp26_midcook_swap`,
`wp26_multi_fuel_unit`, `wp26_fuel_leftover` in `kat.luajit.txt`), and the
engine probe grew case D.

| Finding | What changed | Gate that now covers it |
|---|---|---|
| 1 — negative `step` on a mid-cook recipe change | `node.lua` remembers which recipe `src_time` belongs to (`src_recipe` in node meta) and drops the progress when the match changes; a `step < 0` clamp is kept as belt and braces | KAT case (f), which reproduces the reviewer's exact sequence (5 s of Steel, swap to Bronze, one tick) and asserts `src_time == 1` and `fuel_time == before + 1`; engine probe case D |
| 3 — the fuel stub lost the stack count | the stub copies name **and** count from the real stack | KAT case (g): 30 Copper + 30 Tin on 9 Coal makes 30 bars and burns exactly 3 Coal, so the refuel branch runs three times in one call |
| 6 — MTG's "do not block the fuel slot" branch | ported from `default/furnace.lua:212-219`; a leftover that is not itself fuel is moved to the output instead of written back | KAT case (h), with a synthetic flask fuel in the stub, since nothing Grudgelands ships has a leftover |

Findings 2, 4, 5 and 7 are merge mechanics, a named shared-file touch, a
WP44 boundary question and a docs sweep — handled in the lane report, not in
the code.

## Art

`dual_furnace_faces.png` — the vendored furnace front next to the re-skinned
dual front at 8×, the two shared side/top faces, and the eight frames of the
active strip. Regenerate with `python3 tools/wp26/render_dual_furnace.py`;
regenerate the textures themselves with
`python3 tools/wp26/gen_dual_furnace_textures.py` (`--check` fails on drift).

## Ports and processes

Ports used: 31401 (probe, re-run after the fix round), 31402 (the user-seed
boot on the rebased tree), 31403/31404/31405/31406 (the earlier boot pairs,
whose logs are archived here). No
process of this lane's port block 31400–31499 was left running; the
`luanti.bin` process without `--server` on this workstation is the user's own
GUI client and was never touched.
