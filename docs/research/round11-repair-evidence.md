# Round 11 REPAIR evidence

Date: 2026-09-20. Implementation model: native GPT-5.6 Sol. This package is
non-trivial and requires a fresh independent review before integration.

The package preserves exhausted stacks at wear 65535, applies 3000-event
combat wear (6000 when refined), suppresses broken base/affix/refinement and
tool effects, and restores the exact stack through the quoted atomic city
service. Incoming wear is driven by COMBAT's post-mitigation, nonlethal actual
HP-loss seam. Successful damage, in-combat effective healing and in-combat
effective absorbs drive outgoing wear. Action IDs deduplicate settlement;
Fireball captures its concrete launch-time weapon and spellbook so a later
equipment swap cannot wear the replacement.

The registered-item audit requires every eligible identity to have an explicit
GEAR reference purchase price. Repair preserves ordinary metadata and clears
only the durability remainder and the temporary broken-capability snapshot.
Creative actions, misses, cancellations, full absorbs, lethal hits and
environmental damage do not spend combat durability.

Verification on the frozen candidate:

- plain Lua 5.1 parser over every changed Lua file: pass;
- changed-file `SETGLOBAL` inspection: only the established mod globals;
- five Lua compatibility/sandbox sweeps: no changed-code violation;
- `tools/r11_repair/service_kat.lua` under LuaJIT: pass;
- `tools/r11_combat/armor_kat.lua` under LuaJIT: pass;
- `tools/wp39/projectile_test.lua` under LuaJIT: pass;
- `git diff --check`: pass.

No PUC runtime, broad suite, sync, push or user-world mutation was performed.
