-- The mining effect (spec §7, §10.5): lane CONSUME fills this file. One
-- status id, grug_guild.catalog.STATUS.id ("mining_sense"), with a variant
-- per kind ("ore_sense", "treasure_hunt"), so one of the two runs at a
-- time; not the elixir's id. It works only in its tier's depth
-- (grug_materials.tier_at(y) == tier) and saves its remaining time, so it
-- continues across logout, a crash and death:
--   player meta grug_guild:effect   core.serialize({kind, tier, remaining})
--       remaining in seconds, written on a timer and at leave, read at join
--       and re-applied after on_dieplayer clears the statuses; no position
--       (nothing map-bound; the Treasure Hunt's block lives in the map and
--       removes itself)
--
--   grug_guild.active_effect(player) -> {kind, tier, remaining} | nil
--   grug_guild.start_effect(player, kind, tier) -> true | false, err
--       err "unknown", "level" (below the item's use level), "depth"
--       (outside its tier's band), "active" (an effect runs: never replaced)
--   grug_guild.stop_effect(player) -> bool   (admin and tests)

grug_guild.EFFECT_KEY = "grug_guild:effect"

-- Stubs (lane CONSUME).
function grug_guild.active_effect(player)
	return nil
end

function grug_guild.start_effect(player, kind, tier)
	return false, "unavailable"
end

function grug_guild.stop_effect(player)
	return false
end
