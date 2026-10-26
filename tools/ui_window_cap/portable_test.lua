-- Exact viewport cap against the native fitting equations (LuaJIT).
local root = arg[1] or "."
local checks = 0
local function check(ok, message)
	checks = checks + 1
	assert(ok, message)
end
local function near(a, b, message, tolerance)
	check(math.abs(a - b) < (tolerance or 0.001), message .. ": " .. a .. " / " .. b)
end
local report
core = {get_player_window_information = function() return report end}
grug_core = {}
grug_inventory = {UI = {window_h = 15}}
dofile(root .. "/mods/CORE/grug_core/ui.lua")
dofile(root .. "/mods/CORE/grug_core/ui_window.lua")
local UI = grug_core.ui
local player = {get_player_name = function() return "fixture" end}
local function preferred(w, h, gui, density)
	return math.max(0.5555 * 96 * density * gui, math.min(w, h) / 15 * gui)
end
local function information(w, h, gui, density)
	local slot = preferred(w, h, gui, density)
	return {size = {x = w, y = h}, max_formspec_size = {x = w / slot, y = h / slot},
		real_gui_scaling = gui * density}
end
local function fitted(w, h, gui, density, fw, fh, padding, legacy)
	local px, py = padding:match("padding%[([^,]+),([^%]]+)%]")
	px, py = tonumber(px) or 0.05, tonumber(py) or 0.05
	local available_w, available_h = w * (1 - 2 * px), h * (1 - 2 * py)
	if legacy then fw, fh = 1.25 * (0.5 + fw), 15 / 13 * (0.85 + fh) end
	return math.min(preferred(available_w, available_h, gui, density), available_w / fw, available_h / fh)
end
for _, dimensions in ipairs({{1035,696},{1920,1080},{2560,1440},{3840,2160},{3440,1080},{1200,1600}}) do
	for _, scale in ipairs({{1,1},{1.5,1},{1,2},{1.5,2}}) do
		local w,h,gui,density = dimensions[1],dimensions[2],scale[1],scale[2]
		report = information(w,h,gui,density)
		local snapshot = report
		local padding = UI.window_padding(player)
		for _, form in ipairs({{20,15},{18.8,12.2},{10,3},{11,20},{8,4,true}}) do
			local actual = fitted(w,h,gui,density,form[1],form[2],padding,form[3])
			local reference = fitted(math.min(w,1920),math.min(h,1080),gui,density,form[1],form[2],"",form[3])
			near(actual,reference,"native frame equals capped reference",0.002)
		end
		local virtual = UI.window_information(report)
		local expected = information(math.min(w,1920),math.min(h,1080),gui,density)
		near(virtual.max_formspec_size.x,expected.max_formspec_size.x,"responsive width")
		near(virtual.max_formspec_size.y,expected.max_formspec_size.y,"responsive height")
		check(snapshot.size.x == w and snapshot.size.y == h,"report is not mutated")
		check(UI.window_information(virtual) == virtual,"responsive cap is idempotent")
		local map_padding = UI.window_padding(nil,0,report)
		near(fitted(w,h,gui,density,virtual.max_formspec_size.x*.85,
			virtual.max_formspec_size.y*.85,map_padding),
			fitted(math.min(w,1920),math.min(h,1080),gui,density,expected.max_formspec_size.x*.85,
			expected.max_formspec_size.y*.85,"padding[0,0]"),"map native cap",0.002)
		if w <= 1920 and h <= 1080 then check(padding == "","small and Full-HD forms stay byte-identical") end
	end
end
report = nil
check(UI.window_padding(player) == "","missing join report leaves native fitting")
check(UI.window_padding(nil) == "","no player is safe")
check(UI.window_padding(nil,0) == "padding[0,0]","map fallback retains zero padding")
check(UI.window_information(nil) == nil,"missing responsive report is safe")
for _, invalid in ipairs({{}, {size={x=0,y=1080}}, {size={x=0/0,y=1080}}, {size={x=math.huge,y=1080}}}) do
	report = invalid
	check(UI.window_padding(player) == "","malformed dimensions retain native fitting")
end
report = information(1920,1080,1,1)
local first = UI.frame(20,15,nil,nil,player)
check(not first:find("padding",1,true),"Full-HD has no added padding")
report = information(2560,1440,1,1)
local second = UI.frame(20,15,nil,nil,player)
check(second:find("padding[0.162500,0.162500]",1,true) ~= nil,"next rebuild follows enlarged window")
check(UI.frame(20,15,nil,nil,player) == second,"tab switch with same report has identical frame")
report = information(1035,696,1,1)
check(UI.frame(20,15,nil,nil,player) == first,"next rebuild removes cap after resize smaller")
-- Density alone is never interpreted as a reason to halve body text.
report = information(2560,1600,1,2)
near(UI.text_scale(player),1080 / (0.5555*96*2) / 15,"HiDPI body fit uses virtual actual shrink")
print(("ui_window_cap: %d checks passed"):format(checks))
