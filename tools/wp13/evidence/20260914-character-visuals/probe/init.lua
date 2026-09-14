-- TEMPORARY boot probe for the WP13 character-visuals increment. Staged into
-- mods/PLAYER/zz_wp13_visual_probe/ for exactly one headless run and deleted
-- again; it is archived here so the engine log lines in this evidence
-- directory can be reproduced.
--
-- It answers the two things a clean boot alone does not: do the humanoid mob
-- definitions actually resolve a composed texture at activation, and does the
-- composition of each of the six races name textures the server accepts.

zz_wp13_visual_probe = {}

local MOBS = {
	"grug_mobs:guard_accord",
	"grug_mobs:guard_throng",
	"grug_mobs:bandit",
	"grug_mobs:mirefolk",
	"grug_traders:vendor_general_accord",
	"grug_traders:vendor_race_dwarf",
}

local RACES = {"human", "dwarf", "elf", "undead", "orc", "troll"}

core.register_on_mods_loaded(function()
	core.log("action", "[wp13probe] registered entities: " ..
		tostring(core.registered_entities["grug_mobs:guard_accord"] ~= nil) ..
		" guard, " ..
		tostring(core.registered_entities["grug_mobs:bandit"] ~= nil) ..
		" bandit, " ..
		tostring(core.registered_entities["grug_mobs:mirefolk"] ~= nil) ..
		" mirefolk, " ..
		tostring(core.registered_entities["grug_traders:vendor_general_accord"]
			~= nil) .. " vendor")

	core.after(8, function()
		for _, name in ipairs(MOBS) do
			local obj = core.add_entity({x = 0, y = 80, z = 0}, name)
			if not obj then
				core.log("action", "[wp13probe] " .. name .. " NO ENTITY")
			else
				local ent = obj:get_luaentity()
				local props = obj:get_properties()
				core.log("action", "[wp13probe] " .. name ..
					" textures=" .. dump(props.textures):gsub("%s+", " ") ..
					" skin=" .. tostring(ent and ent._grug_visual_skin) ..
					" wield=" .. tostring(ent and ent._grug_wield_item))
				obj:remove()
			end
		end
		for _, race in ipairs(RACES) do
			local result = grug_visuals.compose({race = race,
				armor_line = "metal", bracket = 6, weapon_family = "sword"})
			core.log("action", "[wp13probe] race " .. race .. " -> " ..
				result.textures[1] .. " size=" ..
				dump(result.visual_size):gsub("%s+", " ") .. " weapon=" ..
				tostring(result.weapon))
		end
		local bare = grug_visuals.compose({race = "troll"})
		core.log("action", "[wp13probe] bare troll -> " .. bare.textures[1])
		core.log("action", "[wp13probe] done")
	end)
end)
