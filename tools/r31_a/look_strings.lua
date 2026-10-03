-- Round 31 lane A: the texture strings of a list of looks, made by the REAL
-- grug_visuals/looks.lua, for the preview renderer (preview.py).
--
--   luajit tools/r31_a/look_strings.lua [REPO] < requests
--
-- One request per line, tab-separated:
--   label  race  tone hair style eyes feature  helmet-or-"-"  overlays-or-"-"
-- (overlays comma-separated). `tone` "R" rolls the look with
-- grug_visuals.roll_look instead, seeded with the `hair` field. Prints
-- "label<TAB>texture string<TAB>tone,hair,style,eyes,feature" per request.

local repo = arg[1] or "."
grug_visuals = {}
dofile(repo .. "/mods/PLAYER/grug_visuals/looks.lua")

for line in io.lines() do
	local f = {}
	for field in line:gmatch("[^\t]+") do
		f[#f + 1] = field
	end
	if #f >= 9 then
		local look
		if f[3] == "R" then
			math.randomseed(tonumber(f[4]))
			look = grug_visuals.roll_look(f[2])
		else
			look = grug_visuals.normalize_look(f[2], {tone = tonumber(f[3]),
				hair = tonumber(f[4]), style = tonumber(f[5]),
				eyes = tonumber(f[6]), feature = tonumber(f[7])})
		end
		local helmet = f[8] ~= "-" and f[8] or nil
		local overlays = nil
		if f[9] ~= "-" then
			overlays = {}
			for overlay in f[9]:gmatch("[^,]+") do
				overlays[#overlays + 1] = overlay
			end
		end
		io.write(f[1], "\t", grug_visuals.look_texture(f[2], look, overlays, helmet),
			"\t", look.tone, ",", look.hair, ",", look.style, ",", look.eyes, ",",
			look.feature, "\n")
	end
end
