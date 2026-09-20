# Source checkpoint — review in progress

Production is implemented; this is not completion or acceptance. The integrated
final PUC/LuaJIT pair belongs to the orchestrator and remains pending, as do the
bounded live placement/current-save witness and independent review.

The real engine loaded the complete game and strict manifest successfully on
port 32751; the first probe then exceeded the default sixteen-block forceload
budget. Its corrected sampling holds only four blocks. Live evidence follows
in an addendum; that initial run proves load order, not placement acceptance.

`regressions-first.log` preserves three failures. The WP13 library and blueprint
failures were obsolete soil expectations, corrected without changing placement
geometry; both pass in `regressions-corrected-2.log`. The older R6 micro fixture
omitted the now-required stone surface-skin host. Adding that actual host exposes
a second `fail_content_ignore` context failure in its synthetic ignore case,
which remains under diagnosis; do not count that job as passing. Current R7
micro, MAP-B actual writer, placement and registration fixtures pass.

`template-refs.log` proves all 21 MTS / 84 rotations retain their decoded geometry:
normalizing the 692 content references shifted by the new soil names exactly
recovers the prior graph hash. No MTS bytes changed. The complete natural-ground
roster is now 25 entries; all strict production/catalog/projection constants are
mechanically derived in `pins-complete-roster.tsv`, not relaxed assertions.

Portable integration calls registration once (including the real FARM fixture)
and placement once (including actual content resolver). Full runtime assembly,
MTS/reference parity and the actual large private-writer fixture remain LuaJIT
checks. Historical changed-production roster 157 remains frozen; added modules
are covered by these dedicated fixtures and global input binding.
