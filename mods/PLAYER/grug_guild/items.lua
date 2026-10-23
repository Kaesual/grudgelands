-- The guild's items (spec §7, §8, §10.6): lane CONSUME fills this file.
--   the twelve consumables grug_guild:ore_sense_t1 .. _t6 and
--   grug_guild:treasure_hunt_t1 .. _t6 (catalog.CONSUMABLES: name, use
--   level as _grug_req_level, the picked icons), stackable, tradeable;
--   on use grug_guild.start_effect, the item taken only when it starts;
--   the six Miner's Remains nodes grug_guild:miners_remains_t1 .. _t6
--   (catalog.REMAINS: the tier rock with the picked overlay, its dig level,
--   no item of its own, is_ground_content = false), dropping the roll below.
--
--   grug_guild.remains_loot(tier, random) -> {copper = n, items = {"name count", ...}}
--       pure: `random(lo, hi)` an integer source (math.random in the game,
--       a fixed sequence in the fixture); the copper goes into one Bag of
--       Coins (grug_money.make_bag), the bars and the gem as stacks

-- Stub (lane CONSUME).
function grug_guild.remains_loot(tier, random)
	return {copper = 0, items = {}}
end
