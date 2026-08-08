# TODO — Housing: remaining open points

**Most of this file was decided on 2026-08-07 and folded into
`docs/design/world.md` §5** (the King's isles: per-character grant at
level 30, 100×100 build box, seabed at −30, **six** depth steps — one
per rock stratum, down to bedrock, re-cut from ten on 2026-08-07 —
treasure clusters instead of ore, styles, access levels, allocation
grid), plus `guilds.md` §2/§3 (bank as one account with terminals),
`economy.md` §4.1, `items_crafting.md` §5.5/§8.4, `story.md` §2,
`progression.md` §2 and `biomes_mobs.md` §1.2 (reef band).

What is left here is **content detail and tuning** — nothing blocks the
housing WP from starting; these are decisions to make *inside* it.

## Q1 — Cluster contents per depth step

world.md §5.4 fixes the shape (8 clusters × 20–40 nodes per step,
deterministic per isle) and the coarse ladder (steps 1–3 ordinary, 4–7
iron/steel-grade and gems, 8–10 depth treasures incl. abyssal gems).
Open: the exact material and count per step, and the resulting value per
step measured against its price (world.md §5.3). Rule to hold: a step's
payout must be **worth roughly its price and no more** — the ladder is a
sink, not an investment.

> **Reconcile before WP24 authors the cluster contents (noted 2026-08-08).**
> `TODO-design-depth.md` C8 decided that a bought step should land as a
> real payday rather than a thin scatter, which is about the *shape* of
> the payout, not its total. The two readings are compatible — a lump
> worth its price is still worth its price — but the wording has to be
> made to say that in one place, or the first person to author a cluster
> will pick whichever sentence they read first.

## Q2 — Detector tuning

Vendor **Dowsing Rod**: 64 m range, direction only, 30 s cooldown, 15c
(items_crafting.md §8.4). Gem Hunter **Gem Detector**: better, by how
much? Open: range, whether it reports distance or depth as well, whether
tier 2 of the profession improves it, and whether it works only on the
owner's own isle (recommendation: yes — otherwise it becomes a
continental ore radar and breaks the world's mining game).

## Q3 — Isle style palettes

The four styles are decided by name and feel (world.md §5.2). Open: the
concrete node palette and tree set per style, the above-water height
profile, and the skirt shape per style (gentle vs. cliffed). Reuse
`grug_nodes`/`grug_trees` and the per-race build sets
(biomes_mobs.md §5) where possible rather than authoring new content.

## Q4 — Reef band content

Decided that it exists (world.md §2b, biomes_mobs.md §1.2). Open: biome
registration, coral/kelp flora, the fish roster and whether the deferred
Shore Crab / Reef Lurker return with it. Belongs to the ocean-content
WP, not to housing itself — housing only needs the 150-node safe ring to
suppress hostile spawns.

## Q5 — Boats vs. the deep sea

world.md §2b makes it binding that deep-sea creatures destroy boats.
Open: whether boats exist at all in the MVP, and the mechanic (attack
the boat entity directly, or dismount and let the swimmer be the
target). Only relevant once someone adds boats.

## Q6 — Allocation edge case (implementation, not design)

Luanti generates deterministically from the seed, so an isle cannot
appear in chunks that were already emerged as plain ocean. Either track
a cheap emerged-flag and skip such slots at allocation time, or accept a
one-time forced regeneration of those chunks. Decide in the WP; both are
acceptable.
