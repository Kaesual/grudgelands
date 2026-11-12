-- Static copies for the Expeditions' templates (Round 78, ruling 5): grug_expeditions
-- writes them in place of the originals (its catalogue.STATIC). Same look and light;
-- no attachment or fall (builtin falling.lua drops an attached node whose support is
-- not walkable at a punch nearby, protection unasked), no callbacks (so no inventory,
-- no form, no flood), no drop. The hanging lantern uses its city copy
-- (city_variants.lua), which already holds still.
local function static(source, suffix)
	local def = table.copy(assert(core.registered_nodes[source], source))
	for key, value in pairs(def) do
		if type(value) == "function" then def[key] = nil end
	end
	def.groups.attached_node, def.groups.falling_node = nil, nil
	def.groups.not_in_creative_inventory = 1
	def.drop = ""
	def.floodable = false
	core.register_node("grug_decor:expedition_" .. suffix, def)
end

static("default:torch_wall", "torch_wall")
static("default:bookshelf", "bookshelf")
