-- Round 78 lane ARMOR: the one armor display helper for fixtures that run a
-- text site (the Character page, the alchemy, ability and talent texts)
-- without the real grug_gear. Cuts grug_gear.format_armor out of
-- grug_gear/init.lua into the global grug_gear table (created when missing,
-- kept when a stub exists) and returns it.
--
--   dofile(repo .. "/tools/r78_armor/format_armor.lua")(repo)
return function(repo)
	local handle = assert(io.open(repo .. "/mods/ITEMS/grug_gear/init.lua", "rb"))
	local source = handle:read("*a")
	handle:close()
	local body = assert(source:match("(function grug_gear%.format_armor%(rating%).-\nend)\n"),
		"format_armor in grug_gear/init.lua")
	grug_gear = rawget(_G, "grug_gear") or {}
	assert(loadstring(body))()
	return grug_gear.format_armor
end
