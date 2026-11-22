# Roadmap — Grudgelands

Goals and milestones: where the game is heading, not what past rounds
delivered. What shipped, release by release: [CHANGELOG](CHANGELOG.md).
Current state: [project status](docs/STATUS.md). Open work and its scope:
[BACKLOG](BACKLOG.md). Rules and numbers: [design index](docs/design/README.md).
Earlier delivery narratives are preserved in the
[historical roadmap](docs/archive/planning/roadmap-before-consolidation.md).

## Next priorities — Deepening the playable game

Direction set by the user on 2026-10-11: the playable foundation needs a
focused improvement pass to become a rewarding experience throughout. These
are the next gameplay priorities, alongside the fixes already queued; most
have no assigned round or release date yet. Each names its goal and the
next step.

- **Expeditions** ([rules](docs/design/expeditions.md)): repeatable group
  content beyond the map. Three Expeditions run today (The Stilled Seam,
  The Second Shift, The Last Mint). Next: tuning run length, bosses and
  coins from the user's runs.
- **Website accounts** ([rules](docs/design/accounts.md),
  [concept](docs/planning/accounts-concept.md)): characters linked to an
  account on the realm's website, with account rewards that reach every
  linked character, such as the Cheer emote and the Supporter and donor
  cloaks; a character can be deleted from the website; the Account page
  shows what linking gives, and an account's characters of one faction can
  share one home, the Account Claim Stone. Next: the end-to-end test on the
  rehearsal realm; more Supporter content, account bans and characters
  created through a bridge command are later phases.
- **Classes, talents and character progression:** make leveling bring more
  meaningful customization. Start with fewer skills and let talent choices
  decide more of which abilities a character gains or leaves out. Build
  coherent ability interactions and rotations, and improve balance in group
  play and PvP. The Scout most urgently needs attention to how it feels to
  play. The four-class rework has shipped
  ([delivery plan](docs/planning/class-redesign/delivery-plan.md)). Next: a
  playtest of the new classes and a short balance fix round.
- **World atmosphere, variety and resources:** review music, sounds and
  icons with care for the details that give each region character. Improve
  areas dominated by wind, add more surface variety, more varied tree shapes
  and more distinctive cities. Rebalance ores, gems and coal, with many ores
  and gems available across more depth tiers. First passes have shipped;
  the next is not yet scheduled.
- **Crafting with more character and purpose:** build on the improved
  recipe system with more variety, wit and versatility, especially in
  Cooking. Explore a broader range of useful food buffs. Next: not yet
  scheduled.
- **Quests that welcome players into the world:** improve how quests teach
  the game and explore more immersive ways to connect their tasks to the
  people and places around them. The quest rework (decided with the user on
  2026-10-22: a story thread from the capital on, story quests marked apart
  from kill quests, cut repetition and dependencies between kill quests, no
  longer rewarding the requested items) is complete from the start zones to
  the front at 60 ([quests](docs/design/quests.md)). Next: not yet
  scheduled.
- **Unique items** (decided with the user on 2026-10-22 and 2026-10-23,
  [Round 57 plan §9](docs/planning/round57-plan.md#9-later)): unique,
  non-craftable items. Quest rewards that replace the crafted items in
  choice rewards, boss drops from fixed loot tables in the Expeditions, and
  items found in the world. A Miner's Guild material obtainable only this
  way waits for them ([miners_guild.md](docs/design/miners_guild.md)).
  Next: a plan; no round assigned.

These are goals for the next design and playtest passes, not changes already
available in the game. Detailed follow-up scope:
[BACKLOG](BACKLOG.md#player-experience-follow-up-2026-10-11).

## Vision

- **Two distinct faction continents.** The Accord holds southern Elandor and
  the Throng northern Kragmar. Their independently authored three-lobed
  silhouettes meet along the continuous four-zone Battlegrounds; ocean
  separates the rest of the coast. The stable 38-zone map fixes names, hubs,
  level ranges, race regions, PvP rules, biome palettes and POI budgets;
  neighbors follow the natural zone borders, and seeds vary local terrain.
- **Six races, six starts, six capitals and six kings.** Each race begins in
  its own outer level-1–10 settlement and later reaches a central gated
  capital. Capitals are peaceful civic hubs with level-60 guards and no
  ambient hostile mobs. Kings and royal guards are killable high-end
  combatants; essential service NPCs are separate and invulnerable.
- **Progression moves toward conflict.** All level-1–30 surface zones are
  peaceful. Every ordinary level-31–60 frontier, Battlegrounds or dragon-island
  zone is contested. At y = −501 and below, every non-ocean land column is
  contested independently of its surface zone.
- **PvP is a simple per-player flag** ([pvp.md](docs/design/pvp.md)). Two
  enemy players can harm each other only while both are flagged. Contested
  ground and enemy territory flag by location, a button and PvP contact
  flag for 60 s, only own peaceful land clears the flag and death clears
  it; no attack or heal ever changes it. Support is one-way, PvP combat
  lasts 10 s and a logout in PvP combat is death. PvE combat does not notice
  PvP. Each faction holds a fortress at the front, and 16 Battlegrounds war
  camps are the targets of PvP quests (players are never quest targets).
- **Controlled destructibility keeps the world playable.** Peaceful home
  terrain is editable by its faction; peaceful enemy land is not. Ordinary
  contested land, including the Battlegrounds at every depth, is editable by
  both sides. Deep ocean and bay, belt and channel water 24 nodes or more
  off the coast are immutable. Roads with their bridges and the building
  cores of POIs, villages and camps are protected for everyone; the rest of
  village/outpost/camp shells and battlefield dressing stays mutable. Only
  bounded functional anchors and complete civic cores — capitals and
  starting settlements with their bare protected bands — are
  hard-protected, fail-closed against indirect mutation.
- **The ocean has authored classes.** Planned mainland water stays part of its
  named zone. A coastal belt 250–350 nodes wide belongs to the zone on land,
  editable only along its shore; the immutable open sea begins beyond it.
  Two shallow organic channels of their islands' level 60 separate the
  offshore dragon islands and keep them boat-only.
  Deep ocean is deadly through the Kraken, which never breaks off a
  pursuit while it stands in open water and leashes normally everywhere else.
- **Two equivalent apex destinations.** The Wyrmglass Crown and Stormscale
  Summit are contested offshore dragon islands, each with a dragon lair and an
  apex camp, reached by boat. Each dragon fights in a round arena whose edge
  is its leash, with hazards of its own. Each boat landing has a small beach
  and a wooden pier; beyond them the islands stay untamed, without paths or
  roads, so the climb is part of reaching the dragon. Minerals never regrow
  anywhere, camps included.
- **Housing lives in the open world** ([housing.md](docs/design/housing.md)).
  From level 20 each player gets one free, soulbound Claim Stone from a
  capital's Housing Steward. It claims the map chunk of 80 × 80 nodes it
  stands in, from y = −100 up, in the player's own level-11–30 and capital
  zones, where the whole chunk holds no road, settlement, camp or quest
  content and quest creatures keep half their ground; it protects it while
  coal or charcoal burns, grants Interact or Everything to named players and can be
  the travel-home target. A linked account's characters may share one such
  home per faction, and every home carries the name its owners give it.
  There are no tiers, and private housing islands do not exist. Next: a map
  reset that keeps homes where their ground did not change (the housing
  concept's [Part C](docs/planning/housing-rework-concept.md)), when the first
  one is needed.
- **One six-tier material spine serves every race.** Bronze, Iron, Steel,
  Silversteel, Embersteel and Abyssal Steel picks dig the six tier rocks:
  stone down to −100, then ever harder rock below −100/−300/−500/−700/−1000.
  Every ore and gem needs the pick of the layer where it first appears, at
  any depth; a weaker pick cannot dig it at all. Loose ground needs no tool,
  and decorative rocks do not drive access.
- **Regional materials add identity without blocking universal progression.**
  Each race region selects one cultural material and one signature wood;
  foreign cultural resources come through contested/deep routes and trade,
  never through a mandatory faction monopoly. Gems are not regional: one gem
  per tier rock — Citrine, Jade, Garnet, Sapphire, Ruby, Diamond — found
  everywhere at its depth; Quartz is universal.
- **The economy stays ledger-only.** Copper/silver/gold are one integer;
  physical Gold is a separate crafting material. The target Common weapon
  axis is 25c/65c/1s60c/4s/10s/25s and vendor buy-back is ceiling-rounded 5%.
  A simple estimate of reliable net solo income after ordinary costs
  calibrates mount, boat and respec prices; the Claim Stone is free.
- **Combat supports solo play and the tank/healer/damage trinity.** Threat,
  taunt and healing threat make group roles matter, but content is sized for
  two or three players and remains beatable without a healer. Level 60 takes
  roughly 10–20 played hours; endgame PvP, bosses, crafting and housing are
  the destination.
- **Travel has separate systems.** Innkeeper home return binds one of
  twelve faction-compatible homes, returns instantly outside combat on a
  personal 30-minute cooldown and owns death respawn. Visit-unlocked
  waystones connect every start, every capital and the PvP fortress of a
  faction. The player's own Claim Stone can replace the innkeeper as the
  home, respawn included. Universal riding unlocks at levels 15/30/45/60
  with land speeds 6.4/8 and flight speeds 8/12 nodes per second; damage
  dismounts. Battlegrounds permit flight, enemy territory allows land mounts
  only, and every exterior-ocean column forbids flight. Boats are water
  mounts: the Shipwright in every capital sells the Boat from level 15 and
  the twice-as-fast Improved Boat from level 30, and any damage ejects a
  rider from a boat exactly as it dismounts one from a mount. There are no
  docks; a boat lands anywhere in water, and only the four island landings
  have piers.
- **Story remains light and environmental.** The Accord–Throng war is old; an
  ancient demonic threat reaches upward through the Nether. Both factions face
  it in parallel without becoming allies. Each faction's main line from
  level 41 follows that threat's branded pay across the front to a shared
  finale at the rift, whose last line points below
  ([story.md](docs/design/story.md)).

**Scope versus delivery:** this vision includes approved future systems,
not just running code. The [CHANGELOG](CHANGELOG.md) records what shipped;
the [BACKLOG](BACKLOG.md) tracks what remains.

## V1 scope

The original V1 baseline (2026-09-18) is Rounds 1–9, open-world Housing,
mounts, the release gates and polish; the approved later rounds extend it. The
user's 2026-09-29 decisions
([WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
B1–B7) settle the rest:

- **In V1:** WP17 boats (the only access to the dragon islands and their
  camps) and waypoints at every start, capital and PvP fortress (no zone hubs, no
  `/unstuck`); WP41 geographic PvP; WP9's story levels 41–60 and the finale;
  **sound** (the user, 2026-10-03): effects for the game's events, mob
  voices, ambience and calm background music without a combat switch
  ([sound.md](docs/design/sound.md); music plays only in the six capitals).
  The small PvP POIs of WP42 are part of V1.
- **After V1:** WP42's scripted NPC battles on the war front.
- **Not V1:** the walkable Nether, the first expansion (V2).

The V1 systems listed above have shipped. What is left before a public
release is [below](#before-the-first-public-release).

## Phase 1 — Playable core and world foundation

The playable core and the world foundation are delivered: the game, its
factions, races and four classes, the named-zone world with its starts and
capitals, combat, mobs and dragons, items, professions and the economy,
quests and the story to 60, housing, travel, PvP, sound and Expeditions.
The [CHANGELOG](CHANGELOG.md) and the round plans' "Completion" sections
record each delivery.

### Remaining work

- [ ] **Deepen the playable game:** the
  [next priorities](#next-priorities--deepening-the-playable-game).
- [ ] **WP46 / WP48:** the fire/explosion guard is deferred until a fire or
  explosion source exists (expected with V2's Nether; nothing damages
  terrain today); several emerge threads for mapgen wait for Luanti #9357.
- [ ] **Later world content:** quest-bearing POIs with an underground part
  ([world_zones.md §8.5](docs/design/world_zones.md#85-seed-dependent-poi-placement-round-46)
  names the hook); the T6 lava lakes ([world.md](docs/design/world.md)).
- Smaller open items, the open design questions of the October 2026 audit
  and the leftovers of each round are in the [BACKLOG](BACKLOG.md).

### Before the first public release

Rewritten 2026-09-29 (audit E9, E10). Gates: freeze game/engine/settings and
the public seed; complete the media publication attribution/flag obligations.
Checks with judgement, not gates: a native start/generation/restart of the
candidate as deep as its changes warrant, an optional PUC Lua 5.1 crash smoke
test, and a resource spot check on a few seeds. Exact wording and ownership:
[BACKLOG release gates](BACKLOG.md#first-public-release-gates).
Historical evidence does not certify later code. Fresh-server development
mode ended with 0.41.0 (the user's announcement, 2026-10-07): from then on
worlds survive upgrades through the
[upgrade contract](docs/technical/upgrade-contract.md), since 0.43.0 also
through migration steps.

## Phase 2 — Expansion

- [ ] Further classes, names open. Scout already owns the delivered bow and
  melee class paths; its stealth remains deferred.
- [ ] Further coastal life and shore wildlife (seals and cold coasts, a sea
  turtle, underwater places for quests), without redefining the open sea or
  the dragon channels. Coral, kelp, seagrass, shipwrecks, fishing and five
  water families by band have shipped.
- [ ] **V2's main content update: the walkable Nether**, with its own mapgen,
  story line and mob cast. The Fire Dragon and the Nether reserve from the mob
  plan remain reserve content for that update.
- [ ] WP42 bounded war-front encounters (scripted NPC battles, after V1).
- [ ] Player trading, later through an auction house (the user, 2026-11-16).
  Dungeons shipped in a first version as Expeditions, reputation with the
  Miner's Guild, apex encounters with the dragons and kings.

## Phase 3 — Polish

Longer-term work continues beyond the
[next priorities](#next-priorities--deepening-the-playable-game); class
balance, atmosphere and quest onboarding are already part of those next
passes, not postponed to this phase.

- [ ] Original textures, sounds and animated models with complete provenance
  (V1's sound uses licence-clean sources first).
- [ ] Optional: a small weather system (sky, particles within the web
  budget, a rain bed); not V1 (Round 34 ruling 7,
  [BACKLOG](BACKLOG.md#weather-optional-user-2026-10-04)).
- [ ] Localization through Luanti's translation system; German first.
- [ ] Balance, accessibility, onboarding and a 100-player performance pass
  with real clients (Round 32 measured 50 and 100 stand-ins).

## Deliberately outside the target

- Private housing islands, purchased mining-depth rights and private material
  sources.
- An organization with a name, bank, owned land or any game effect.
  Clans ([clans.md](docs/design/clans.md)) stay anonymous and purely
  social: roles, invitations and a clan chat only.
- Instanced PvP battlegrounds/arenas and permanent war-front capture in the
  current scope.
- A separate Enchanter profession; each profession enchants the families it
  owns.
- Taming mounts; riding is a permanent purchase and summons an ephemeral
  owner-bound entity.
- Removed from the design (2026-09-29): held-torch moving light, natural
  out-of-combat regeneration, rested XP, renewable ores, the dragon hoard
  chest and `/unstuck`. Friendly-guard healing stays deferred.
