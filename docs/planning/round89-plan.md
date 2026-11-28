# Round 89 — Shield feedback, home names and the arena's balconies

**Agreed 2026-11-28.** Release 0.89.0, planned as **migrate** from 0.88.0: no
map reset, but one declared migration step whose online part rewrites the
arena's two halls in place (the upgrade contract classifies a protected
composition rewritten inside its unchanged box as migrate, §5.9; the pattern
of 0.69.0). The round
shows how long an effect still runs on its icon, draws an active shield as a
bubble around the player, names the own home in the waypoint list and gives each
hall of the arena Breach Road a stair to a roofed balcony from which players
watch the field in safety.

## 1. Lanes and waves

| Wave | Lane | Deliverable | Model |
|---|---|---|---|
| 0 | BALCONYDRAFT | The design draft of stair and balcony for both halls, on a pick page for the user's go. Starts before the round, from main; tools only. | Astra |
| 1 | UI | The duration cover on every timed effect icon; the home's name in the waypoint list and on the map markers. | Opus |
| 1 | BUBBLE | The shield bubble (UI lane: merged only after the user's go on its screenshots). | Opus |
| 1 | REWRITE | The one-off rewrite of the two hall boxes in an existing world, built and proven against a test change of the templates. | Opus |
| 2 | HALLS | The approved draft in the game: both hall templates, the friendly boxes, the checks of Round 85, Help. Starts on the user's go on the draft. | Opus |
| last | D | The round's records. | Opus |

Wave 1's three lanes and the draft run at the same time; they share no file.
HALLS waits only for the user's go on the draft and for REWRITE's merge.

## 2. User rulings

1. **Duration on the icon** (2026-11-28). Every effect that runs out shows its
   remaining share as a cover on its icon, like the hotbar's cooldowns; the icon
   darkens clockwise as time passes. The caption under the icon stays as it is:
   the shield shows its remaining points, every other timed effect its
   countdown. No second caption line.
2. **Shield bubble.** A half-transparent bubble surrounds a player while a
   shield (an absorb) is active, for **every** shield: yellow-gold for the
   Priest's Shield, bluish for the Mage's Rime Mantle, white to light grey for
   all others (Hold Ground, Unbroken, Parry, Close Dance, Last Light). With
   several shields at once the bubble takes the colour of the **shield cast
   last**; there is never more than one bubble.
3. **The balcony.** Each hall gets a stair inside and, at roof level, a balcony
   out of the building toward the road. The balcony has a **roof of its own**
   and is closed toward the hall's roof, so on foot it is reached only by the
   stair; toward the field it is open behind a parapet. Stair and balcony are
   the faction's **friendly territory**, like the hall. The hall's roof and the
   balcony's roof stay contested ground: a player on a flying mount may land
   and mount there. This narrows Round 85 rulings 10 and 11 only by the new
   boxes.
4. **No new PvP rule.** A player must flag by their own choice to attack an
   enemy in friendly territory; the balcony needs nothing further.
5. **No map reset.** The arena's outer measures do not change. Production runs
   0.87.0 on the map of 0.86.0; the halls are rewritten in place (§3).
6. **Home name.** The waypoint list shows the name the home carries
   (`grug_housing.home_name`) instead of "Your Claim Stone".
7. **Astra drafts the balcony**; the user looks at the proposal as an artifact
   before anything is built.

## 3. Shared conventions

- **The cover** (coordinator default). One more image element per status slot,
  drawn from the hotbar's existing cover frames mirrored, so no texture is
  added and no icon texture is recombined per step. The total duration of an
  effect is what the icon row saw when the effect (id and expiry) first
  appeared, so status sources need no change; a refreshed effect starts a new
  cover. Untimed effects show none. Writes only on a visible change, in the
  status pass's existing 0.5 s cadence.
- **The bubble** (coordinator default). One entity attached to the player,
  made when the first absorb appears and removed when the last one ends or is
  used up, on death and on leave; nothing saved. It is not shown to its own
  player in first person (the engine's default for attached objects), so it
  never covers the view; other players and the third-person camera see it. A
  low-poly sphere mesh and one texture per colour. The colour follows the id of
  the absorb added last (`shield_spell`, `rime_mantle`, else neutral).
- **The hall rewrite** (coordinator default). The pattern of Round 69's camp
  rewrite (`camp_rewrite.lua`, upgrade contract §5.9): once after the load,
  every cell of each hall's template box becomes what the new generation writes
  there, read back before the pending key goes. A declared step `0.89.0` of
  `tools/migrate.py` writes only the world marker; its world handler records the
  job, as 0.69.0's does. The arena is protected for
  every player, so no built cell has to survive. The two hall waystones keep
  working (the same node on the same cell, its travel state lives with the
  players). A fresh or reset map generates the new halls and never has the key.
- **The friendly boxes.** A hall's friendly territory becomes a short list of
  inclusive boxes (interior, stairwell, balcony up to the underside of its
  roof) in `breach_layout.lua`; `grug_pvp/rules.lua` already takes a list.

## 4. Lane goals

**BALCONYDRAFT.** A proposal the user can accept or correct: for each hall
where the stair stands, how it reaches roof level without a jump, how the
balcony sits toward the road, what its roof and its wall toward the hall's roof
look like, what a spectator sees from it, and which boxes are friendly. It
stays inside each hall template's box (21 × 19 × 31), keeps the waystone, the
arrival and the muster cells and the sills free, and uses shipped nodes only.
Both factions get the same function in their own style. Output: an offline pick
page with before and after, the draft templates in the tool's folder and a
report with the boxes in the layout's local coordinates.

**UI.** *Cover:* `grug_core/status.lua` (the slot's third element, the first-seen
duration), `status_icons.lua` (the pure frame arithmetic, with the mirrored
frame), `hud_layout.lua` if a geometry constant is needed; the cover frames stay
`grug_abilities`' textures. *Home name:* `grug_home/claim_home.lua` (the claim
waypoint's label), `grug_map/providers.lua` (the home marker and the waypoint
marker, label and tooltip); the greyed entry of a player without a stone keeps
"Your Claim Stone". The lane checks that a 24-letter name fits the list.

**BUBBLE.** The entity and its lifecycle beside the absorb bookkeeping in
`grug_core/combat.lua` (`add_absorb`, `get_absorb`, the soak, death, leave),
the mesh and three textures, and a screenshot probe (each colour, a small and a
tall race, mounted, at night) for the user's go. It reports what the bubble
costs: objects per shielded player, nothing per step.

**REWRITE.** The job for the two hall boxes: its request through the round's
migration world handler, the write, the read-back and the severe report, with
the test the migration rules ask for (a world of the version before, the new
version's boot, both halls equal to a fresh world's). Whether it generalises
`camp_rewrite.lua` or stands beside it is the lane's choice, reported before it
builds if it changes the camp job.

**HALLS.** The two templates as approved, the friendly boxes in the layout, the
territory and build fixtures and probes of Round 85 (`tools/r85_territory`,
`tools/r85_build`), the building-template gate, the Help paragraph and
`docs/design/pvp.md`. One engine boot shows a walk up the stair and the banner
on the balcony, under the roof and on both roofs.

**D.** CHANGELOG, STATUS (production is 0.87.0, the user 2026-11-28), the
design documents the lanes did not own, the Completion.

## 5. Rules

Every lane states its upgrade classification. The planned outcome is
migrate, because of REWRITE's job alone (upgrade contract §5.9); UI and BUBBLE
are expected compatible. BUBBLE and HALLS are merged only after the user's go on their pictures.
No lane changes a shield's numbers, a flag rule or the arena outside the two
hall boxes.

## 6. Verification

- Fixtures per lane: the cover's frame arithmetic and the first-seen duration
  (a refreshed effect, an untimed one, a source entry); the bubble's lifecycle
  (two shields, the colour of the last, used up, expired, death, leave); the
  waypoint label (own home, account home, no stone); the rewrite's test; the
  territory answers of every node of the new boxes and of both roofs.
- The seed fleet is not owed for a change inside the hall templates' boxes
  unless HALLS changes the layout's footprint or the writer's logic.
- **Human tests offered:** the cover's readability on the 40 px icons on desktop
  and web; the bubble in a fight with several shielded players; the walk to the
  balcony and the view of the field from it.

## 7. Orchestration and open points

- **Start state.** The round branch comes from main once Round 88 has landed
  (Round 88 changes `grug_core/combat.lua` and `status_icons.lua`, which UI and
  BUBBLE edit). BALCONYDRAFT touches only `tools/r89_balcony_draft/` and starts
  from main before that.
- **Shared files.** UI owns `status.lua`, `status_icons.lua`, `hud_layout.lua`,
  `grug_home`, `grug_map`; BUBBLE owns `combat.lua` and its new file; REWRITE
  owns the rewrite job and the migration handler; HALLS owns the templates,
  `breach_layout.lua`, `grug_pvp` and `help.lua`. Merge order: UI, REWRITE,
  BUBBLE (after the user's go), HALLS (after the user's go), D.
- **Compaction checkpoints:** after wave 1's merges; after HALLS; after D and
  the round-end run.
- **Decided during the round:** the draft (the user's go, possibly after a
  second pass); the bubble's opacity and colours on the screenshots.
