-- Shared page geometry and plain-text tooltip wrapping. Legacy coordinates
-- preserve native inventory cells while providing a larger content area.
grug_inventory.UI = {width = 10.4, height = 11.1, inventory_y = 7.2,
	content_bottom = 7.0}

function grug_inventory.wrap_text(value, width)
	width = width or 58
	local lines = {}
	for paragraph in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			if #line > 0 and #line + #word + 1 > width then
				lines[#lines + 1] = line
				line = word
			else
				line = line == "" and word or line .. " " .. word
			end
		end
		lines[#lines + 1] = line
	end
	return table.concat(lines, "\n")
end

-- The game's theme overrides the public sfinv builder instead of editing
-- vendored sources. All shipped pages use this shared inventory boundary.
function sfinv.make_formspec(player, context, content, show_inv, size)
	local parts = {size or "size[10.4,11.1]",
		sfinv.get_nav_fs(player, context, context.nav_titles, context.nav_idx)}
	if show_inv then
		for index = 0, 7 do
			parts[#parts + 1] = ("image[%.1f,7.2;1,1;gui_hb_bg.png]"):format(1.2 + index)
		end
		parts[#parts + 1] = "list[current_player;main;1.2,7.2;8,1;]" ..
			"list[current_player;main;1.2,8.35;8,3;8]"
	end
	parts[#parts + 1] = content
	return table.concat(parts)
end

core.register_on_mods_loaded(function()
	if not rawget(_G, "creative") then return end
	local foods = {}
	for name, definition in pairs(core.registered_items) do
		if ((definition.groups or {}).grug_food or 0) > 0 then
			foods[name] = definition
		end
	end
	creative.register_tab("food", "Food", foods)
end)
