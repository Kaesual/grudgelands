-- Round 89 lane UI portable test (LuaJIT; docs/planning/round89-plan.md
-- §2.1, §2.6, §3 "The cover", §4 UI). Loads the REAL
-- grug_core/hud_layout.lua, status_icons.lua and status.lua,
-- grug_abilities/cooldown_math.lua, grug_housing/registry.lua,
-- grug_home/claim_home.lua and waypoints_core.lua and grug_map/providers.lua
-- under a minimal `core` stub.
--
--   C  the cover's frame arithmetic: clear at the start, the elapsed share
--      in 72 steps rounded down, the last step before the end; the frame of
--      the remaining share mirrored; the frames are grug_abilities' cooldown
--      covers (same name pattern, count and size) and every frame used
--      ships;
--   R  the row: one cover per slot above its icon, drawn exactly as large
--      and where the icon is; a fresh, a half-run and an almost-run-out
--      effect; untimed effects (stored and source) without a cover; the
--      shield keeps its points as the caption; a refresh (a new expiry)
--      starts a new cover, a repeated set with the same expiry keeps it;
--      a source entry's duration is what the row saw first, a jitter of a
--      second is no refresh, a later expiry is, an entry that went and came
--      back starts afresh; the cover follows its effect when the row
--      reorders, not its slot; an expired effect's slot loses its cover;
--      the heartbeat statuses (Scorched, Dragon's Wrath: set again for 1.5 s
--      on every 1 s tick) never show a cover, and only they are flagged;
--   W  HUD writes: an idle refresh writes nothing; a 10 s and a 30 min
--      effect over their whole run (the counts are printed);
--   H  the home's name: the waystone list's entry and both map markers
--      for an own home, a renamed home and an account home as a member;
--      no stone and a draft keep the greyed "Your Claim Stone";
--      grug_home.get's row keeps the label "Claim Stone";
--   L  the Waystones tab's status column clears the widest name; the
--      Expeditions tab's buttons share its column.
--
-- Usage (repo root): luajit tools/r89_ui/portable_test.lua [REPO]
local ROOT = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function png_size(path)
	local file = io.open(ROOT .. "/" .. path, "rb")
	if not file then return nil end
	local header = file:read(24)
	file:close()
	if not header or header:sub(2, 4) ~= "PNG" then return nil end
	local function u32(offset)
		local a, b, c, d = header:byte(offset, offset + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

------------------------------------------------------------------------------
-- The engine stub.
------------------------------------------------------------------------------
local S = 1e6
local us_time = 1000000000
local joins, deaths, leaves, steps, players = {}, {}, {}, {}, {}
local chat = {}
core = {
	get_us_time = function() return us_time end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) deaths[#deaths + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_mods_loaded = function() end,
	get_connected_players = function() return players end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do
			if p:get_player_name() == name then return p end
		end
	end,
	get_mod_storage = function()
		local data = {}
		return {get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end}
	end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
	log = function() end,
}
vector = {new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

local function fake_player(name)
	local p = {name = name, huds = {}, next_id = 0, writes = {}}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_hp() return 20 end
	function p:get_meta()
		self.meta = self.meta or {}
		local data = self.meta
		return {get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end}
	end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, key, value)
		local w = self.writes
		w[#w + 1] = {id = id, key = key, value = value}
		self.huds[id][key] = value
	end
	return p
end

grug_core = {}
dofile(ROOT .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")
dofile(ROOT .. "/tools/r81_passes/all_players_pass.lua")(grug_core, core)
dofile(ROOT .. "/mods/CORE/grug_core/status.lua")
local icons = grug_core.status_icons
local layout = grug_core.hud_layout

------------------------------------------------------------------------------
-- C: the frame arithmetic.
------------------------------------------------------------------------------
do
	local T = 10 * S
	eq(icons.cover_step(T, T), 0, "C a fresh effect: clear")
	eq(icons.cover_step(T - 0.1 * S, T), 0, "C ...rounded down, still clear after 0.1 s")
	eq(icons.cover_step(T / 2, T), 36, "C half run: half of the 72 steps")
	eq(icons.cover_step(T / 4, T), 54, "C three quarters run")
	eq(icons.cover_step(0.1 * S, T), 71, "C almost run out: the last step")
	eq(icons.cover_step(0, T), 71, "C at the end: the last step, never more")
	eq(icons.cover_step(-S, T), 71, "C past the end (a pending last tick): the last step")
	eq(icons.cover_step(T + S, T), 0, "C more left than the total (a jittered read): clear")
	eq(icons.cover_step(T, nil), nil, "C no total (untimed): no step")
	eq(icons.cover_step(nil, T), nil, "C no remaining time: no step")
	eq(icons.cover_step(T, 0), nil, "C a zero total: no step")
	eq(icons.cover_texture(nil), "", "C no step: nothing drawn")
	eq(icons.cover_texture(0), "", "C step 0: nothing drawn")
	-- Frame k clears clockwise from twelve (k/72 cleared); the step's frame
	-- is the remaining share's, mirrored, so the covered wedge grows
	-- clockwise from twelve (checked against the pixels on the screenshot).
	eq(icons.cover_texture(36), "grug_abilities_cd_pie_36.png^[transformFX", "C step 36: frame 36 mirrored")
	eq(icons.cover_texture(18), "grug_abilities_cd_pie_54.png^[transformFX",
		"C a quarter run: frame 54 (its one covered quarter, the upper left) mirrored to the upper right")
	eq(icons.cover_texture(1), "grug_abilities_cd_pie_71.png^[transformFX", "C step 1: frame 71")
	eq(icons.cover_texture(71), "grug_abilities_cd_pie_01.png^[transformFX", "C step 71: frame 1")
	-- The frames are the hotbar's.
	local cd = dofile(ROOT .. "/mods/PLAYER/grug_abilities/cooldown_math.lua")
	eq(icons.COVER, cd.PIE, "C the hotbar's frame names")
	eq(icons.COVER_FRAMES, cd.FRAMES, "C the hotbar's frame count")
	eq(icons.COVER_PX, cd.PIE_PX, "C the hotbar's frame size")
	local all = true
	for step = 1, icons.COVER_FRAMES - 1 do
		local w, h = png_size("mods/PLAYER/grug_abilities/textures/" ..
			cd.PIE:format(icons.COVER_FRAMES - step))
		if w ~= icons.COVER_PX or h ~= icons.COVER_PX then all = false end
	end
	check(all, "C every frame a step uses ships, " .. icons.COVER_PX .. " px square")
	check(not read("mods/CORE/grug_core/mod.conf"):find("grug_abilities", 1, true),
		"C grug_core still does not depend on grug_abilities")
end

------------------------------------------------------------------------------
-- R: the row.
------------------------------------------------------------------------------
local function join(name)
	local p = fake_player(name)
	players[#players + 1] = p
	for _, fn in ipairs(joins) do fn(p) end
	return p
end
-- The slots in row order, from the elements as added (icon, caption, cover).
local function slots_of(p)
	local out = {}
	for id = 1, p.next_id do
		local def = p.huds[id]
		if def and def.type == "image" and def.z_index == 2 then
			out[#out].cover = def
		elseif def and def.type == "image" then
			out[#out + 1] = {icon = def}
		elseif def and def.type == "text" then
			out[#out].caption = def
		end
	end
	return out
end
local function refresh(p) grug_core.refresh_status_hud(p) end
-- The slot that shows `id`'s picture (`picture` a unique part of it).
local function slot_with(p, picture)
	for index, slot in ipairs(slots_of(p)) do
		if slot.icon.text:find(picture, 1, true) then return slot, index end
	end
end
local function step_of(texture)
	local frame = texture:match("cd_pie_(%d%d)%.png%^%[transformFX$")
	return frame and icons.COVER_FRAMES - tonumber(frame) or (texture == "" and 0 or nil)
end

local alice = join("alice")
do
	local slots = slots_of(alice)
	eq(#slots, layout.STATUS_LIMIT, "R ten slots")
	local ok = true
	for _, slot in ipairs(slots) do
		local icon, cover = slot.icon, slot.cover
		if not cover or cover.text ~= "" or cover.z_index <= icon.z_index or
				cover.offset.x ~= icon.offset.x or cover.offset.y ~= icon.offset.y or
				cover.alignment.x ~= 0 or cover.alignment.y ~= 0 or
				cover.position.x ~= icon.position.x or cover.position.y ~= icon.position.y then
			ok = false
		end
	end
	check(ok, "R every slot has an empty cover above its icon, at the icon's place")
	-- hud.cpp:496: s32(image px * scale * scale factor): the cover is drawn
	-- exactly as large as the icon at the usual HUD scalings.
	local icon, cover = slots[1].icon, slots[1].cover
	local same = true
	for _, sf in ipairs({1, 1.25, 1.5, 2, 3}) do
		local a = math.floor(64 * icon.scale.x * sf)
		local b = math.floor(icons.COVER_PX * cover.scale.x * sf)
		if a ~= b or b ~= math.floor(layout.STATUS_ICON * sf) then same = false end
	end
	check(same, "R the cover is drawn as large as the icon at HUD scale factor 1 .. 3")
end

local sidestep_tex = "grug_abilities_skill_sidestep.png"
do
	local t0 = us_time
	grug_core.set_status(alice, "sidestep", {duration = 10})
	grug_core.set_status(alice, "mount", {untimed = true, variant = "flight"})
	grug_core.set_status(alice, "shield", {duration = 20, value = function() return 42 end})
	refresh(alice)
	local slot = slot_with(alice, sidestep_tex)
	check(slot ~= nil, "R the sidestep shows")
	eq(slot and slot.cover.text, "", "R a fresh effect: no cover")
	eq(slot_with(alice, "mount_flight").cover.text, "", "R an untimed stored status: no cover")
	us_time = t0 + 5 * S
	refresh(alice)
	slot = slot_with(alice, sidestep_tex)
	eq(slot.cover.text, "grug_abilities_cd_pie_36.png^[transformFX", "R half run: frame 36 mirrored")
	eq(slot.caption.text, "5s", "R ...the caption stays the countdown")
	local shield = slot_with(alice, "grug_status_shield")
	eq(shield and shield.caption.text, "42", "R the shield's caption stays its points")
	eq(shield and step_of(shield.cover.text), 18, "R ...its cover the time share (5 of 20 s)")
	eq(slot_with(alice, "mount_flight").cover.text, "", "R ...the mount still none")
	us_time = t0 + 9.9 * S
	refresh(alice)
	eq(step_of(slot_with(alice, sidestep_tex).cover.text), 71, "R almost run out: the last step")
	-- The cover's place is the icon's once it is drawn.
	slot = slot_with(alice, sidestep_tex)
	check(slot.cover.offset.x == slot.icon.offset.x and slot.cover.offset.y == slot.icon.offset.y,
		"R a drawn cover sits on its icon")

	-- A refresh starts a new cover; a repeated set with the same expiry keeps it.
	grug_core.set_status(alice, "sidestep", {duration = 10})
	refresh(alice)
	eq(slot_with(alice, sidestep_tex).cover.text, "", "R a refresh: clear again")
	local t1 = us_time
	local expiry = t1 + 10 * S
	grug_core.set_status(alice, "poisoned", {expiry_us = expiry})
	us_time = t1 + 5 * S
	grug_core.set_status(alice, "poisoned", {expiry_us = expiry})
	eq(grug_core.get_status(alice, "poisoned").started_us, t1,
		"R a set with the same expiry keeps the start")
	refresh(alice)
	eq(step_of(slot_with(alice, "grug_status_poisoned").cover.text), 36,
		"R ...and the cover runs on (half of 10 s)")
	grug_core.set_status(alice, "poisoned", {expiry_us = expiry + 5 * S})
	refresh(alice)
	eq(slot_with(alice, "grug_status_poisoned").cover.text, "",
		"R a later expiry (a stacked chain) starts a new cover")
	grug_core.clear_status(alice, "poisoned")
	grug_core.clear_status(alice, "sidestep")
	grug_core.clear_status(alice, "shield")
	grug_core.clear_status(alice, "mount")
	refresh(alice)
end

-- Heartbeat statuses (fix round): their owner sets them for 1.5 s on every
-- 1 s tick (grug_mobs boss_dragons.lua); a cover would loop with each tick.
do
	local flagged = {}
	for id in pairs(icons.STATUS) do
		if not icons.has_cover(id) then flagged[#flagged + 1] = id end
	end
	table.sort(flagged)
	eq(table.concat(flagged, ","), "dragon_wrath,scorched", "R exactly the heartbeats have no cover")
	check(icons.has_cover("sidestep") and icons.has_cover("unregistered_x"),
		"R every other id has one")
	local looped = false
	for tick = 1, 6 do
		grug_core.set_status(alice, "scorched", {duration = 1.5})
		grug_core.set_status(alice, "dragon_wrath", {duration = 1.5})
		for _ = 1, 4 do
			us_time = us_time + 0.25 * S
			refresh(alice)
			for _, picture in ipairs({"grug_status_scorched"}) do
				for _, slot in ipairs(slots_of(alice)) do
					if slot.icon.text:find(picture, 1, true) and slot.cover.text ~= "" then
						looped = true
					end
				end
			end
		end
	end
	local shown = 0
	for _, slot in ipairs(slots_of(alice)) do
		if slot.icon.text:find("grug_status_scorched", 1, true) then shown = shown + 1 end
	end
	eq(shown, 2, "R both heartbeats show")
	check(not looped, "R ...and never a cover over six ticks")
	grug_core.clear_status(alice, "scorched")
	grug_core.clear_status(alice, "dragon_wrath")
	refresh(alice)
end

-- Source entries: the PvP flag in whole seconds of a wall clock that is
-- not the row's (as grug_pvp, the potion and the Deserter's Mark report),
-- and an untimed one.
local tag_end, contested = nil, false
local WALL_OFFSET = 0.7 -- the wall clock's fraction differs from the row's
local function wall_now() return math.floor(us_time / S + WALL_OFFSET) end
grug_core.register_status_source(function(player, now)
	if player ~= alice then return nil end
	local out = {}
	if contested then out[#out + 1] = {id = "pvp_contested", untimed = true} end
	local left = tag_end and tag_end - wall_now()
	if left and left > 0 then
		out[#out + 1] = {id = "pvp_tagged", expiry_us = now + left * S}
	end
	return out
end)
do
	local tag_tex = "grug_status_pvp_tagged"
	local t0 = us_time
	tag_end = wall_now() + 30
	refresh(alice)
	eq(slot_with(alice, tag_tex).cover.text, "", "R a source entry first seen: clear")
	-- Over the whole run the cover never restarts (the read jitters by up
	-- to a second) and runs on with the time.
	local steady, last = true, 0
	for tenth = 1, 285 do
		us_time = t0 + tenth * S / 10
		refresh(alice)
		local s = step_of(slot_with(alice, tag_tex).cover.text)
		if not s or s < last then steady = false end
		last = s or last
	end
	check(steady, "R a jittering source entry's cover never goes back")
	us_time = t0 + 15 * S
	refresh(alice)
	local mid = step_of(slot_with(alice, tag_tex).cover.text)
	check(mid and mid >= 33 and mid <= 39, "R half its 30 s run: about step 36 (" .. tostring(mid) .. ")")
	-- The row reorders: a debuff and a buff come in front; the tag's cover
	-- goes with it (neutral states are drawn last), the newcomers are clear.
	grug_core.set_status(alice, "poisoned", {duration = 30})
	grug_core.set_status(alice, "food", {duration = 300, icon = "bread.png"})
	contested = true
	refresh(alice)
	local slot, index = slot_with(alice, tag_tex)
	eq(step_of(slot.cover.text), mid, "R the cover follows its effect into another slot")
	check(index > 1, "R ...which moved (slot " .. tostring(index) .. ")")
	eq(slot_with(alice, "bread.png").cover.text, "", "R the newcomer in its old slot is clear")
	eq(slot_with(alice, "grug_status_poisoned").cover.text, "", "R the fresh debuff is clear")
	eq(slot_with(alice, "pvp_contested").cover.text, "", "R an untimed source entry: no cover")
	-- A refresh of the source (a later end) starts a new cover.
	tag_end = wall_now() + 30
	refresh(alice)
	eq(slot_with(alice, tag_tex).cover.text, "", "R a refreshed source entry: clear again")
	us_time = us_time + 10 * S
	refresh(alice)
	check((step_of(slot_with(alice, tag_tex).cover.text) or 0) > 0, "R ...and runs again")
	-- Gone and back: a fresh first sight.
	tag_end = nil
	refresh(alice)
	eq(slot_with(alice, tag_tex), nil, "R the tag ended")
	tag_end = wall_now() + 30
	refresh(alice)
	eq(slot_with(alice, tag_tex).cover.text, "", "R a tag that came back starts clear")
	-- An expired effect leaves no cover behind in the slot it had.
	tag_end, contested = nil, false
	grug_core.clear_status(alice, "food")
	us_time = us_time + 30 * S
	refresh(alice)
	local leftover = false
	for _, s in ipairs(slots_of(alice)) do
		if s.cover.text ~= "" or s.icon.text ~= "" then leftover = true end
	end
	check(not leftover, "R everything ran out: no icon and no cover left")
end

------------------------------------------------------------------------------
-- W: HUD writes over a whole run, through the 0.5 s status pass.
------------------------------------------------------------------------------
local function step(dt)
	us_time = us_time + dt * S
	for _, fn in ipairs(steps) do fn(dt) end
end
local function writes(p, kind)
	local covers, captions = {}, {}
	for _, slot in ipairs(slots_of(p)) do
		-- the ids, from the defs' identity
		for id, def in pairs(p.huds) do
			if def == slot.cover then covers[id] = true end
			if def == slot.caption then captions[id] = true end
		end
	end
	local n = 0
	for _, w in ipairs(p.writes) do
		if (kind == "cover" and covers[w.id] and w.key == "text") or
				(kind == "caption" and captions[w.id] and w.key == "text") or
				(kind == "all") then
			n = n + 1
		end
	end
	return n
end
do
	local bob = join("bob")
	step(0.5)
	bob.writes = {}
	step(0) -- no time passes
	eq(#bob.writes, 0, "W an idle refresh writes nothing")
	grug_core.set_status(bob, "sidestep", {duration = 10})
	bob.writes = {}
	for _ = 1, 22 do step(0.5) end -- the whole 10 s and one more second
	local cover, caption, all = writes(bob, "cover"), writes(bob, "caption"), writes(bob, "all")
	check(cover >= 19 and cover <= 21, "W 10 s effect: one cover write per pass at most (" .. cover .. ")")
	print(("R89 UI W 10 s effect: %d cover, %d caption, %d writes in all over 11 s"):format(
		cover, caption, all))

	local carol = join("carol")
	step(0.5)
	grug_core.set_status(carol, "food", {duration = 1800, icon = "bread.png"})
	carol.writes = {}
	for _ = 1, 3602 do step(0.5) end -- 30 min and one more second
	cover, caption, all = writes(carol, "cover"), writes(carol, "caption"), writes(carol, "all")
	check(cover >= 71 and cover <= 73, "W 30 min effect: one cover write per 5-degree step (" .. cover .. ")")
	print(("R89 UI W 30 min effect: %d cover, %d caption, %d writes in all over 1801 s (%d passes)"):format(
		cover, caption, all, 3602))
end

------------------------------------------------------------------------------
-- H: the home's name.
------------------------------------------------------------------------------
local clock = 1800000000
local function new_storage()
	local data = {}
	return {get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local m = dofile(ROOT .. "/mods/PLAYER/grug_housing/registry.lua")({storage = new_storage(),
	now = function() return clock end})
m.load()
local housing = {
	player_claim = m.player_claim, is_owner = m.is_owner, is_draft = m.is_draft,
	is_active = m.is_active, home_name = m.home_name, owner_names = m.owner_names,
	arrival_pos = function(claim)
		return {x = claim.center.x, y = claim.center.y + 1, z = claim.center.z}
	end,
	register_on_claim_changed = function() end,
	STONE_TEXTURE = "stone.png", ACCOUNT_STONE_TEXTURE = "account_stone.png",
}
rawset(_G, "grug_housing", housing)
grug_factions = {get_faction = function() return "accord" end}
grug_core.map_reset = {register_on_relocate = function() end}
local INN = {id = "highcourt", label = "Highcourt", faction = "accord", pos = {x = 0, y = 0, z = 0}}
grug_home = {innkeeper = function() return INN end, cancel = function() end,
	locations = function() return {INN} end, known_waypoints = function() return {} end}
dofile(ROOT .. "/mods/PLAYER/grug_home/claim_home.lua")
local rules = dofile(ROOT .. "/mods/PLAYER/grug_home/waypoints_core.lua")
local providers = {}
grug_map = {atlas = {register_marker_provider = function(kind, fn) providers[kind] = fn end}}
dofile(ROOT .. "/mods/PLAYER/grug_map/providers.lua")
local function markers(kind, p)
	local out = {}
	for _, marker in ipairs(providers[kind](p)) do
		if marker.id ~= INN.id then out[#out + 1] = marker end
	end
	return out
end
do
	-- Own home.
	local ann = fake_player("ann")
	local claim = m.create("ann", {x = 100, y = 5, z = 0})
	eq(grug_home.claim_waypoint(ann), nil, "H a draft is no waypoint")
	eq(rules.claim_entry(grug_home.claim_waypoint(ann)).row.label, "Your Claim Stone",
		"H ...its entry is the greyed Your Claim Stone")
	eq(m.activate(claim, 5), 5, "H the stone activated")
	local row = grug_home.claim_waypoint(ann)
	eq(row and row.label, "ann's Home", "H own home: the waystone list shows its default name")
	eq(rules.claim_entry(row).state, "travel", "H ...as a travel entry")
	eq(row and row.texture, "stone.png", "H ...with the personal stone's look")
	local wp = markers("waypoint", ann)
	check(#wp == 1 and wp[1].label == "ann's Home" and (wp[1].detail == nil or
		wp[1].detail == "ann's Home"), "H ...the map's waypoint marker: label and tooltip the name")
	check(grug_home.set_home_claim(ann), "H set as the travel home")
	local home = grug_home.get(ann)
	eq(home.label, "Claim Stone", "H grug_home.get keeps the kind of home as its label")
	eq(home.name, "ann's Home", "H ...and carries the name")
	local hm = markers("home", ann)
	check(#hm == 1 and hm[1].label == "ann's Home" and hm[1].detail == "Your home: ann's Home" and
		hm[1].kind == "home", "H the home marker: the name, tooltip Your home: <name>")
	eq(#markers("waypoint", ann), 0, "H ...the waypoint marker gives way to it")
	-- Renamed: every look after the rename reads the new name.
	check(m.set_name(claim, "Rook's Rest"), "H renamed")
	eq(grug_home.claim_waypoint(ann).label, "Rook's Rest", "H the list reads the new name")
	hm = markers("home", ann)
	check(hm[1].label == "Rook's Rest" and hm[1].detail == "Your home: Rook's Rest",
		"H the home marker reads the new name")
	local long = ("W"):rep(24)
	check(m.set_name(claim, long), "H the longest name")
	eq(grug_home.claim_waypoint(ann).label, long, "H ...shown whole")

	-- No stone.
	local nob = fake_player("nob")
	eq(grug_home.claim_waypoint(nob), nil, "H no stone: no waypoint")
	local entry = rules.claim_entry(nil)
	check(entry.state == "no_claim" and entry.row.label == "Your Claim Stone",
		"H no stone: the greyed Your Claim Stone")
	eq(#markers("waypoint", nob) + #markers("home", nob), 0, "H no stone: no marker")

	-- An account home, read by a member.
	local OWNER = m.owner_text("acc_7", "accord")
	m.join("zed", OWNER)
	m.join("mia", OWNER)
	local acc = m.create("zed", {x = 300, y = 5, z = 0}, "account")
	eq(m.activate(acc, 5), 5, "H the account stone activated")
	local mia = fake_player("mia")
	row = grug_home.claim_waypoint(mia)
	eq(row and row.label, "zed's Home", "H a member: the account home's name")
	eq(row and row.texture, "account_stone.png", "H ...with the account stone's look")
	wp = markers("waypoint", mia)
	check(#wp == 1 and wp[1].label == "zed's Home", "H ...and the waypoint marker")
	check(m.set_name(acc, "Hearth Hall"), "H the account home renamed")
	eq(grug_home.claim_waypoint(mia).label, "Hearth Hall", "H ...the member reads the new name")
	eq(grug_home.claim_waypoint(fake_player("zed")).label, "Hearth Hall",
		"H ...and so does the other member")
end

------------------------------------------------------------------------------
-- L: the Waystones tab's status column clears the widest name.
------------------------------------------------------------------------------
do
	local text = read("mods/PLAYER/grug_home/waypoints.lua")
	local x, w = text:match("local STATUS_X, STATUS_W = ([%d%.]+), ([%d%.]+)")
	x, w = tonumber(x), tonumber(w)
	check(x ~= nil, "L the column's constants")
	-- The smallest unit a form is drawn with beside the 16 px default font
	-- (guiFormSpecMenu.cpp getFixedImgsize: 0.5555 x 96 px; both scale with
	-- the GUI scaling and the display density, fontengine.cpp:259).
	local unit = 0.5555 * 96
	local widest = 0
	for _, name in ipairs({("W"):rep(24), ("W"):rep(20) .. "'s Home",
			("m"):rep(24), ("M"):rep(24), "Your Claim Stone"}) do
		widest = math.max(widest, layout.text_px(name, 16, false))
	end
	eq(widest, 360, "L the widest name: 24 W, 360 px")
	check(x and 0.4 + widest / unit + 0.15 <= x + 1e-9,
		"L the name ends 0.15 units before the column (" .. tostring(x) .. ")")
	check(x and x + w <= 9.6 + 1e-9, "L the Travel button ends with the separator line")
	local body = text:match("local function waystones_form.-\nend\n")
	check(body and not body:find("6%.8") and select(2, body:gsub("STATUS_X", "")) == 4,
		"L every status cell of the tab stands at STATUS_X")
	-- Fix round: the Expeditions tab's Enter, Confirm and action buttons
	-- stand in the same column (Back and further buttons left of it), so
	-- switching tabs moves no button; its button texts are single words.
	local exp = text:match("local function expeditions_form.-\nend\n")
	check(exp and not exp:find("6%.8") and not exp:find("4%.3") and
		select(2, exp:gsub("STATUS_X", "")) == 4 and select(2, exp:gsub("STATUS_W", "")) == 6,
		"L the Expeditions tab's buttons share the column")
	local widest_word = 0
	for _, word in ipairs({"Enter", "Confirm", "Back", "Finish", "Cancel", "Travel"}) do
		widest_word = math.max(widest_word, layout.text_px(word, 16, false))
	end
	check(widest_word / unit + 0.3 <= w, "L the button words fit " .. tostring(w) ..
		" units (" .. widest_word .. " px)")
	check(x - 2 * (w + 0.1) >= 0.4, "L two action buttons and Back stay inside the panel")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R89 UI PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R89 UI PORTABLE PASS checks=" .. checks)
