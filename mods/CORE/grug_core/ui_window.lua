-- Viewport ceiling, evaluated only when an owner builds a form: Full HD, and
-- since Round 66 (ruling 4) at least two thirds of a taller screen.
-- Native fitting still handles smaller windows, GUI scaling and display DPI.
-- Reports can be absent on join or lag a resize; no polling/resend is added.
local UI = grug_core.ui
local WIDTH, HEIGHT = 1920, 1080
local function positive(value)
	return type(value) == "number" and value > 0 and value < math.huge
end

-- The capped viewport: height min(H, max(1080, 2/3 H)), width 1920 scaled by
-- the same factor (at most W). Up to a 1620 px high screen this is exactly
-- the Full-HD ceiling; `full_hd` asks for that ceiling on any screen (the
-- reference text sizes are measured against it).
local function dimensions(info, full_hd)
	local size = type(info) == "table" and info.size
	if type(size) ~= "table" or not positive(size.x) or not positive(size.y) then return end
	local w, h = size.x, size.y
	local vh = full_hd and math.min(h, HEIGHT) or math.min(h, math.max(HEIGHT, h * 2 / 3))
	return w, h, math.min(w, WIDTH * math.max(1, vh / HEIGHT)), vh
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
	-- a client of that size, including its fixed DPI/GUI lower bound.
	return ("padding[%.6f,%.6f]"):format(
		(1 - vw / w * (1 - 2 * base)) / 2,
		(1 - vh / h * (1 - 2 * base)) / 2)
end

-- Responsive layouts use the same virtual viewport as native fitting.
-- max_formspec_size reports the unpadded viewport / preferred image size.
-- The fixed floor uses real_gui_scaling (GUI * density); we never mistake
-- density for GUI scale. Shrinking the viewport scales the other term,
-- which is proportional to its smaller dimension, until it meets the floor.
-- `full_hd` derives the Full-HD-capped report instead (text sizes). A
-- derived report is marked `capped` and passes through unchanged: since the
-- ceiling follows the screen height, capping it again would shrink it.
function UI.window_information(info, full_hd)
	if type(info) == "table" and info.capped then return info end
	local w, h, vw, vh = dimensions(info, full_hd)
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
	result.capped = true
	return result
end

-- Pixels per unit of a real-coordinate fw x fh form with the default 5 %
-- padding on a (virtual) report, as GUIFormSpecMenu::calculateImgsize sizes
-- it: the preferred size (padded, never under the fixed floor) unless the
-- form must shrink to fit.
local function imgsize(info, fw, fh)
	local w, h = info.size.x, info.size.y
	return math.min(math.max(0.5555 * 96 * info.real_gui_scaling,
		0.9 * w / info.max_formspec_size.x), 0.9 * w / fw, 0.9 * h / fh)
end

-- How much larger a fw x fh form is drawn under the grown ceiling than under
-- the Full-HD one (Round 66: text grows by the same factor, so it keeps its
-- 1080p proportion to the slots). Exactly 1 wherever the ceiling did not
-- grow (screens up to 1620 px high) or the form does not grow with it (a
-- narrow portrait screen, or the fixed floor on a high-density display).
function UI.form_growth(info, fw, fh)
	local grown, full_hd = UI.window_information(info), UI.window_information(info, true)
	if grown == info or full_hd == info or not positive(fw) or not positive(fh) or
			(grown.size.x == full_hd.size.x and grown.size.y == full_hd.size.y) then
		return 1
	end
	return imgsize(grown, fw, fh) / imgsize(full_hd, fw, fh)
end
