-- Gathering tools never double as weapons. Exact use accounting belongs to
-- grug_repair's after_use callback; capabilities retain mining speed/access.
local lifetimes = {300, 600, 1000, 1500, 2000, 3000}
local function normalize(name, uses)
	local def = assert(core.registered_items[name], "missing tool " .. name)
	local groups = table.copy(def.groups or {})
	groups.grug_equip_weapon = nil
	groups.grug_gathering_tool = 1
	local caps = table.copy(def.tool_capabilities)
	caps.damage_groups = {fleshy = 0}
	caps.punch_attack_uses = 0
	for _, cap in pairs(caps.groupcaps or {}) do
		cap.uses = math.max(1, math.ceil(uses / (3 ^ (cap.maxlevel or 0))))
	end
	local description = (def.description or name):gsub("\n.*", "")
	if (groups.axe or 0) > 0 and not description:find("Woodcutting", 1, true) then
		description = description:gsub("Axe$", "Woodcutting Axe")
	end
	core.override_item(name, {groups = groups, tool_capabilities = caps,
		_grug_tool_uses = uses, description = description .. "\n" .. uses .. " uses"})
end

for _, family in ipairs({"pick", "axe", "shovel"}) do
	normalize("default:" .. family .. "_wood", 30)
	normalize("default:" .. family .. "_stone", 60)
	for tier, row in ipairs(grug_materials.TIERS) do
		local prefix = (tier == 1 or tier == 3) and "default:" or "grug_materials:"
		normalize(prefix .. family .. "_" .. row.key, lifetimes[tier])
	end
end
