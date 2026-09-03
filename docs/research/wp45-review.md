# WP45 Independent Review Record

Status: **CLEAN**. No open findings remain.

## Reviewed revisions

- Base: `21841c9543a18ea2fbb4649b6664ed0ae98bd125`
- Initial implementation head: `8a51a393197527e6a16464b640215c5d90779555`
- Final code head after the review fixes:
  `737f1e7529406e9767be0a5e586fad5d49043346`

The reviewer was a fresh GPT-5.6 Sol context and did not participate in the
implementation. It reviewed the complete WP45 diff, the work-package contract,
the process and Lua 5.1 rules, the relevant world design, every changed
production/test file and the pinned Luanti engine behavior. No Claude model was
used because the user explicitly requested the available Sol review path.

The main lenses were callback and mod-load ordering; initial-position safety;
engine immortality; external physics writers; asynchronous emerge actions;
ObjectRef re-fetch; exact-once commit; faction/race identity changes; admin,
disconnect, reconnect, death and stale-callback paths; formspec behavior;
state restoration; Lua 5.1 compatibility; steady-state cost; and harness
fidelity.

## Findings and resolution

The initial full review found **0 Critical, 1 High, 3 Medium and 1 Low**:

1. **High — later physics writers could break stasis.** A Giant Spider slow
   could set a still-incomplete player's speed after the initial lock even when
   immortality rejected its damage.
2. **Medium — a ready spawn cache was not revalidated at commit.** An admin
   race change after prefetch could place the new race at the old race's start.
3. **Medium — admin faction changes bypassed the coordinator.** The command
   launched its own teleport and could move a classless player early, followed
   by a second creation teleport.
4. **Medium — a persisted dead incomplete player remained dead.** Creation UI
   replaced the builtin death form, while class stat application deliberately
   does not heal zero HP.
5. **Low — package counts and current-state text still ended at WP44.**

Commit `737f1e7529406e9767be0a5e586fad5d49043346` fixed the four technical
findings and extended the regression fixture. Active creation sessions now
receive a throttled compare-before-write reassertion of frozen physics, zero
velocity and immortality. Every faction set notifies the coordinator; the
admin path no longer starts an independent teleport. Every final commit checks
the exact faction/race identity, invalidates stale generations and emerges the
replacement destination. Admin race/class changes join the same transaction,
and a first admin-picked class remains transient. Creation stasis suppresses
the respawn callback's eager repositioning; if an incomplete player is still
dead at completion, the final positioning and class commit are followed by a
full-class-HP revival. This completion documentation closes the Low finding.

The focused review verified every technical fix, found no regression and
returned **CLEAN: 0 Critical / 0 High / 0 Medium / 0 Low** for code, with only
the then-authorized completion-documentation follow-up pending.

## Verification

The frozen final Lua candidate passed:

- `tools/wp45/run.sh` under LuaJIT.
- One final compact PUC Lua 5.1 process and the same fixture once under
  LuaJIT, with byte-identical canonical output:
  `wp45_character_creation_v1|fresh_teleports=1|prefetched_teleports=1|retry_teleports=1|rejoin_teleports=1|class_sets=7|chats=19`.
- `tools/bin/luac51 -p` for every project mod Lua file and the WP45 fixture.
- `SETGLOBAL` inspection for both changed mod files and the standalone mock.
- All five Lua compatibility sweeps, with matches classified as comments or
  ordinary text delimiters.
- `bash -n tools/wp45/run.sh` and `git diff --check`.

Final frozen-file SHA-256 values:

- `8fc1d5143fd506f76d2ef121c85b72eeaf93c05be4cb72e400fa053568b11447`
  — `mods/PLAYER/grug_factions/init.lua`
- `0fed850efa1fdb447ce9298863e998df11cfd5de5c155efc61466a3f6e989592`
  — `mods/PLAYER/grug_classes/selection.lua`
- `d38d624e7bda7a86a25c2bf1caef3648889192c721907cc56430dfc029726912`
  — `tools/wp45/character_creation_test.lua`
- `959369f0d396e7c71fe49452a517de11e40a38751bb7b88fe5d99d94369ed531`
  — `tools/wp45/run.sh`

At the independent-review gate, no map population, fresh-world, GUI or in-game
runtime test had been performed. WP45 changes no mapgen bytes and therefore
required only the short user runtime pass recorded at handoff.

## Runtime acceptance

The user completed the short Flatpak Luanti runtime pass on 2026-09-03 after
the reviewed build was synced locally. Both an existing character and a new
character completed their expected flows, and inspection of `debug.txt` found
no relevant Lua error or fatal engine error. No map population or fresh-world
run was required because WP45 changes no mapgen bytes. The executed GUI scope
did not disconnect an incomplete character in the middle of creation; that
reconnect path remains covered by the headless callback harness only.
