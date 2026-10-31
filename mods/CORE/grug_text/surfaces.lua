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

-- The ink of each sign, one value each (lane ART's board art may change
-- them): dark on the wooden board, dark on the light grey iron board.
local SIGN_INK = {
	["default:sign_wall_wood"] = INK.dark,
	["grug_materials:iron_sign_wall"] = INK.iron,
}

local SIGN = {lines = 4, chars = 15, offset = {x = 0, y = 0, z = 7 / 16 - 1 / 64}}

for name, ink in pairs(SIGN_INK) do
	local def = core.registered_nodes[name]
	if def then
		local receive = def.on_receive_fields
		core.override_item(name, {
			on_receive_fields = function(pos, formname, fields, sender)
				receive(pos, formname, fields, sender)
				grug_text.refresh(pos)
			end,
		})
		local surface = table.copy(SIGN)
		surface.ink = ink
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

-- The ink per tier, one value each: dark on the Wooden chest, light on the
-- dark Steel-Reinforced and Abyssal fronts.
local CHEST_INK = {INK.dark, INK.light, INK.light}

local function label_text(_, _, meta)
	return meta:get_string(default.containers.LABEL_KEY)
end

for tier = 1, #default.containers.TIERS do
	for _, base in ipairs({"default:chest", "default:chest_locked"}) do
		local name = default.containers.tier_name(base, tier)
		local surface = table.copy(LABEL)
		surface.text = label_text
		surface.ink = CHEST_INK[tier]
		grug_text.register(name, surface)
		grug_text.register(name .. "_open", surface)
	end
end
