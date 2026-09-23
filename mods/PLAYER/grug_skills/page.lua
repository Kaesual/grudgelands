local PAGE = "grug_skills:skills"
local detached = {}
local slots = {}

local function inv_name(name) return "grug_skills_" .. name end
local function present(player, itemname)
	local inv = player:get_inventory()
	for _, listname in ipairs({"main", "craft"}) do
		if inv:contains_item(listname, itemname) then return true end
	end
	for i = 1, grug_inventory.BAG_COUNT do
		if inv:contains_item(grug_inventory.content_list(i), itemname) then return true end
	end
	return false
end

local function entries(player)
	local result = {}
	for index, id in ipairs(grug_abilities.unlocked_ids(player)) do
		assert(index <= 8, "Skills ability row exceeds the decided class-kit limit")
		result[index] = {kind = "ability", id = id,
			stack = grug_abilities.stack_for(player, id)}
	end
	for _, id in ipairs(grug_mounts.owned_tier_ids(player)) do
		result[8 + id] = {kind = "mount", id = id,
			stack = grug_mounts.stack_for(player, id)}
	end
	return result
end

local function current_stack(player, entry)
	if entry.kind == "ability" then return grug_abilities.stack_for(player, entry.id) end
	return grug_mounts.stack_for(player, entry.id)
end

local function rebuild(player, announce)
	local name = player:get_player_name()
	local inv = detached[name]
	if not inv then return end
	local previous = {}
	for _, entry in pairs(slots[name] or {}) do
		if entry.kind == "ability" then previous[entry.id] = true end
	end
	local rows = entries(player)
	if announce == true then
		for _, entry in pairs(rows) do
			local def = entry.kind == "ability" and grug_abilities.registered[entry.id]
			if def and def.talent_gated and not previous[entry.id] then
				core.chat_send_player(name, def.name .. " unlocked. Open Inventory > Skills to use it.")
			end
		end
	end
	slots[name] = rows
	inv:set_size("catalog", 16)
	for i = 1, 16 do inv:set_stack("catalog", i, ItemStack("")) end
	for i, entry in pairs(rows) do inv:set_stack("catalog", i, entry.stack) end
end

grug_skills.rebuild = rebuild
local function create(player)
	local name = player:get_player_name()
	local callbacks = {
		allow_move = function() return 0 end,
		allow_take = function(_, listname, index, stack, actor)
			if not actor or actor:get_player_name() ~= name or listname ~= "catalog" then return 0 end
			local entry = slots[name] and slots[name][index]
			local fresh = entry and current_stack(actor, entry)
			if not fresh or fresh:get_name() ~= stack:get_name() or present(actor, stack:get_name()) then return 0 end
			if not actor:get_inventory():room_for_item("main", fresh) then return 0 end
			return -1
		end,
		on_take = function(_, _, index, stack, actor)
			local entry = slots[name] and slots[name][index]
			local fresh = entry and current_stack(actor, entry)
			if not fresh then return end
			local inv = actor:get_inventory()
			for i = 1, inv:get_size("main") do
				if inv:get_stack("main", i):get_name() == stack:get_name() then
					inv:set_stack("main", i, fresh); break
				end
			end
		end,
		allow_put = function(_, listname, index, stack, actor)
			if not actor or actor:get_player_name() ~= name or listname ~= "catalog" then return 0 end
			local entry = slots[name] and slots[name][index]
			local fresh = entry and current_stack(actor, entry)
			if fresh and fresh:get_name() == stack:get_name() and
					grug_skills.is_entitled(actor, stack) then return -1 end
			return 0
		end,
	}
	detached[name] = core.create_detached_inventory(inv_name(name), callbacks, name)
	rebuild(player)
end

local function passive_text(player)
	local lines = {}
	for id, def in pairs(grug_classes.registered_talents or {}) do
		local rank = grug_classes.talent_rank(player, id)
		if rank > 0 and not def.ability then
			lines[#lines + 1] = def.name .. " (" .. rank .. "): " ..
				(grug_classes.talent_description_for and
				grug_classes.talent_description_for(player, def) or def.description)
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

local function content(player)
	grug_skills.guard_destinations()
	rebuild(player)
	local location = "detached:" .. core.formspec_escape(inv_name(player:get_player_name()))
	local hint = core.formspec_escape(
		"Drop skills to remove them. Drag them back from here.")
	return "label[0.25,0.2;" .. hint .. "]" ..
		"label[0.25,0.65;Abilities]" ..
		"list[" .. location .. ";catalog;0.25,1.05;8,1;0]" ..
		"label[0.25,2.25;Purchased mounts]" ..
		"list[" .. location .. ";catalog;0.25,2.65;4,1;8]" ..
		"label[0.25,3.75;Passive and replacement talents]" ..
		"textarea[0.25,4.15;9.9,2.3;;;" ..
		core.formspec_escape(passive_text(player)) .. "]"

end

grug_skills.page_content = content
sfinv.register_page(PAGE, {title = "Skills", get = function(_, player, context)
	return sfinv.make_formspec(player, context, content(player), true)
end})

core.register_on_joinplayer(function(player) core.after(0, function(name)
	local current = core.get_player_by_name(name); if current then create(current) end
end, player:get_player_name()) end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name(); core.remove_detached_inventory(inv_name(name)); detached[name] = nil; slots[name] = nil
end)
grug_classes.register_on_class_chosen(rebuild)
if grug_classes.register_on_talents_changed then
	grug_classes.register_on_talents_changed(function(player) rebuild(player, true) end)
end
grug_classes.register_on_race_chosen(rebuild)
grug_factions.register_on_faction_chosen(rebuild)
grug_mounts.register_on_owned_tiers_changed(rebuild)

core.register_on_mods_loaded(function()
	local page, ordered, inserted = sfinv.pages[PAGE], {}, false
	for _, def in ipairs(sfinv.pages_unordered) do
		if def ~= page then ordered[#ordered + 1] = def end
		if def.name == "grug_classes:talents" then ordered[#ordered + 1] = page; inserted = true end
	end
	if not inserted then ordered[#ordered + 1] = page end
	sfinv.pages_unordered = ordered
end)
