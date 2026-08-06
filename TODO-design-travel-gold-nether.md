# TODO — Waypoints (replaces Home Stone), gold economy, Nether crossings

Raised 2026-08-06, under discussion. Three connected ideas (user):

1. **Waypoint travel** (Diablo/PoE style) instead of the Home Stone.
2. **Gold drops only from humanoids** → mob-gold farming only in enemy
   territory (quests pay gold everywhere).
3. **The Nether** as story element and travel layer: portals in own
   territory lead across deadly Nether islands into enemy territory.

## 1. Waypoints

Decided direction: spawn camp, own (guild) housing and the capital are
waypoints; more spread across the world; **none claimable in enemy
territory**; teleporting only works while standing AT a waypoint
(waypoint → waypoint), so travel and mounts stay relevant; density is
the tuning knob for travel comfort. Requires the per-player **fog-of-war
world map** (WP12) showing discovered waypoints. Home Stone (world.md
§6) is dropped.

Analysis / consequences:

- The Home Stone's job was "nobody is trapped". Waypoints don't cover
  it: stuck in an enemy-territory pit (no dig/place) → death is the
  escape valve (XP loss = the price). Recommendation: accept + add a
  `/unstuck` suicide command for hard stuck states.
- The **capital housing portal building** (world.md §3/§5) becomes
  obsolete — capital waypoint ↔ housing waypoint replaces it.
- Incremental build: waypoint travel works with a formspec list first;
  the map UI (WP12) hooks in later. WP12 rises in priority.
- Recommendation: unlock per character by visiting (PoE model), stored
  in player meta; travel is free (travel time is the cost, gold sinks
  live elsewhere); no waypoints in the neutral borderland (border
  travel stays dangerous).

Open: cast time at the waypoint (instant vs. short channel)? Borderland
waypoint yes/no (recommendation: no)? Density (proposal: ~1 per ring
per race region ≈ 12–15 per faction + capital + housing)? Flight
points/portals extension: parked (hard on random maps).

## 2. Gold from humanoids only

Decided direction: only humanoid mobs drop gold; hostile humanoids
exist only in enemy territory (faction guards/outposts) → farming gold
from mobs means raiding. Quests pay gold everywhere (first boar quest
already pays a little).

Analysis / consequences:

- **Interaction with WP7** ("traders buy EVERY mob drop"): selling
  trash loot IS a gold income in own territory. Resolution (proposed
  framing): three income streams — quest gold (baseline), vendor trash
  (trickle), humanoid gold drops (risk premium, clearly the best
  rate/hour). Balanced via numbers, not removed.
- **Interaction with cloth loot** (items TODO §5: humanoids drop
  cloth): if hostile humanoids exist only in enemy territory, tailoring
  material would require raids. Proposal: **neutral bandit camps** in
  both territories — hostile to everyone, drop cloth but **no gold**
  (poor outlaws); enemy faction humanoids drop the gold. Cloth farmable
  at home, gold requires raids.
- **Anti-farming**: apply the gray rule to gold too — guards/humanoids
  ≥10 levels below the killer drop no gold (else high levels farm enemy
  starter-zone guards risk-free).

Open: bandit camps yes/no? Gray rule for gold confirmed?

## 3. Nether crossings

Decided direction: the Nether is a deadly place where "the magic of the
world created connections between places". Portals appear in own
territory (first in midlands, lvl 10+); each leads to a **Nether island
surrounded by lava** with two exit portals — one to Alliance, one to
Horde territory, far apart on the island; Nether mobs at the level of
the connected areas; **always same-level areas are linked** (gameplay
symmetry). Fight across the island → farm/quest in enemy land.

Analysis:

- **Mirror pairing does the symmetry for free**: link overworld (x, z)
  ↔ (x, −z). Both ends automatically sit in the same difficulty ring
  (rings are |z|-based) and in mirrored race regions.
- Portals are **two-way** → a crossed island is a persistent raid
  route; enemy players can camp the exit — that is PvP content, kept
  fair by multiple islands spread across x and exit scatter.
- Technical route: own Nether layer in a deep y-band via our mapgen
  (custom `on_generated` pass, like the wall/camps); portal pairing is
  deterministic from coordinates. No external mod needed (ContentDB
  "nether" as reference only).
- Portal structures must be protected zones (indestructible frames).
- Recommendation: **design now, build Phase 2** — MVP raids cross the
  borderland on foot (starter/midlands are reachable); the Nether adds
  depth+story for deep raids later. Revisit after the MVP playtest.

Open: Phase 2 placement confirmed? Portal activation (always open vs.
quest-unlocked per portal)? Nether-side settlements/loot (pure transit
vs. farmable zone)? Story framing (who/what created the connections)?

**Decision (all three):** _pending discussion_
