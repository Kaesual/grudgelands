-- Round 40 lane CD: the server-side Lua cost of the cooldown display, before
-- and after (docs/planning/round40-plan.md §4.2 "CD"). Tools only, never
-- shipped: staged into a throwaway headless boot with
--   PROBE=tools/r40_cd/bench tools/luanti_headless.sh 120
-- it logs `[r40 cd bench]` lines and shuts the server down.
--
-- A headless server has no player, so a stand-in carries the calls: its
-- inventory is a real detached InvRef (the same C++ get_stack/set_stack a
-- player inventory runs, minus the per-step send), its HUD calls are counted.
-- Numbers are comparisons, never targets.
--
--   before  the wear-bar ticker of main 44859742 (grug_abilities/init.lua:
--           889-924 set_item_wear, 983-996 arm_cooldown, 2357-2386 the
--           cooldown block of the shared 0.5 s pass), copied here verbatim
--           in behaviour, so both sides run on the same boot and inventory
--   after   the real overlay (grug_abilities.cooldown_hud), one pass per
--           0.1 s, when the running game has it
-- Steady state over 60 s of simulated time: N cooldowns of 2, 5, 10, 30, 60,
-- 90, 120 and 300 s on hotbar slots 1..N, a finished one restarted at once;
-- then the whole pass with PLAYERS stand-ins of N cooldowns each (their
-- start times staggered).

local US = core.get_us_time
local NAME = "r40cdbench"
local IDS = {"charge", "taunt", "fireball", "ice_nova", "blink", "smite",
	"hold_ground", "glacial_ward"}
local DURATIONS = {2, 5, 10, 30, 60, 90, 120, 300}
local SECONDS = 60
local PLAYERS = 100

local function log(line)
	core.log("action", "[r40 cd bench] " .. line)
end

local function median(list)
	local copy = {}
	for i, v in ipairs(list) do copy[i] = v end
	table.sort(copy)
	return copy[math.floor((#copy + 1) / 2)] or 0
end

local function stats(samples)
	local sum, top = 0, 0
	for _, s in ipairs(samples) do
		sum = sum + s
		if s > top then top = s end
	end
	return sum / math.max(1, #samples), median(samples), top
end

-- A detached inventory shaped like a player's: main 32, the four bag content
-- lists, the ability stacks on slots 1..8 with meta like the game writes
-- (description, skin token, wield override, swing caps).
local inv = core.create_detached_inventory("r40_cd_bench", {})
inv:set_size("main", 32)
for i = 1, grug_inventory.BAG_COUNT do
	inv:set_size(grug_inventory.content_list(i), 0)
end

local function fill()
	for slot, id in ipairs(IDS) do
		local stack = ItemStack("grug_abilities:" .. id)
		local meta = stack:get_meta()
		meta:set_string("description", ("%s (Warrior)\n25 rage, 10 s cooldown\n" ..
			"Rush a hostile up to 12 m away and stun it for 1.5 s; deals weapon damage."):format(id))
		meta:set_string("inventory_image", "")
		meta:set_string("wield_image", "grug_gear_sword_iron.png^[transformFX")
		meta:set_string("wield_scale", "")
		meta:set_string("grug_skin", "4|grug_gear_sword_iron.png")
		meta:set_tool_capabilities({full_punch_interval = 1.1, max_drop_level = 0,
			groupcaps = {dig_immediate = {times = {[2] = 0.3, [3] = 0.3}, uses = 0, maxlevel = 0}},
			damage_groups = {fleshy = 0}, punch_attack_uses = 0})
		inv:set_stack("main", slot, stack)
	end
	inv:set_stack("main", 12, ItemStack("default:torch 40"))
	inv:set_stack("main", 13, ItemStack("default:apple 12"))
end
fill()

local calls
local function stand_in(name)
	return {
		get_player_name = function() return name end,
		get_inventory = function() return inv end,
		hud_add = function() calls.add = calls.add + 1 return calls.add end,
		hud_change = function() calls.change = calls.change + 1 end,
		hud_remove = function() calls.remove = calls.remove + 1 end,
		hud_get_hotbar_itemcount = function() return 8 end,
		is_player = function() return true end,
	}
end
local fake = stand_in(NAME)

--
-- Before: the wear ticker of main 44859742, behaviour for behaviour.
--
local WEAR_STEPS = 32
local function representation_lists()
	local lists = {"main"}
	for i = 1, grug_inventory.BAG_COUNT do
		lists[#lists + 1] = grug_inventory.content_list(i)
	end
	return lists
end

local writes
local function set_item_wear(player, ability_id, wear)
	local pinv = player:get_inventory()
	local itemname = "grug_abilities:" .. ability_id
	for _, listname in ipairs(representation_lists()) do
		for i = 1, pinv:get_size(listname) do
			local stack = pinv:get_stack(listname, i)
			if stack:get_name() == itemname then
				stack:set_wear(wear)
				pinv:set_stack(listname, i, stack)
				writes = writes + 1
				return
			end
		end
	end
end

local function wear_bench(n)
	writes = 0
	local cds, steps = {}, {}
	local function arm(id, d, now)
		cds[id] = {expiry = now + d * 1e6, duration = d}
		steps[id] = WEAR_STEPS
		set_item_wear(fake, id, 65534)
	end
	for slot = 1, n do arm(IDS[slot], DURATIONS[slot], 0) end
	local start_writes = writes
	local samples, dirty_passes = {}, 0
	local passes = SECONDS / 0.5
	for k = 1, passes do
		local now = k * 0.5e6
		local before = writes
		local c0 = US()
		-- init.lua:2360-2386 (the cooldown block of the 0.5 s pass)
		for id, rec in pairs(cds) do
			local remaining = (rec.expiry - now) / 1e6
			if remaining <= 0 then
				cds[id] = nil
				steps[id] = nil
				set_item_wear(fake, id, 0)
			else
				local frac = remaining / rec.duration
				local step = math.max(1,
					math.min(WEAR_STEPS, math.ceil(frac * WEAR_STEPS)))
				if step ~= steps[id] then
					steps[id] = step
					set_item_wear(fake, id,
						math.floor(step / WEAR_STEPS * 65534))
				end
			end
		end
		samples[#samples + 1] = US() - c0
		-- A restart is a cast (arm_cooldown): its write counts, its time not.
		for slot = 1, n do
			if not cds[IDS[slot]] then arm(IDS[slot], DURATIONS[slot], now) end
		end
		if writes > before then dirty_passes = dirty_passes + 1 end
	end
	local avg, med, top = stats(samples)
	return ("before (wear bar, 0.5 s pass) %d cooldowns: pass avg %.1f us, median %d us, max %d us; " ..
		"%.1f inventory writes/s, %.2f inventory sends/s (one per pass with a write)")
		:format(n, avg, med, top, (writes - start_writes) / SECONDS, dirty_passes / SECONDS)
end

--
-- After: the real overlay.
--
local function overlay_bench(H, n)
	local real_info = H.window_info
	H.window_info = function()
		return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	end
	calls = {add = 0, change = 0, remove = 0}
	local recs = {}
	local function arm(slot, now)
		local d = DURATIONS[slot]
		recs[slot] = {expiry = now + d * 1e6, duration = d}
		H.track(fake, IDS[slot], recs[slot], now)
	end
	for slot = 1, n do arm(slot, 0) end
	local start = calls.add + calls.change + calls.remove
	local samples = {}
	local passes = SECONDS / 0.1
	for k = 1, passes do
		local now = k * 0.1e6
		local c0 = US()
		H.update(fake, now)
		samples[#samples + 1] = US() - c0
		for slot = 1, n do
			if recs[slot].expiry <= now then arm(slot, now) end
		end
	end
	local total = calls.add + calls.change + calls.remove - start
	H.forget(NAME)
	H.window_info = real_info
	local avg, med, top = stats(samples)
	return ("after (overlay, 0.1 s pass) %d cooldowns: pass avg %.1f us, median %d us, max %d us; " ..
		"%.1f HUD writes/s (%d adds, %d changes, %d removes)")
		:format(n, avg, med, top, total / SECONDS, calls.add, calls.change, calls.remove)
end

-- PLAYERS players with n cooldowns each. Before: the 0.5 s pass ran the
-- cooldown block for every connected player; after: H.pass, the overlay's
-- whole pass (at most PLAYERS_PER_PASS players). Start times are staggered
-- by 37 ms per player, as casts would be.
local function wear_crowd(n)
	writes = 0
	local who = {}
	for i = 1, PLAYERS do
		local player = stand_in(NAME .. i)
		local cds, steps = {}, {}
		for slot = 1, n do
			local start = i * 37e3
			cds[IDS[slot]] = {expiry = start + DURATIONS[slot] * 1e6, duration = DURATIONS[slot]}
			steps[IDS[slot]] = WEAR_STEPS
		end
		who[i] = {player = player, cds = cds, steps = steps}
	end
	local start_writes = writes
	local samples = {}
	local passes = SECONDS / 0.5
	for k = 1, passes do
		local now = 5e6 + k * 0.5e6
		local c0 = US()
		for _, w in ipairs(who) do
			for id, rec in pairs(w.cds) do
				local remaining = (rec.expiry - now) / 1e6
				if remaining <= 0 then
					w.cds[id] = nil
					w.steps[id] = nil
					set_item_wear(w.player, id, 0)
				else
					local step = math.max(1, math.min(WEAR_STEPS,
						math.ceil(remaining / rec.duration * WEAR_STEPS)))
					if step ~= w.steps[id] then
						w.steps[id] = step
						set_item_wear(w.player, id, math.floor(step / WEAR_STEPS * 65534))
					end
				end
			end
		end
		samples[#samples + 1] = US() - c0
		for _, w in ipairs(who) do
			for slot = 1, n do
				local id = IDS[slot]
				if not w.cds[id] then
					w.cds[id] = {expiry = now + DURATIONS[slot] * 1e6, duration = DURATIONS[slot]}
					w.steps[id] = WEAR_STEPS
					set_item_wear(w.player, id, 65534)
				end
			end
		end
	end
	local avg, med, top = stats(samples)
	return ("before, %d players x %d cooldowns (0.5 s pass): pass avg %.0f us, median %d us, max %d us; " ..
		"%.0f inventory writes/s, up to %d inventory sends/s")
		:format(PLAYERS, n, avg, med, top, (writes - start_writes) / SECONDS, 2 * PLAYERS)
end

local function overlay_crowd(H, n)
	local real_info = H.window_info
	H.window_info = function()
		return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
	end
	calls = {add = 0, change = 0, remove = 0}
	local who = {}
	for i = 1, PLAYERS do
		local player = stand_in(NAME .. i)
		local recs = {}
		local start = i * 37e3
		for slot = 1, n do
			recs[slot] = {expiry = start + DURATIONS[slot] * 1e6, duration = DURATIONS[slot]}
			H.track(player, IDS[slot], recs[slot], start)
		end
		who[i] = {player = player, recs = recs}
	end
	local active = H.active_count()
	local start_calls = calls.add + calls.change + calls.remove
	local samples = {}
	local passes = SECONDS / 0.1
	for k = 1, passes do
		local now = 5e6 + k * 0.1e6
		local c0 = US()
		H.pass(now)
		samples[#samples + 1] = US() - c0
		for _, w in ipairs(who) do
			for slot = 1, n do
				if w.recs[slot].expiry <= now then
					w.recs[slot] = {expiry = now + DURATIONS[slot] * 1e6, duration = DURATIONS[slot]}
					H.track(w.player, IDS[slot], w.recs[slot], now)
				end
			end
		end
	end
	local total = calls.add + calls.change + calls.remove - start_calls
	for i = 1, PLAYERS do H.forget(NAME .. i) end
	H.window_info = real_info
	local avg, med, top = stats(samples)
	return ("after, %d players x %d cooldowns (0.1 s pass, %d active, cap %d): pass avg %.0f us, " ..
		"median %d us, max %d us; %.0f HUD writes/s")
		:format(PLAYERS, n, active, H.PLAYERS_PER_PASS, avg, med, top, total / SECONDS)
end

-- The cast path: one arm_cooldown through the game's public call.
local function arm_bench(H)
	local def = grug_abilities.registered.charge
	local real_info = H and H.window_info
	if H then
		H.window_info = function()
			return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
		end
	end
	calls = {add = 0, change = 0, remove = 0}
	local samples = {}
	for _ = 1, 50 do
		local c0 = US()
		grug_abilities.arm_cooldown(fake, def, 10)
		samples[#samples + 1] = US() - c0
	end
	if H then
		H.forget(NAME)
		H.window_info = real_info
	end
	local avg, med = stats(samples)
	return ("arm_cooldown (one cast): avg %.1f us, median %d us"):format(avg, med)
end

-- What one inventory send carries for `main` (the engine sends the whole
-- list): the serialized stacks, an estimate from ItemStack:to_string.
local function main_bytes()
	local bytes = 0
	for i = 1, inv:get_size("main") do
		local stack = inv:get_stack("main", i)
		bytes = bytes + (stack:is_empty() and 6 or (#stack:to_string() + 6))
	end
	return bytes
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		local H = grug_abilities.cooldown_hud
		log("game has the overlay: " .. tostring(H ~= nil))
		log(("main list as sent: about %d bytes (8 ability stacks, 2 others)"):format(main_bytes()))
		for _, n in ipairs({1, 4, 8}) do
			fill()
			log(wear_bench(n))
		end
		if H then
			for _, n in ipairs({1, 4, 8}) do
				log(overlay_bench(H, n))
			end
		end
		for _, n in ipairs({1, 4}) do
			fill()
			log(wear_crowd(n))
			if H then log(overlay_crowd(H, n)) end
		end
		fill()
		log(arm_bench(H))
		log("done")
		core.request_shutdown("r40 cd bench done", false, 0)
	end)
end)
