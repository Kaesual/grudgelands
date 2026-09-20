return function(root)
	local function read(path)
		local file = assert(io.open(root .. "/" .. path, "rb"), path)
		local value = assert(file:read("*a")); file:close(); return value
	end
	local abilities = read("mods/PLAYER/grug_abilities/init.lua")
	local mounts = read("mods/PLAYER/grug_mounts/state.lua")
	local items = read("mods/PLAYER/grug_mounts/items.lua")
	local skills = read("mods/PLAYER/grug_skills/page.lua")
	local bound = read("mods/PLAYER/grug_skills/bound_items.lua")
	assert(abilities:find("function grug_abilities.is_unlocked", 1, true))
	assert(abilities:find("function grug_abilities.unlocked_ids", 1, true))
	assert(abilities:find("function grug_abilities.stack_for", 1, true))
	assert(not abilities:find("return itemstack -- ability items cannot be dropped", 1, true))
	assert(mounts:find("function grug_mounts.owned_tier_ids", 1, true))
	assert(not mounts:find("room_for_item", 1, true))
	assert(items:find("grug_bound_skill = 1", 1, true))
	assert(skills:find("return -1", 1, true))
	assert(skills:find('for _, listname in ipairs({"main", "craft"})', 1, true))
	assert(bound:find("core.override_item", 1, true))
	assert(bound:find('if action == "move"', 1, true))
	return "r12-skills-ok"
end
