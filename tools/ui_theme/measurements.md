# Crafting and container presentation measurements

Measured 2026-10-24 with LuaJIT portable fixtures. Baseline: `0ab3aea0`.
UI implementation: `9854ed2337bf17929793191c492dfaf8a1174c3b` (includes `23db5587`, the shared hotbar theme).
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
| Basic page 1, no recipe selected | 3099 / 4499 | 3507 / 5428 |
| Profession area, two recipes | 1729 / 3129 | 2171 / 4092 |
| Selected recipe during a job | 2566 / 3966 | 3269 / 5190 |
| Raw dish with cooked-item description | 2592 / 3992 | 3207 / 5128 |
| Gear recipe with generated item description | 2275 / 3675 | 2888 / 4809 |

The forms are larger because panels, roles and shared navigation add elements.
Both versions retain the fixture's traffic behavior: one resend at job start,
one at completion, one at cancellation, none for a pure inventory-scroll
event, and none for a search suppressed by the existing cooldown. Progress
still uses the original client animation rather than periodic UI updates.

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
normalization, state-change detection and lag buffers. The full animation
fixture passed 207 checks before the final hotbar-only style correction;
the measurement above includes that correction.

The integrated container fixture also passed 1125 checks, including node and
detached lists, shift-click rings, scroll preservation, hotbar switching,
per-viewer inventory and seven sign-field/quit/protection checks. Desktop
and web-client GUI verification remains the user's acceptance step.
