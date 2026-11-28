-- Round 88 STATS: neutral stand-ins for the accessors the Character page's
-- stat sheet (mods/PLAYER/grug_inventory/stats.lua) reads, for fixtures that
-- render the page on their own stubs of grug_classes and grug_core. Only
-- missing ones are filled (a pool breakdown that names only `final` gets the
-- rest neutral); then the sheet itself is loaded. A fixture that checks the
-- sheet's numbers loads the real formulas instead (tools/r88_stats).
--
-- Usage, before dofile(".../grug_inventory/pages.lua"):
--   dofile(repo .. "/tools/r88_stats/sheet_stubs.lua")(repo)
return function(repo)
	repo = repo or "."
	local C, G = grug_classes, grug_core
	local function fill(t, key, value)
		if t[key] == nil then t[key] = value end
	end
	local neutral = function() return 0 end
	fill(C, "get_attributes", function() return {str = 10, int = 10, dex = 10} end)
	fill(C, "get_melee_bonus", function() return 1 end)
	fill(C, "get_spell_power_bonus", function() return 1 end)
	fill(C, "get_support_factor", function() return 1 end)
	fill(C, "get_crit_chance", function() return 0.05 end)
	fill(C, "get_dodge_chance", function() return 0.01 end)
	fill(C, "get_crit_chance_raw", C.get_crit_chance)
	fill(C, "get_dodge_chance_raw", C.get_dodge_chance)
	fill(C, "get_talent_bonus", neutral)
	local breakdown = C.get_pool_breakdown or function() return {final = 100} end
	C.get_pool_breakdown = function(player, pool)
		local b = breakdown(player, pool)
		if b.base == nil then
			b = {base = b.final, class_factor = 1, gear_percent = 0, talent_percent = 0,
				status_percent = 0, final = b.final}
		end
		return b
	end
	fill(G, "get_armor_rating", neutral)
	fill(G, "armor_reduction", neutral)
	fill(G, "armor_k", function(level) return 20 + 0.5 * level end)
	fill(G, "baseline_melee_total", function(level) return 4 + 0.35 * level end)
	grug_gear = grug_gear or {}
	fill(grug_gear, "format_armor", function(rating)
		return tostring(math.floor((tonumber(rating) or 0) * 10 + 0.5))
	end)
	grug_xp = grug_xp or {}
	fill(grug_xp, "get_level", function(player)
		return G.get_player_level and G.get_player_level(player) or 1
	end)
	fill(grug_inventory, "slot_label", function() return nil end)
	fill(grug_inventory, "equipment_slots", {})
	dofile(repo .. "/mods/PLAYER/grug_inventory/stats.lua")
end
