-- Round 64 M0: exact recipe identities and decoded RGBA size accounting.
-- LuaJIT only. This does not upload textures or measure GPU/process memory.
-- Uses real map geometry; artificial tiles stand in for one prepared world.
local root = arg[1] or "."
rawset(_G, "grug_core", {})
dofile(root .. "/mods/CORE/grug_core/hud_layout.lua")
local V = dofile(root .. "/mods/PLAYER/grug_map/minimap_view.lua")
local atlas = dofile(root .. "/mods/PLAYER/grug_map/atlas.lua")
local tiles, overlay = {}, {}
local width, height = 1215, 1080
for y = 0, height - 1, 512 do
	for x = 0, width - 1, 512 do
		local w, h = math.min(512, width - x), math.min(512, height - y)
		local suffix = x .. "_" .. y .. ".png"
		tiles[#tiles + 1] = {x = x, y = y, w = w, h = h, name = "map_" .. suffix}
		overlay[#overlay + 1] = {x = x, y = y, w = w, h = h, name = "flight_" .. suffix}
	end
end
local view = V.new({width = width, height = height, quality = "normal", tiles = tiles}, atlas.view())
local function escape(s) return (s:gsub("[\\^:]", "\\%0")) end
-- Minimal candidate: upscale a terrain cell before inserting a native 32px
-- icon. One artificial central marker suffices to test texture/cache cost;
-- real marker placement and roster composition are deliberately not built.
local function candidate(terrain, frame)
	local n = frame.drawn
	local background = terrain .. ("^[resize:%dx%d"):format(n, n)
	return ("[combine:%dx%d:0,0=%s:%d,%d=grug_map_innkeeper.png"):format(
		n, n, escape(background), math.floor(n / 2 - 16), math.floor(n / 2 - 16))
end
local old_seen, new_seen = {}, {}
local old_bytes, new_bytes = 0, 0
local function run(label, screen_y, flight, reverse)
	local frame = V.frame(view, grug_core.hud_layout.minimap_box({
		size = {x = screen_y * 16 / 9, y = screen_y},
		real_hud_scaling = 1, real_gui_scaling = 1}))
	local old_count, new_count, longest_old, longest_new = 0, 0, 0, 0
	local cell_x, cell_y
	-- 9,750 nodes on a diagonal: x -3900..3900, z -2925..2925.
	-- 12 nodes/s at 0.09 s/step (same step and flight speed as bench_glide).
	local steps = math.ceil(9750 / (12 * 0.09))
	for step = 0, steps do
		local t = step / steps
		if reverse then t = 1 - t end
		local cx, cy = V.cell(view, -3900 + 7800 * t, -2925 + 5850 * t)
		if cx ~= cell_x or cy ~= cell_y then
			cell_x, cell_y = cx, cy
			local ox, oy = V.origin(view, cx, cy)
			local old = V.texture(view, ox, oy, "map_mask.png", nil, flight and overlay)
			local new = candidate(old, frame)
			longest_old, longest_new = math.max(longest_old, #old), math.max(longest_new, #new)
			if not old_seen[old] then
				old_seen[old] = true
				old_count, old_bytes = old_count + 1, old_bytes + view.pixels * view.pixels * 4
			end
			if not new_seen[new] then
				new_seen[new] = true
				new_count, new_bytes = new_count + 1, new_bytes + frame.drawn * frame.drawn * 4
			end
		end
	end
	if reverse then assert(old_count == 0 and new_count == 0, "revisit allocated new recipes") end
	print(("%-18s %3d -> %3d px | new recipes %4d / %4d | cumulative RGBA %6.1f / %6.1f MiB | max recipe %3d / %3d B"):
		format(label, view.pixels, frame.drawn, old_count, new_count,
			old_bytes / 1048576, new_bytes / 1048576, longest_old, longest_new))
end
print("Current / proposed full-resolution cell; cumulative final-texture RGBA accounting only")
run("1080 normal", 1080, false)
run("1080 revisit", 1080, false, true)
run("1080 flight", 1080, true)
run("720 normal", 720, false)
run("2160 normal", 2160, false)
