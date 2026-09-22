# Round 17 — Home travel, combat readability and reliable ranged attacks

Approved by the user on 2026-09-22. Status: implemented and independently reviewed; final technical gates PASS.
Delivery and GUI status: [round17-completion.md](round17-completion.md).
Base: `2c0f444668e78f9d8904d53f751440536ade31f4` (Round 16 delivered).
Root: native Astra. This contract records the latest user decisions and
supersedes conflicting historical projectile/spawn/display rules. Living design
owners must be updated during implementation, not left as conflicting specs.
Execution and resumption: [round17-execution.md](round17-execution.md).

## Session constraints

- Standard unmodified Luanti clients only. No engine/client fork, upstream PR
  dependency, required client mods or SSCSM. Native own-provider agents only;
  Claude unavailable. Native Sol ordinarily; native Astra for HOME and COMBAT.
- Fresh-server development: no migrations/legacy readers. Same-version
  persistence, reconnect, death and entity lifecycle remain required.
- Independent strong review for each non-trivial package; author cannot review
  their own work. Root integrates and delivers main/sync/push after clean gates.
- Escalate unexpected major complexity before expanding a lane. No speculative
  PERF campaign, full-world generation, seed census, or multi-hour mapgen tests.
- Read AGENTS.md, wp-workflow.md, agent-model-policy.md and luanti-lua.md.
  LuaJIT for bounded development fixtures; luac51 parser/SETGLOBAL/five sweeps
  for every changed Lua (tools included). Root owns ONE compact final PUC/JIT
  parity pair on final integrated bytes. Agents must not run intermediate PUC
  runtime or broad historical gate scripts. At most seven interpreter processes
  workstation-wide; up to three workers plus root in the current native slots.
- GUI validation is user-run; any native probe uses an isolated scratch world.
  Reference pins/content stay read-only. No personal-world writes.

## A — HOME (Astra)

Exactly 12 authored home locations: six racial start towns and six capitals.
Default is the character's racial start town. Any of the six locations of the
character's faction may be bound through its innkeeper; enemy binding refused.
One innkeeper per location, integrated into an existing suitable building.
No new settlements or large new buildings. One canonical registry of stable
location IDs, faction, label, NPC location and safe arrival position derived
from existing terrain-resolved settlement authority; never free player coords.

Innkeeper UI offers `Set home here` or `This is your home`. Authenticate actual
nearby NPC interaction on submission, like existing trainers. Persist chosen ID
in player metadata. Add a Map-tab return-home button showing destination and
remaining cooldown, plus innkeeper/home atlas markers with labels.

Return is immediate, no cast/channel; allowed only alive and OUT of combat.
Use one persistent personal 1800-second real-time cooldown, elapsed while
logged out and across server restarts. Charge only after successful teleport.
Binding another home never resets cooldown. Death respawns at bound home,
independent of return cooldown and without changing it. Dismount before return.
Prepare destination safely; revalidate player/session/home/combat before async
completion and prevent duplicate requests. Death, disconnect, new session or
changed binding cannot complete a stale teleport. No new inventory skill/item.
Own faction/race creation fallback is retained for characters before binding.

Acceptance: all twelve authenticated sockets/registry rows; enemy refusal;
initial home; change/reload home; combat refusal; successful return cooldown;
failed emerge no charge; duplicate/stale completion; death cooldown independence;
map button and marker provider integration. No full terrain population required.

## B — COMBAT (Astra)

All targeted combat projectiles use one agreed homing contract, including Scout
arrows, Mage Fireball, ranged mobs, bosses and applicable guards. Smite stays
instant. Ground/area abilities retain function and are not converted to homing.

At actual release (bow release; spell execution after cast), acquire the current
crosshair hostile target server-side in range with initial line of sight. Never
read stale enemy memory as aim. Enemy actors lock their current valid target at
launch with corresponding range/LOS checks. No valid target => no shot and no
mana/ammo payment. Ordinary pickup behavior stays intact.

After launch keep exactly that target; no retarget or interception by characters
or terrain, no range expiry. Cover protects BEFORE launch only. Establish short
flight duration from launch distance/speed; visually converge to current target
position until once-only impact. This avoids endless pursuit of faster targets.
No obstacle navigation, dynamic ballistic solver or client code. Preserve arrow
orientation and class-specific visuals. Damage occurs only at impact through
existing armor/dodge/absorb/PvP/evade/settlement rules, so geometric arrival is
not guaranteed HP loss. Preserve attribution, threat, XP, talents, ammunition
transactions and one-action wear. Lost/dead/unloaded/teleported target or invalid
combat lifecycle cancels safely; never hit a respawned/replacement identity.
Normal movement out of original range is explicitly valid. Nonpersistent shots.

Add startup setting `grug_mob_damage_scale`, default 1.5. Covers ALL non-player
combat actors: ordinary aggressive/neutral mobs, guards, adds, elites/rares,
kings/dragons. Includes their melee, missiles, auras, DoTs and authored ground
attack damage exactly once. 1.0 reproduces prior base damage. Excludes player
attacks, falls and ordinary environmental damage. Shared formula/helper rather
than hand-retuning every creature. Audit fixed damage paths as well as derived
`self.damage`; never multiply already-scaled arrows/boss coefficients twice.
Document validation and numeric setting range; load once, restart to change.

Acceptance: moving/out-of-range target; postlaunch wall; initial blocked/no aim;
exact once; canceled target/lifecycle; authoritative PvP/mitigation; Scout batch
payment and wear; mob/boss launches; scale 1.0/1.5 derived and fixed damage.

## C — DISPOSITION (Sol)

Write a concise existing-family disposition matrix as implementation rationale,
then implement within the approved design (no extra user approval needed).
Fixed category by creature family or deliberately named variant, not by current
aggro or player faction. Neutral = no unsolicited player attack, but retaliation.
Aggressive = attacks eligible players proactively. Ordinary starter Boars become
neutral. Fightable Rats aggressive; harmless critters are not promoted to combat.
Grazer/prey families naturally neutral; hostile humanoids/undead/monsters
aggressive. Danger in higher zones comes from predominant aggressive species,
not arbitrarily changing the same animal's disposition by location. Keep a few
plausible neutral animals. No exact numerical population quotas. Only targeted
roster/spawn-weight adjustments if needed; do not increase total density, ranges,
HP or per-family damage. Global scale is B's authority. Preserve drops/quest IDs.

Expose `_grug_disposition = "neutral" | "aggressive" | "critter"` in canonical
registered mob definitions/entities for DISPLAY; classify all ordinary families
centrally where possible without duplicating behavior authority. Guards/NPCs
are role categories, independent of these ambient definitions. Coordinate seam
with DISPLAY before editing shared init/levels. Root owns shared doc integration.
Acceptance: actual initial aggression/retaliation, family matrix and high-zone
roster sanity; no full spawn census or engine population/performance runs.

## D — DISPLAY (Sol)

Six global categories, identical colors to all viewers: aggressive, neutral,
guard, npc, player, critter. Boss/elite/add reuse behavior or faction role;
mounts get no new nametag. Defaults: red aggressive, yellow neutral, violet
watches/guards, light lavender peaceful faction NPCs, white players/critters.
Twelve startup minetest.conf colors (foreground/background per category), alpha
supported. Default background black about 25% opacity for all (`#00000040`).
No extra color enable toggle or live settings UI. Pick readable concrete colors
and document them; valid defaults require no user config.

One startup boolean enables injured-mob HP sprites (default true). Living
injured combat mobs including bosses/guards only, no critters/peaceful NPCs.
Small green fill and dark background, camera-facing 2D sprite; no player HP
sprite requested. Hide at full HP/death. Keep existing HP text in V1. Update
visible integer percentage changes only; reuse existing 25/30m nametag observer
hysteresis and central pass, no per-viewer duplicate bars or independent scans.
Ephemeral, nonphysical, nonpointable, no drops, lifecycle cleanup. Verify alpha
and sprite attachment behavior against pinned engine implementation. Easily
reversible via settings, no engine modification or art-generation dependency.

Acceptance: all six roles; settings/default/invalid fallback; HP injured/full/
dead; percentage unchanged avoids writes; per-viewer existing visibility;
parent unload/removal cleanup; no quest symbol interaction/regression.

## E — PARTY (Sol)

Personal persistent Group-tab dropdown: `All green` (default existing style),
`By class`. Warrior brown, Mage blue, Priest white, Scout darker olive-green.
Keep readable fill on dark backing; no party-wide setting or class inference
from another player's private state. Offline rows remain legible. Existing HUD
visibility preference, membership, faction restrictions and invites unchanged.
Root will schedule after a native slot becomes available; separate module from
other lanes. Acceptance: default, every class, preference persistence and UI
receive-field validation; no repeated unchanged HUD writes.

## Integration, review and delivery

Initial parallel lanes A/B/C; root writes living spec and prepares shared-display
integration. D/E begin as slots free; no competing writers on same checkout.
All implementations use isolated worktrees and lane commits. Shared docs and
settingtypes edits are integrated sequentially by root, with final drift review.
A and B receive independent Astra review; C/D/E independent Sol review. No
reviewer may have authored their reviewed scope. Record model, findings,
fix-rounds and elapsed time (or unknown). Root final compact parity loads changed
production paths with bounded fixtures; one targeted isolated native registration
smoke may complement fixtures. Actual mapgen content seams require actual
manifest/planner consumers if altered, but no general mapgen census.

Deliver updated living specs, plan/execution/completion records, playtest
checklist, coherent reviewed commits merged to main, local game sync and origin
push. Runtime acceptance remains a distinct user playtest. No Nether, waypoints,
new POI program, armor/refinement redesign or unrelated fixes this round.
