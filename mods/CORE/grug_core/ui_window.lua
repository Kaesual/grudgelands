-- Full-HD viewport ceiling, evaluated only when an owner builds a form.
-- Native fitting still handles smaller windows, GUI scaling and display DPI.
-- Reports can be absent on join or lag a resize; no polling/resend is added.
local UI = grug_core.ui
local WIDTH, HEIGHT = 1920, 1080
local function positive(value)
	return type(value) == "number" and value > 0 and value < math.huge
end

local function dimensions(info)
	local size = type(info) == "table" and info.size
	if type(size) ~= "table" or not positive(size.x) or not positive(size.y) then return end
	return size.x, size.y, math.min(size.x, WIDTH), math.min(size.y, HEIGHT)
end

-- Keep the parser's required order: size, position, anchor, padding, no_prepend.
-- The optional info is the same snapshot used by responsive layouts such as Map.
function UI.window_padding(player, base, info)
	base = base or 0.05
	if info == nil and player and core.get_player_window_information then
		info = core.get_player_window_information(player:get_player_name())
	end
	local w, h, vw, vh = dimensions(info)
	if not w or (w == vw and h == vh) then
		return base == 0.05 and "" or ("padding[%g,%g]"):format(base, base)
	end
	-- calculateImgsize uses screen * (1 - 2 * padding) as its available
	-- viewport. Substituting a capped viewport reproduces the same form on
	-- a Full-HD client, including its fixed DPI/GUI lower bound.
	return ("padding[%.6f,%.6f]"):format(
		(1 - vw / w * (1 - 2 * base)) / 2,
		(1 - vh / h * (1 - 2 * base)) / 2)
end

-- Responsive layouts use the same virtual viewport as native fitting.
-- max_formspec_size reports the unpadded viewport / preferred image size.
-- The fixed floor uses real_gui_scaling (GUI * density); we never mistake
-- density for GUI scale. Shrinking the viewport scales the other term,
-- which is proportional to its smaller dimension, until it meets the floor.
function UI.window_information(info)
	local w, h, vw, vh = dimensions(info)
	local max = type(info) == "table" and info.max_formspec_size
	local rgs = type(info) == "table" and info.real_gui_scaling
	if not w or (w == vw and h == vh) or type(max) ~= "table" or
			not positive(max.x) or not positive(max.y) or not positive(rgs) then return info end
	local preferred = math.max(w / max.x, h / max.y)
	local virtual_preferred = math.max(0.5555 * 96 * rgs,
		preferred * math.min(vw, vh) / math.min(w, h))
	local result = {}
	for key, value in pairs(info) do result[key] = value end
	result.size = {x = vw, y = vh}
	result.max_formspec_size = {x = vw / virtual_preferred, y = vh / virtual_preferred}
	return result
end
