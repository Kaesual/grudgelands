-- Round 81 lane SOCIAL portable test (LuaJIT): the audit fixes of the tag
-- carriers, the party HUD and the Claim Stone registry and pass
-- (round81-plan.md §4 SOCIAL; docs/audit-2026-11 C1-04, X4-03, P5-03,
-- P5-04, P4-02, X4-11, P4-10). Loads the REAL files through harness.lua.
--
--   luajit tools/r81_social/portable_test.lua [repo]
--
--   T  tag carriers: every carrier's own and foe observer sets and the
--      visibility callback's set equal a brute-force model (25/30 node
--      hysteresis, friend and foe split) over a random walk with jumps
--      across the snapshot cells, both through the test seams and through
--      the production steps; one faction read per player per second; a
--      steady scene allocates nothing and sends no set; an HP bar reads no
--      parent properties per visit and follows a rescale through
--      sync_tag_carrier_box; nearest_tag_player_d2 follows a move within
--      one 1/8 s step; a faction chosen later shows within two seconds; a
--      replaced player carrier rebuilds the combined set.
--   P  parties: the HUD poll builds a party's view once per poll for all
--      its members (one HP-maximum read per member per 0.5 s) and shows the
--      same rows as a view of its own; a level change reaches the party,
--      the player and the holders of its invitations only; the Party HUD
--      switch and the health colours are read once and follow their setters.
--   H  housing: draft_scan and expiry_scan give the full scans' answers
--      over random placements, activations, refuels, removals, clock jumps
--      and a reload; the overlap refusal equals the old all-claims test;
--      stone.lua checks each claim once per 5 s cycle in slices of at most
--      one eighth, copies the ordered claims only after a change, removes a
--      vanished stone within one cycle and never one removed meanwhile.
-- Prints "R81 SOCIAL PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local H = dofile(repo .. "/tools/r81_social/harness.lua")
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function names(set)
	local list = {}
	for name in pairs(set or {}) do list[#list + 1] = name end
	table.sort(list)
	return table.concat(list, ",")
end
local random = math.random
math.randomseed(81)

------------------------------------------------------------------------------
-- T: tag carriers
------------------------------------------------------------------------------
do
	local W = H.tags(repo)
	local CARRIER = "grug_core:tag_carrier"
	local visible, recording = {}, true
	grug_core.register_tag_visibility(function(parent, observers, removed)
		if recording and not removed then visible[parent] = names(observers) end
	end)
	local FACTIONS = {"accord", "throng", false}
	local function town(i) return i % 2 == 0 and 0 or 220 end
	local players = {}
	for i = 1, 60 do
		local faction = FACTIONS[i % 3 + 1] or nil
		players[i] = W.player("p" .. i, faction, town(i) + random(-60, 60),
			random(-10, 10), random(-60, 60))
	end
	-- Carriers: hostile mobs (no faction), guards of both sides, each
	-- player's own tag.
	local units = {}
	for i = 1, 150 do
		local fields = {name = "grug_mobs:wolf", _grug_disposition = "aggressive"}
		if i % 3 == 0 then
			fields = {name = "grug_mobs:guard_accord", _grug_faction = i % 2 == 0 and "accord" or "throng"}
		end
		if i % 7 == 0 then fields.health = 40 end -- injured: an HP bar
		local entity = W.mob(fields, town(i) + random(-70, 70), random(-10, 10), random(-70, 70))
		units[#units + 1] = {parent = entity.object, faction = fields._grug_faction,
			carrier = grug_core.create_tag_carrier(entity.object)}
	end
	for _, p in ipairs(players) do
		units[#units + 1] = {parent = p, owner = p.name, player = p,
			carrier = grug_core.create_tag_carrier(p, p.name)}
	end
	-- The model: the previous sets per carrier, as the code keeps them.
	local model = {}
	local function expected(unit)
		local m = model[unit] or {own = {}, foe = {}}
		local pos = unit.parent:get_pos()
		local faction = unit.player and unit.player.faction or unit.faction
		local own, foe = {}, {}
		for _, p in ipairs(players) do
			if p.name ~= unit.owner then
				local dx, dy, dz = pos.x - p.pos.x, pos.y - p.pos.y, pos.z - p.pos.z
				local d2 = dx * dx + dy * dy + dz * dz
				if d2 < 625 or (d2 <= 900 and (m.own[p.name] or m.foe[p.name])) then
					if faction and p.faction and p.faction ~= faction then
						foe[p.name] = true
					else
						own[p.name] = true
					end
				end
			end
		end
		model[unit] = {own = own, foe = foe}
		return own, foe
	end
	local function compare(label)
		local bad = 0
		for _, unit in ipairs(units) do
			local own, foe = expected(unit)
			local held = unit.carrier
			local got_own = held.entity._grug_observers
			local foe_carrier = W.foe_of(unit.parent, held)
			local got_foe = foe_carrier and foe_carrier.entity._grug_observers or {}
			local union = {}
			for name in pairs(own) do union[name] = true end
			for name in pairs(foe) do union[name] = true end
			if names(got_own) ~= names(own) or names(held.observers) ~= names(own) or
					names(got_foe) ~= names(foe) or
					(foe_carrier and names(foe_carrier.observers) ~= names(foe)) or
					(next(union) and visible[unit.parent] ~= names(union)) then
				bad = bad + 1
			end
		end
		eq(bad, 0, label .. ": carriers that differ from the model")
	end
	local function move()
		for _, p in ipairs(players) do
			local roll = random()
			if roll < 0.05 then
				p.pos.x, p.pos.z = town(random(1, 2)) + random(-60, 60), random(-60, 60)
			elseif roll < 0.6 then
				p.pos.x = p.pos.x + random(-9, 9)
				p.pos.z = p.pos.z + random(-9, 9)
				p.pos.y = p.pos.y + random(-2, 2)
			end
		end
	end
	local seen_foe, seen_hysteresis = false, false
	for pass = 1, 25 do
		move()
		grug_core.refresh_tag_player_snapshot()
		grug_core.manage_tag_carriers()
		if pass == 1 or pass == 25 then compare("T seam pass " .. pass) end
		if pass > 1 and pass < 25 then
			-- The model must see every pass to keep its previous sets.
			for _, unit in ipairs(units) do expected(unit) end
		end
		for _, unit in ipairs(units) do
			if W.foe_of(unit.parent, unit.carrier) then seen_foe = true end
		end
	end
	check(seen_foe, "T the scene has foe carriers")
	-- Production: eight 1/8 s steps visit every carrier once.
	for second = 1, 6 do
		move()
		W.second()
		compare("T production second " .. second)
	end
	-- Hysteresis across a cell border: a viewer 28 nodes away stays.
	do
		local guard = W.mob({name = "grug_mobs:wolf", _grug_disposition = "aggressive"}, 1000, 0, 1000)
		local held = grug_core.create_tag_carrier(guard.object)
		local p = players[1]
		p.pos.x, p.pos.y, p.pos.z = 1000 + 20, 0, 1000
		W.second()
		local shown = held.entity._grug_observers[p.name] == true
		p.pos.x = 1000 + 28 -- 1028 lies in the next 32-node cell
		W.second()
		seen_hysteresis = shown and held.entity._grug_observers[p.name] == true
		p.pos.x = 1000 + 31
		W.second()
		check(seen_hysteresis and not held.entity._grug_observers[p.name],
			"T hysteresis across a cell border: shown at 20, kept at 28, hidden at 31")
		grug_core.remove_tag_carrier(held)
	end
	-- One faction read per player per second, none per carrier.
	W.counters.faction = 0
	W.second()
	eq(W.counters.faction, #players, "T one faction read per player per second")
	-- A steady scene: no set sent, nothing allocated. The count includes the
	-- Lua stack, and the full collection may halve it (LuaJIT shrinks a
	-- stack used below a quarter; whether it does varies from run to run), so
	-- one warm-up second from the same call site regrows it before the
	-- count is taken. The code runs in the interpreter, which makes every
	-- allocation the code asks for: jit.off alone still runs the traces made
	-- so far, so they are flushed too. Then three seconds, every slot three
	-- times, must not grow the count at all.
	W.second()
	W.second()
	W.counters.set_observers = 0
	recording = false
	if jit then jit.off(); jit.flush() end
	collectgarbage("collect")
	collectgarbage("stop")
	local before
	for second = 0, 3 do
		if second == 1 then before = collectgarbage("count") end
		W.second()
	end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	recording = true
	eq(W.counters.set_observers or 0, 0, "T a steady scene sends no observer set")
	check(grown == 0, ("T a steady scene of %d carriers allocates nothing in 3 s (%.3f KB)")
		:format(#units, grown))
	-- HP bars: no parent properties per visit; a rescale moves the bar.
	do
		local wolf = W.mob({name = "grug_mobs:wolf", _grug_disposition = "aggressive", health = 50},
			2000, 0, 2000)
		local held = grug_core.create_tag_carrier(wolf.object)
		local p = players[2]
		p.pos.x, p.pos.y, p.pos.z = 2005, 0, 2000
		W.second()
		local bar
		for o in pairs(W.live) do
			if o.parent == wolf.object and o.entity and o.entity.name == "grug_core:injured_hp_bar" then bar = o end
		end
		check(bar ~= nil and bar.observers and bar.observers[p.name], "T an injured mob shows its bar")
		W.counters.properties = 0
		wolf.health = 45
		W.second()
		W.second()
		eq(W.counters.properties, 0, "T the bar reads no parent properties on its visits")
		local y0 = bar and bar.offset.y
		wolf.object.props.selectionbox = {-0.5, 0, -0.5, 0.5, 2.4, 0.5}
		wolf.object.props.visual_size = {x = 1.4, y = 1.4}
		W.second()
		eq(bar and bar.offset.y, y0, "T without the sync the bar stays")
		check(grug_core.sync_tag_carrier_box(wolf.object), "T sync_tag_carrier_box answers")
		eq(bar and bar.offset.y, (2.4 + 0.12) * 10 / 1.4, "T the sync moves the bar to the new top")
		eq(held.props.selectionbox[5], 2.4, "T ...and the tag's box")
		grug_core.remove_tag_carrier(held)
	end
	-- The snapshot positions stay fresh for the mobs (MOBRUN: <= 0.5 s).
	do
		local p = players[3]
		p.pos.x, p.pos.y, p.pos.z = 5000, 0, 5000
		W.step(0.125)
		eq(grug_core.nearest_tag_player_d2({x = 5003, y = 0, z = 5004}), 25,
			"T nearest_tag_player_d2 follows a move within one 1/8 s step")
	end
	-- A faction chosen later shows within two seconds.
	do
		local p = W.player("late", nil, 3000, 0, 3000)
		local own = grug_core.create_tag_carrier(p, "late")
		local viewer = W.player("viewer", "throng", 3005, 0, 3000)
		W.second()
		eq(names(own.entity._grug_observers), "viewer", "T a factionless player's one tag")
		p.faction = "accord"
		W.second()
		W.second()
		local foe = W.foe_of(p, own)
		check(foe ~= nil and names(foe.entity._grug_observers) == "viewer" and
			names(own.entity._grug_observers) == "",
			"T a faction chosen later moves the other side to the foe tag within 2 s")
		eq(own.props.nametag_color, "#4bdc4b", "T ...and the held tag turns green")
		check(viewer ~= nil, "T viewer")
		-- A lost own carrier replaced on the visit its last own viewer
		-- leaves, the foe side unchanged: the combined set drops that viewer.
		local ally = W.player("ally", "accord", 3008, 0, 3000)
		W.second()
		eq(visible[p], "ally,viewer", "T own and foe viewers together")
		own:remove()
		ally.pos.x = 3500
		W.second()
		local replaced
		for o in pairs(W.live) do
			if o.parent == p and o ~= foe and o.valid and o.entity and
					o.entity.name == CARRIER then
				replaced = o
			end
		end
		check(replaced ~= nil and names(replaced.entity._grug_observers) == "",
			"T the lost carrier is replaced, without own viewers")
		eq(visible[p], "viewer", "T the replacement's combined set is rebuilt")
	end
end

------------------------------------------------------------------------------
-- P: parties
------------------------------------------------------------------------------
do
	local W = H.parties(repo, H.party_groups(10, 10))
	local all = {}
	for k = 1, 10 do
		for i = 1, 10 do
			local p = W.player(("p%d_%d"):format(k, i), "accord", i % 2 == 0 and "mage" or "warrior", 10 + i)
			all[#all + 1] = p
			W.join(p)
		end
	end
	local solo = W.player("solo", "accord", "scout", 5)
	W.join(solo)
	local solo2 = W.player("solo2", "accord", "scout", 5)
	W.join(solo2)
	W.step(1)
	-- One HP maximum per member per poll: 100 members, two polls a second.
	W.counters.properties, W.counters.meta = 0, 0
	W.step(1)
	eq(W.counters.properties, 200, "P one HP-maximum read per member per 0.5 s")
	eq(W.counters.meta, 0, "P the poll reads no player meta of its own")
	-- The rows equal the view of the player's party (hud.lua's label rule).
	local width = grug_core.hud_layout.side_text_width(core.get_player_window_information("x"))
	local function label(view, m)
		local prefix = m.name == view.leader and "* " or ""
		local suffix = " [Lv " .. m.level .. "]" ..
			(m.online and ("  %d/%d"):format(m.hp, m.hp_max) or " [Offline]")
		local limit = math.max(4, math.min(18, width - #prefix - #suffix))
		local shown = #m.name > limit and m.name:sub(1, limit - 2) .. ".." or m.name
		return prefix .. shown .. suffix
	end
	local bad = 0
	for _, p in ipairs(all) do
		local view = grug_parties.view(p)
		local want = {}
		for _, m in ipairs(view.members) do want[#want + 1] = label(view, m) end
		table.sort(want)
		if W.labels(p) ~= table.concat(want, "\n") then bad = bad + 1 end
	end
	eq(bad, 0, "P every player's rows show its party's view")
	-- An HP change shows on every mate within 0.5 s.
	all[5].hp, all[5].hp_max = 7, 24
	W.step(0.5)
	local shown = 0
	local five = label(grug_parties.view(all[5]), grug_parties.view(all[5]).members[5])
	check(five:find("7/24", 1, true) ~= nil, "P the view carries the new HP")
	for i = 1, 10 do
		if W.labels(all[i]):find(five, 1, true) then shown = shown + 1 end
	end
	eq(shown, 10, "P an HP change shows on the whole party within 0.5 s")
	-- A level change: the party, the player and its invitations' holders.
	W.changes = {}
	all[12].level = 30
	for _, fn in ipairs(W.level_callbacks) do fn(all[12]) end
	local heard = {}
	for _, change in ipairs(W.changes) do
		if change.reason == "level" then heard[#heard + 1] = change.name end
	end
	table.sort(heard)
	local want = {}
	for i = 11, 20 do want[#want + 1] = all[i].name end
	table.sort(want)
	eq(table.concat(heard, ","), table.concat(want, ","), "P a member's level reaches its party")
	check(grug_parties.invite(solo, "solo2"), "P a player alone invites another")
	W.changes = {}
	solo.level = 6
	for _, fn in ipairs(W.level_callbacks) do fn(solo) end
	heard = {}
	for _, change in ipairs(W.changes) do
		if change.reason == "level" then heard[#heard + 1] = change.name end
	end
	table.sort(heard)
	eq(table.concat(heard, ","), "solo,solo2", "P a level reaches the holder of the player's invitation")
	W.step(0.5)
	check(W.labels(all[13]):find(all[12].name .. " [Lv 30]", 1, true) ~= nil,
		"P the new level shows on the mates' rows")
	-- The display switches: read once, kept by their setters.
	W.counters.meta = 0
	W.step(2)
	eq(W.counters.meta, 0, "P the Party HUD switch and the colours are not read per poll")
	local p = all[3]
	check(grug_parties.set_hud_enabled(p, false), "P the HUD switch goes off")
	eq(grug_parties.hud_enabled(p), false, "P ...and reads off")
	W.step(0.5)
	eq(W.labels(p), "", "P ...and the rows go")
	grug_parties.set_hud_enabled(p, true)
	W.step(0.5)
	check(W.labels(p) ~= "", "P ...and come back")
	eq(grug_parties.health_color_mode(p), "by_class", "P the colours default to by class")
	grug_parties.set_health_color_mode(p, "all_green")
	eq(grug_parties.health_color_mode(p), "all_green", "P the colours follow their setter")
	eq(p.meta.fields["grug_parties:health_colors"], "all_green", "P ...and are saved")
	local names_only = grug_parties.member_names(p)
	eq(names_only and #names_only, 10, "P member_names lists the party")
	eq(grug_parties.member_names(solo), nil, "P ...and nil without one")
	eq(grug_parties.party_id(p), "1", "P party_id")
end

------------------------------------------------------------------------------
-- H: housing
------------------------------------------------------------------------------
do
	local M, clock, reload = H.registry(repo)
	local function ids(list)
		local out = {}
		for i, claim in ipairs(list) do out[i] = claim.id end
		return table.concat(out, ",")
	end
	local function want_drafts(model)
		local out = {}
		for _, claim in ipairs(model.all_claims()) do
			if claim.activated_at == 0 and claim.placed_at + model.DRAFT_SECONDS <= clock.t then
				out[#out + 1] = claim
			end
		end
		return ids(out)
	end
	local function want_expired(model)
		local out = {}
		for _, claim in ipairs(model.all_claims()) do
			if claim.paid_until <= clock.t and claim.expired_for ~= claim.paid_until then
				out[#out + 1] = claim
			end
		end
		return ids(out)
	end
	local live, serial, bad = {}, 0, 0
	local reported = 0
	for round = 1, 400 do
		local roll = random()
		if roll < 0.3 then
			serial = serial + 1
			local name = "o" .. serial
			M.issue(name, 20, false)
			live[#live + 1] = M.create(name, {x = serial * 300, y = 0, z = 0})
		elseif roll < 0.5 and #live > 0 then
			M.activate(live[random(#live)], random(5, 20))
		elseif roll < 0.65 and #live > 0 then
			M.add_fuel(live[random(#live)], random(1, 4))
		elseif roll < 0.72 and #live > 0 then
			local index = random(#live)
			M.remove(live[index], "picked_up")
			table.remove(live, index)
		else
			clock.t = clock.t + random(0, 3) * (random() < 0.5 and 100 or M.LUMP_SECONDS)
		end
		if round == 200 then
			M = reload()
			for i, claim in ipairs(live) do live[i] = M.claim_by_id(claim.id) end
		end
		local drafts, expired = want_drafts(M), want_expired(M)
		local got_drafts = ids(M.draft_scan())
		local got_expired = M.expiry_scan()
		reported = reported + #got_expired
		if got_drafts ~= drafts or ids(got_expired) ~= expired then bad = bad + 1 end
		-- The scan's caller removes the expired drafts.
		for _, claim in ipairs(M.draft_scan()) do
			M.remove(claim, "draft_expired")
			for i = #live, 1, -1 do if live[i] == claim then table.remove(live, i) end end
		end
	end
	eq(bad, 0, "H draft_scan and expiry_scan equal the full scans")
	check(reported >= 5, "H the walk reported expiries (" .. reported .. ")")
	-- The overlap refusal against the old all-claims test.
	local world = {water_class_at = function() return "land" end,
		-- Every column is enemy land: a placement without overlap is
		-- refused by the zone scan's first column ("enemy").
		zone_at = function() return {faction = "throng", level_min = 11, level_max = 30,
			territory_rule = "throng_home"} end,
		territory_at = function() return "accord_home" end,
		feature_in = function() return nil end,
		cube_clear = function() return true end}
	local R = M.RADIUS
	local mismatch, refused = 0, 0
	for i = 1, 600 do
		local base = live[random(#live)]
		local c = base and base.center or {x = 0, z = 0}
		local pos = {x = c.x + random(-3 * R, 3 * R), y = 0, z = c.z + random(-3 * R, 3 * R)}
		local old = false
		for _, other in ipairs(M.all_claims()) do
			if math.abs(other.center.x - pos.x) <= 2 * R and math.abs(other.center.z - pos.z) <= 2 * R then
				old = true
			end
		end
		local _, code = M.validate("newcomer" .. i, "accord", pos, world)
		if (code == "overlap") ~= old or (not old and code ~= "enemy") then mismatch = mismatch + 1 end
		if old then refused = refused + 1 end
	end
	eq(mismatch, 0, "H the overlap refusal equals the all-claims test")
	check(refused > 50 and refused < 550, "H the placements were near and far (" .. refused .. ")")
end

do
	local W = H.stone(repo)
	local M = W.model
	local claims = W.claims(40)
	local TICK = 5 / 8
	W.counters.all_claims = 0
	local most, checked = 0, {}
	local real_get = core.get_node_or_nil
	core.get_node_or_nil = function(pos)
		checked[W.key(pos)] = (checked[W.key(pos)] or 0) + 1
		return real_get(pos)
	end
	for _ = 1, 16 do
		local before = W.counters.get_node or 0
		W.step(TICK)
		most = math.max(most, (W.counters.get_node or 0) - before)
	end
	core.get_node_or_nil = real_get
	-- A standing stone costs two reads (the check and the variant sync).
	check(most <= 2 * 5, "H at most one eighth of the stones per tick (" .. most .. " reads)")
	local twice = true
	for _, claim in ipairs(claims) do
		if checked[W.key(claim.center)] ~= 4 then twice = false end
	end
	check(twice, "H every stone checked once per 5 s (two cycles: two checks, two syncs)")
	eq(W.counters.all_claims, 1, "H the ordered claims are copied once while none comes or goes")
	-- A stone gone from a loaded block: the claim goes within one cycle.
	W.nodes[W.key(claims[7].center)] = "air"
	for _ = 1, 8 do W.step(TICK) end
	eq(M.claim_by_id(claims[7].id), nil, "H a vanished stone removes its claim within a cycle")
	eq(W.events[#W.events].event, "destroyed", "H ...as destroyed")
	-- A claim picked up during a cycle is not reported as destroyed.
	W.events = {}
	W.step(TICK) -- cycle start
	local late = claims[40]
	M.remove(late, "picked_up")
	W.nodes[W.key(late.center)] = nil
	W.nodes[W.key(late.center)] = "air"
	for _ = 1, 7 do W.step(TICK) end
	eq(#W.events, 0, "H a claim removed meanwhile is not checked again")
	-- A draft crumbles at a cycle start.
	M.issue("drafter", 20, false)
	local draft = M.create("drafter", {x = -9000, y = 10, z = 0})
	W.nodes[W.key(draft.center)] = "grug_housing:claim_stone_draft"
	W.clock.t = W.clock.t + M.DRAFT_SECONDS
	for _ = 1, 8 do W.step(TICK) end
	eq(M.claim_by_id(draft.id), nil, "H an expired draft crumbles at the next cycle")
	eq(W.nodes[W.key(draft.center)], nil, "H ...its stone removed")
end

if failures > 0 then
	error(("R81 SOCIAL PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R81 SOCIAL PORTABLE PASS checks=%d"):format(checks))
