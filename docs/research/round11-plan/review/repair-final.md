# R11 REPAIR final focused re-review

Candidate: `20ab7b50b57f2b9bcc14cccb7106142de45a8548`  
Review: fresh native GPT-5.6 Sol, read-only  
Result: **clean — no substantive findings**

The final correction resolves the remaining metadata/cadence defect. Repair
wear and first projectile-identity writes publish the explicit
`durability_metadata` reason after invalidating the ordinary equipment caches.
The real ability consumer refreshes its concrete comparison snapshot while both
the previous and current effective weapons remain nonempty and have the same
registered name; it preserves `next_due`, late carry, the queued input latch and
the accumulated-melee state. A true A→B replacement still takes the ordinary
path, clears accumulated melee and starts one full interval.

The nonempty guard correctly keeps broken/unbroken transitions out of the
metadata-only shortcut. At exhaustion the effective equipped weapon becomes
bare hands immediately and receives the appropriate conservative full-interval
reset. Repair changes it back from bare hands to the restored weapon and also
receives a full reset. A worn but still usable weapon and first persistent-ID
assignment do not reset cadence, including repeated notifications.

The strengthened runtime KAT now proves the first debit for both shared
heal/absorb identity and an ordinary table context before proving deduplication.
The WP39 fixture loads the actual equipment-change consumer with metadata- and
wear-sensitive `ItemStack:equals`; it exercises preserved late carry, preserved
input latch, repeated durability notifications, a real A→B swap, exhaustion and
repair transitions.

Targeted LuaJIT verification rerun on the frozen bytes:

- `tools/r11_repair/runtime_kat.lua`: pass;
- `tools/r11_combat/armor_kat.lua`: pass;
- `tools/wp39/swing_aim_test.lua`: pass;
- `git diff --check c53a512d..20ab7b50`: pass.

The earlier ordinary-table finding remains retracted: Lua's `and/or` expression
falls back to the original table when `.id` is nil, and the strengthened
first-debit assertion now covers that behavior directly.

No PUC runtime, broad suite, production edit, commit, sync, push or user-world
mutation was performed.
