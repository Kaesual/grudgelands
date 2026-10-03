-- Round 31 lane A: the texture strings of a list of looks, made by the REAL
-- grug_visuals compose (looks.lua + compose.lua against a stub grug_gear),
-- for the preview renderer (preview.py).
--
--   luajit tools/r31_a/look_strings.lua [REPO] < requests
--
-- One request per line, tab-separated:
--   label  race  look  armour  royal
-- look:   "tone,hair,style,eyes,feature", "S<seed>" for an NPC's look
--         derived from its rolled seed (grug_visuals.look_from_seed) or "K"
--         for the race's king;
-- armour: "-" or "<line>:<bracket>" (a whole set, helmet included) or
--         "<line>:<bracket>:nohead" (no helmet);
-- royal:  "-", "guard" or "king".
-- Prints "label<TAB>texture string<TAB>tone,hair,style,eyes,feature".

local repo = arg[1] or "."
core = {log = function() end}
grug_gear = {
	BRACKETS = {{}, {}, {}, {}, {}, {}},
	MATERIALS = {
		{metal = {key = "bronze"}, cloth = {key = "patch"}, leather = {key = "light"}},
		{metal = {key = "iron"}, cloth = {key = "woven"}, leather = {key = "cured"}},
		{metal = {key = "steel"}, cloth = {key = "heavy"}, leather = {key = "heavy"}},
		{metal = {key = "silversteel"}, cloth = {key = "silkweave"}, leather = {key = "scaled"}},
		{metal = {key = "embersteel"}, cloth = {key = "silk"}, leather = {key = "sleek"}},
		{metal = {key = "abyssal_steel"}, cloth = {key = "stormweave"}, leather = {key = "nightscale"}},
	},
	bracket_for_level = function() return 1 end,
}
grug_visuals = {}
dofile(repo .. "/mods/PLAYER/grug_visuals/looks.lua")
dofile(repo .. "/mods/PLAYER/grug_visuals/compose.lua")

-- The armour index, as index_armor builds it from the item registry.
local items = {}
for bracket = 1, 6 do
	for rank, line in ipairs({"cloth", "leather", "metal"}) do
		for _, slot in ipairs(grug_visuals.SLOTS) do
			items[line .. ":" .. slot .. ":" .. bracket] = {groups = {
				["grug_equip_" .. slot] = 1, grug_armor_class = rank}, _grug_bracket = bracket}
		end
	end
end
grug_visuals.index_armor(items)

for line in io.lines() do
	local f = {}
	for field in line:gmatch("[^\t]+") do
		f[#f + 1] = field
	end
	if #f >= 5 then
		local race, look = f[2], nil
		if f[3] == "K" then
			look = grug_visuals.KING_LOOKS[race]
		elseif f[3]:sub(1, 1) == "S" then
			look = grug_visuals.look_from_seed(race, tonumber(f[3]:sub(2)))
		else
			look = grug_visuals.parse_look(race, f[3])
		end
		local armor = nil
		local armour_line, bracket, nohead = f[4]:match("^(%l+):(%d)(:?%l*)$")
		if armour_line then
			armor = {}
			for _, slot in ipairs(grug_visuals.SLOTS) do
				if not (slot == "head" and nohead ~= "") then
					armor[slot] = armour_line .. ":" .. slot .. ":" .. bracket
				end
			end
		end
		local royal = f[5] ~= "-" and f[5] or nil
		local result = grug_visuals.compose({race = race, look = look, armor = armor,
			royal = royal})
		look = grug_visuals.normalize_look(race, look)
		io.write(f[1], "\t", result.textures[1], "\t", grug_visuals.look_string(look), "\n")
	end
end
