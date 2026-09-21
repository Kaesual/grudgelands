# Wooden weapon ingredients

Status: discussion only; user requested feedback before implementation
(2026-09-21). Existing recipes remain authoritative until approval.

The user proposes one matching-tier metal bar replacing the middle wood in
every staff, and the middle side wood in every bow (including mirrored shapes).
They also ask whether ordinary planks/sticks should replace graded wood.

Current Seasoned Wood consumers: four ordinary output identities (Bronze Staff,
Bronze Bow, Bronze Wand, Polished Wood), represented by six grid routes when
mirrored bows and the wand's metal-rod alternative are counted. Eighteen T1
Woodcarver enchant operations additionally consume it: eight caster-weapon and
ten bow prefix/suffix choices. Seasoned Wood itself costs two horizontal planks;
the six-grade chain is an authored profession material ladder, not only a recipe
collision workaround. Higher grades recursively add another ordinary plank.

Recommendation to discuss: ordinary sticks plus the matching bar for plain
staves/bows, retaining graded wood for professional enchant costs initially.
Removing the entire grade chain would also require redefining enchant costs.
A plain wand must retain a distinct recipe: bar-over-stick is already the dagger
recipe. No wand redesign or material-chain deletion is approved.

## Subsequent occult-component proposal (discussion, not implementation Go)

The user proposes `-O- / -M- / -H-` for wands and
`OMO / -H- / -H-` for staves, with H wood/stick, M the matching-tier metal
bar and O an accessible ordinary mob drop. Root recommends ordinary sticks
for H. This gives one occult component per wand and two per staff, and avoids
the dagger shape. The bow proposal above is unchanged.

Existing-source candidate ladder, reviewed read-only by root and native Sol:

| Equipment tier | Candidate | Existing drop source and probability |
|---|---|---|
| T1 | Boar Tusk | Boar family, one at 1/3 |
| T2 | Rotting Flesh | Zombies, one guaranteed; night source |
| T3 | Bone | Skeletons, one guaranteed |
| T4 | Bear Claw | Bear/Plaguehide Bear, one at 1/4; normal sources on both continents |
| T5 | Sharp Feather | Eagle/Vulture, 1–2 guaranteed; shared Shattered Line has the mountain roster |
| T6 | Venom Sac | Serpent, one at 1/3; shared Skyglass/Stormscale jungle rosters |

These are existing ingredients, not newly tier-exclusive drops. The metal
remains the tier gate. Accessibility is regional: T4 may require travel to a
forest, T6 to jungle rather than the Gravesalt/Wyrmglass routes; ordinary
solo sources exist, but equal convenience in every zone is not established.
Bear spawns can rarely promote to Elder; ordinary Bears remain available.
No new drop system is needed for this candidate ladder. Broadening local source
coverage or changing drop rates would be a separate decision.

Evidence: `mods/ENTITIES/grug_mobs/{boar,boar_variants,zombie,skeleton_archer,
bear,eagle,serpent,spawn_policy}.lua`, current named-zone brackets in
`mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua`. Drop `chance` is the
denominator in `mods/ENTITIES/mobs/api.lua`'s drop routine. No gameplay changes
or runtime tests were made during this discussion.
