# Story & Main Questline

Decided premise (2026-08-06; royal roles revised 2026-08-12; housing revised
2026-09-29); the main line of levels 41–60 shipped in Round 36 (§2a).
Delivery: quests, setting and environmental storytelling (a light layer, not
cutscene opera).

V1 takes place entirely in the overworld. The Nether is the first expansion,
not a V1 destination; V1 quests cannot require Nether-exclusive items, mobs
or travel. Overworld foreshadowing does not unlock or include that expansion.

## 1. Premise

> **"A darkness has befallen the land."**

- The conflict between the Accord and the Throng is **old** — a
  generations-long war over territory and pride. It stays: PvP, border
  raids, the whole faction game.
- The **new** threat rises from the flames of the Nether — this world's
  hell, a world of lava and demons. Something **demonic and ancient**
  stretches its dark hands from below into the overworld (genre
  tradition: classic MMO demon legions, the genre's hells and corruption).
- It threatens **both factions equally, despite their enmity** — but it
  does not unite them: each side fights the darkness on its own,
  in parallel and in competition. (Cross-faction cooperation is NOT part
  of the MVP story.)
- In V1, scorched breaches, twisted vegetation and corruption set pieces
  foreshadow a connection from below; no Nether portal or crossing is built.
  V2 introduces the portals and the walkable Nether, revealing that
  **something opened the connections from the other side.**

## 2. Main questline

- **V1 scope** (user decision 2026-09-29,
  [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
  B7): the main questline through levels 41–60 and its finale are part of
  V1 (WP9, shipped in Round 36, §2a); only the Nether payoff below waits
  for V2.
- One equivalent but faction-specific main questline per side carries the premise:
  early quests are local and mundane (boars, bandits, guard duty), then
  signs of corruption appear, and the questline progressively reveals
  the demonic influence behind local troubles.
- **Quests have minimum levels** (core mechanic, WP8): every quest can
  carry a `min_level`; main-questline beats use them as hard level
  gates — e.g. only at level 30 comes the order to kill a corrupted
  outpost leader that advances the main story.
- Existing mandatory-quest beats (fight at the contested land front, kill
  enemy war-front guards, elite kill in hostile territory — ROADMAP 1.5) get
  framed by this premise:
  the enemy faction is suspected of dealings with the darkness,
  intelligence must be gathered behind enemy lines, etc.
- **Housing** is a level-20 civic service, separate from royal combat. The
  Housing Steward in each capital hands out the player's free Claim Stone and
  briefly explains its upkeep. The home is claimed in the player's own
  level-11–30 home zones; it is not an island, a king's personal gift or a
  purchase of underground rights ([housing.md](housing.md)).
- Each race still has its own king, for six kings total. Kings and their royal
  guards are killable high-end raid combatants, unlike passive service NPCs.
  Their Fallen Crowns are optional personal trophies with race provenance
  that a Crownbinder uses to crown one item (Round 33,
  [item_tiers.md](item_tiers.md) §4), never housing deeds or universal
  progression ingredients (`items_crafting.md` §5.4).
- Phase 2 payoff: the Nether becomes walkable through its own later travel
  contract, and its
  **world bosses are demonic lords** behind challenges
  (TODO-design-nether.md) — the questline's late chapters point there.

## 2a. The main line, levels 41–60 (Round 36)

Shipped in Round 36 (WP9); the full source is the approved
[story bible](../planning/round36/story-bible.md) (names, rules of the
threat, beats, objects, cloaks), the quest structure is in
[quests.md](quests.md) "The main line".

- **The threat:** **the Undertithe**, an ancient hunger beneath the world
  that counts the dead as payment owed to it. Its **Tithe-Brand**, burned
  into battlefield coin, binds whoever takes that coin as pay, living or
  dead: the living cannot spend it or put it down, the branded dead cannot
  rest, and every name paid with it goes on the Undertithe's **roll**. No
  portal opens; the money does the work. Branded dead are *owned*, which
  sets them apart from the Undead people, whose blight is old death (§3).
- **The circuit:** the **soot factors** (greedy debtors who cannot stop,
  with the front's brigands and the Saltroad Deserters as their hands)
  strip coin from the dead of both armies and brand it; Paymaster Chirr
  pays his archers with it, Toll-Taker Senn his raised dead; Ninepins
  pledges his standard against it, Huskell's watch is re-enlisted with it.
  Ten **corrupted** front creatures share one ember tint.
- **Shape:** each faction's line runs from its fortress Warmaster
  (Ashenward Bastion, Bannerbreak Warhold) with handoffs to the front's
  givers; chapters open at **41, 46 and 53**, the finale at **60**; every
  step is solo but the finale, and optional "Group:" hunts never block the
  line. Some steps are done **at a place** with a quest object only the
  quest's holders see (breaking a seal, taking a rubbing, burning names off
  a tally-stone).
- **The Accord, "Every Name Accounted For":** (1) branded pay on the
  Causeway leads to Senn, whose bundle wears a Throng requisition on good
  fortress paper; (2) after Ninepins, the Throng captain's orders from its
  war camp on The Shattered Line show The Throng hunting the same factors
  and the false seal printed on Ashenward's own forms, countersigned by
  **Requisition Clerk Odren Vell**; the Warmaster seals the finding;
  (3) Huskell's roll is a page of the Undertithe's own, with Vell's name at
  its foot, and after Chirr the player strikes the names from the roll
  until the debt's collector comes for it in person.
- **The Throng, "Our Oaths Are Ours":** (1) Senn's toll-box and pay bundles
  sealed as Accord requisitions make The Accord the suspect; (2) after
  Ninepins, the Accord captain's orders show The Accord robbed and burned
  too, and the seized grave coin entered by the Warhold's own **Tallykeeper
  Mardra**, struck from the roll before the drill yard; (3) Huskell's roll
  ends with Mardra, and after Chirr the player burns the bought names off
  the tally until the collector comes.
- **The finale, shared:** at **Tombroad Ambush** in Gravesalt Escarpment
  the unpaid balance takes a body, **Isquarre the Tithe-Eater**, beside a
  burning crack in the ground; two or three players of either faction, in
  competition and never together, defeat him under their own commission.
  He can return (the respawn); the crack stays. The traitors are named in
  texts only, never placed. War Commanders **Greyvow** and **Stonegrudge**
  guard two enemy war camps as optional group fights.
- **The last lines** point below without naming a place: The Accord, "We
  closed his account. Beneath us, someone turned a fresh page."; The
  Throng, "His last blow struck the ground. The answering blow came from
  underneath." The answer is V2's.
- **Earliest traces:** the 11–30 debt and forgery chains of both factions
  (Copperfell's counting-house stamp, the forged bough-seal, Mortuary Clerk
  Hush's ledger and others) read as the Undertithe's apprenticeship; no
  quest requires them.

## 3. Environmental storytelling hooks

- Corruption visuals at overworld breaches (scorched ground, twisted
  vegetation) — the darkness leaks through. There are no Nether portals in
  V1.
- Distinct from the Undead race's blight home region (§7 world.md):
  the Undead are a *faction people*, not the demon threat — their blight
  is old death, the Nether corruption is fresh, fiery evil.
- Elite/heartland areas can carry early corruption set pieces long
  before the Nether itself ships.

## 4. Naming

- Own names for the evil, its lords and the questline — recognizable
  genre character, **no 1:1 copies from existing games** (licensing policy,
  AGENTS.md).
