-- Round 55 lane ICONS's scene for the GAME capture probe
-- (SCENE=tools/r54_art/icons_scene.lua ART=tools/r55_art/art
-- tools/r55_game/capture.sh OUT_DIR; the format is in the probe's init.lua):
-- the redrawn armor icons as the game draws them.
--
-- I1: the 72 armor items' icons (item_image: the registered image), a column
-- per line and slot, a row per tier; below them each line's T3 pieces
-- enchanted (Strength prefix red, Dexterity suffix mint) and broken, as
-- grug_gear composes a stack's image, and the Character page's four
-- empty-slot ghosts. I2, I3: the same plain grid with the icons about 32 and
-- 16 px high (at 1600 x 900, gui_scaling 1, a unit is about 54 px). G1, G2: the
-- Character tab of an unarmored Warrior and Mage (the ghosts in their
-- slots). Icons do not depend on the offhand setting.
return function(api)
	local LINES = {"metal", "leather", "cloth"}

	local function grid(cell, step, extras)
		local cols = #LINES * #grug_visuals.SLOTS
		local x0, y0 = extras and 2.0 or 1.0, 1.0
		local rows = 6 + (extras and 3 or 0)
		local fs = {("formspec_version[6]size[%.2f,%.2f]bgcolor[#202024;true]"):format(
			x0 + cols * step + 0.4, y0 + rows * step + 0.4),
			"style_type[label;font_size=*1.0]"}
		local col = 0
		for _, line in ipairs(LINES) do
			for _, slot in ipairs(grug_visuals.SLOTS) do
				local x = x0 + col * step
				if extras then
					fs[#fs + 1] = ("label[%.2f,0.5;%s]"):format(x, line:sub(1, 1) .. " " .. slot)
				end
				for b = 1, 6 do
					fs[#fs + 1] = ("item_image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y0 + (b - 1) * step,
						cell, cell, grug_gear.armor_item(slot, line, b))
				end
				if extras then
					local image = core.registered_items[grug_gear.armor_item(slot, line, 3)].inventory_image
					fs[#fs + 1] = ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y0 + 6 * step, cell, cell,
						core.formspec_escape(grug_gear.enchant_image(image, "str", "dex")))
					fs[#fs + 1] = ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y0 + 7 * step, cell, cell,
						core.formspec_escape("(" .. image .. ")" .. grug_gear.BROKEN_MODIFIER))
				end
				col = col + 1
			end
		end
		for b = 1, 6 do
			fs[#fs + 1] = ("label[0.3,%.2f;T%d]"):format(y0 + (b - 1) * step + cell / 2, b)
		end
		if extras then
			fs[#fs + 1] = ("label[0.3,%.2f;T3 ench]"):format(y0 + 6 * step + cell / 2)
			fs[#fs + 1] = ("label[0.3,%.2f;T3 broken]"):format(y0 + 7 * step + cell / 2)
			fs[#fs + 1] = ("label[0.3,%.2f;ghosts]"):format(y0 + 8 * step + cell / 2)
			for i, slot in ipairs(grug_visuals.SLOTS) do
				fs[#fs + 1] = ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x0 + (i - 1) * step, y0 + 8 * step,
					cell, cell, core.formspec_escape("grug_gear_item_" .. slot .. "_metal.png^[multiply:#666666"))
			end
		end
		api.log(("icon grid shown (cell %.2f)"):format(cell))
		return table.concat(fs)
	end

	local scene = {}
	local function shots()
		return {
			{name = "I1_armor_icons_plain_enchanted_broken_ghosts", formspec = function() return grid(1, 1.15, true) end},
			{name = "I2_armor_icons_32px", formspec = function() return grid(0.6, 0.72, false) end},
			{name = "I3_armor_icons_16px", formspec = function() return grid(0.3, 0.4, false) end},
			{name = "G1_tab_warrior_unarmored_ghosts", tab = {class = "warrior"}},
			{name = "G2_tab_mage_unarmored_ghosts", tab = {class = "mage"}},
		}
	end
	scene.on, scene.off = shots, shots
	return scene
end
