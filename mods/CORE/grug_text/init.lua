-- grug_text: readable text in the world (Round 68 lane TEXT, rulings 1-4).
--
-- The engine draws no text on nodes. A written surface (a sign's board, a
-- chest's label) gets one text entity: a non-pointable `upright_sprite`
-- just in front of the surface whose texture is the text, one `[combine` of
-- the imported CC0 glyphs (textures/grug_text_*.png, characters.tsv; see
-- LICENSE-media.md) tinted with `[multiply` by the surface's ink. The
-- entities are not saved (`static_save = false`): the engine deletes one
-- with its unloaded mapblock, the LBM below recreates it when the node's
-- block is activated again, and the node's own update paths (writing,
-- clearing, swapping) call `refresh`. A surface without text has no
-- entity. The wrapping and the texture are pure (layout.lua).
--
-- API (lane SIGNS builds the standing sign, waypost and notice board on it):
--
--   grug_text.register(node_name, surface_or_list)
--     At load time, after the node is registered. One surface description
--     or a list of them (one entity each, e.g. a board's two sides). Adds
--     the group `grug_text` (the LBM's node list) and wraps the node's
--     `after_destruct` to remove its entities. A surface description:
--       lines, chars  the text grid (required), e.g. 4 x 15
--       ink           ColorString the white glyphs are multiplied with
--                     (default grug_text.INK.dark)
--       offset        the text block's centre from the node's centre, in
--                     the surface's frame: x to the reader's right, y up,
--                     z away from the reader (into the surface); default 0
--       frame         how the node turns the surface: "wallmounted",
--                     "facedir" (4dir too), "degrotate", "none", or a
--                     function(node) -> forward, up (unit vectors: the
--                     reader's look direction and the text's up). Default:
--                     from the node's paramtype2. Unrotated (facedir 0,
--                     degrotate 0, wallmounted 4) the reader looks along +z;
--                     wallmounted floor and ceiling boards read with their
--                     top towards +z (towards +x for param2 6 and 7).
--       faces         1 (default) or 2: the sprite's back shows the same
--                     text, read correctly from behind, not mirrored (the
--                     engine swaps the back quad's corners and keeps its
--                     UVs, src/client/content_cao.cpp:654-663, and uses
--                     textures[2] for it, :1360-1369). Only useful where
--                     nothing solid encloses the sprite from behind.
--       align         "center" (default) or "left"; valign "center"
--                     (default) or "top"
--       text          function(pos, node, meta) -> string; default the
--                     meta field "text"
--   grug_text.refresh(pos)  rebuild, create or remove the entities of the
--                     node at pos from its current text (after writing,
--                     clearing, a swap_node to another registered node)
--   grug_text.remove(pos)   remove the node's entities
--   grug_text.layout        the pure wrapping and texture functions
--   grug_text.charmap       {[code point] = texture name}
--
-- Known limit: an entity lives in the mapblock its position rounds to. A
-- chest label sits in front of the chest, so for a chest on a block's edge
-- it lives in the next block; if that block alone is unloaded while the
-- chest's block stays active (a player far away at the edge of the active
-- range), the label is gone until the chest's block is activated again.

grug_text = {}

local modpath = core.get_modpath(core.get_current_modname())
local layout = dofile(modpath .. "/layout.lua")
grug_text.layout = layout
grug_text.charmap = layout.load_charmap(modpath .. "/characters.tsv")

-- The plan's inks (Round 68 coordinator default): dark ink on wood and on
-- the light iron board, light ink on the dark metal chest fronts.
grug_text.INK = {dark = "#2a1b0e", iron = "#1c1c22", light = "#ece4cc"}

local ENTITY = "grug_text:text"
local UP = vector.new(0, 1, 0)
local ZERO = vector.new(0, 0, 0)
local surfaces = {}
-- The search radius around a node: its farthest text entity, plus a margin.
local radius = 0.75

local function default_text(_, _, meta)
	return meta:get_string("text")
end

local frames = {
	none = function()
		return vector.new(0, 0, 1), UP
	end,
	facedir = function(node)
		return core.facedir_to_dir(node.param2 % 4), UP
	end,
	degrotate = function(node)
		return core.yaw_to_dir(math.rad(1.5 * (node.param2 % 240))), UP
	end,
	wallmounted = function(node)
		local p = node.param2 % 8
		local forward = core.wallmounted_to_dir(p)
		if forward.y ~= 0 then
			return forward, p >= 6 and vector.new(1, 0, 0) or vector.new(0, 0, 1)
		end
		return forward, UP
	end,
}
frames["4dir"] = frames.facedir

core.register_entity(ENTITY, {
	initial_properties = {
		visual = "upright_sprite",
		textures = {"blank.png", "blank.png"},
		pointable = false,
		physical = false,
		collide_with_objects = false,
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	-- Set by refresh: _grug_pos (the node), _grug_index (the surface),
	-- _grug_tex, _grug_at, _grug_rot (what was last sent).
})

-- The text entities of the node at pos.
local function attached(pos)
	local found = {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == ENTITY and ent._grug_pos and vector.equals(ent._grug_pos, pos) then
			found[#found + 1] = ent
		end
	end
	return found
end

function grug_text.remove(pos)
	for _, ent in ipairs(attached(vector.round(pos))) do
		ent.object:remove()
	end
end

-- The surface's texture for `text`, or nil when nothing would show.
local function texture(surface, text)
	if text == "" then return nil end
	return layout.texture(layout.wrap(text, surface.lines, surface.chars), surface,
		grug_text.charmap)
end

-- Where the surface's entity stands and how it is turned.
local function placement(surface, pos, node)
	local forward, up = surface.frame(node)
	local rot = vector.dir_to_rotation(forward, up)
	return vector.add(pos, vector.rotate(surface.offset, rot)), rot
end

-- Sends only what changed (the LBM also runs on a block that was merely
-- deactivated, whose entities are still there).
local function place(ent, surface, at, rot, tex)
	if not (ent._grug_at and vector.equals(ent._grug_at, at)) then
		ent.object:set_pos(at)
		ent._grug_at = at
	end
	if not (ent._grug_rot and vector.equals(ent._grug_rot, rot)) then
		ent.object:set_rotation(rot)
		ent._grug_rot = rot
	end
	if ent._grug_tex ~= tex then
		ent.object:set_properties({
			textures = {tex, surface.faces == 2 and tex or "blank.png"},
			visual_size = surface.visual_size,
		})
		ent._grug_tex = tex
	end
end

-- `loading`: from the LBM, where no entity of the node can exist yet unless
-- the block was only deactivated; a node without text then needs no search.
local function refresh(pos, node, loading)
	local list = surfaces[node.name]
	local meta = core.get_meta(pos)
	local textures = {}
	local any = false
	for index, surface in ipairs(list or {}) do
		textures[index] = texture(surface, surface.text(pos, node, meta) or "")
		any = any or textures[index] ~= nil
	end
	if loading and not any then return end
	local kept = {}
	for _, ent in ipairs(attached(pos)) do
		local index = ent._grug_index
		if textures[index] and not kept[index] then
			kept[index] = ent
		else
			ent.object:remove()
		end
	end
	for index, surface in ipairs(list or {}) do
		local tex = textures[index]
		if tex then
			local ent = kept[index]
			local at, rot = placement(surface, pos, node)
			if not ent then
				local obj = core.add_entity(at, ENTITY)
				ent = obj and obj:get_luaentity()
				if ent then
					ent._grug_pos, ent._grug_index, ent._grug_at = vector.copy(pos), index, at
				end
			end
			if ent then place(ent, surface, at, rot, tex) end
		end
	end
end

function grug_text.refresh(pos)
	pos = vector.round(pos)
	local node = core.get_node_or_nil(pos)
	if node then refresh(pos, node, false) end
end

function grug_text.register(name, list)
	local def = core.registered_nodes[name]
	assert(def, "grug_text.register: unknown node " .. tostring(name))
	assert(not surfaces[name], "grug_text.register: " .. name .. " is registered twice")
	if list.lines then list = {list} end
	local out = {}
	for index, given in ipairs(list) do
		assert(given.lines and given.chars, "grug_text.register: lines and chars")
		local surface = table.copy(given)
		surface.text = given.text or default_text
		surface.ink = given.ink or grug_text.INK.dark
		surface.offset = vector.copy(given.offset or ZERO)
		local frame = given.frame or def.paramtype2
		surface.frame = type(frame) == "function" and frame or frames[frame] or frames.none
		local w, h = layout.canvas(surface.lines, surface.chars)
		surface.visual_size = {x = w * layout.PIXEL, y = h * layout.PIXEL}
		radius = math.max(radius, vector.length(surface.offset) + 0.25)
		out[index] = surface
	end
	surfaces[name] = out
	local groups = table.copy(def.groups or {})
	groups.grug_text = 1
	local after_destruct = def.after_destruct
	core.override_item(name, {
		groups = groups,
		after_destruct = function(pos, oldnode)
			if after_destruct then after_destruct(pos, oldnode) end
			grug_text.remove(pos)
		end,
	})
end

-- The surfaces of a node name (read-only), or nil.
function grug_text.surfaces(name)
	return surfaces[name]
end

core.register_lbm({
	label = "Recreate the text entities of written surfaces",
	name = "grug_text:restore",
	nodenames = {"group:grug_text"},
	run_at_every_load = true,
	action = function(pos, node)
		refresh(pos, node, true)
	end,
})

dofile(modpath .. "/surfaces.lua")
