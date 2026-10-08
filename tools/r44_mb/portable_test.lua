-- Round 44 lane MB portable test (LuaJIT): the baked map layer and the
-- minimap's markers (round44-plan.md §4.4, the UI rework spec §2 rulings
-- 11-13, §3.6-§3.7).
--
--   luajit tools/r44_mb/portable_test.lua [REPO]
--
-- Loads the REAL grug_map bake.lua, settlement_icons.lua and baked_art.lua
-- (pure), and reads minimap.lua and providers.lua. Checks:
--   K  the kind mapping: every one of the source's 118 anchors has a baked
--      kind (6 starts, 6 capitals, 12 villages, 24 outposts, 2 fortresses,
--      16 war camps, 12 bandit and 4 Mirefolk camps, 8 mines, 16 clash
--      sites, 10 rare dens, 2 dragon arenas); unknown slots have none;
--      every kind has its art, 16 x 16 and 6 x 6;
--   I  the items: a dragon arena next to its dragon is drawn once, a dragon
--      settlement elsewhere stays; kings and dragons draw last (on top);
--      settlements without a kind are counted, not drawn;
--   V  the visibility rule: one layer for everyone, both factions' starts,
--      capitals, villages, outposts and fortresses included; no per-viewer
--      rule is left in settlement_icons.lua;
--   G  the glyph layout of a name: upper case, glyph widths and gaps from
--      the font, the halo border, a wrapped name centred line by line;
--      every region name is in the font; the mask marks glyph and halo;
--   D  drawing: an icon blends only its opaque pixels, scales by whole
--      pixels and is clipped at the image edge; a name is clamped into the
--      image; nothing writes outside the image; the minimap variant draws
--      no names;
--   C  the cache key text changes with the layout, art and font versions
--      and with an icon's kind or place, and only then;
--   M  the minimap's marker kinds are quest givers, the Steward, the
--      capital services, trainers, innkeepers, home and waystones (the
--      user, Round 44), never kings, dragons or settlements; trainers use
--      their profession icon, a 16 x 16 PNG for every profession.
-- Prints "R44 MB PORTABLE PASS checks=<n>" or the failures.
local repo = arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function read(path)
	local file = assert(io.open(repo .. path, "rb"), "cannot read " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

local MAP = "/mods/PLAYER/grug_map/"
local B = dofile(repo .. MAP .. "bake.lua")
local icons = dofile(repo .. MAP .. "settlement_icons.lua")
local art = dofile(repo .. MAP .. "baked_art.lua")
_G.core = _G.core or {}
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

-- ---------------------------------------------------------------------------
-- K: the kind mapping
-- ---------------------------------------------------------------------------
do
	local counts, unknown = {}, {}
	for _, anchor in ipairs(source.anchors) do
		local kind = icons.kind(anchor.slot_id)
		if kind then counts[kind] = (counts[kind] or 0) + 1 else unknown[#unknown + 1] = anchor.slot_id end
	end
	eq(#source.anchors, 118, "K 118 anchors")
	eq(#unknown, 0, "K every anchor has a kind (" .. table.concat(unknown, ",") .. ")")
	local want = {start = 6, capital = 6, village = 12, outpost = 24, fortress = 2,
		war_camp = 16, bandit = 12, mirefolk = 4, mine = 8, clash = 16, rare_den = 10, dragon = 2}
	for kind, n in pairs(want) do eq(counts[kind], n, "K " .. kind) end
	check(icons.kind(nil) == nil and icons.kind("landmark") == nil and icons.kind("") == nil,
		"K no kind for an unknown slot")
	check(icons.kind("apex_mine") == "mine" and icons.kind("rare_captain_bonerattle") == "rare_den" and
		icons.kind("clash_3") == "clash" and icons.kind("pvp_throng_low") == "war_camp",
		"K other split by slot")
	for _, kind in ipairs(B.KINDS) do
		local big, mini = art.icons[kind], art.icons[kind .. "_mini"]
		check(big and big.w == 16 and big.h == 16 and #big.rows == 16, "K art " .. kind .. " 16x16")
		check(mini and mini.w == 6 and mini.h == 6 and #mini.rows == 6, "K art " .. kind .. "_mini 6x6")
		if big then
			local image = B.decode(big)
			local opaque = 0
			for i = 1, 256 do if image.cells[i] then opaque = opaque + 1 end end
			check(opaque > 0 and opaque < 256, "K " .. kind .. " has opaque and transparent pixels")
		end
	end
	check(type(art.art_version) == "string" and #art.art_version == 16 and
		type(art.font_version) == "string" and #art.font_version == 16, "K art and font versions")
end

-- ---------------------------------------------------------------------------
-- I: the items
-- ---------------------------------------------------------------------------
do
	local settlements = {
		{kind = "capital", x = 0, z = 1500}, {kind = "dragon", x = -3260, z = -40},
		{kind = "dragon", x = 100, z = 100}, {kind = nil, x = 5, z = 5},
		{kind = "village", x = -50, z = 20}, {kind = "start", x = 10, z = 10},
	}
	local kings = {{x = 30, z = 1480}}
	local dragons = {{x = -3250, z = -30}, {x = 3260, z = -40}}
	local items, unknown = B.items(settlements, kings, dragons)
	eq(unknown, 1, "I one settlement without a kind")
	local dragons_at = {}
	for _, item in ipairs(items) do
		if item.kind == "dragon" then dragons_at[#dragons_at + 1] = item.x .. "," .. item.z end
	end
	table.sort(dragons_at)
	eq(table.concat(dragons_at, " "), "-3250,-30 100,100 3260,-40",
		"I the arena beside its dragon drawn once, the other dragon settlement kept")
	eq(#items, 7, "I seven icons")
	eq(items[#items].kind, "dragon", "I dragons last")
	check(items[#items - 3].kind == "king" and items[1].kind == "village",
		"I kings above the settlements, villages under the capitals")
end

-- ---------------------------------------------------------------------------
-- V: one layer for everyone
-- ---------------------------------------------------------------------------
do
	check(icons.visible == nil and icons.HIDDEN == nil, "V no per-viewer icon rule left")
	local rows = {}
	for _, anchor in ipairs(source.anchors) do
		if anchor.slot_id == "start" or anchor.slot_id == "capital" or
				anchor.slot_id:match("^village_") or anchor.slot_id:match("^outpost_") or
				anchor.slot_id == "pvp_fortress" then
			rows[#rows + 1] = {kind = icons.kind(anchor.slot_id), x = anchor.position.x,
				z = anchor.position.z}
		end
	end
	local items = B.items(rows, {}, {})
	eq(#rows, 50, "V both factions' 50 owned places")
	eq(#items, #rows, "V every owned place of both factions is baked")
	local north, south = 0, 0
	for _, item in ipairs(items) do
		if item.kind == "capital" then
			if item.z > 0 then north = north + 1 else south = south + 1 end
		end
	end
	check(north == 3 and south == 3, "V the capitals of both factions")
	check(not read(MAP .. "page.lua"):find('register_marker_provider("settlement"', 1, true),
		"V the Map tab has no settlement provider")
end

-- ---------------------------------------------------------------------------
-- G: the glyph layout of a name
-- ---------------------------------------------------------------------------
local font = art.font
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '-.,"
	local missing = {}
	for i = 1, #chars do
		local glyph = font.glyphs[chars:sub(i, i)]
		if not glyph or #glyph ~= font.height then missing[#missing + 1] = chars:sub(i, i) end
	end
	eq(#missing, 0, "G the font has every character at its height (" .. table.concat(missing) .. ")")
	eq(font.height, 7, "G cap height 7")
	local function width(char) return #font.glyphs[char][1] end
	local layout = B.layout(font, "Orc Lands")
	local text = "ORC LANDS"
	local expect, x = 0, 1
	for i = 1, #text do
		local glyph = layout.glyphs[i]
		local char = text:sub(i, i)
		check(glyph and glyph.char == char and glyph.x == x and glyph.y == 1,
			"G glyph " .. i .. " " .. char .. " at x " .. x)
		x = x + width(char) + B.LETTER_GAP
		expect = expect + width(char) + (i > 1 and B.LETTER_GAP or 0)
	end
	eq(#layout.glyphs, 9, "G nine glyphs (the space is a blank glyph)")
	eq(layout.width, expect + 2, "G width: glyphs, gaps and the halo")
	eq(layout.height, font.height + 2, "G height: one line and the halo")
	eq(layout.missing, 0, "G nothing missing")
	local wrapped = B.layout(font, "Wyrmglass Crown", true)
	local top, bottom = 0, 0
	for _, glyph in ipairs(wrapped.glyphs) do
		if glyph.y == 1 then top = top + 1 elseif glyph.y == 1 + font.height + B.LINE_GAP then
			bottom = bottom + 1 end
	end
	check(top == 9 and bottom == 5, "G wrapped: WYRMGLASS over CROWN (" .. top .. ", " .. bottom .. ")")
	eq(wrapped.height, 2 * font.height + B.LINE_GAP + 2, "G wrapped height")
	local crown = 0
	for _, char in ipairs({"C", "R", "O", "W", "N"}) do crown = crown + width(char) end
	crown = crown + 4 * B.LETTER_GAP
	local first_bottom
	for _, glyph in ipairs(wrapped.glyphs) do
		if glyph.y > 1 then first_bottom = first_bottom or glyph.x end
	end
	eq(first_bottom, 1 + math.floor((wrapped.width - 2 - crown) / 2), "G the shorter line centred")
	for _, row in ipairs(B.REGION_LABELS) do
		eq(B.layout(font, row[1], row.wrap).missing, 0, "G " .. row[1] .. " is in the font")
	end
	local odd = B.layout(font, "A{B")
	eq(odd.missing, 1, "G a missing character counts")
	local mask = B.mask(font, B.layout(font, "I"))
	local glyph = font.glyphs.I
	local w = #glyph[1] + 2
	local ok = true
	for y = 0, font.height + 1 do
		for x = 0, w - 1 do
			local inside = y >= 1 and y <= font.height and x >= 1 and x <= w - 2 and
				glyph[y]:sub(x, x) == "#"
			local near = false
			for dy = -1, 1 do
				for dx = -1, 1 do
					local gy, gx = y + dy, x + dx
					if gy >= 1 and gy <= font.height and gx >= 1 and gx <= w - 2 and
							glyph[gy]:sub(gx, gx) == "#" then near = true end
				end
			end
			local want = inside and 2 or (near and 1 or nil)
			if mask[y * w + x] ~= want then ok = false end
		end
	end
	check(ok, "G the mask: glyph pixels 2, their eight neighbours halo 1, nothing else")
end

-- ---------------------------------------------------------------------------
-- D: drawing
-- ---------------------------------------------------------------------------
do
	local W, H, GROUND = 40, 30, 0x204060
	local function image()
		local p = {}
		for i = 1, W * H do p[i] = GROUND end
		return p
	end
	local icon = {w = 2, h = 2, palette = {["."] = "00000000", a = "ff000080", b = "00ff00ff"},
		rows = {".a", "b."}}
	local p = image()
	local box = B.draw_icon(p, W, H, icon, 10, 10, 3)
	check(box[1] == 7 and box[2] == 7 and box[3] == 13 and box[4] == 13, "D icon box centred, 3x")
	check(p[7 * W + 7 + 1] == GROUND and p[9 * W + 9 + 1] == GROUND, "D a transparent pixel keeps the ground")
	check(p[10 * W + 7 + 1] == 0x00ff00 and p[12 * W + 9 + 1] == 0x00ff00, "D an opaque pixel replaces it, 3x3")
	local half = p[7 * W + 10 + 1]
	check(math.floor(half / 65536) == 144 and math.floor(half / 256) % 256 == 32 and half % 256 == 48,
		"D a half-transparent pixel blends (" .. ("%06x"):format(half) .. ")")
	local q = image()
	B.draw_icon(q, W, H, icon, 0, 0, 3)
	B.draw_icon(q, W, H, icon, W - 1, H - 1, 3)
	eq(#q, W * H, "D icons at the corners write nothing outside the image")
	check(q[29 * W + 36 + 1] == 0x00ff00 and q[29 * W + 39 + 1] == GROUND,
		"D the clipped icon's visible part is drawn")
	local r = image()
	local label = B.draw_label(r, W, H, font, {"Orc Lands"}, 0, 0, 1)
	check(label[1] == 0 and label[2] == 0, "D a name at the corner is clamped into the image")
	local big = image()
	B.draw_label(big, W, H, font, {"The Contested Front"}, 20, 15, 2)
	eq(#big, W * H, "D a name wider than the image writes nothing outside it")
	local layer = {items = {{kind = "capital", x = 0, z = 0}, {kind = "king", x = 10, z = 10}},
		labels = {{"Orc Lands", 0, 500}}}
	local view = {min_x = -400, max_x = 400, min_z = -300, max_z = 300}
	local world = {}
	for i = 1, 200 * 150 do world[i] = GROUND end
	local stats = B.draw(world, 200, 150, view, layer, art, 1, true, "")
	check(stats.icons == 2 and stats.names == 1 and stats.icon_overlaps == 1 and stats.name_overlaps == 0,
		("D the layer: 2 icons, 1 overlapping pair, 1 name (%d, %d, %d, %d)"):format(stats.icons,
			stats.icon_overlaps, stats.names, stats.name_overlaps))
	local mini = {}
	for i = 1, 200 * 150 do mini[i] = GROUND end
	local stats_mini = B.draw(mini, 200, 150, view, layer, art, 1, false, "_mini")
	local changed_row = false
	for x = 0, 199 do
		local y = math.floor((300 - 500) * 150 / 600)
		if y >= 0 and mini[y * 200 + x + 1] ~= GROUND then changed_row = true end
	end
	check(stats_mini.icons == 2 and stats_mini.names == 0 and not changed_row,
		"D the minimap variant: small icons, no names")
	-- the capital's 6x6 icon is centred on the pixel of world 0,0
	local cx, cy = math.floor(400 * 200 / 800), math.floor(300 * 150 / 600)
	local hit = false
	for y = cy - 3, cy + 2 do
		for x = cx - 3, cx + 2 do
			if mini[y * 200 + x + 1] ~= GROUND then hit = true end
		end
	end
	check(hit, "D the small icon sits on its world point")
end

-- ---------------------------------------------------------------------------
-- C: the cache key text
-- ---------------------------------------------------------------------------
do
	local items = {{kind = "capital", x = 1, z = 2}, {kind = "king", x = 3, z = 4}}
	local base = {layout = "L", art = "A", font = "F"}
	local key = B.key_text(base, items)
	eq(B.key_text({layout = "L", art = "A", font = "F"}, {{kind = "capital", x = 1, z = 2},
		{kind = "king", x = 3, z = 4}}), key, "C the same inputs, the same key")
	check(B.key_text({layout = "L2", art = "A", font = "F"}, items) ~= key, "C the layout version")
	check(B.key_text({layout = "L", art = "A2", font = "F"}, items) ~= key, "C the art version")
	check(B.key_text({layout = "L", art = "A", font = "F2"}, items) ~= key, "C the font version")
	check(B.key_text(base, {{kind = "village", x = 1, z = 2}, items[2]}) ~= key, "C an icon's kind")
	check(B.key_text(base, {{kind = "capital", x = 1, z = 3}, items[2]}) ~= key, "C an icon's place")
	check(B.key_text(base, {items[1]}) ~= key, "C an icon less")
	local base_src = read(MAP .. "base.lua")
	check(base_src:find("bake.key_text(layer.versions, layer.items)", 1, true) and
		base_src:find("art = art.art_version, font = art.font_version", 1, true) and
		base_src:find("layout = core.sha256(", 1, true), "C base.lua keys the bake")
end

-- ---------------------------------------------------------------------------
-- M: the minimap's marker kinds and the trainer icons
-- ---------------------------------------------------------------------------
do
	local minimap = read(MAP .. "minimap.lua")
	local shown = minimap:match("local SHOWN = (%b{})") or ""
	local kinds = {}
	for kind in shown:gmatch("(%w+) = true") do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	eq(table.concat(kinds, ","), "home,innkeeper,quest,service,steward,trainer,waypoint",
		"M minimap kinds")
	local priority = minimap:match("local PRIORITY = (%b{})") or ""
	check(priority:find("quest = 1", 1, true) and priority:find("steward = 2", 1, true) and
		priority:find("innkeeper = 4", 1, true), "M quest givers keep a slot first, then the Steward")
	check(minimap:find("MARKER_SLOTS, PARTY_SLOTS = 24, 9", 1, true), "M 24 marker slots stay")
	local providers = read(MAP .. "providers.lua")
	check(providers:find('return "grug_map_trainer_" .. profession .. ".png"', 1, true) and
		providers:find("texture = grug_map.trainer_icon(socket.profession)", 1, true) and
		not providers:find("grug_jobs_book.png", 1, true), "M trainers use their profession icon")
	check(providers:find('"grug_mounts_icon_" .. settlement.race_id .. ".png"', 1, true),
		"M Riding keeps the mount icon")
	local registry = read("/mods/PLAYER/grug_jobs/registry.lua")
	local block = registry:match("grug_jobs.PROFESSIONS = (%b{})") or ""
	local professions = 0
	for id in block:gmatch("(%w+) = {name") do
		professions = professions + 1
		local file = io.open(repo .. MAP .. "textures/grug_map_trainer_" .. id .. ".png", "rb")
		local header = file and file:read(24)
		if file then file:close() end
		local function u32(at)
			local a, b, c, d = header:byte(at, at + 3)
			return ((a * 256 + b) * 256 + c) * 256 + d
		end
		check(header and header:sub(2, 4) == "PNG" and u32(17) == 16 and u32(21) == 16,
			"M grug_map_trainer_" .. id .. ".png is a 16x16 PNG")
	end
	eq(professions, 8, "M eight professions")
end

if #failures == 0 then
	print(("R44 MB PORTABLE PASS checks=%d"):format(checks))
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R44 MB PORTABLE FAIL %d/%d"):format(#failures, checks), 0)
end
