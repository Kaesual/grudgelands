-- grug_text/surfaces.lua: the written surfaces of existing nodes (Round 68
-- lane TEXT): the two wall signs and every chest tier's label. Lane SIGNS
-- registers its own nodes where it defines them.

local INK = grug_text.INK

--
-- Wall signs (4 x 15). The board's front face lies 7/16 from the node's
-- centre towards the wall (default/nodes.lua `register_sign`: wall_side
-- -0.5 .. -0.4375), the text just in front of it in every wallmounted
-- orientation. Writing goes through the sign's own form handler (meta
-- `text`, core.is_protected); the text follows it, the hover text stays.
--

-- Placeholder boards without the vendored texture's scribble, which would
-- run through the text: rows 7 and 8 (the scribble) covered with copies of
-- the plain rows 6 and 9 of the same texture. One line each to swap for
-- picked art.
local function blank_board(png)
	return png .. "^[combine:16x16:0,7=" .. png .. "\\^[sheet\\:1x16\\:0,6:0,8=" ..
		png .. "\\^[sheet\\:1x16\\:0,9"
end
local SIGN_TILES = {
	["default:sign_wall_wood"] = blank_board("default_sign_wall_wood.png"),
	["grug_materials:iron_sign_wall"] = blank_board("default_sign_wall_steel.png"),
}

local SIGN = {lines = 4, chars = 15, offset = {x = 0, y = 0, z = 7 / 16 - 1 / 64}}

for name, tile in pairs(SIGN_TILES) do
	local def = core.registered_nodes[name]
	if def then
		local receive = def.on_receive_fields
		core.override_item(name, {
			tiles = {tile},
			on_receive_fields = function(pos, formname, fields, sender)
				receive(pos, formname, fields, sender)
				grug_text.refresh(pos)
			end,
		})
		local surface = table.copy(SIGN)
		surface.ink = name == "default:sign_wall_wood" and INK.dark or INK.iron
		grug_text.register(name, surface)
	end
end

--
-- Chest labels (3 x 13 of the label's 40 characters). On the front's lower
-- part, which stays when the lid opens (models/chest_open.obj: the body
-- ends at y = 3/16), below the lock plate (texture rows 4-10) and above the
-- bottom rim (row 15): the block's centre at y = -5/16, its glyphs' ink
-- (rows 3-10 of each 12 px line) centred there. Open and closed chests
-- share the front, so the open/close swap leaves the entity as it is; the
-- label save and the tier upgrade refresh it through
-- default.containers.update_infotext.
--

local LABEL = {lines = 3, chars = 13, frame = "facedir",
	offset = {x = 0, y = -5 / 16 + 0.5 / 128, z = -0.5 - 1 / 64}}

local function label_text(_, _, meta)
	return meta:get_string(default.containers.LABEL_KEY)
end

for tier = 1, #default.containers.TIERS do
	for _, base in ipairs({"default:chest", "default:chest_locked"}) do
		local name = default.containers.tier_name(base, tier)
		local surface = table.copy(LABEL)
		surface.text = label_text
		surface.ink = tier == 1 and INK.dark or INK.light
		grug_text.register(name, surface)
		grug_text.register(name .. "_open", surface)
	end
end
