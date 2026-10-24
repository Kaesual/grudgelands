# Crafting and container presentation measurements

Measured 2026-10-24 with LuaJIT portable fixtures. Baseline: `0ab3aea0`.
UI implementation: `3fff1faf7836472fcc8d942a5c3e0e22db7a66e7`, after the review corrections. Both byte probes were rerun on that integrated commit.
These are comparisons of the same scripted states, not performance budgets.

## Method and limits

The baseline was read with `git archive 0ab3aea0` into
`/tmp/grug-ui-craft-baseline-0ab3aea0`, limited to the two fixtures, their
`r44_ch` harness, sfinv, the furnace/node-form builders, inventory/jobs/
achievements modules and the gear permissions helper (1.34 MB archive).
The main checkout was not changed. Each tree used its own fixture and game
sources; the UI fixture's changed assertions cover presentation only.

Commands, run from the respective source tree:

- `luajit tools/r45_ui/portable_test.lua .`
- `luajit tools/r491_anim/portable_test.lua . measure`

Bytes are raw Lua formspec-string lengths. They exclude protocol compression,
media transfer, client rendering and the formspec prepend sent at login.
The engine, inventory and clock are fixture stand-ins. No Luanti GUI or
production-server performance result is claimed.

## Crafting

All transaction, ingredient, quantity, focus, search-throttling and resend
assertions remain. Baseline: 302 checks passed. UI: 305 checks passed (the
single combined tab-style assertion became four individual button checks).

| Same scripted page | Baseline content / whole form bytes | UI content / whole form bytes |
|---|---:|---:|
| Basic page 1, no recipe selected | 3099 / 4499 | 3525 / 5446 |
| Profession area, two recipes | 1729 / 3129 | 2190 / 4111 |
| Selected recipe during a job | 2566 / 3966 | 3287 / 5208 |
| Raw dish with cooked-item description | 2592 / 3992 | 3225 / 5146 |
| Gear recipe with generated item description | 2275 / 3675 | 2907 / 4828 |

The forms are larger because panels, roles and shared navigation add elements.
Both versions retain the fixture's traffic behavior: one resend at job start,
one at completion, one at cancellation, none for a pure inventory-scroll
event, and none for a search suppressed by the existing cooldown. Progress
still uses the original client animation rather than periodic UI updates.

### Form construction cost

A bounded CPU probe uses the fixture's initial Basic page, no selected recipe,
and the real `sfinv.get_formspec` in each tree (baseline `0ab3aea0`, UI
`3fff1faf`). After 500 warm-up builds, five samples each build the same form
10,000 times, using `os.clock` process CPU time. The two LuaJIT processes run
sequentially under idle CPU/I/O scheduling. Temporary probe copies stop after
this measurement; they do not alter the shipped fixture or production code.

| CPU microseconds per form | Baseline | UI |
|---|---:|---:|
| Sample 1 | 64.081 | 75.689 |
| Sample 2 | 65.386 | 74.616 |
| Sample 3 | 64.280 | 74.744 |
| Sample 4 | 64.176 | 74.231 |
| Sample 5 | 64.222 | 74.428 |
| Median | 64.222 | 74.616 |

The median increase is 10.394 microseconds (16.2%) for this small scripted
page. This measures Lua construction with stand-in inventories, not live
server latency, client rendering or a performance budget. The probe sources,
method and logs accompany the private implementation review archive.

## Furnace workspace

Same player with four bags (16, 8, 16, 8 slots), five coal lumps, thirty ore
items at ten seconds per item, sixty simulated seconds. The measurement
excludes opening and initial input/start resends and sums subsequent forms.

| Measurement | Baseline | UI |
|---|---:|---:|
| Resends during the minute | 6 | 6 |
| Total formspec bytes | 17432 | 18086 |
| Final form bytes | 2906 | 3015 |

The byte increase is 654 bytes over the minute (about 3.8%); resend frequency
is unchanged. The unchanged animation owner retains its frame-start
normalization, state-change detection and lag buffers. The final integrated animation fixture passed 207 checks; the measurement
above uses the same integrated commit.

The integrated container fixture also passed 1125 checks, including node and
detached lists, shift-click rings, scroll preservation, hotbar switching,
per-viewer inventory and seven sign-field/quit/protection checks. Desktop
and web-client GUI verification remains the user's acceptance step.
