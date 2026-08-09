-- Class abilities (docs/design/classes.md): hotbar items with cooldowns,
-- mana/rage resources with HUD line, kit granting on class pick. Resources
-- and cooldowns are runtime state (not persisted): mana is full on
-- join/respawn, rage starts at 0.

grug_abilities = {}

grug_abilities.registered = {} -- ability id -> def
grug_abilities.by_class = {} -- class id -> ordered list of defs
-- Abilities every character has, class or no class (weapon-slot design E1).
-- Ordered like by_class, and granted BEFORE it, so a universal ability lands
-- on hotbar key 1 for everyone.
grug_abilities.universal = {}
local item_defs = {} -- item name -> ability def

local mana = {} -- player name -> current mana (fractional)
local rage = {} -- player name -> current rage (fractional)
-- player name -> {ability id -> {expiry = us time, duration = seconds}}. The
-- duration is stored per cast, not looked up from the def, because the wear
-- ticker needs the value THIS cast used to draw a fraction of it.
local cooldowns = {}
local targets = {} -- player name -> {enemy = rec, ally = rec}; rec = {obj, expiry}
local resource_huds = {} -- player name -> hud id
local flash_huds = {} -- player name -> {id = hud id, token = n}
-- Skill-name line (classes.md §2c) and the wield watcher that feeds it
-- (WP38 T3). The watcher keeps the last noticed wielded stack per player:
-- the index alone is not the item — a same-index content swap has to raise
-- `dirty` or it reads as "unchanged".
local skillname_huds = {} -- player name -> {id = hud id, token = n}
local wield_watch = {} -- player name -> {index = hotbar index, item = name}
local dirty = {} -- player name -> true (inventory action since last pass)

-- Soft target lock (classes.md core principles): the last punched/pointed
-- enemy or ally stays the implicit target this long; abilities fall back
-- to it when pointed_thing has no valid target.
grug_abilities.TARGET_LOCK = 8

local function resource_of(player)
	local def = grug_classes.get_class_def(player)
	return def and def.resource or nil
end

--
-- Resource API
--

function grug_abilities.get_mana(player)
	return math.floor(mana[player:get_player_name()] or 0)
end

function grug_abilities.get_rage(player)
	return math.floor(rage[player:get_player_name()] or 0)
end

local hud_update -- forward

function grug_abilities.add_rage(player, amount)
	if resource_of(player) ~= "rage" then
		return
	end
	local name = player:get_player_name()
	rage[name] = math.max(0, math.min(100, (rage[name] or 0) + amount))
	hud_update(player)
end

local function refill_mana(player)
	mana[player:get_player_name()] = grug_classes.get_max_mana(player)
end

-- cost = {mana = n} or {rage = n}; returns false if not affordable.
local function spend(player, cost)
	local name = player:get_player_name()
	if cost.mana then
		if (mana[name] or 0) < cost.mana then
			return false
		end
		mana[name] = mana[name] - cost.mana
	end
	if cost.rage then
		if (rage[name] or 0) < cost.rage then
			return false
		end
		rage[name] = rage[name] - cost.rage
	end
	hud_update(player)
	return true
end

local function affordable(player, cost)
	local name = player:get_player_name()
	return (not cost.mana or (mana[name] or 0) >= cost.mana)
		and (not cost.rage or (rage[name] or 0) >= cost.rage)
end

-- kits.lua (separate chunk) reads the def behind an item name and pays
-- proc costs through these three; the locals stay private.
function grug_abilities.ability_of_item(itemname)
	return item_defs[itemname]
end

function grug_abilities.can_afford(player, cost)
	return affordable(player, cost)
end

function grug_abilities.pay(player, cost)
	spend(player, cost)
end

--
-- Soft target lock. Enemy and ally are separate slots — a Priest who
-- Smites a mob must not lose their heal target over it. The kits
-- re-validate faction/range/LOS on every use; this only stores identity
-- and freshness.
--

function grug_abilities.set_target(player, obj, ally)
	local name = player:get_player_name()
	targets[name] = targets[name] or {}
	targets[name][ally and "ally" or "enemy"] = {
		obj = obj,
		expiry = core.get_us_time() + grug_abilities.TARGET_LOCK * 1e6,
	}
end

-- Locked enemy (ally = false) or ally (ally = true) — nil when no lock,
-- expired, or the object is gone (mob died/unloaded, player left;
-- invalid ObjectRefs return nil from get_pos).
function grug_abilities.get_target(player, ally)
	local name = player:get_player_name()
	local slot = ally and "ally" or "enemy"
	local rec = targets[name] and targets[name][slot]
	if not rec then
		return nil
	end
	if core.get_us_time() > rec.expiry or not rec.obj:get_pos() then
		targets[name][slot] = nil
		return nil
	end
	return rec.obj
end

-- Effective targeting range of an ability for this player (elf passive:
-- +5 m on RANGED abilities, world.md §7). The granted item's meta `range`
-- override (sync_kit) keeps pointed_thing in step with this — both go through
-- here, so the reach the engine allows and the reach the lock fallback checks
-- can never disagree.
--
-- `def.melee = true` opts an ability OUT of the perk (weapon-slot design E7).
-- The perk is written as "+5 m on every ability", and on the auto-attack that
-- is a 9 m sword: an elf would hit things it cannot reach with a weapon,
-- through the one ability every character has. The opt-out is an explicit
-- flag rather than a range threshold because a threshold silently re-tunes
-- the perk the day an ability's range changes.
--
-- Mighty Blow and Hamstring are melee at 4 m and carried the same pre-existing
-- bug; T4 set the flag on both (kits.lua). Every ability that is still meant to
-- reach further -- Fireball and Smite at 20 m, Flash Heal / Power Word: Shield /
-- Renew at 15 m, Charge at 12 m, Taunt at 8 m, and the two self-centred Mage
-- spells -- keeps the perk, because it is granted by the ABSENCE of the flag.
function grug_abilities.get_range(player, def)
	local base = def.range or 4
	if def.melee then
		return base
	end
	return base
		+ (grug_classes.get_race_perk(player, "ability_range_bonus") or 0)
end

--
-- HUD: resource line above the XP line (mana blue / rage red) and a
-- short-lived error flash top center ("Not enough mana", "No target", ...).
--

local function hud_state(player)
	local res = resource_of(player)
	if res == "mana" then
		return ("Mana %d / %d"):format(grug_abilities.get_mana(player),
			grug_classes.get_max_mana(player)), 0x4a9bd8
	elseif res == "rage" then
		return ("Rage %d / 100"):format(grug_abilities.get_rage(player)), 0xc41e3a
	end
	return "", 0xffffff
end

hud_update = function(player)
	local id = resource_huds[player:get_player_name()]
	if not id then
		return
	end
	local text, color = hud_state(player)
	player:hud_change(id, "text", text)
	player:hud_change(id, "number", color)
end

function grug_abilities.flash(player, msg)
	local name = player:get_player_name()
	local rec = flash_huds[name]
	if not rec then
		return
	end
	rec.token = rec.token + 1
	local token = rec.token
	player:hud_change(rec.id, "text", msg)
	core.after(1.5, function()
		local p = core.get_player_by_name(name)
		local r = flash_huds[name]
		if p and r and r.token == token then
			p:hud_change(r.id, "text", "")
		end
	end)
end

--
-- Skill-name HUD and the wield watcher (WP38 T3, classes.md §2c). The
-- engine has no callback for a wield change, so the watcher polls it per
-- globalstep (cost model documented above the globalstep). The name line
-- answers "which skill is this?" at the moment the player asks it; it is
-- deliberately the neutral white of the resource line, not the error
-- flash's red.
--

local function show_skill_name(player, text)
	local name = player:get_player_name()
	local rec = skillname_huds[name]
	if not rec then
		return
	end
	rec.token = rec.token + 1
	local token = rec.token
	player:hud_change(rec.id, "text", text)
	core.after(1.5, function()
		local p = core.get_player_by_name(name)
		local r = skillname_huds[name]
		if p and r and r.token == token then
			p:hud_change(r.id, "text", "")
		end
	end)
end

-- Any player inventory action (signature: player, action, inventory,
-- inventory_info) marks the wield slot possibly changed. Not filtered: the
-- filter would have to read the inventory to decide, and a spurious flag
-- costs exactly one item-name read on the next step — filtering would pay
-- the read once per action anyway, plus the branches to skip the rest.
core.register_on_player_inventory_action(function(player)
	dirty[player:get_player_name()] = true
end)

-- `repeating` lives in the auto-repeat section below; forward-declared so
-- the watcher sees the LOCAL, not an undeclared global (strict.lua).
local repeating
local function watch_wield()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local rec = wield_watch[name]
		local idx = player:get_wield_index()
		if not rec then
			-- Join already initialises (below); this is the belt-and-braces
			-- first sight: record without any feedback.
			dirty[name] = nil
			wield_watch[name] = {
				index = idx,
				item = player:get_wielded_item():get_name(),
			}
		elseif rec.index ~= idx or dirty[name] then
			dirty[name] = nil
			-- The one inventory read of the change path, and the read that
			-- makes a same-index content swap visible.
			local item = player:get_wielded_item():get_name()
			wield_watch[name] = {index = idx, item = item}
			if item == rec.item then
				-- Dirty from an unrelated action (bag rearranging): the
				-- wielded stack is untouched, nothing to do.
			elseif item_defs[item] == nil then
				-- Not an ability item: the loop follows the selected item
				-- (classes.md §2b) — switching to a pick STOPS it, with the
				-- same text as the manual toggle-off.
				local running = repeating[name]
				if running then
					grug_abilities.stop_repeat(player)
					grug_abilities.flash(player, running.name .. " off.")
				end
			else
				-- An ability item was selected: name it. The loop is left
				-- running — re-arming it on the selected skill is WP38 T5.
				show_skill_name(player, item_defs[item].name)
			end
		end
	end
end

--
-- Ability registration & item. One tool per ability; the item's `range`
-- doubles as the targeting range (pointed_thing works up to it), the wear
-- bar displays the running cooldown.
--

function grug_abilities.register_ability(def)
	assert(def.id and (def.kind == "swing" or def.kind == "cast"),
		"ability needs kind = \"swing\" or \"cast\"")
	-- Class ability or universal one, never both (weapon-slot design E1). A
	-- universal ability has NO class at all -- it is granted on join whatever
	-- the character is, because class selection happens after the
	-- faction/race flow and a classless character must not stand in the world
	-- with no way to fight back.
	assert((def.class ~= nil) ~= (def.universal == true),
		"an ability needs either a class or universal = true")
	-- Kind-dependent shape (classes.md §2b): a CAST skill is a discrete
	-- action with a cast function and a cooldown; a SWING skill's click IS
	-- a weapon swing — it has no cast and no cooldown, only an optional
	-- charge timer and an optional proc_swing (defined in kits.lua).
	if def.kind == "cast" then
		assert(def.cast and def.cooldown ~= nil,
			"a cast ability needs cast and cooldown")
		assert(def.charge == nil,
			"charge timers belong to swing abilities")
	else
		assert(not def.cast and def.cooldown == nil and def.off_gcd == nil,
			"swing abilities have no cast/cooldown — the swing IS the cast")
		assert(def.charge == nil or def.charge > 0,
			"charge must be seconds > 0")
	end
	def.cost = def.cost or {}
	-- Which equipment slot's item this ability wears and (from T4 on) swings
	-- (weapon-slot design C1). "weapon" is the default and every shipped
	-- ability takes it -- deliberately INCLUDING the ones that deal no weapon
	-- damage at all (Blink, Renew, Power Word: Shield): "all skills use the
	-- weapon skin" is the rule, and an exception list would put the orb back on
	-- precisely the abilities whose colour is hardest to remember. "offhand"
	-- exists for WP14's shield abilities and has no user yet -- it is built now
	-- so WP14 does not pay for the same plumbing twice.
	def.slot = def.slot or "weapon"
	assert(def.slot == "weapon" or def.slot == "offhand",
		"ability slot must be \"weapon\" or \"offhand\"")
	grug_abilities.registered[def.id] = def
	if def.universal then
		table.insert(grug_abilities.universal, def)
	else
		grug_abilities.by_class[def.class] = grug_abilities.by_class[def.class] or {}
		table.insert(grug_abilities.by_class[def.class], def)
	end

	-- No class_def lookup for a universal ability: `registered_classes[nil]`
	-- is nil and dereferencing its `.name` was a hard crash at load time.
	local class_def = def.class and grug_classes.registered_classes[def.class]
	local owner_line = class_def and class_def.name or "every class"
	local cost_line = def.cost.mana and (def.cost.mana .. " mana")
		or def.cost.rage and (def.cost.rage .. " rage") or "free"
	-- Timing line: swing skills show their CHARGE (classes.md §2b), cast
	-- skills their cooldown. The old per-cast text flag is gone with WP38.
	local cd_line
	if def.kind == "swing" then
		cd_line = def.charge and (def.charge .. " s charge") or "no charge"
	else
		cd_line = (def.cooldown > 0 and (def.cooldown .. " s cooldown"))
			or "no cooldown"
	end
	local itemname = "grug_abilities:" .. def.id
	item_defs[itemname] = def

	core.register_tool(itemname, {
		description = def.name .. " (" .. owner_line .. ")\n" ..
			cost_line .. ", " .. cd_line .. "\n" ..
			def.description,
		inventory_image = "grug_abilities_orb.png^[multiply:" .. def.color,
		wield_image = "grug_abilities_orb.png^[multiply:" .. def.color,
		range = def.range or 4,
		stack_max = 1,
		groups = {grug_ability = 1, not_in_creative_inventory = 1},
		on_drop = function(itemstack)
			return itemstack -- ability items cannot be dropped
		end,
		on_use = function(itemstack, user, pointed_thing)
			grug_abilities.try_cast(user, def, pointed_thing)
			return nil
		end,
	})
end

-- Cooldown display via item wear. Inventory writes re-send the whole
-- player inventory to the client, so this path is deliberately stingy:
-- slot indices are cached (no full-list scan per tick) and the wear bar is
-- quantized to WEAR_STEPS — a write happens only when the visible step
-- changes, not every tick.
local WEAR_STEPS = 12

local slot_cache = {} -- player name -> {ability id -> main list index}
local wear_steps = {} -- player name -> {ability id -> last written step}

local function set_item_wear(player, ability_id, wear)
	local inv = player:get_inventory()
	local itemname = "grug_abilities:" .. ability_id
	local name = player:get_player_name()
	slot_cache[name] = slot_cache[name] or {}
	local idx = slot_cache[name][ability_id]
	if idx then
		local stack = inv:get_stack("main", idx)
		if stack:get_name() == itemname then
			stack:set_wear(wear)
			inv:set_stack("main", idx, stack)
			return
		end
		slot_cache[name][ability_id] = nil
	end
	local list = inv:get_list("main") or {}
	for i, stack in ipairs(list) do
		if stack:get_name() == itemname then
			slot_cache[name][ability_id] = i
			stack:set_wear(wear)
			inv:set_stack("main", i, stack)
			return
		end
	end
end

-- Ability items live in the main inventory only — stashing one in a bag
-- would hide its cooldown and used to confuse the kit sync. NB other
-- allow callbacks OR-combine (see grug_inventory): return nil when
-- unconcerned, a number swallows later callbacks.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" and info.to_list ~= "main" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if item_defs[stack:get_name()] then
			return 0
		end
	end
end)

--
-- Cooldowns. Two public calls for the repeat loop in kits.lua (a separate
-- chunk), which drives the very same clock the manual cast does: one timer
-- per ability, whether the swing came from a click or from the repeat loop.
-- The duration is passed in per call — the cast computes what THIS cast
-- earns (def.cooldown), the swing loop what its swing earned.
--

-- Is this ability off cooldown for this player right now?
function grug_abilities.ready(player, id)
	local cds = cooldowns[player:get_player_name()]
	local rec = cds and cds[id]
	return not rec or core.get_us_time() >= rec.expiry
end

-- Start (or restart) an ability's cooldown. `duration` <= 0 is "no cooldown"
-- and stores nothing at all, so a free ability never enters the ticker.
-- Every remaining user is a cast skill and displays its wear bar.
function grug_abilities.arm_cooldown(player, def, duration)
	if not duration or duration <= 0 then
		return
	end
	local name = player:get_player_name()
	cooldowns[name] = cooldowns[name] or {}
	cooldowns[name][def.id] = {
		expiry = core.get_us_time() + duration * 1e6,
		duration = duration,
	}
	wear_steps[name] = wear_steps[name] or {}
	wear_steps[name][def.id] = WEAR_STEPS
	set_item_wear(player, def.id, 65534)
end

--
-- Skill charge timers (classes.md §2b, WP38 T5). Every swing skill charges
-- on its own timer, and the timer runs ALWAYS — including while the skill
-- is not selected (a timestamp needs no ticking): several skills come up
-- during a fight and are spent in consecutive swings. Charges do not stack
-- (one maximum), a full charge never decays, the start state is CHARGED
-- (join/grant/class switch = no record = ready), and the ONLY reset is a
-- fired proc (kits.lua). Runtime-only, never persisted.
--

local charges = {} -- player name -> {ability id -> ready_at us time}

-- A def WITHOUT def.charge is always ready (Mighty Blow: limited by its
-- resource alone). An absent record means charged (the join/grant state).
function grug_abilities.charge_ready(player, def)
	if not def.charge then
		return true
	end
	local per_player = charges[player:get_player_name()]
	return core.get_us_time() >= ((per_player and per_player[def.id]) or 0)
end

-- The one reset: a fired proc starts the timer over.
function grug_abilities.reset_charge(player, def)
	if not def.charge then
		return
	end
	local name = player:get_player_name()
	charges[name] = charges[name] or {}
	charges[name][def.id] = core.get_us_time() + def.charge * 1e6
end

-- 0..1, for the charge bar (T6 drives the wear bar with it).
function grug_abilities.charge_fraction(player, def)
	if not def.charge then
		return 1
	end
	local per_player = charges[player:get_player_name()]
	local ready_at = (per_player and per_player[def.id]) or 0
	local remaining = (ready_at - core.get_us_time()) / 1e6
	if remaining <= 0 then
		return 1
	end
	return 1 - remaining / def.charge
end

--
-- The melee auto-attack loop (classes.md §2b). Any swing skill starts or
-- toggles it; the proc identity is the live selected item — melee_swing reads
-- it every swing — and the def in `repeating` is toggle identity only. Cast
-- skills are unaffected: they arm their cooldown and are never looped.
-- (Weapon-slot design E3's repeat_swing toggle is the history of this loop.)
--
-- The loop is deliberately not a core.after chain: it re-fetches the player
-- by name every tick (an ObjectRef does not survive a disconnect), it drives
-- a swing whose interval CHANGES underneath it (weapon swap), and it has
-- to be stoppable from six different places. Two tables — who is swinging and
-- when the next swing is due — are all of that.
--

repeating = {} -- player name -> ability def of the running loop (forward-declared above)
local repeat_due = {} -- player name -> us time the last armed swing was DUE at

-- How much of a LATE swing the loop may reclaim, in seconds.
--
-- The loop can only swing on a globalstep boundary, so a swing due at t lands
-- at the first step at or after t. Arming the next one from `now` throws that
-- overshoot away and makes the real cadence ceil(fpi / step) * step — which
-- re-tunes every weapon UPWARD, and each by a different amount: at the engine's
-- shipped dedicated_server_step of 0.09 s
-- (reference_projects/luanti/src/defaultsettings.cpp:498) a 1.0 s sword would
-- swing at 1.08 (−7.4 % DPS) while a 0.7 s dagger swings at 0.72 (−2.8 %). That
-- is a non-uniform re-tune of the very numbers combat_stats.md §2 balances
-- against. Arming the next swing from the previous DUE time instead CARRIES the
-- remainder, so the mean cadence is the weapon's interval exactly, at any step
-- size.
--
-- The clamp is what bounds how much LATENESS one swing may reclaim. There is
-- no shared melee clock any more (WP38, combat_stats.md §2 — the cadence gate
-- and the per-player swing clock are deleted), so nothing outside this loop
-- constrains the value; what it reconciles now is only the loop against
-- itself: a swing that lands late (a busy server step, a lag spike) forgives
-- up to SWING_CATCHUP of its lateness — and never more than half the
-- interval, so a badly delayed swing cannot cascade into several swings
-- firing back to back. An absurdly fast weapon is clamped into a
-- non-positive duration by the half-interval rule alone (which would store
-- no record at all and fire once per step — the very failure the cooldown
-- guard below guards).
local SWING_CATCHUP = 0.1

-- Starts (or restarts) the loop for `def` after a click's swing, with `fpi`
-- the interval that swing earned: the click's immediate swing already
-- happened, so the next loop swing is one interval out. Public, so it
-- validates: without this an unregistered def would throw from inside
-- run_repeat_tick.
--
-- The validation LOGS AND REFUSES rather than asserting (review LOW C). A
-- LuaError raised from a mod callback does not stay local to that callback: it
-- propagates out of Server::AsyncRunStep, and the ServerThread catches
-- `LuaError` only to call `setAsyncFatalError`
-- (reference_projects/luanti/src/server.cpp:128-132 and :163-167), which shuts
-- the server down. For a guard whose whole point is that it should be
-- unreachable, killing everyone's session is the worst available outcome:
-- refusing to start a broken loop costs one player one ability.
function grug_abilities.start_repeat(player, def, fpi)
	if type(def) ~= "table" or grug_abilities.registered[def.id] ~= def then
		core.log("error", "[grug_abilities] start_repeat called with something" ..
			" that is not a registered ability definition -- no loop started")
		return
	end
	if def.kind ~= "swing" then
		core.log("error", "[grug_abilities] ability \"" .. tostring(def.id) ..
			"\" is not a swing ability -- no loop started")
		return
	end
	local name = player:get_player_name()
	-- Toggle identity only — the swing itself comes from melee_swing, which
	-- reads the SELECTED skill live every swing (classes.md §2b).
	repeating[name] = def
	repeat_due[name] = core.get_us_time() + fpi * 1e6
end

-- Stops a running loop. With `def`, only that ability's loop is stopped (a
-- Fireball must not switch the auto-attack off). Returns true when something
-- was actually running — that is what makes the "second cast" stop condition
-- a single test at the top of try_cast.
function grug_abilities.stop_repeat(player, def)
	local name = player:get_player_name()
	local running = repeating[name]
	if not running or (def and running ~= def) then
		return false
	end
	repeating[name] = nil
	repeat_due[name] = nil
	return true
end

function grug_abilities.is_repeating(player, def)
	local running = repeating[player:get_player_name()]
	return running ~= nil and (def == nil or running == def)
end

-- Arms the next swing of the loop, carrying the remainder of the current
-- one (see SWING_CATCHUP). `cooldown` is the interval the swing earned; what
-- is actually armed is that minus however late this swing was, capped. It
-- writes ONLY repeat_due — the loop no longer touches the cooldown table at
-- all (WP38): swing skills display their CHARGE (T6), cast skills their
-- cooldown, and the loop's cadence is repeat_due alone.
local function arm_repeat(player, cooldown)
	local name = player:get_player_name()
	local now = core.get_us_time()
	local due = repeat_due[name]
	local late = due and (now - due) / 1e6 or 0
	-- Never more than half the interval, so an absurdly fast weapon cannot be
	-- clamped into a non-positive duration (which would store no record at all
	-- and fire once per step — the very failure the assert below guards).
	local budget = math.min(SWING_CATCHUP, cooldown * 0.5)
	if late < 0 then
		late = 0
	elseif late > budget then
		late = budget
	end
	local duration = cooldown - late
	repeat_due[name] = now + duration * 1e6
end

-- One pass over the running loops, once per globalstep.
--
-- `grug_abilities.melee_swing(player, nil)` answers one of two things:
--   * a POSITIVE number — it swung; that is the interval the swing earned,
--   * `nil` plus an optional message — STOP, which is where target dead / out
--     of range / out of LOS arrive, since melee_swing re-validates every
--     swing.
-- The former `false` answer ("declined, the shared swing clock is held") is
-- gone with WP38 — the clock was deleted, the Strike now always swings when
-- it has a target (kits.lua).
--
-- The loop is the generic melee auto-attack loop (classes.md §2b):
-- `repeating[name]`'s def is the toggle identity ONLY — what actually swings
-- is the live selected skill, read by melee_swing every pass.
--
-- The pass deliberately has NO accumulator of its own. One at 0.1 s used to
-- coarsen the swing grid from `dtime` to ceil(0.1 / dtime) * dtime — 0.18 s at
-- the shipped server step, i.e. twice the error SWING_CATCHUP is able to
-- reclaim — and it saved nothing: with nobody attacking, `repeating` is empty
-- and this is one `next()` on an empty table.
local function run_repeat_tick()
	for name, def in pairs(repeating) do
		local player = core.get_player_by_name(name)
		if not player or player:get_hp() <= 0 then
			-- Disconnect and death. Both have their own hooks below; this is
			-- the backstop that guarantees no loop can ever run against a
			-- stale player name, whatever a future caller forgets.
			repeating[name] = nil
			repeat_due[name] = nil
		elseif core.get_us_time() >= (repeat_due[name] or 0) then
			local fpi, stop_msg = grug_abilities.melee_swing(player, nil)
			if fpi == nil then
				-- STOP. Tested for explicitly and BEFORE the guard below, which
				-- would otherwise swallow it: `nil` is not a positive number
				-- either, and an ordinary "the target died" would have been
				-- reported as a broken ability.
				repeating[name] = nil
				repeat_due[name] = nil
				if stop_msg then
					grug_abilities.flash(player, stop_msg)
				end
			elseif type(fpi) ~= "number" or fpi <= 0 then
				-- A swing whose interval comes back 0 (or anything but a
				-- positive number) stores no record at all, so the gate is
				-- instantly true again and the loop degenerates into one swing
				-- per globalstep. melee_swing cannot reach this — swing_stats
				-- clamps a non-positive full_punch_interval — so this is a
				-- guard for the NEXT swing source.
				--
				-- It logs and STOPS the loop instead of asserting (review
				-- LOW C). This runs inside a registered globalstep, and a
				-- LuaError from there reaches ServerThread's `catch (LuaError)`
				-- -> setAsyncFatalError -> server shutdown
				-- (reference_projects/luanti/src/server.cpp:128-132, :163-167)
				-- — and because the record in `repeating` would never be
				-- cleared, every following step would raise it again. Stopping
				-- the one loop leaves the other players' game running and puts
				-- the reason in the log. (The old assert also paid for its
				-- message on every PASSING call: Lua evaluates the second
				-- argument eagerly, so the concatenation ran once per swing per
				-- player. This branch builds it only when it fires.)
				core.log("error", "[grug_abilities] melee_swing of ability \"" ..
					tostring(def.id) .. "\" returned a non-positive interval (" ..
					tostring(fpi) .. ") -- loop stopped for player \"" ..
					name .. "\"")
				repeating[name] = nil
				repeat_due[name] = nil
			else
				arm_repeat(player, fpi)
			end
		end
	end
end

function grug_abilities.try_cast(user, def, pointed_thing)
	if user:get_hp() <= 0 then
		return
	end
	-- The "second cast" stop condition (E3), and it sits BEFORE every gate on
	-- purpose: the ability's own cooldown is running for most of the time its
	-- loop is, so an off switch behind that gate would only be reachable in
	-- the sliver between two swings — i.e. not at all.
	if grug_abilities.stop_repeat(user, def) then
		grug_abilities.flash(user, def.name .. " off.")
		return
	end
	-- Universal abilities have no class to be (E1) — without this a Mage
	-- clicking the auto-attack was told "You are no Warrior".
	if not def.universal and grug_classes.get_class(user) ~= def.class then
		grug_abilities.flash(user, "You are no " ..
			grug_classes.registered_classes[def.class].name .. ".")
		return
	end
	-- The swing/cast fork IS the toggle (classes.md §2b, WP38). The T3
	-- watcher never touches `repeating`, and melee_swing reads the SELECTED
	-- skill live every swing — so selecting another swing skill mid-fight
	-- re-arms the proc with zero interruption, and the first CLICK on it only
	-- updates the toggle identity (+ target refresh). Only a click on the
	-- swing skill the loop already counts as stops it: "second click on the
	-- same slot stops."
	if def.kind == "swing" then
		if grug_abilities.is_repeating(user) then
			-- Loop already running: re-arm ONLY (toggle identity + target
			-- refresh from the click), NO extra swing — click spam must not
			-- be a second damage stream (classes.md §2b).
			repeating[user:get_player_name()] = def
			grug_abilities.refresh_melee_target(user, pointed_thing)
			return
		end
		local fpi, err = grug_abilities.melee_swing(user, pointed_thing)
		if fpi == nil then
			grug_abilities.flash(user, err or "Invalid target.")
			return
		end
		grug_abilities.start_repeat(user, def, fpi)
		return
	end
	-- Cast skills: ready check, affordable check, cast, spend, arm the
	-- cooldown. No GCD anywhere (classes.md core principles, WP38).
	local name = user:get_player_name()
	cooldowns[name] = cooldowns[name] or {}
	if not grug_abilities.ready(user, def.id) then
		grug_abilities.flash(user, def.name .. " is not ready.")
		return
	end
	if not affordable(user, def.cost) then
		grug_abilities.flash(user,
			"Not enough " .. (def.cost.mana and "mana" or "rage") .. ".")
		return
	end
	-- A false return means "no valid cast" (e.g. no target): no cost, no
	-- cooldown. def is passed through for the target-lock helpers
	-- (range checks). The cast succeeded, so it arms the one cooldown it
	-- earned; a swing skill's charge reset is the proc's job in kits.lua.
	local ok, err = def.cast(user, pointed_thing, def)
	if not ok then
		grug_abilities.flash(user, err or "Invalid target.")
		return
	end
	spend(user, def.cost)
	grug_abilities.arm_cooldown(user, def, def.cooldown)
end

--
-- Ability item skins (weapon-slot design C1-C4). Every ability item wears the
-- item that sits in its slot: a Warrior with a sword equipped holds HIS sword
-- no matter which ability is selected, and swapping the weapon swaps all four
-- icons at once. The mechanism is the per-stack meta override of A1
-- (lua_api.md:2929-2949, src/inventory.cpp:258-295) -- no new item
-- registrations, no new asset, no engine patch.
--
-- C3 (a), the orb backdrop: the hotbar icon is the tinted orb DIMMED, with the
-- weapon art composited on top, so the colour the eye already learned stays a
-- large area. The wield (in-hand) image is the weapon art ALONE -- a glowing
-- disc extruded into a slab in the player's hand is exactly the "round thing"
-- this work removes.
--
-- C2, empty slot: the meta keys are simply NOT written, so the item definition's
-- own tinted orb shows through and a character without a weapon looks exactly
-- like the game did before this. An empty slot makes skills weak, never
-- uncastable.
--

local ORB_TEXTURE = "grug_abilities_orb.png"
-- Alpha of the backdrop, 0..255. Dimmed so the weapon on top stays the thing
-- you read first; the hue still carries the ability identity.
local ORB_BACKDROP_ALPHA = 150

-- The skin token: what a stack has to say about itself so a sync can decide, in
-- ONE string compare, that it is already correct. Load-bearing, not polish --
-- every inventory write re-sends the whole list to the client, which is why the
-- cooldown-wear path above is so stingy (D2/2). Without it, dragging any item
-- would rewrite four stacks.
--
-- Shape: "<version>|<colour>|<inventory source>|<wield source>", or the empty
-- string for "no skin" (which is also what an untouched stack answers, so a
-- weaponless character never writes anything).
--
-- EVERY input of the composition below is in the token, and that is the whole
-- rule: the source images rather than just the item NAME (a per-stack image
-- override on the weapon -- a WP5 affix -- must not read as unchanged), and
-- def.color, because it lives in kits.lua, i.e. in a different file from the
-- SKIN_VERSION a colour edit would otherwise have to remember to bump. Without
-- it, changing an ability's colour left every already-granted stack tinted the
-- old way until the player next swapped weapons -- indefinitely, for a
-- character that keeps one sword.
--
-- SKIN_VERSION stays for what the token cannot see: a change to the
-- composition ITSELF (the modifier chain, the backdrop alpha, the orb
-- texture). Bump it there, or an already-granted stack keeps the old look
-- forever.
local SKIN_VERSION = 2
local SKIN_TOKEN_KEY = "grug_skin"

-- The equipment list behind each ability slot. This is grug_inventory's
-- vocabulary, but grug_abilities deliberately does not depend on that mod --
-- the seam is grug_core's, and `listname` arrives as a plain string. The names
-- are audited against the real slot table at mods_loaded below, because a
-- silent mismatch here would look exactly like "the skin never updates".
local SLOT_OF_LIST = {grug_weapon = "weapon", grug_offhand = "offhand"}

-- The equipment lists that provably CANNOT change an ability skin. Named one by
-- one on purpose: "not a hand list" and "not a list I have heard of" are
-- different statements, and only the first one may skip the pass (see the
-- equipment-change hook below).
local SKIN_IRRELEVANT_LIST = {
	grug_head = true,
	grug_chest = true,
	grug_legs = true,
	grug_feet = true,
	grug_trinket1 = true,
	grug_trinket2 = true,
}

-- Lists sync_kit must never WRITE: an equipment list belongs to
-- grug_inventory's cache-drop/notify contract (equipment.lua:56-78), and a bare
-- inv:set_stack there would leave the weapon cache reporting an item that is
-- gone. Seeded from the two tables above and completed from the real slot table
-- at mods_loaded, so a slot added by a later WP is covered without an edit
-- here.
local equipment_list = {}
for list in pairs(SLOT_OF_LIST) do
	equipment_list[list] = true
end
for list in pairs(SKIN_IRRELEVANT_LIST) do
	equipment_list[list] = true
end

-- `inventory_image`/`wield_image` in a DEFINITION may be an item image
-- definition table rather than a string (lua_api.md:10388-10392); the meta
-- override is always a plain name.
local function def_image(img)
	if type(img) == "table" then
		return img.name or ""
	end
	return img or ""
end

-- The two source images of what is in one hand slot: the one the hotbar icon is
-- composed from and the one that goes into the player's hand. Both "" when
-- there is nothing to wear (an empty slot, or an item with no inventory image
-- -- a node item). Mirrors the engine's own resolution order: stack meta wins
-- over the definition (src/inventory.cpp:258-295).
--
-- The wield source is asked for SEPARATELY rather than reusing the inventory
-- image: an item may define its own `wield_image`, and the engine prefers it
-- over everything else for the extruded in-hand mesh
-- (src/client/wieldmesh.cpp:454-493). No shipped weapon defines one today --
-- taking the inventory image is correct for every one of them -- but the day
-- one does, the ability item would have shown the wrong art in hand.
local function slot_sources(player, slot)
	local stack
	if slot == "offhand" then
		stack = grug_core.get_equipped_offhand(player)
	else
		stack = grug_core.get_equipped_weapon(player)
	end
	if not stack or stack:is_empty() then
		return "", ""
	end
	local def = core.registered_items[stack:get_name()]
	local meta = stack:get_meta()
	local inv_src = meta:get_string("inventory_image")
	if inv_src == "" then
		inv_src = def_image(def and def.inventory_image)
	end
	if inv_src == "" then
		-- Nothing to wear: an item the inventory itself cannot draw has no art
		-- for us to borrow either, so the ability keeps its orb (C2).
		return "", ""
	end
	local wield_src = meta:get_string("wield_image")
	if wield_src == "" then
		wield_src = def_image(def and def.wield_image)
	end
	if wield_src == "" then
		wield_src = inv_src
	end
	return inv_src, wield_src
end

-- THE one place a texture-modifier string is composed (D2/5). These strings are
-- parsed CLIENT-side: a malformed one yields a generateImagePart error and an
-- untextured icon, not a server error, so there is exactly one site to get
-- right and no second one to drift from it.
--
-- Returns inventory_image, wield_image -- or nil, nil when there is nothing to
-- wear, which is the caller's signal to remove the overrides (C2).
--
-- Escaping: `src` is wrapped in `^( ... )` rather than backslash-escaped.
-- generateImage splits on top-level `^` only, tracking parentheses
-- (src/client/imagesource.cpp:1819-1847), so a source image that carries its
-- own modifier -- every grug_gear weapon does, they are tinted per bracket --
-- composes correctly as a group. Backslash escaping (lua_api.md:698-708) is
-- required only by modifiers that take a texture NAME as an argument
-- ([combine, [mask, [lowpart); we use none of those.

-- Would this source survive that splitter? Three inputs do not, and the source
-- is NOT ours: it is a per-stack override, i.e. exactly the key WP5's affix
-- roller is planned to write. Verified against the engine
-- (src/client/imagesource.cpp:1819-1866, the backwards scan):
--   * an unbalanced "(" -> the scan reaches a "(" at balance 0 and returns NULL
--     ("extranous '('"),
--   * an unbalanced ")" -> the scan ends with balance > 0 and returns NULL
--     ("missing matching '('"),
--   * a source ending in "\" -> the scan skips any character whose predecessor
--     is a backslash, so it never sees the ")" we appended, and falls into the
--     first case.
-- All three yield an untextured icon and a client-side error with NOTHING in
-- the server log, so the check is what makes the failure diagnosable at all.
local function composable(src)
	local bal = 0
	for i = #src, 1, -1 do
		-- The splitter's escape rule, verbatim. (i > 1: the character before
		-- src[1] is our own "(", never a backslash.)
		if not (i > 1 and src:sub(i - 1, i - 1) == "\\") then
			local c = src:sub(i, i)
			if c == ")" then
				bal = bal + 1
			elseif c == "(" then
				if bal == 0 then
					return false
				end
				bal = bal - 1
			end
		end
	end
	return bal == 0 and src:sub(-1) ~= "\\"
end

-- One log line per distinct bad source per server run: the token compare would
-- already keep it rare, but a WP5 re-roll loop must not be able to fill the
-- log. Bounded by the number of distinct broken strings, not by time.
local warned_source = {}

local function reject_source(src, which)
	if not warned_source[src] then
		warned_source[src] = true
		core.log("error", "[grug_abilities] equipped item's " .. which ..
			" image cannot be composed into an ability skin: \"" .. src ..
			"\" (unbalanced parentheses, or a trailing backslash that would" ..
			" escape the closing one). The ability items keep their orb icon.")
	end
	return nil, nil
end

local function skin_images(color, src)
	if src.inv == "" then
		return nil, nil
	end
	-- Refuse the WHOLE skin when either source is bad, not just the broken half:
	-- the orb is a complete, correct look (C2), a sword icon over an untextured
	-- hand is not. The wield source is emitted UNWRAPPED and therefore only
	-- needs the two balance rules -- it gets the trailing-backslash rule too,
	-- because one predicate slightly too strict beats two that can drift.
	if not composable(src.inv) then
		return reject_source(src.inv, "inventory")
	end
	if not composable(src.wield) then
		return reject_source(src.wield, "wield")
	end
	return ORB_TEXTURE .. "^[multiply:" .. color ..
		"^[opacity:" .. ORB_BACKDROP_ALPHA .. "^(" .. src.inv .. ")", src.wield
end

local function skin_token(color, src)
	if src.inv == "" then
		return ""
	end
	return SKIN_VERSION .. "|" .. color .. "|" .. src.inv .. "|" .. src.wield
end

-- Skin one ability stack IN PLACE; returns true only when something actually
-- changed, i.e. only when the caller has to spend an inventory write.
--
-- Touches nothing but the three meta keys: the wear bar is the cooldown display
-- and stays whatever it was, and so does the elf `range` override.
local function apply_skin(stack, def, src)
	local meta = stack:get_meta()
	local token = skin_token(def.color, src)
	if meta:get_string(SKIN_TOKEN_KEY) == token then
		return false
	end
	local inv_img, wield_img = skin_images(def.color, src)
	-- Writing "" REMOVES the key (same as the `range` override below), which is
	-- how the empty slot gets back to the definition's own orb.
	meta:set_string("inventory_image", inv_img or "")
	meta:set_string("wield_image", wield_img or "")
	meta:set_string(SKIN_TOKEN_KEY, token)
	return true
end

-- Resolve each hand at most once per pass, and only when a stack actually asks
-- for it. The entry is the {inv, wield} source pair, so one hand is read once
-- even though two images come out of it.
local function skin_source_cache(player)
	local cache = {}
	return function(def)
		local src = cache[def.slot]
		if not src then
			local inv_src, wield_src = slot_sources(player, def.slot)
			src = {inv = inv_src, wield = wield_src}
			cache[def.slot] = src
		end
		return src
	end
end

-- Rewrite the skins of the granted ability items. `slot` limits the pass to one
-- hand; nil means both. Ability items live in "main" only (the allow callback
-- above enforces it), so this is one list, and it writes only the stacks whose
-- token is stale.
local function sync_skins(player, slot)
	local inv = player:get_inventory()
	local list = inv and inv:get_list("main")
	if not list then
		return
	end
	local source_of = skin_source_cache(player)
	for i = 1, #list do
		local stack = list[i]
		local def = item_defs[stack:get_name()]
		if def and (slot == nil or def.slot == slot) then
			if apply_skin(stack, def, source_of(def)) then
				inv:set_stack("main", i, stack)
			end
		end
	end
end

-- C4's third trigger (join and class pick are sync_kit's). Consumers of this
-- hook must be idempotent and cheap and may be called twice for one change --
-- both are the token compare's job.
--
-- `listname` is the one equipment list that changed, or nil for "assume
-- everything".
--
-- Three cases, and the third one is the reason this is not one lookup: a HAND
-- list syncs that hand only; a list that provably cannot change a skin (armor,
-- trinkets -- SKIN_IRRELEVANT_LIST) returns before touching the inventory at
-- all; and ANY other name -- nil, a renamed list, a slot a later WP added --
-- falls through to the full pass. Being slow is recoverable, being silently
-- wrong is not: a skip on an unknown name is 0 writes, i.e. the skins stop
-- following the weapon with nothing but one load-time log line to say so.
-- The full pass costs one walk of `main` with a token compare per ability
-- stack, and writes only what actually changed.
grug_core.register_on_equipment_change(function(player, listname)
	if listname and SKIN_IRRELEVANT_LIST[listname] then
		return
	end
	-- nil (or an unrecognised name) -> nil -> both hands.
	sync_skins(player, listname and SLOT_OF_LIST[listname])
end)

-- The list names above are a string contract with a mod we do not depend on.
-- The hook is written so that getting them wrong costs speed rather than
-- correctness, but a stale name still means every equip pays for a full pass --
-- so read the real slot table once, after every mod has registered its slots,
-- and say so. This pass also completes `equipment_list`, i.e. the set sync_kit
-- refuses to write.
core.register_on_mods_loaded(function()
	if not core.global_exists("grug_inventory")
			or not grug_inventory.equipment_slots then
		return
	end
	local seen = {}
	for _, entry in ipairs(grug_inventory.equipment_slots) do
		equipment_list[entry.list] = true
		if SLOT_OF_LIST[entry.list] then
			seen[SLOT_OF_LIST[entry.list]] = true
		elseif not SKIN_IRRELEVANT_LIST[entry.list] then
			core.log("warning", "[grug_abilities] equipment list \"" ..
				entry.list .. "\" is in neither skin table -- correct, but every" ..
				" change to it now costs a full skin pass. Add it to" ..
				" SLOT_OF_LIST if it is a hand slot, to SKIN_IRRELEVANT_LIST" ..
				" if it cannot change an ability skin.")
		end
	end
	for list, slot in pairs(SLOT_OF_LIST) do
		if not seen[slot] then
			core.log("error", "[grug_abilities] no equipment slot uses list \"" ..
				list .. "\" -- ability skins now follow the " .. slot ..
				" slot only via the full pass on every equipment change")
		end
	end
end)

--
-- Kit granting: exactly one item per class ability, foreign class items are
-- purged, wear resets with the (runtime) cooldowns. Runs on join and on
-- class pick/switch. Talent-gated abilities (def.talent_gated, e.g. Renew)
-- stay registered but are NOT part of the base kit — WP11's talent system
-- will grant them. The elf range passive lands here as a per-stack meta
-- `range` override (engine 5.9+: overrides the pointing range), so
-- pointed_thing reaches as far as grug_abilities.get_range allows.
--

-- Does this ability belong in THIS character's kit? One predicate, used by both
-- the purge below and the grant loop, so the two can never disagree about what
-- a kit is. The universal auto-attack is granted to every class and must be
-- exempt from the purge (or it is granted and destroyed in the same pass).
local function in_kit(def, class)
	return def.universal or def.class == class
end

-- Every ability this character gets, in hotbar order: universal first (E1 —
-- the auto-attack lands on key 1 for everyone), then the class kit. Talent-
-- gated abilities are left out entirely, so a def's position in this list IS
-- its hotbar slot (Renew must not push Power Word: Shield off key 4).
local function kit_of(class)
	local kit = {}
	for _, def in ipairs(grug_abilities.universal) do
		if not def.talent_gated then
			kit[#kit + 1] = def
		end
	end
	for _, def in ipairs(grug_abilities.by_class[class] or {}) do
		if not def.talent_gated then
			kit[#kit + 1] = def
		end
	end
	return kit
end

-- Put a freshly granted ability item at its kit position instead of wherever
-- there happens to be room.
--
-- `inv:add_item("main", stack)` takes the first FREE slot, so E1's "first in
-- the hotbar, key 1 for everyone" only ever held for a character created after
-- the ability existed: every already-playing Warrior had keys 1-4 filled with
-- the class kit granted in an earlier session and got the universal Strike
-- behind it. That is not a migration case that fades — it is the state of every
-- live character on the day this ships.
--
-- Only NEWLY granted items are placed. Rearranging the whole kit on every join
-- would undo the hotbar order a player chose for themselves (ability items are
-- locked to `main`, but they can be moved around inside it).
local function grant_at(inv, stack, index)
	local size = inv:get_size("main")
	if index < 1 or index > size then
		inv:add_item("main", stack)
		return
	end
	local occupant = inv:get_stack("main", index)
	if occupant:is_empty() then
		inv:set_stack("main", index, stack)
		return
	end
	-- The slot is taken — by the player's own item, or by an ability granted
	-- before this one existed. Move it aside rather than destroying it.
	local free
	for i = 1, size do
		if inv:get_stack("main", i):is_empty() then
			free = i
			break
		end
	end
	if not free then
		inv:add_item("main", stack) -- pack full: exactly as before, i.e. lost
		return
	end
	inv:set_stack("main", free, occupant)
	inv:set_stack("main", index, stack)
end

local function sync_kit(player)
	local class = grug_classes.get_class(player)
	local name = player:get_player_name()
	-- Join, class pick and class SWITCH all land here, and a class switch can
	-- happen mid-fight: whatever was auto-attacking a moment ago has just had
	-- its cooldowns and charges wiped and its items re-granted, so the loop
	-- stops with them (E3 — no loop may survive a purge/re-grant pass).
	-- Wiping the charges makes the new kit start fully charged: no record
	-- IS the charged state (see the charge timers section).
	grug_abilities.stop_repeat(player)
	cooldowns[name] = {}
	charges[name] = {}
	wear_steps[name] = {}
	slot_cache[name] = {}
	local source_of = skin_source_cache(player)
	local inv = player:get_inventory()
	local have = {}
	for listname, list in pairs(inv:get_lists()) do
		-- Equipment lists are skipped ENTIRELY, purge included: writing one
		-- bypasses grug_inventory's cache-drop/notify contract
		-- (equipment.lua:56-78), which is the one rule T5 asks of every writer,
		-- and this loop is the only writer in the game that could break it. No
		-- ability item can reach such a list either -- the equip gate refuses
		-- anything without the slot's group and the allow callback above refuses
		-- moving an ability item out of "main" -- so nothing is lost by not
		-- looking. Closing it by NOT writing rather than by announcing the write
		-- is what keeps grug_abilities free of a dependency on grug_inventory.
		if not equipment_list[listname] then
			for i, stack in ipairs(list) do
				local def = item_defs[stack:get_name()]
				if def then
					-- Only granted items in "main" count as present:
					-- foreign-class items, talent-gated items (not granted
					-- yet), duplicates and strays in other lists (bags from
					-- old saves) are removed; own-class strays re-granted
					-- into main below.
					if not in_kit(def, class) or def.talent_gated or
							listname ~= "main" or have[stack:get_name()] then
						inv:set_stack(listname, i, ItemStack(""))
					else
						have[stack:get_name()] = true
						local changed = false
						if stack:get_wear() ~= 0 then
							stack:set_wear(0)
							changed = true
						end
						local meta = stack:get_meta()
						-- The override exists only while the EFFECTIVE range
						-- differs from the item definition's own. E7's melee
						-- opt-out lives inside get_range, so the reach the
						-- engine allows and the reach the lock fallback checks
						-- cannot drift apart.
						local base = def.range or 4
						local effective = grug_abilities.get_range(player, def)
						local desired = effective > base and effective or 0
						if meta:get_float("range") ~= desired then
							if desired > 0 then
								meta:set_float("range", desired)
							else
								meta:set_string("range", "") -- remove override
							end
							changed = true
						end
						-- The skin, same discipline as the range override
						-- above: compare first, write once, or not at all.
						if apply_skin(stack, def, source_of(def)) then
							changed = true
						end
						if changed then
							inv:set_stack(listname, i, stack)
						end
					end
				end
			end
		end
	end
	for index, def in ipairs(kit_of(class)) do
		local itemname = "grug_abilities:" .. def.id
		if not have[itemname] then
			local stack = ItemStack(itemname)
			local effective = grug_abilities.get_range(player, def)
			if effective > (def.range or 4) then
				stack:get_meta():set_float("range", effective)
			end
			-- Skin it BEFORE it reaches the inventory: a freshly granted item
			-- must not spend one write appearing as an orb and a second one
			-- turning into the weapon.
			apply_skin(stack, def, source_of(def))
			grant_at(inv, stack, index)
		end
	end
end

grug_classes.register_on_class_chosen(function(player, class_id)
	sync_kit(player)
	refill_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

--
-- Rage generation (classes.md §1, WP38): +12 × clamp(tflp/fpi, 0, 1) per
-- HELD-BUTTON melee punch, granted only when hit points actually came off
-- the mob (never for the punch EVENT: while the dig key is held the
-- callback fires once per punch packet, ≈5/s, so per-event rage would be
-- 60/s — the exact defect combat_stats.md §2's "rage on damage that
-- landed" rule exists to prevent), +4 per hit taken (+1 with the orc
-- passive, world.md §7). Charge's +15 lives in the ability itself. Punches
-- also refresh the soft target lock ("last punched enemy or ally"). Rage is
-- fractional-capable already: the `rage` table holds doubles and the HUD
-- floors.
--
-- "HP sank" is tested against the remainder accumulator's APPLIED integer:
-- on the accumulator path the health subtraction right after this hook
-- removes exactly `applied`, so `applied >= 1` and "hit points came off"
-- are the same statement; on the non-accumulator path (immune_to, which
-- SETS damage rather than scaling it) the subtraction removes floor(damage),
-- so floor(damage) >= 1 — floors absolutely. Nothing else reaches the
-- hook with a landed hit: a vendor NPC never reaches this wrapper at all
-- (plain mobs:register_mob, no grug wrapper), an evading mob cancels the
-- punch before it.
--
-- SINCE THE AUTO-ATTACK IS AN ABILITY (E1) the hooks below no longer see
-- the swing that classes.md §1 actually means: an ability punch sets
-- in_ability_punch and is skipped here by design (rage must not come from
-- Fireball). The Strike therefore grants its own FLAT +12 per LANDED loop
-- swing, in kits.lua, next to the damage it granted it for — the loop
-- swings once per weapon interval at full damage, so there is no fraction
-- to multiply there. Without that the Warrior's whole resource economy
-- would have stopped the day auto-attack became a skill: Mighty Blow costs
-- 25 rage and Hamstring 10, and the only remaining income would have been
-- +4 per hit TAKEN.
--

grug_core.register_on_player_hit_mob(function(player, mob_ent, damage, applied, fraction)
	if mob_ent.object and (mob_ent.health or 0) > 0 then
		grug_abilities.set_target(player, mob_ent.object, false)
	end
	if grug_core.in_ability_punch then
		return
	end
	local landed = (applied ~= nil and applied >= 1)
		or (applied == nil and math.floor(damage or 0) >= 1)
	if landed then
		grug_abilities.add_rage(player, 12 * (fraction or 1))
	end
end)

--
-- PvP melee (combat_stats.md §2, WP38 T4): the held-button path against
-- PLAYERS runs through the same pipeline as the mob path — proportional
-- partial-swing damage, the remainder accumulator, then the central
-- dodge → armor → absorb modifier, rage on damage that LANDED. The hook
-- this replaces granted +12 rage per punch EVENT: while the dig key is
-- held the callback fires once per punch packet (≈5/s, combat_stats.md
-- §2), so that was 60 rage/s against a hostile player — the exact
-- firehose the landed-damage rule of combat_stats.md §2 killed for mobs
-- on 2026-08-08 (see the rage section above).
--
-- MODE_OR composition (reference_projects/luanti/src/script/cpp_api/
-- s_player.cpp:63): ANY callback returning true marks the punch handled
-- and the engine's own damage is suppressed (player_sao.cpp:482-490).
-- Same-faction pairs are grug_factions' handler (its true suppresses
-- before ours could matter); hostile pairs are ours. Neither vetoes the
-- other — this one never returns true outside the hostile path.
--
-- Knockback is deliberately not fed our damage (MVP): builtin's own
-- on_punchplayer (builtin/game/knockback.lua:25-48) applies knockback
-- velocity to punched players off the ENGINE's `damage` argument — for a
-- handled punch that is the pre-pipeline hitparams.hp the callbacks
-- receive. Routing OUR damage into core.calculate_knockback is deferred.
--
-- enable_pvp = false means this callback never fires at all: PlayerSAO::punch
-- returns before the script callback when PvP is off (player_sao.cpp:463-470),
-- so nothing here can leak damage into a no-PvP world.
--
core.register_on_punchplayer(function(player, hitter, tflp, tool_capabilities, dir, damage)
	-- Guards first. Mob punches, self-hits and punches on corpses keep
	-- the engine path; ability punches on players run fully through
	-- grug_core.deal_ability_damage (which pre-rolls dodge and punches at
	-- full interval) — handling them here would double-apply.
	if not (hitter and hitter:is_player()) then
		return
	end
	if hitter == player or player:get_hp() <= 0 then
		return
	end
	if grug_core.in_ability_punch then
		return
	end
	if grug_factions.same_faction(hitter, player) then
		-- Ally heal targeting, kept from the old hook. The damage is
		-- grug_factions' concern: its own handler returns true and
		-- suppresses it (MODE_OR, s_player.cpp:63) — never return true
		-- here, or the same-faction punch would end up handled twice.
		grug_abilities.set_target(hitter, player, true)
		return
	end
	if not grug_factions.hostile(hitter, player) then
		-- Factionless/neutral pairs keep the engine's damage, exactly as
		-- before this WP: hostile() requires BOTH sides to have a faction
		-- (grug_factions/init.lua:87-91), so two factionless players are
		-- neutral, not hostile.
		return
	end

	-- Hostile pair from here on. Target lock and combat marking, kept
	-- from the old hook.
	grug_abilities.set_target(hitter, player, false)
	grug_core.mark_in_combat(hitter)

	-- Damage source is the WIELDED stack (combat_stats.md §2: the
	-- held-button path stays wielded-item damage — the weapon SLOT feeds
	-- only the ability swings; this path is the tools-and-fists one). The
	-- callback's tool_capabilities are normally present; when absent,
	-- get_tool_capabilities resolves an empty hand to the hand item's own
	-- caps (the engine always registers the "" item, inventory.cpp:344-346).
	local caps = tool_capabilities or
		hitter:get_wielded_item():get_tool_capabilities()
	local fleshy = caps.damage_groups and caps.damage_groups.fleshy or 0
	local fpi = caps.full_punch_interval
	if not (type(fpi) == "number" and fpi > 0) then
		fpi = 1.4
	end

	-- Mirror the mob path (the api.lua GRUG PATCH): partial-swing factor,
	-- Strength added BEFORE the factor so the factor scales the whole hit,
	-- unfloored crit (the accumulator floors at application time — a ×1.5
	-- on a 0.4 swing must ride the same remainder as the pre-crit
	-- fraction), then the accumulated integer applied.
	local fraction = math.max(0, math.min(1, (tflp or 0.2) / fpi))
	local raw = (fleshy + grug_core.get_melee_bonus(hitter)) * fraction
	raw = grug_core.melee_crit(hitter, raw, player)
	local applied = grug_core.apply_accumulated_melee(hitter, player, raw)
	if applied >= 1 then
		local hp_before = player:get_hp()
		-- set_hp with the punch reason routes through the central hp-change
		-- modifier ONCE (player_sao.cpp:519): the dodge roll happens here,
		-- not pre-rolled like deal_ability_damage does, then armor, then
		-- the absorb shield. A dodge zeroes the hit → `landed` stays false
		-- → no rage.
		player:set_hp(hp_before - applied, {type = "punch", object = hitter})
		local landed = player:get_hp() < hp_before
		if landed then
			-- Rage only on damage that actually landed, scaled by the same
			-- fraction that scaled the hit. At a held button (5 packets/s
			-- at fraction ≈ 0.2/fpi each) the influx integrates back to
			-- 12 rage per weapon interval instead of 60 per second — but
			-- in LUMPS of 12×fraction per landing packet, and only when
			-- that packet applied ≥ 1: a hit weaker than 5 damage at a
			-- 1.0 s interval lands every other packet and grants
			-- proportionally less. Rage follows the damage applied, not
			-- the weapon.
			grug_abilities.add_rage(hitter, 12 * fraction)
		end
	end
	-- The engine's own damage is suppressed on the hostile path ALWAYS —
	-- even when nothing landed (applied 0, absorbed, dodged): the
	-- pipeline is ours now.
	return true
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" then
		grug_abilities.add_rage(player, 4
			+ (grug_classes.get_race_perk(player, "rage_per_hit_taken_bonus") or 0))
	end
end, false)

--
-- Regen / decay / cooldown ticker (0.5 s): mana 2%/s out of combat,
-- 0.5%/s in combat; rage decays 2/s out of combat (combat_stats §5,
-- classes.md §1). Cooldown wear is updated here too — and, at a finer step
-- of its own, the auto-repeat swing pass (E3).
--

local acc = 0

core.register_globalstep(function(dtime)
	-- The swing pass FIRST, and before the 0.5 s gate returns: quantised to
	-- 0.5 s every weapon would become a 1.0 s weapon (0.7 s dagger included).
	--
	-- IT RUNS ON EVERY STEP, WITHOUT AN ACCUMULATOR — a deliberate, measured
	-- exception to AGENTS.md's performance rule "always throttle
	-- register_globalstep with a dtime accumulator", and to E3's own "with its
	-- own finer accumulator". Recorded here rather than left to be
	-- rediscovered (review LOW E). Two reasons, in this order:
	--   * an accumulator does not just cost precision, it takes it. Any period
	--     p coarsens the swing grid from `dtime` to ceil(p / dtime) * dtime;
	--     at p = 0.1 and the engine's shipped dedicated_server_step of 0.09
	--     (reference_projects/luanti/src/defaultsettings.cpp:498) that is
	--     0.18 s, twice the error SWING_CATCHUP is able to reclaim, so every
	--     weapon's cadence would be re-tuned and each by a different amount.
	--   * it would save nothing measurable. `repeating` is keyed by player and
	--     is EMPTY unless somebody is actually auto-attacking, so the idle
	--     cost of this call is one `next()` on an empty table — measured at
	--     0.0003 ms/step idle, and 0.093 ms/step with 100 players all
	--     attacking, against a 90 ms step budget.
	-- The rule stands for passes whose work does not scale down to nothing on
	-- an idle server; this one does, and it is the throttle that would cost.
	--
	-- The wield watcher also runs on every step, and for a correctness
	-- reason rather than a precision one: switching the hotbar to a pick is
	-- a COMBAT STOP CONDITION (classes.md §2b) and must bite within one
	-- step, not within the 0.5 s window the ticker below gates on — a
	-- throttled watcher would keep the player auto-attacking from the
	-- weapon slot for up to half a second after the hotbar changed. Its
	-- cost model: per step, one core.get_connected_players() list, and per
	-- connected player one get_wield_index() call plus an int compare —
	-- nothing allocated and no inventory read while nothing changed.
	-- `dirty` (set by any player inventory action) forces exactly one
	-- get_wielded_item() on the next step, which is also the read that
	-- sees a same-index content swap: an index is not the item. It is
	-- deliberately not folded into the 0.5 s body below, which already
	-- iterates the players — throttling is the point.
	run_repeat_tick()
	watch_wield()
	acc = acc + dtime
	if acc < 0.5 then
		return
	end
	local elapsed = acc
	acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local res = resource_of(player)
		if res == "mana" then
			local max = grug_classes.get_max_mana(player)
			local cur = math.min(mana[name] or 0, max)
			-- Troll passive (world.md §7): +50% out-of-combat regen. Today
			-- this multiplier only reaches mana (HP regen does not exist
			-- yet); WP21's HP regen must consume the same perk.
			local rate
			if grug_core.in_combat(player) then
				rate = 0.005
			else
				rate = 0.02
					* (grug_classes.get_race_perk(player, "ooc_regen_mult") or 1)
			end
			local new = math.min(max, cur + max * rate * elapsed)
			if math.floor(new) ~= math.floor(mana[name] or 0) then
				mana[name] = new
				hud_update(player)
			else
				mana[name] = new
			end
		elseif res == "rage" and not grug_core.in_combat(player) then
			local cur = rage[name] or 0
			if cur > 0 then
				local new = math.max(0, cur - 2 * elapsed)
				rage[name] = new
				if math.floor(new) ~= math.floor(cur) then
					hud_update(player)
				end
			end
		end
		-- cooldown wear display (write only when the visible step changes)
		local cds = cooldowns[name]
		if cds then
			local now = core.get_us_time()
			local steps = wear_steps[name] or {}
			wear_steps[name] = steps
			for id, rec in pairs(cds) do
				local remaining = (rec.expiry - now) / 1e6
				-- Every remaining cooldown user is a cast skill and displays
				-- its wear bar. A wear write costs a full inventory re-send,
				-- which is why the step quantization above exists.
				if remaining <= 0 then
					cds[id] = nil
					steps[id] = nil
					set_item_wear(player, id, 0)
				else
					-- The duration of THIS cast (stored in the record), not
					-- def.cooldown.
					local frac = remaining / rec.duration
					local step = math.max(1,
						math.min(WEAR_STEPS, math.ceil(frac * WEAR_STEPS)))
					if step ~= steps[id] then
						steps[id] = step
						set_item_wear(player, id,
							math.floor(step / WEAR_STEPS * 65534))
					end
				end
			end
		end
	end
end)

--
-- Player lifecycle
--

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	resource_huds[name] = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = -135},
		alignment = {x = 0, y = 0},
		number = 0xffffff,
		text = "",
	})
	flash_huds[name] = {token = 0, id = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.35},
		offset = {x = 0, y = 0},
		alignment = {x = 0, y = 0},
		number = 0xff4444,
		text = "",
	})}
	skillname_huds[name] = {token = 0, id = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = -70},
		alignment = {x = 0, y = 0},
		number = 0xffffff,
		text = "",
	})}
	rage[name] = 0
	refill_mana(player)
	sync_kit(player)
	-- Watcher baseline AFTER the kit sync, so the snapshot is the post-grant
	-- wielded slot. Recording is feedback-free by design: nothing changed,
	-- so no "Strike" popup on login.
	wield_watch[name] = {
		index = player:get_wield_index(),
		item = player:get_wielded_item():get_name(),
	}
	hud_update(player)
end)

-- Death and respawn are two of E3's stop conditions and are hooked
-- separately: dying stops the loop AT the death (the tick's own hp check is
-- the backstop, one globalstep later — it has no accumulator of its own, so
-- there is no 0.1 s window any more), and the respawn stops it a second time
-- because a respawn is also a re-grant path -- a loop that somehow outlived
-- the death must not be handed the fresh character.
core.register_on_dieplayer(function(player)
	grug_abilities.stop_repeat(player)
end)

core.register_on_respawnplayer(function(player)
	grug_abilities.stop_repeat(player)
	refill_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	-- A disconnect drops the loop with everything else: it is keyed by NAME,
	-- so a reconnect under the same name must not resume the old fight.
	grug_abilities.stop_repeat(player)
	mana[name] = nil
	rage[name] = nil
	repeat_due[name] = nil
	cooldowns[name] = nil
	charges[name] = nil
	targets[name] = nil
	wear_steps[name] = nil
	slot_cache[name] = nil
	resource_huds[name] = nil
	flash_huds[name] = nil
	skillname_huds[name] = nil
	wield_watch[name] = nil
	dirty[name] = nil
end)

-- Mana pool grows with Int on level up: clamp/refresh the HUD (no refill).
grug_xp.register_on_level_change(function(player, old_level, new_level)
	hud_update(player)
end)

dofile(core.get_modpath(core.get_current_modname()) .. "/kits.lua")
