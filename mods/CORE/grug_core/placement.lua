-- Placement rules (Round 72 PLACE, round72-plan.md §2.2; combat_stats.md
-- "Placement in combat and around bodies").
--
--   * In combat a player places nothing that restricts movement: a walkable
--     or climbable node or a liquid is refused with a grey feed line.
--     Torches, plants and other nodes that block nobody stay allowed;
--     digging and right-click interaction are untouched.
--   * In or out of combat, a walkable node is never placed into a cell that
--     overlaps the collision box of a live mob (guards, bosses, NPCs) or
--     player; a body spans several cells. The placing player's own body is
--     exempt (Round 78 ruling 8: towering, a block under one's own feet in a
--     jump); other players and mobs still block.
--   * A walkable falling node is tested where it lands: a landing cell that
--     overlaps a live body refuses the landing and builtin drops the node as
--     an item (falling.lua on_step). This also catches sand whose support was
--     dug.
--
-- One seam round core.item_place_node (every node without placement code of
-- its own, and the wrappers that call it: stairs, slabs, decor shapes,
-- torches, packed containers); the paths that write their nodes with their
-- own set_node ask grug_core.placement_refused themselves: doors and beds
-- (GRUG PATCH), the water bucket, the notice board and the Claim Stone.
--
-- Cost: nothing per tick; one get_objects_inside_radius per placement that
-- could block (and per walkable falling node's landing), the in-combat test
-- a table lookup.
--
--   grug_core.placement_refused(placer, node_name, cells) -> true | false
--     True when the rules refuse writing `node_name` into every cell of
--     `cells` (a list of positions) for `placer` (a player, another object or
--     nil); a player placer then gets the grey feed line. Callers run their
--     protection check first, so a protected cell keeps its own line.
--   grug_core.body_in_cells(cells, except) -> true | false
--     Whether any cell overlaps a live body (the rule above); `except` is a
--     player whose own body does not count (the placer), nil for none.

local placement = {}
grug_core.placement = placement

-- Objects whose position lies farther than this from the tested cells cannot
-- reach into them: the widest and tallest mob boxes reach about 1 node
-- sideways and under 3 nodes up from their position.
placement.QUERY_RADIUS = 4
-- A body that only touches a cell's face (a player against a wall, a mob's
-- box dipping 0.01 into the ground it stands on) does not stand in it.
placement.TOUCH = 0.05

placement.COMBAT_LINE = "Cannot place that in combat."
placement.BODY_LINE = "Cannot place a block where someone stands."
local FEED_KEY = "placement"

local function is_player(object)
	return object ~= nil and type(object.is_player) == "function" and
		object:is_player() == true
end

-- Blocks movement: refused in combat. Walkable defaults to true in the
-- registered definition (builtin's nodedef_default).
function placement.restricts_movement(def)
	return def ~= nil and (def.walkable ~= false or def.climbable == true or
		(def.liquidtype ~= nil and def.liquidtype ~= "none"))
end

-- The collision box of a live body, or nil for anything else (items, falling
-- nodes, projectiles, tag carriers, a dead mob or player). mobs_redo keeps a
-- mob's live box in `_grug_cbox` (mobs/api.lua, Round 30 P2).
local function body_box(object)
	if is_player(object) then
		if object:get_hp() <= 0 then return nil end
		local props = object:get_properties()
		return props and props.collisionbox
	end
	local entity = object:get_luaentity()
	if not entity or not entity._cmi_is_mob then return nil end
	if (entity.health or 0) <= 0 or entity.state == "die" then return nil end
	return entity._grug_cbox or entity.base_colbox
end

local function overlaps(pos, box, cell)
	local touch = placement.TOUCH
	return pos.x + box[1] + touch < cell.x + 0.5 and pos.x + box[4] - touch > cell.x - 0.5 and
		pos.y + box[2] + touch < cell.y + 0.5 and pos.y + box[5] - touch > cell.y - 0.5 and
		pos.z + box[3] + touch < cell.z + 0.5 and pos.z + box[6] - touch > cell.z - 0.5
end

-- The placer's own body (by name: a player is one object, whichever ref).
local function own_body(object, except_name)
	return except_name ~= nil and is_player(object) and
		object:get_player_name() == except_name
end

-- One area query round the cells' middle (the cells of one placement are
-- neighbours: a door's two, a bed's two).
function grug_core.body_in_cells(cells, except)
	local count = #cells
	if count == 0 then return false end
	local cx, cy, cz = 0, 0, 0
	for index = 1, count do
		local cell = cells[index]
		cx, cy, cz = cx + cell.x, cy + cell.y, cz + cell.z
	end
	local middle = {x = cx / count, y = cy / count, z = cz / count}
	local spread = 0
	for index = 1, count do
		local cell = cells[index]
		local dx, dy, dz = cell.x - middle.x, cell.y - middle.y, cell.z - middle.z
		spread = math.max(spread, math.sqrt(dx * dx + dy * dy + dz * dz))
	end
	local except_name = is_player(except) and except:get_player_name() or nil
	local objects = core.get_objects_inside_radius(middle, placement.QUERY_RADIUS + spread)
	for index = 1, #objects do
		local object = objects[index]
		local box = not own_body(object, except_name) and body_box(object)
		local pos = box and object:get_pos()
		if pos then
			for c = 1, count do
				if overlaps(pos, box, cells[c]) then return true end
			end
		end
	end
	return false
end

-- The reason to refuse, or nil.
function placement.refusal(placer, node_name, cells)
	local def = core.registered_nodes[node_name]
	if not def then return nil end
	if is_player(placer) and placement.restricts_movement(def) and
			grug_core.in_combat(placer) then
		return placement.COMBAT_LINE
	end
	if def.walkable ~= false and grug_core.body_in_cells(cells, placer) then
		return placement.BODY_LINE
	end
	return nil
end

function grug_core.placement_refused(placer, node_name, cells)
	local line = placement.refusal(placer, node_name, cells)
	if not line then return false end
	if is_player(placer) then
		grug_core.feed(placer, "combat", line, FEED_KEY)
	end
	return true
end

-- The cell builtin core.item_place_node writes, or nil when it places nothing
-- there anyway (unloaded, nothing buildable); builtin/game/item.lua.
local function builtin_place_cell(pointed_thing)
	local under, above = pointed_thing.under, pointed_thing.above
	local node_under = under and core.get_node_or_nil(under)
	local node_above = above and core.get_node_or_nil(above)
	if not node_under or not node_above then return nil end
	local def_under = core.registered_nodes[node_under.name] or core.nodedef_default
	local def_above = core.registered_nodes[node_above.name] or core.nodedef_default
	if def_under and def_under.buildable_to then return under end
	if def_above and def_above.buildable_to then return above end
	return nil
end

local builtin_item_place_node = core.item_place_node

function core.item_place_node(itemstack, placer, pointed_thing, param2, prevent_after_place)
	local def = itemstack:get_definition()
	if def and def.type == "node" and pointed_thing and pointed_thing.type == "node" then
		local cell = builtin_place_cell(pointed_thing)
		local line = cell and placement.refusal(placer, def.name, {cell})
		-- A protected cell keeps builtin's refusal and its protection line.
		if line and not core.is_protected(cell,
				is_player(placer) and placer:get_player_name() or "") then
			if is_player(placer) then
				grug_core.feed(placer, "combat", line, FEED_KEY)
			end
			return itemstack, nil
		end
	end
	return builtin_item_place_node(itemstack, placer, pointed_thing, param2,
		prevent_after_place)
end

-- The cell builtin's try_place writes (builtin/game/falling.lua): the node it
-- landed on when that is buildable (and the float rule lets it through), a
-- leveled node of the same kind grows in place, else the cell above.
local function landing_cell(entity, bcp, bcn)
	local bcd = core.registered_nodes[bcn.name]
	if bcd and bcd.paramtype2 == "leveled" and bcn.name == entity.node.name then
		return bcp
	end
	if bcd and bcd.buildable_to and (not entity.floats or bcd.liquidtype == "none" or
			(entity.floats and entity.liquidtype ~= "none" and bcd.liquidtype ~= "source")) then
		return bcp
	end
	return {x = bcp.x, y = bcp.y + 1, z = bcp.z}
end

local falling = core.registered_entities["__builtin:falling_node"]
if falling and type(falling.try_place) == "function" then
	local builtin_try_place = falling.try_place
	-- Entities look methods up in their registered definition (prototype), so
	-- every falling node, also one activated from a saved block, takes this.
	falling.try_place = function(self, bcp, bcn)
		local def = self.node and core.registered_nodes[self.node.name]
		if def and def.walkable ~= false and
				grug_core.body_in_cells({landing_cell(self, bcp, bcn)}) then
			return false
		end
		return builtin_try_place(self, bcp, bcn)
	end
end
