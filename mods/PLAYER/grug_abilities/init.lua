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
local clear_swing_progress -- assigned after the swing-clock declaration
local reset_swing_boundary -- assigned after the swing-clock declaration
local swing_progress -- assigned after ability registration helpers
local attempt_swing -- assigned after the swing-clock declaration

local function refuse_mounted_attack(player)
	return grug_core.refuse_mounted_attack and
		grug_core.refuse_mounted_attack(player) == true
end
local swing_input_latch = {} -- player name -> one direct hostile object click

local mana = {} -- player name -> current mana (fractional)
local rage = {} -- player name -> current rage (fractional)
-- player name -> {ability id -> {expiry = us time, duration = seconds}}. The
-- duration is stored per cast, not looked up from the def, because the
-- cooldown overlay needs the value THIS cast used to draw a fraction of it.
local cooldowns = {}
-- Player name -> {ability id -> next accepted cast time in microseconds}.
-- This is a server-authoritative input cadence, not a visible cooldown: it
-- has no cooldown overlay and talents cannot shorten it.
local cast_intervals = {}
local targets = {} -- player name -> {enemy = rec, ally = rec}; rec = {obj, expiry}
local ready_reticle_huds = {} -- player name -> {id = hud id, visible = bool}
-- Skill-name line (classes.md §2c) and the throttled wield watcher that feeds
-- it (WP38 T3). The watcher keeps the last noticed wielded stack per player:
-- the index alone is not the item — a same-index content swap has to raise
-- `dirty` or it reads as "unchanged".
local skillname_huds = {} -- player name -> {id = hud id, token = n}
local wield_watch = {} -- player name -> {index = hotbar index, item = name}
local dirty = {} -- player name -> true (inventory action since last pass)

-- Presentation target memory: enemy and ally use separate
-- slots. Enemy memory is Target-Frame state only and is never hostile aim
-- authority; ally memory likewise supplies presentation only.
grug_abilities.TARGET_LOCK = 8

local function resource_of(player)
	local def = grug_classes.get_class_def(player)
	return def and def.resource or nil
end

--
-- Resource API
--

local hud_update -- forward

function grug_abilities.get_mana(player)
	return math.floor(mana[player:get_player_name()] or 0)
end

function grug_abilities.restore_mana(player, amount)
	local name = player:get_player_name()
	local maximum = math.max(0, grug_classes.get_max_mana(player))
	local current = mana[name] or 0
	local before = math.max(0, math.min(maximum, current))
	local after = math.min(maximum,
		before + math.max(0, tonumber(amount) or 0))
	mana[name] = after
	if after ~= current then
		hud_update(player)
	end
	return math.max(0, after - before)
end

function grug_abilities.get_rage(player)
	return math.floor(rage[player:get_player_name()] or 0)
end

--
-- The rage ledger (classes.md §3). Ruling 25 of 2026-09-16 answers the user's
-- "in combat the resource is effectively unlimited" finding with option (b) --
-- lower the income and add decay: a landed full swing grants 8 instead of 12,
-- a hit taken 3 instead of 4, and rage bleeds 5/s (it was 2/s) while
-- grug_core.in_combat is false. The numbers are named here because five swing
-- sites and one hit-taken site share them, and the talents Stoke and Spite add
-- to them (skill_trees.md §2.1/§2.2).
--
grug_abilities.RAGE_PER_SWING = 8
grug_abilities.RAGE_PER_HIT_TAKEN = 3
grug_abilities.RAGE_DECAY_PER_SECOND = 5

-- Rage for one landed full swing, Stoke included.
local function swing_rage(player)
	return grug_abilities.RAGE_PER_SWING
		+ grug_classes.get_talent_bonus(player, "rage_per_swing_add")
end
grug_abilities.swing_rage = swing_rage

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

-- Every callback that can change maximum mana goes through this one clamp.
-- It deliberately does not draw: callers clamp first and then issue exactly
-- one HUD update after all their other state changes are complete.
local function clamp_mana(player)
	local name = player:get_player_name()
	local maximum = math.max(0, grug_classes.get_max_mana(player))
	mana[name] = math.max(0, math.min(maximum, mana[name] or 0))
end

-- Absolute mana per second. Out of combat the deliberately linear curve keeps
-- food relevant at high level. In combat a maximum-mana floor prevents that
-- curve from falling too far behind the growing pool. Cold Focus raises the
-- in-combat rate by 0.4 of itself per rank (x3 at 5/5, Round 35).
function grug_abilities.mana_regen_rate(player, in_combat)
	local level = math.max(1, grug_core.get_player_level(player))
	local rate = 1 + 0.15 * level
	local trinket = grug_core.trinket_mana_regen and
		grug_core.trinket_mana_regen(player) or 0
	if in_combat then
		local bonus = grug_classes.get_talent_bonus(player,
			"combat_mana_regen_add")
		local combat_rate = math.max(rate * 0.25,
			grug_classes.get_max_mana(player) * 0.0025)
		return combat_rate * (1 + 2 * bonus) + trinket
	end
	return rate *
		(grug_classes.get_race_perk(player, "ooc_regen_mult") or 1) + trinket
end

function grug_abilities.mana_cost(player, percent)
	local base = grug_core.base_pool(grug_core.get_player_level(player))
	return math.max(1, math.floor(base * percent / 100 + 0.5))
end

function grug_abilities.cost_for(player, cost, ability_id)
	if cost.mana_percent then
		local percent = cost.mana_percent
		if ability_id == "fireball" and
				grug_classes.talent_window_active(player, "whitehot") then
			percent = 3
		elseif ability_id == "smite" and
				grug_classes.get_talent_bonus(player, "smite_absorb") > 0 then
			percent = 6
		end
		return {mana = grug_abilities.mana_cost(player, percent)}
	end
	return cost
end

-- Resolved cost = {mana = n} or {rage = n}; returns false if not affordable.
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
	local alive = true
	if rec.obj:is_player() then
		alive = rec.obj:get_hp() > 0
	else
		local ent = rec.obj:get_luaentity()
		alive = not ent or not ent._cmi_is_mob or (ent.health or 0) > 0
	end
	if core.get_us_time() > rec.expiry or not rec.obj:get_pos() or not alive then
		targets[name][slot] = nil
		return nil
	end
	return rec.obj
end

-- A live mob that may fight this user (faction and non-combatant rules), and
-- whether it is evading home after a leash reset (grug_mobs aggro.lua).
local function hostile_mob(user, ent)
	if not ent or not ent._cmi_is_mob or (ent.health or 0) <= 0 then
		return false
	end
	if grug_mobs.is_noncombatant(ent) then
		return false
	end
	return not (ent._grug_faction and
		ent._grug_faction == grug_factions.get_faction(user))
end

local function evading(ent)
	return ent.temp ~= nil and ent.temp.grug_evading ~= nil
end

-- One relation predicate for every ability target. `target_kind` describes
-- the button's acquisition authority, not every object an area effect may
-- later touch: Ice Nova is self-targeted even though its effect visits
-- nearby hostiles. Friendly targeting remains player-only by design; guards
-- and civic NPCs are not party members and cannot receive player heals.
-- Players are gated by the PvP flag (pvp-plan rulings 1, 5, 6): an enemy only
-- while both are flagged, an ally not when the ally is flagged and the user
-- is not. It is the ONE predicate of the crosshair, the LMB hold, swings and
-- casts (Round 36 §2.14.1), so the crosshair is red exactly when a press would
-- act: a mob evading home after a leash reset (grug_mobs aggro.lua) takes no
-- hit and is therefore no target (`evading_target` names that case).
function grug_abilities.valid_target(user, obj, target_kind)
	if target_kind == "self" then
		return obj == user and user:get_hp() > 0
	end
	if not obj or obj == user or not obj:get_pos() then
		return false
	end
	if target_kind == "friendly" then
		return obj:is_player() and obj:get_hp() > 0
			and grug_factions.same_faction(user, obj)
			and grug_pvp.can_support(user, obj)
	end
	if target_kind ~= "hostile" then
		return false
	end
	if obj:is_player() then
		return obj:get_hp() > 0 and grug_factions.hostile(user, obj)
			and grug_pvp.can_harm(user, obj)
	end
	local ent = obj:get_luaentity()
	return hostile_mob(user, ent) and not evading(ent)
end

-- A mob that would be a valid hostile for `user` but is evading home now: the
-- press at it answers "Evading" (grug_mobs.evade_notice) instead of silence.
function grug_abilities.evading_target(user, obj)
	if not obj or obj == user or not obj:get_pos() or obj:is_player() then
		return false
	end
	local ent = obj:get_luaentity()
	return hostile_mob(user, ent) and evading(ent)
end

local function invalidate_target_locks(obj)
	for _, slots in pairs(targets) do
		for _, slot in ipairs({"enemy", "ally"}) do
			if slots[slot] and slots[slot].obj == obj then
				slots[slot] = nil
			end
		end
	end
end

-- Effective server action range, including race/talent bonuses. Native skill
-- representations keep a separate four-node hand interaction/digging reach.
-- Melee explicitly opts out of the ranged race bonus.
function grug_abilities.get_range(player, def)
	local base = def.range or 4
	if def.range_talent then
		base = base + grug_classes.get_talent_bonus(player, def.range_talent)
	end
	if def.melee then
		return base
	end
	return base
		+ (grug_classes.get_race_perk(player, "ability_range_bonus") or 0)
end

--
-- HUD: the three thin bars directly above the hotbar (user ruling
-- 2026-09-16, docs/research/hud-bars.md) and a short-lived error flash top
-- center ("Not enough mana", "No target", ...).
--
-- Each bar is three elements: a dark track, a coloured foreground whose
-- `scale.x` IS its drawn width in pixels, and a centred label carrying the
-- exact numbers. The builtin heart and bubble statbars are switched off on
-- join, in the same commit that added these -- half hearts are the
-- approximation the ruling rejects, and a 325 HP Warrior
-- (`combat_stats.md` section 2) is 16.25 HP per half heart.
--
-- `hud_change` sends a packet whether the value changed or not
-- (`src/script/lua_api/l_object.cpp:2026` still carries the "FIXME: only
-- send when actually changed"), so EVERY write below is gated on the drawn
-- value and the drawn value is quantized to whole pixels by
-- `grug_core.hud_layout.bar_fill`.
--

-- player name -> {life = rec, secondary = rec, breath = rec}, where rec is
-- {track_id, fill_id, label_id} plus the last drawn track texture, fill
-- colour, fill width and label.
local bar_huds = {}

-- The secondary resource as a bar: value, maximum, colour. Nothing (a
-- character with no class yet) returns nil, which reserves the row without
-- drawing in it.
local function hud_state(player)
	local layout = grug_core.hud_layout
	local res = resource_of(player)
	if res == "mana" then
		return grug_abilities.get_mana(player),
			grug_classes.get_max_mana(player), layout.COLOR.mana
	elseif res == "rage" then
		return grug_abilities.get_rage(player), 100, layout.COLOR.rage
	end
	return nil, nil, nil
end

-- One bar. `maximum` nil or 0 blanks the row; the row keeps its space.
local function draw_bar(player, name, row, value, maximum, color)
	local recs = bar_huds[name]
	local rec = recs and recs[row]
	if not rec then
		return
	end
	local layout = grug_core.hud_layout
	local shown = type(maximum) == "number" and maximum > 0
	local track = layout.bar_texture(shown and layout.COLOR.track or nil)
	local width = shown and layout.bar_fill(value, maximum) or 0
	local label = shown and ("%d / %d"):format(value, maximum) or ""
	if rec.track ~= track then
		rec.track = track
		player:hud_change(rec.track_id, "text", track)
	end
	if shown and rec.color ~= color then
		rec.color = color
		player:hud_change(rec.fill_id, "text", layout.bar_texture(color))
	end
	if rec.width ~= width then
		rec.width = width
		player:hud_change(rec.fill_id, "scale",
			{x = width, y = layout.BAR_HEIGHT})
	end
	if rec.label ~= label then
		rec.label = label
		player:hud_change(rec.label_id, "text", label)
	end
end

-- player name -> the hit points the engine is ABOUT to store.
--
-- A non-modifier `register_on_player_hpchange` callback runs BEFORE the
-- engine stores the new value: `setHP` calls the loggers and only then
-- assigns `m_hp` (`src/server/player_sao.cpp:519-535`,
-- `builtin/game/register.lua:560`), so `get_hp()` inside such a callback --
-- and inside anything a LATER logger calls, the rage hook included -- is
-- still the OLD hit points. The prediction outlives the callback for that
-- reason and is dropped by the next shared pass, which reads the value the
-- engine really stored.
local predicted_hp = {}

-- `authoritative` is what the 0.5 s pass passes: the engine has stored
-- whatever it was going to store, so the prediction goes and the real hit
-- points are read.
hud_update = function(player, authoritative)
	local name = player:get_player_name()
	if not bar_huds[name] then
		return
	end
	if authoritative then
		predicted_hp[name] = nil
	end
	local layout = grug_core.hud_layout
	-- One properties read for both hp_max and breath_max.
	local props = player:get_properties()

	local max_hp = props.hp_max or 0
	local hp = predicted_hp[name] or player:get_hp()
	hp = math.max(0, math.min(max_hp, hp))
	draw_bar(player, name, "life", hp, max_hp, layout.COLOR.life)

	local value, maximum, color = hud_state(player)
	draw_bar(player, name, "secondary", value or 0, maximum, color)

	-- Breath is the one value with no change callback in the Lua API, so it
	-- rides the shared pass. Builtin's own rule for showing the bubbles is
	-- "breath is not full" (`builtin/game/hud.lua:208-210`); the bar uses
	-- the same one, which also covers the refill after surfacing.
	local max_breath = props.breath_max or 0
	local breath = player:get_breath()
	if max_breath > 0 and breath < max_breath then
		draw_bar(player, name, "breath", breath, max_breath,
			layout.COLOR.breath)
	else
		draw_bar(player, name, "breath", 0, nil, nil)
	end
end

-- Immediate life-bar feedback. Registered separately from the rage logger so
-- that the HUD and the resource rules stay independently editable.
core.register_on_player_hpchange(function(player, hp_change, reason)
	predicted_hp[player:get_player_name()] = player:get_hp() + hp_change
	hud_update(player)
end, false)

local function add_bar(player, row)
	local layout = grug_core.hud_layout
	return {
		-- Track, foreground, label: explicit z_index because elements that
		-- share one are drawn in an arbitrary order (lua_api.md "z_index").
		track_id = player:hud_add(layout.bar_element(row,
			layout.BAR_WIDTH, nil, 0)),
		fill_id = player:hud_add(layout.bar_element(row, 0, nil, 1)),
		label_id = player:hud_add(layout.text_element(row, {
			number = layout.COLOR.text,
			text = "",
			z_index = 2,
		})),
		track = "",
		color = nil,
		width = 0,
		label = "",
	}
end

-- The flash line itself lives in grug_core (flash.lua, shared with the
-- mining hints since Round 24); skill errors keep its red.
function grug_abilities.flash(player, msg)
	grug_core.flash(player, msg, grug_core.FLASH_COLOR.error)
end

--
-- Skill-name HUD and the wield watcher (WP38 T3, classes.md §2c). The
-- engine has no callback for a wield change, so the watcher polls it in the
-- shared 0.5 s HUD/resource pass. The name line
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

-- Shared short neutral notification. Skill changes and fishing catches use
-- the same row/token, so a previous timer cannot erase a newer message.
grug_abilities.notify = show_skill_name

-- Binary weapon-ready overlay (classes.md §2b). Lua HUD elements are drawn
-- after the builtin crosshair (src/client/render/plain.cpp:48-52); z_index 2
-- orders it above the crosshair state overlay (z 1) and below the bow draw
-- ring (z 3, both crosshair.lua), and above the conventional z_index-0
-- gameplay HUD. Only a changed boolean sends a HUD packet. This is never an
-- inventory bar.
local READY_RETICLE_TEXTURE = "grug_abilities_weapon_ready.png"

local function set_ready_reticle(player, visible)
	local rec = ready_reticle_huds[player:get_player_name()]
	if not rec or rec.visible == visible then
		return
	end
	rec.visible = visible
	player:hud_change(rec.id, "text", visible and READY_RETICLE_TEXTURE or "")
end

-- Any player inventory action (signature: player, action, inventory,
-- inventory_info) marks the wield slot possibly changed. Not filtered: the
-- filter would have to read the inventory to decide, and a spurious flag
-- costs exactly one item-name read on the next step — filtering would pay
-- the read once per action anyway, plus the branches to skip the rest.
core.register_on_player_inventory_action(function(player)
	dirty[player:get_player_name()] = true
end)

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
			elseif item_defs[item] then
				-- An ability item was selected: name it. Native LMB reads the
				-- selected swing skill live on each due server swing, so no combat state or
				-- inventory write belongs in this watcher.
				show_skill_name(player, item_defs[item].name)
			end
		end
		local entry = swing_progress and swing_progress[name]
		local selected
		if entry then
			selected = item_defs[player:get_wielded_item():get_name()]
		end
		if entry and not entry.inactive
				and (not selected or selected.kind ~= "swing") then
			-- Crossing out of the swing-item family is a real attack-clock boundary.
			reset_swing_boundary(player)
		end
	end
end

--
-- Context-first right-click interaction. Native pointable nodes retain their
-- callbacks and nodemeta forms. The fallback ray includes actors so it cannot
-- reach a door through an NPC; native object clicks remain engine-dispatched.
-- Interaction is limited to hand reach, independent of spell range, and owns
-- the current RMB press so it cannot also draw a bow or consume food.
-- Sneaking retains the ordinary node-placement bypass rule.
--
local NODE_INTERACT_RANGE = 4

-- Hand the click to the node's own `on_rightclick`, or answer nil when the node
-- has none (the caller then does nothing at all -- a right-click that hits a
-- plain wall is not an error and must not become one).
local function pass_to_node(pos, clicker, itemstack, pointed_thing)
	local node = pos and core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	if not def or not def.on_rightclick then
		return nil
	end
	if grug_abilities.input then
		local owner = grug_abilities.input.right_action(clicker)
		if owner and owner ~= "interaction" then return itemstack end
		grug_abilities.input.interaction(clicker)
	end
	return def.on_rightclick(pos, node, clicker, itemstack, pointed_thing) or
		itemstack
end

local function sneaking(player)
	local control = player.get_player_control and player:get_player_control()
	return control ~= nil and control.sneak == true
end

-- Is `pos` within hand reach of `player`'s eye? Measured to the NEAREST POINT OF
-- THE NODE'S CUBE, not to its centre: the engine's own range test runs against
-- the selection box's intersection point, and a client's `pointed_thing` carries
-- no intersection point, so measuring to the centre would refuse nodes the bare
-- hand reaches. This is the generous side of the same bound, never the strict
-- one.
local function within_hand_reach(player, pos)
	local eye = grug_core.combat_eye_pos(player)
	if not eye or not pos then
		return false
	end
	local function clamp(value, centre)
		if value < centre - 0.5 then
			return centre - 0.5
		elseif value > centre + 0.5 then
			return centre + 0.5
		end
		return value
	end
	local nearest = vector.new(clamp(eye.x, pos.x), clamp(eye.y, pos.y),
		clamp(eye.z, pos.z))
	return vector.distance(eye, nearest) <= NODE_INTERACT_RANGE
end

-- The client DID point at a node: builtin's placement rule, spelled out, plus
-- the hand-reach bound builtin does not have.
local function ability_on_place(itemstack, placer, pointed_thing)
	if placer and grug_abilities.input then grug_abilities.input.right_action(placer) end
	if not placer or not pointed_thing or pointed_thing.type ~= "node" or
			sneaking(placer) then
		return itemstack
	end
	if not within_hand_reach(placer, pointed_thing.under) then
		return itemstack
	end
	return pass_to_node(pointed_thing.under, placer, itemstack, pointed_thing) or
		itemstack
end

-- Air/secondary fallback: the first visible actor or node owns interaction.
-- Never reach through a foreground blocker or duplicate native object dispatch.
local function ability_on_secondary_use(itemstack, user, pointed_thing)
	if user and grug_abilities.input then grug_abilities.input.right_action(user) end
	-- An OBJECT click arrives here too (see the header): the engine is about to
	-- run that object's own right-click, so this callback must do nothing at all.
	if pointed_thing and pointed_thing.type ~= "nothing" then
		if grug_abilities.input and pointed_thing.type == "object" then
			local entity = pointed_thing.ref and pointed_thing.ref:get_luaentity()
			if entity and entity.on_rightclick then grug_abilities.input.interaction(user)
			else grug_abilities.input.right_action(user) end
		end
		return itemstack
	end
	if not user or not user.is_player or not user:is_player() or
			sneaking(user) then
		return itemstack
	end
	local origin = grug_core.combat_eye_pos(user)
	local look = user:get_look_dir()
	if not origin or not look then
		return itemstack
	end
	local destination = vector.add(origin,
		vector.multiply(vector.normalize(look), NODE_INTERACT_RANGE))
	-- Even a client "nothing" result can hide an object behind skill-specific
	-- pointability. Resolve both kinds by physical distance; never reach a door
	-- through the first visible actor. Liquids stay excluded like hand clicks.
	local nearest, nearest_distance
	for pointed in grug_core.aim_raycast(origin, destination, false) do
		if pointed.type == "node" or (pointed.type == "object" and pointed.ref ~= user and
				not grug_core.unseen_by(pointed.ref, user)) then
			local point = pointed.intersection_point
			local distance = point and vector.distance(origin, point) or math.huge
			if not nearest_distance or distance < nearest_distance or
					(distance == nearest_distance and pointed.type == "node") then
				nearest, nearest_distance = pointed, distance
			end
		end
	end
	if not nearest then
		return itemstack
	end
	if nearest.type == "object" then
		local entity = nearest.ref and nearest.ref:get_luaentity()
		if entity and entity.on_rightclick then
			if grug_abilities.input then grug_abilities.input.interaction(user) end
			entity:on_rightclick(user)
		end
		return itemstack
	end
	return pass_to_node(nearest.under, user, itemstack, nearest) or itemstack
end

--
-- Ability registration & item. One tool per ability; the item's `range`
-- doubles as the targeting range (pointed_thing works up to it). A running
-- cooldown or charge shows as the overlay on the hotbar (cooldown_hud.lua).
--

-- The cue of each ability (Round 34 S1b, plan §4.3), one per theme. A cast
-- skill's event plays at the caster when try_cast succeeds; "projectile"
-- abilities sound through their projectile's launch and hit
-- (grug_projectiles.register); "weapon" skills are swings: their tool plays
-- the swing into the air on the client and the hit sounds by weapon kind
-- (grug_core.melee_hit_sound); "silent" is the user's choice (Blink, Sprint).
-- tools/r34_s1b/portable_test.lua checks every registered ability is here.
grug_abilities.CAST_SOUNDS = {
	strike = "weapon", mighty_blow = "weapon", hamstring = "weapon",
	opening = "weapon",
	fireball = "projectile", loose = "projectile", snare_shot = "projectile",
	pinning_shot = "projectile",
	-- Warrior.
	charge = "cast_charge", taunt = "cast_taunt", hold_ground = "cast_guard",
	-- Mage: frost, the arcane blink, fire.
	ice_nova = "cast_ice_nova", glacial_ward = "cast_frost_ward",
	blink = "silent", cinderfall = "cast_cinderfall",
	-- Priest: holy, healing, the shield, shadow.
	smite = "cast_holy", heal = "cast_heal", mend = "cast_heal",
	shield_spell = "cast_shield", word_of_ruin = "cast_shadow",
	-- Scout.
	sidestep = "cast_evade", sprint = "silent",
}

-- The pose clip each skill plays when it really fires (Round 40, round40-plan
-- §2.14; grug_visuals/poses.lua): a cast skill when try_cast succeeds, a swing
-- skill's proc when it lands. A refused cast and the Strike fallback (a
-- swing without a proc) play none. Charge's pose follows its dash (lane CH,
-- grug_visuals.start_pose/stop_pose), the Scout's drawn bow is scout.lua's.
grug_abilities.SKILL_POSES = {
	fireball = "cast1", smite = "cast1", word_of_ruin = "cast1",
	cinderfall = "cast1",
	ice_nova = "cast2", glacial_ward = "cast2", heal = "cast2", mend = "cast2",
	shield_spell = "cast2",
	hold_ground = "block", mighty_blow = "swing",
}

local function play_skill_pose(player, def)
	local pose = grug_abilities.SKILL_POSES[def.id]
	if pose then grug_visuals.play_pose(player, pose) end
end

function grug_abilities.register_ability(def)
	def.repeat_policy = def.repeat_policy or "repeat"
	assert(def.repeat_policy == "repeat" or def.repeat_policy == "once")
	assert(def.id and (def.kind == "swing" or def.kind == "cast"),
		"ability needs kind = \"swing\" or \"cast\"")
	assert(def.target_kind == "friendly" or def.target_kind == "hostile"
		or def.target_kind == "self",
		"ability needs target_kind = \"friendly\", \"hostile\" or \"self\"")
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
		assert(def.cast_interval == nil or def.cast_interval > 0,
			"a cast interval must be seconds > 0")
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
	-- (weapon-slot design C1). "weapon" is the default -- deliberately
	-- INCLUDING the ones that deal no weapon damage at all (Blink, Mend,
	-- Shield): "all skills use the weapon skin" is the rule, and an
	-- exception list would put the orb back on precisely the abilities whose
	-- colour is hardest to remember. A melee skill defaults to "melee", the
	-- list its swing reads: the Scout's Melee slot (the offhand), everyone
	-- else's Weapon slot (Round 28 ruling 25, grug_inventory.melee_list). So a
	-- Scout's bow skills show the bow and Strike or Opening show the blade.
	-- "offhand" exists for WP14's shield abilities and has no user yet.
	def.slot = def.slot or (def.melee and "melee" or "weapon")
	assert(def.slot == "weapon" or def.slot == "offhand" or def.slot == "melee",
		"ability slot must be \"weapon\", \"offhand\" or \"melee\"")
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
	-- Timing line: swing skills show their CHARGE (classes.md §2b), cast
	-- skills their cooldown. The old per-cast text flag is gone with WP38.
	local cd_line
	if def.kind == "swing" then
		cd_line = def.charge and (def.charge .. " s charge") or "no charge"
	elseif def.cast_interval then
		cd_line = string.format("%g s cast interval", def.cast_interval)
	else
		cd_line = (def.cooldown > 0 and (def.cooldown .. " s cooldown"))
			or "no cooldown"
	end
	local itemname = "grug_abilities:" .. def.id
	local skill_icon = "grug_abilities_skill_" .. def.id .. ".png"
	item_defs[itemname] = def
	def._grug_skill_icon = skill_icon
	def._grug_owner_line = owner_line
	def._grug_timing_line = cd_line
	def._grug_description_prefix = grug_abilities.description_prefix(nil, def)

	local tool_def = {
		-- Numeric abilities replace this fallback per ItemStack. The registered
		-- wording deliberately contains no damage/heal/absorb number, so a stack
		-- without player context can never advertise a false value.
		description = def._grug_description_prefix .. def.description,
		inventory_image = skill_icon,
		-- The neutral fallback before the first skin sync; the skin shows the
		-- slot's item, or the bare hand for an empty slot (apply_skin). Action
		-- artwork must not masquerade as an equipped weapon in the hand.
		wield_image = "grug_abilities_orb.png^[multiply:" .. def.color,
		range = 4, -- Native pointing/digging has hand reach; casts use server rays.
		stack_max = 1,
		groups = {grug_ability = 1, grug_bound_skill = 1, not_in_creative_inventory = 1},
		-- The hand slot whose item the held skill shows (grug_visuals).
		_grug_ability_slot = def.slot,
		on_drop = function()
			return ItemStack("")
		end,
		-- Right-click never cast and still does not; both callbacks only hand
		-- the click on to an interactive node (see the block above this
		-- function).
		on_place = ability_on_place,
		on_secondary_use = ability_on_secondary_use,
	}
	-- Every representation retains the native hand-dig path. The server input
	-- owner dispatches skills from native press events and sampled controls.
	tool_def.tool_capabilities = {
		full_punch_interval = 0.9, max_drop_level = 0, punch_attack_uses = 0,
		groupcaps = {dig_immediate = {times = {[2] = 0.3, [3] = 0.3}, uses = 0, maxlevel = 0}},
		damage_groups = {fleshy = 0},
	}
	tool_def.after_use = function(stack) return stack end
	-- A swing into the air (the client plays it; hits sound on the server).
	if def.kind == "swing" then
		tool_def.sound = {punch_use_air = grug_sounds.item_sound("swing")}
	end

	core.register_tool(itemname, tool_def)
end

function grug_abilities.description_prefix(player, def)
	local cost_line
	if def.cost.mana_percent then
		cost_line = string.format("%g%% base mana", def.cost.mana_percent)
		if player then
			cost_line = cost_line .. " (" ..
				grug_abilities.mana_cost(player, def.cost.mana_percent) .. " mana)"
		end
	elseif def.cost.mana then
		cost_line = def.cost.mana .. " mana"
	elseif def.cost.rage then
		cost_line = def.cost.rage .. " rage"
	else
		cost_line = "free"
	end
	local timing = def._grug_timing_line
	if player and def.kind == "swing" and def.charge then
		timing = grug_abilities.effective_charge(player, def) .. " s charge"
	elseif player and def.cooldown_talent and not def.cast_interval then
		-- The cooldown this player's cast earns (Second Skin, Swift Word,
		-- Grudge, Quick Step ...); refreshed with every talent change.
		local cooldown = grug_abilities.effective_cooldown(player, def)
		timing = cooldown > 0 and string.format("%g s cooldown", cooldown)
			or "no cooldown"
	end
	return def.name .. " (" .. def._grug_owner_line .. ")\n" ..
		cost_line .. ", " .. timing .. "\n"
end

-- Apply one player's effective numeric description to an ability stack in
-- place. Returns true only when the caller must write the stack back. Ability
-- formulas live in kits.lua's def.values accessors; this plumbing only asks
-- the definition to format the current result.
function grug_abilities.update_stack_description(stack, def, player)
	if not grug_core.scale_player_damage then
		return false
	end
	local body = def.description_for and def.description_for(player, def)
		or def.description
	local desired = grug_abilities.description_prefix(player, def) .. body
	local meta = stack:get_meta()
	if meta:get_string("description") == desired then
		return false
	end
	meta:set_string("description", desired)
	return true
end

-- The lists ability representations may live in: main and the bag contents.
local function representation_lists()
	local lists = {"main"}
	if core.global_exists("grug_inventory") then
		for i = 1, grug_inventory.BAG_COUNT do
			lists[#lists + 1] = grug_inventory.content_list(i)
		end
	end
	return lists
end

-- The cooldown overlay on the hotbar (classes.md "The cooldown overlay"):
-- arm_cooldown and reset_charge hand it their records, it draws them on the
-- skill's hotbar slot and drops them when they run out. It never writes the
-- inventory.
local cooldown_hud = dofile(core.get_modpath(core.get_current_modname()) ..
	"/cooldown_hud.lua")({
	math = dofile(core.get_modpath(core.get_current_modname()) ..
		"/cooldown_math.lua"),
	ability_of = function(itemname)
		local def = item_defs[itemname]
		return def and def.id
	end,
})
grug_abilities.cooldown_hud = cooldown_hud

-- Destination policy for ability and mount representations is centralized in
-- grug_skills. Source-side take callbacks cannot distinguish Q/drop from an
-- external transfer, so this mod deliberately registers no take veto.

--
-- Cooldowns belong to cast skills. Swing timing uses the shared authoritative
-- weapon clock; swing effects use the independent charge timers below.
--

-- Is this ability off cooldown for this player right now?
function grug_abilities.ready(player, id)
	local cds = cooldowns[player:get_player_name()]
	local rec = cds and cds[id]
	return not rec or core.get_us_time() >= rec.expiry
end

local function cast_interval_ready(player, def)
	if not def.cast_interval then
		return true
	end
	local records = cast_intervals[player:get_player_name()]
	local next_cast = records and records[def.id]
	return not next_cast or core.get_us_time() >= next_cast
end

local function arm_cast_interval(player, def)
	if not def.cast_interval then
		return
	end
	local name = player:get_player_name()
	cast_intervals[name] = cast_intervals[name] or {}
	cast_intervals[name][def.id] = core.get_us_time()
		+ def.cast_interval * 1e6
end

-- The cooldown this player's cast actually earns. Same reason as get_range
-- above: `cooldown` in a kit table is a load-time constant with no player in
-- scope, so the talents that shorten one (Grudge, Onset, Quick Step, Swift
-- Word, Second Skin, Slip Away -- skill_trees.md §3.2) are read HERE, at the one
-- arm_cooldown(user, def, def.cooldown) call the game has. Without a ranked
-- talent this returns def.cooldown exactly.
function grug_abilities.effective_cooldown(player, def)
	local cooldown = def.cooldown or 0
	if def.cooldown_talent then
		cooldown = cooldown
			- grug_classes.get_talent_bonus(player, def.cooldown_talent)
		if cooldown < 0 then
			cooldown = 0
		end
	end
	return cooldown
end

-- Start (or restart) an ability's cooldown. `duration` <= 0 is "no cooldown"
-- and stores nothing at all, so a free ability never enters the overlay.
-- Every remaining user is a cast skill and shows the overlay.
function grug_abilities.arm_cooldown(player, def, duration)
	if not duration or duration <= 0 then
		return
	end
	local name = player:get_player_name()
	local rec = {
		expiry = core.get_us_time() + duration * 1e6,
		duration = duration,
	}
	cooldowns[name] = cooldowns[name] or {}
	cooldowns[name][def.id] = rec
	cooldown_hud.track(player, def.id, rec)
end

-- End a running cooldown now (Last Word resets Word of Ruin's, Round 35).
-- The overlay holds the same record and drops it on its next pass.
function grug_abilities.clear_cooldown(player, id)
	local cds = cooldowns[player:get_player_name()]
	local rec = cds and cds[id]
	if rec then
		rec.expiry = core.get_us_time()
	end
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

-- player name -> {ability id -> {expiry = ready_at us time, duration = s}},
-- the shape of a cooldown record, so the overlay draws both alike.
local charges = {}

function grug_abilities.effective_charge(player, def)
	local duration = def.charge or 0
	if def.charge_talent then
		duration = duration - grug_classes.get_talent_bonus(player,
			def.charge_talent)
	end
	return math.max(0, duration)
end

-- A def WITHOUT def.charge is always ready (Mighty Blow: limited by its
-- resource alone). An absent record means charged (the join/grant state).
function grug_abilities.charge_ready(player, def)
	if not def.charge then
		return true
	end
	local per_player = charges[player:get_player_name()]
	local rec = per_player and per_player[def.id]
	return not rec or core.get_us_time() >= rec.expiry
end

-- The one reset: a fired proc starts the timer over, and the overlay covers
-- the skill from the swing on.
function grug_abilities.reset_charge(player, def)
	if not def.charge then
		return
	end
	local name = player:get_player_name()
	local duration = grug_abilities.effective_charge(player, def)
	local rec = {expiry = core.get_us_time() + duration * 1e6,
		duration = duration}
	charges[name] = charges[name] or {}
	charges[name][def.id] = rec
	cooldown_hud.track(player, def.id, rec)
end

-- Authoritative swing clock (classes.md §2b). Native object punches from a
-- swing item only acquire the target and signal the initial click; this clock
-- is the sole damage cadence for both that click and held LMB. Releasing LMB
-- stops held repeats immediately; only a direct hostile-object packet already
-- received by the server gets one latch for the next throttled attack pass.
-- `next_due` deliberately survives release, so click-spamming cannot
-- manufacture extra full swings. Swing-skill selection and non-swing/cast
-- selection do not reset the weapon clock; lifecycle/class reset it, while a
-- concrete weapon change safely re-arms it.
swing_progress = {}
-- player name -> {
--   weapon = ItemStack copy, next_due = monotonic us time,
--   inactive = true while no swing item is active,
-- }

-- A due swing lands on the next throttled attack pass: the accumulator threshold
-- is 0.05 s, but the pass can run only on an actual engine step (currently often
-- 0.09 s). Carry bounded lateness into the next interval instead of arming
-- permanently from `now`: otherwise a 1.0 s weapon at dtime 0.09 becomes a
-- 1.08 s weapon. The cap prevents a long lag/range/LOS gap from turning into a
-- backlog burst.
local SWING_CATCHUP = 0.1

-- Cast/wield boundaries use reset_swing_boundary below and preserve the
-- weapon clock.
clear_swing_progress = function(player)
	local name = player:get_player_name()
	swing_progress[name] = nil
	swing_input_latch[name] = nil
	set_ready_reticle(player, false)
end

-- A non-swing/cast boundary stops the loop, but deliberately preserves the
-- current weapon due time. Otherwise swing -> tool/cast -> swing would
-- recreate the old instant-hit exploit.
reset_swing_boundary = function(player)
	local name = player:get_player_name()
	local entry = swing_progress[name]
	swing_input_latch[name] = nil
	set_ready_reticle(player, false)
	if entry then
		entry.inactive = true
	end
end

grug_core.register_on_stun(function(player)
	clear_swing_progress(player)
end)

local function selected_swing_def(player)
	local def = item_defs[player:get_wielded_item():get_name()]
	return (def and def.kind == "swing" and
		grug_abilities.is_unlocked(player, def.id)) and def or nil
end

-- Proc preparation still uses the two-phase grug_core seam because mobs_redo
-- can reject a punch through do_punch or CMI after damage was calculated. The
-- context is now one whole authoritative swing, never a native packet
-- fraction; only the accepted finish phase may pay/reset/apply an effect.
local function prepare_authoritative_swing(player, target, token)
	if not grug_core.valid_authoritative_swing(token, player, target) then
		return nil
	end
	local swing = grug_core.get_authoritative_swing_context(token)
	if not swing then
		return nil
	end
	local weapon_damage = swing.weapon_damage
	local fpi = swing.fpi
	local melee_bonus = swing.melee_bonus
	local normal_damage = weapon_damage + melee_bonus
	local context = {
		player = player,
		target = target,
		raw_damage = swing.raw_damage,
		scaled_damage = swing.scaled_damage,
		-- The delta may be negative: every authoritative swing replaces its raw
		-- total with the once-scaled total before armor and crit.
		extra_damage = swing.scaled_damage - normal_damage,
		threat_mult = swing.threat_mult,
		debug_name = swing.debug_name,
		transaction = swing.debug_name and swing or nil,
		proc = swing.proc,
		proc_cost = swing.proc_cost,
		post = swing.post,
	}
	return context
end

local function finish_authoritative_swing(context, result)
	if context.settled then
		return false
	end
	context.settled = true
	if context.transaction then
		context.transaction.outcome = result
		context.transaction.proc = context.proc and context.proc.id or "none"
	end
	if context.debug_name and grug_core.combat_debug_due(
			context.debug_name, "swing:settlement", 0.05) then
		grug_core.combat_debug_log(context.debug_name, "swing_settlement",
			"proc=" .. context.transaction.proc ..
			" cancelled=" .. tostring(result.cancelled == true) ..
			" landed=" .. tostring(result.landed == true) ..
			" damage=" .. tostring(result.damage or 0) ..
			" rage=" .. tostring(result.grant_rage == true))
	end
	if result.cancelled or not result.landed then
		return false
	end
	grug_core.run_settled_outgoing_action(context.player, context, "damage")
	local function grant_battlebeat()
		if grug_core.trinket_weapon_hit then
			grug_core.trinket_weapon_hit(context.player)
		end
	end
	if not context.proc then
		if result.grant_rage then
			grug_abilities.add_rage(context.player, swing_rage(context.player))
		end
		grant_battlebeat()
		return false
	end
	if not spend(context.player, context.proc_cost) then
		-- Preparation and finish are synchronous around one punch, so this is
		-- reachable only if foreign callback code mutates our private resource
		-- tables. Keep the charge/effect untouched and report the free damage.
		core.log("error", "[grug_abilities] authoritative proc lost its " ..
			"affordable resource before commit: " .. context.proc.id)
		if result.grant_rage then
			grug_abilities.add_rage(context.player, swing_rage(context.player))
		end
		grant_battlebeat()
		return false
	end
	grug_abilities.reset_charge(context.player, context.proc)
	play_skill_pose(context.player, context.proc)
	if result.mob and context.threat_mult ~= 1 then
		grug_core.add_threat(result.mob, context.player,
			(result.damage or 0) * (context.threat_mult - 1))
	end
	if context.post then
		context.post(context)
	end
	-- Pay the proc before granting the swing's rage. At the 100 cap this keeps
	-- the landed swing's grant instead of silently discarding it before Mighty
	-- Blow's cost opens room in the pool.
	if result.grant_rage then
		grug_abilities.add_rage(context.player, swing_rage(context.player))
	end
	grant_battlebeat()
	return true
end

grug_core.register_native_melee_handler(prepare_authoritative_swing,
	finish_authoritative_swing)

local function debug_target_name(target)
	if not target then
		return "none"
	end
	if target:is_player() then
		return "player:" .. target:get_player_name()
	end
	local ent = target:get_luaentity()
	return "entity:" .. (ent and ent.name or "unknown")
end

-- One due full swing against the current server eye/look ray. Aim misses leave
-- `next_due` untouched; the first live hostile consumes it before punch and
-- then enters WP38's exact claim-once/two-phase settlement unchanged.
attempt_swing = function(player, selected, held, latched)
	local name = player:get_player_name()
	if player:get_hp() <= 0 or grug_core.is_stunned(player) then
		if swing_progress[name] then
			clear_swing_progress(player)
		end
		return false
	end
	if not selected then
		if swing_progress[name] and not swing_progress[name].inactive then
			reset_swing_boundary(player)
		end
		return false
	end
	if not held and not latched then
		return false
	end
	if refuse_mounted_attack(player) then
		return false
	end

	local weapon = grug_core.get_melee_weapon(player) or ItemStack("")
	local weapon_damage, fpi = grug_abilities.swing_stats(player, weapon)
	local now = core.get_us_time()
	local entry = swing_progress[name]
	if not entry then
		entry = {weapon = ItemStack(weapon), next_due = 0}
		swing_progress[name] = entry
	elseif not entry.weapon:equals(weapon) then
		-- A concrete slot swap never grants an instant attack. Start the new
		-- weapon's own full interval.
		entry = {
			weapon = ItemStack(weapon),
			next_due = now + fpi * 1e6,
		}
		swing_progress[name] = entry
		return false
	end
	entry.inactive = nil
	if grug_core.combat_debug_due(name, "swing:readiness", 0.25) then
		grug_core.combat_debug_log(name, "swing_readiness",
			"held=" .. tostring(held == true) ..
			" latched=" .. tostring(latched == true) ..
			" ready=" .. tostring(now >= entry.next_due) ..
			" now=" .. now .. " next_due=" .. entry.next_due ..
			" fpi=" .. fpi)
	end
	if now < entry.next_due then
		return false
	end

	-- The combat ray runs only after input and readiness gates. Its structured
	-- result is also the one debug record; diagnostics never cast a second ray.
	local ray = grug_core.combat_ray(player,
		grug_abilities.get_range(player, selected))
	if grug_core.combat_debug_due(name, "swing:ray", 0.25) then
		grug_core.combat_debug_log(name, "swing_ray",
			"status=" .. ray.status .. " reason=" .. ray.reason ..
			" target=" .. debug_target_name(ray.target) ..
			" kind=" .. tostring(ray.object_kind or "none") ..
			" relation=" .. tostring(ray.relation or "none") ..
			" distance=" .. tostring(ray.distance or "none") ..
			" range=" .. tostring(ray.range or "none") ..
			" blocker=" .. tostring(ray.node or ray.blocker or "none"))
	end
	if ray.status ~= "target" then
		return false
	end
	local target = ray.target
	if not grug_abilities.valid_target(player, target, selected.target_kind) then
		return false
	end
	-- Presentation memory may follow an attempted/current pointed hostile, but
	-- it is never read back as aim by this path.
	grug_abilities.set_target(player, target, false)

	local late = 0
	if entry.next_due > 0 then
		late = math.max(0, (now - entry.next_due) / 1e6)
		late = math.min(late, SWING_CATCHUP, fpi * 0.5)
	end
	entry.next_due = now + (fpi - late) * 1e6
	-- A valid attack hides readiness before any dodge/refusal/callback outcome.
	set_ready_reticle(player, false)
	local caps = {
		full_punch_interval = fpi,
		damage_groups = {fleshy = weapon_damage},
		groupcaps = {},
		max_drop_level = 0,
		punch_attack_uses = 0,
	}
	local melee_bonus = grug_classes.get_melee_bonus(player)
	local melee_damage_add = grug_classes.get_talent_bonus(player,
		"melee_damage_add")
	local raw_damage = weapon_damage + melee_bonus + melee_damage_add
	local proc
	local proc_cost
	local post
	local threat_mult = 1
	-- Selection is read live at this actual due swing. An unavailable or
	-- unaffordable proc stays armed and the ordinary swing still lands. Its
	-- replacement amount is assembled before the transaction crosses the
	-- scalar, so even Mighty Blow has exactly one scaling pass.
	local selected_cost = grug_abilities.cost_for(player, selected.cost)
	if selected.proc_swing
			and grug_abilities.charge_ready(player, selected)
			and affordable(player, selected_cost) then
		local proc_damage, proc_threat, proc_post = selected.proc_swing(player,
			target, {
			weapon_damage = weapon_damage,
			fpi = fpi,
			melee_bonus = melee_bonus,
			melee_damage_add = melee_damage_add,
		})
		if proc_damage ~= nil then
			raw_damage = proc_damage
			proc = selected
			proc_cost = selected_cost
			threat_mult = proc_threat or 1
			post = proc_post
		end
		-- Affront raises a tank multiplier only; the cast-side equivalent stays
		-- in grug_core/combat.lua's deal_ability_damage.
		if threat_mult ~= 1 then
			threat_mult = threat_mult
				+ grug_classes.get_talent_bonus(player, "threat_mult_add")
		end
	end
	local transaction = {
		weapon_damage = weapon_damage,
		fpi = fpi,
		melee_bonus = melee_bonus,
		raw_damage = raw_damage,
		proc = proc,
		proc_cost = proc_cost,
		post = post,
		threat_mult = threat_mult,
		-- The complete gear + flat Strength amount crosses the one player-level
		-- scalar and target-level malus here, before the punch can reach crit
		-- or armor.
		scaled_damage = grug_core.scale_player_damage(player, target, raw_damage),
		debug_name = grug_core.combat_debug_enabled(name) and name or nil,
	}
	local token = grug_core.begin_authoritative_swing(player, target, transaction)
	if not token then
		core.log("warning", "[grug_abilities] authoritative swing could not " ..
			"start while another transaction is active")
		return false
	end
	if grug_core.combat_debug_due(name, "swing:attempt", 0.05) then
		grug_core.combat_debug_log(name, "swing_attempt",
			"target=" .. debug_target_name(target) .. " fpi=" .. fpi ..
			" late=" .. late .. " next_due=" .. entry.next_due)
	end
	local ppos = player:get_pos()
	local tpos = target:get_pos()
	local dir = ppos and tpos and vector.direction(ppos, tpos) or ray.direction
	local ok, err = pcall(target.punch, target, player, fpi, caps, dir)
	grug_core.end_authoritative_swing(token)
	if not ok then
		-- The due time is already consumed: retrying immediately after a target
		-- callback error would create a hot error loop and an attack-rate exploit.
		core.log("warning", "[grug_abilities] authoritative swing failed: " ..
			tostring(err))
		return false
	end
	if transaction.debug_name and grug_core.combat_debug_due(
			name, "swing:outcome", 0.05) then
		local outcome = transaction.outcome
		grug_core.combat_debug_log(name, "swing_outcome", outcome and
			("landed=" .. tostring(outcome.landed == true) ..
			" cancelled=" .. tostring(outcome.cancelled == true) ..
			" damage=" .. tostring(outcome.damage or 0)) or
			"no accepted settlement (protection/PvP/do_punch/CMI refusal)")
	end
	return true
end

-- Native object punches are input edges only. Contextual input revalidates
-- current aim and owns the action; tools/fists never initiate native combat.
grug_core.register_native_swing_input_handler(function(player, target)
	if grug_core.authoritative_swing_active(player) then return true end
	if grug_abilities.input then grug_abilities.input.press(player) end
	-- Only the selected skill's authoritative path may initiate player combat.
	-- Ordinary held tools retain harvesting and interaction, not native damage.
	return true
end)

-- Why `user` cannot cast `def` right now (class, unlock, cooldown, cast
-- interval, resource), or nil when nothing stands in the way. One wording for
-- the dispatcher below and the contextual input gate (input.lua), which asks
-- before it reaches the dispatcher.
local function cast_refusal(user, def)
	-- Universal abilities have no class to be (E1) — without this a Mage
	-- using the universal Strike was told "You are no Warrior".
	if not def.universal and grug_classes.get_class(user) ~= def.class then
		return "You are no " ..
			grug_classes.registered_classes[def.class].name .. "."
	end
	if not grug_abilities.is_unlocked(user, def.id) then
		return "This skill is not unlocked."
	end
	if not grug_abilities.ready(user, def.id) then
		return def.name .. " is not ready."
	end
	if not cast_interval_ready(user, def) then
		return def.name .. " cast interval is not ready."
	end
	local cost = grug_abilities.cost_for(user, def.cost, def.id)
	if not affordable(user, cost) then
		return "Not enough " .. (cost.mana and "mana" or "rage") .. "."
	end
	return nil
end

-- `notify(message)` receives every refusal message; without it they flash.
function grug_abilities.try_cast(user, def, pointed_thing, notify)
	local notice = notify or function(message)
		grug_abilities.flash(user, message)
	end
	-- A cast is a synchronous boundary even if the player switches back before
	-- the 0.5 s wield watcher sees it. Stop swing input before affordability,
	-- while preserving the anti-spam due time.
	if def.kind == "cast" then
		reset_swing_boundary(user)
	end
	if user:get_hp() <= 0 or grug_core.is_stunned(user) then
		return
	end
	-- Swing skills use the authoritative melee transaction, not the cast path.
	if def.kind ~= "cast" then
		return
	end
	if refuse_mounted_attack(user) then
		return
	end
	-- Cast skills: class, unlock, ready and affordable checks, cast, spend,
	-- arm the cooldown. No GCD anywhere (classes.md core principles, WP38).
	local refusal = cast_refusal(user, def)
	if refusal then
		notice(refusal)
		return
	end
	local effective_cost = grug_abilities.cost_for(user, def.cost, def.id)
	-- A false return means "no valid cast" (e.g. no target): no cost, no
	-- cooldown. def is passed through for the target-lock helpers
	-- (range checks). The cast succeeded, so it arms the one cooldown it
	-- earned; a swing skill's charge reset is the proc's job in kits.lua.
	-- A self-targeted ability never receives client pointing context. This is a
	-- hard boundary at the dispatcher, so a future self skill cannot quietly
	-- grow a target just because its closure happens to inspect pointed_thing.
	local cast_pointed = pointed_thing
	if def.target_kind == "self" then
		cast_pointed = nil
	end
	local ok, err = def.cast(user, cast_pointed, def)
	if not ok then
		notice(err or "Invalid target.")
		return
	end
	spend(user, effective_cost)
	local cue = grug_abilities.CAST_SOUNDS[def.id]
	if cue ~= "weapon" and cue ~= "projectile" and cue ~= "silent" then
		grug_sounds.play(cue, user)
	end
	play_skill_pose(user, def)
	arm_cast_interval(user, def)
	grug_abilities.arm_cooldown(user, def,
		grug_abilities.effective_cooldown(user, def))
	return true
end

--
-- Ability item presentation. Inventory, hotbar and catalogue resolve the
-- registered semantic skill icon. The per-stack wield override alone follows
-- the equipped hand item, preserving first/third-person weapon authority.

-- The skin token: what a stack has to say about itself so a sync can decide, in
-- ONE string compare, that it is already correct. Load-bearing, not polish --
-- every inventory write re-sends the whole list to the client (D2/2). Without
-- it, dragging any item would rewrite four stacks.
--
-- Shape: "<version>|<wield source>"; an empty slot is "<version>|", so a
-- freshly granted stack of a weaponless character is written once (it shows
-- the bare hand, below) and never again.
--
-- The resolved source rather than just the item name is included because a
-- per-stack wield override must update an already-granted ability stack.
local SKIN_VERSION = 4
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

-- The wield source image of what is in one hand slot. Empty when
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
local function slot_source(player, slot)
	local stack = grug_inventory.get_cosmetic_hand(player, slot)
	if not stack or stack:is_empty() then
		return ""
	end
	local def = core.registered_items[stack:get_name()]
	local meta = stack:get_meta()
	local inventory_src = meta:get_string("inventory_image")
	if inventory_src == "" then
		inventory_src = def_image(def and def.inventory_image)
	end
	if inventory_src == "" then
		-- Nothing to wear: an item the inventory itself cannot draw has no art
		-- for us to borrow either, so the registered skill icon remains.
		return ""
	end
	local wield_src = meta:get_string("wield_image")
	if wield_src == "" then
		wield_src = def_image(def and def.wield_image)
	end
	if wield_src == "" then
		wield_src = inventory_src
	end
	return wield_src
end

-- Would this source survive the client's image-source splitter? Three inputs
-- do not, and the source
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
			" escape the closing one). The ability item keeps its skill icon.")
	end
	return nil, nil
end

local function skin_wield_image(src)
	if src == "" then
		return nil
	end
	if not composable(src) then
		reject_source(src, "wield")
		return nil
	end
	return src
end

local function skin_token(src)
	return SKIN_VERSION .. "|" .. src
end

-- With nothing in the skill's slot the first-person view shows the bare hand,
-- not the skill orb the engine would fall back to (the item definition's
-- wield_image): the engine hand's own image and default's hand scale
-- (builtin register.lua, default tools.lua). The engine draws the hand item
-- from that image, not from the player's skin, so this is the hand a player
-- sees with an empty hotbar slot too.
local EMPTY_HAND_IMAGE = "wieldhand.png"
local EMPTY_HAND_SCALE = "(1, 1, 2.5)"

-- Skin one ability stack IN PLACE; returns true only when something actually
-- changed, i.e. only when the caller has to spend an inventory write.
--
-- Touches nothing but the three meta keys: the wear and the Loose draw-time
-- `range` stay whatever they were.
local function apply_skin(stack, def, src)
	local meta = stack:get_meta()
	local token = skin_token(src)
	if meta:get_string(SKIN_TOKEN_KEY) == token then
		return false
	end
	local wield_img = skin_wield_image(src)
	-- Inventory and catalogue presentation always resolve from the registered
	-- semantic skill icon. Only the wield override follows the equipped item;
	-- an empty slot shows the bare hand (a source the client cannot compose
	-- keeps the registered orb, as before).
	local empty = src == ""
	meta:set_string("inventory_image", "")
	meta:set_string("wield_image", empty and EMPTY_HAND_IMAGE or wield_img or "")
	meta:set_string("wield_scale", empty and EMPTY_HAND_SCALE or "")
	meta:set_string(SKIN_TOKEN_KEY, token)
	return true
end

-- All skill representations carry zero native combat damage and no tool-tier
-- capability. Ordinary digging falls back to the actual hand; short harvests
-- have a positive zero-wear capability. The clock retains the equipped weapon
-- interval. A compare-before-write token avoids repeated inventory packets.
local SWING_CAPS_VERSION = 3
local SWING_CAPS_TOKEN_KEY = "grug_swing_caps"

local function apply_swing_caps(stack, def, player)
	local _, interval = grug_abilities.swing_stats(player)
	local token = SWING_CAPS_VERSION .. "|" .. string.format("%.17g", interval)
	local meta = stack:get_meta()
	if meta:get_string(SWING_CAPS_TOKEN_KEY) == token then
		return false
	end
	meta:set_tool_capabilities({
		full_punch_interval = interval,
		max_drop_level = 0,
		groupcaps = {dig_immediate = {times = {[2] = 0.3, [3] = 0.3}, uses = 0, maxlevel = 0}},
		damage_groups = {fleshy = 0},
		punch_attack_uses = 0,
	})
	meta:set_string(SWING_CAPS_TOKEN_KEY, token)
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
			src = slot_source(player, def.slot)
			cache[def.slot] = src
		end
		return src
	end
end

-- Rewrite the skins of the granted ability items. `hand_list` limits the pass
-- to the skills that read that equipment list; nil means both hands. The
-- swing clock (apply_swing_caps) follows the melee list. Ability items live in
-- "main" only (the allow callback above enforces it), so this is one list, and
-- it writes only the stacks whose token is stale.
local function sync_skins(player, hand_list)
	local inv = player:get_inventory()
	local source_of = skin_source_cache(player)
	local list_of = {}
	for _, slot in ipairs({"weapon", "offhand", "melee"}) do
		list_of[slot] = grug_inventory.hand_list(player, slot)
	end
	local clock = hand_list == nil or hand_list == list_of.melee
	for _, listname in ipairs(representation_lists()) do
		for i = 1, inv:get_size(listname) do
			local stack = inv:get_stack(listname, i)
			local def = item_defs[stack:get_name()]
			if def then
				local changed = false
				if hand_list == nil or list_of[def.slot] == hand_list then
					changed = apply_skin(stack, def, source_of(def))
				end
				if clock and def.slot ~= "offhand" and
						apply_swing_caps(stack, def, player) then
					changed = true
				end
				if changed then inv:set_stack(listname, i, stack) end
			end
		end
	end
end

-- Level and talent changes can re-tune every numeric ability. Walk only the
-- main list where ability items are allowed to live, and spend at most one
-- inventory write per changed ability. No globalstep or cast path calls this.
local function sync_descriptions(player)
	local inv = player:get_inventory()
	for _, listname in ipairs(representation_lists()) do
		for i = 1, inv:get_size(listname) do
			local stack = inv:get_stack(listname, i)
			local def = item_defs[stack:get_name()]
			if def and grug_abilities.update_stack_description(stack, def, player) then
				inv:set_stack(listname, i, stack)
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
grug_core.register_on_equipment_change(function(player, listname, reason)
	if reason == "durability_metadata" then
		-- Pure wear or a projectile identity on the same stack (Round 37): no
		-- pool, description or skin reads it, and a break is a full change.
		-- Only the swing clock's comparison snapshot follows the melee stack,
		-- so the next swing does not take the worn copy for a weapon swap.
		local entry = swing_progress[player:get_player_name()]
		if entry and (listname == nil or
				listname == grug_inventory.melee_list(player)) then
			local weapon = grug_core.get_melee_weapon(player)
			if weapon and not entry.weapon:is_empty() and
					entry.weapon:get_name() == weapon:get_name() then
				entry.weapon = ItemStack(weapon)
			end
		end
		return
	end
	clamp_mana(player)
	hud_update(player)
	-- Every equipment list may carry rolled attributes; weapon changes also
	-- change weapon-fed ability values. The compare-first pass makes irrelevant
	-- or nested duplicate notifications cost no inventory writes.
	sync_descriptions(player)
	if listname and SKIN_IRRELEVANT_LIST[listname] then
		return
	end
	-- After the proven-irrelevant return above, only the hand that does not
	-- swing (the offhand, or a Scout's Ranged slot) can avoid changing the
	-- melee weapon. Compare the actual concrete stack so a nested
	-- second notifier pass does not restart an unchanged clock. A real A -> B
	-- swap starts B at a full interval instead of granting an instant attack;
	-- swapping back therefore cannot bypass either weapon's cadence.
	local melee_list = grug_inventory.melee_list(player)
	if not (listname and SLOT_OF_LIST[listname] and listname ~= melee_list) then
		local name = player:get_player_name()
		local entry = swing_progress[name]
		local weapon = grug_core.get_melee_weapon(player) or ItemStack("")
		if (entry and not entry.weapon:equals(weapon))
				or (not entry and listname == melee_list) then
			local _, fpi = grug_abilities.swing_stats(player, weapon)
			swing_progress[name] = {
				weapon = ItemStack(weapon),
				next_due = core.get_us_time() + fpi * 1e6,
			}
			swing_input_latch[name] = nil
			set_ready_reticle(player, false)
		end
	end
	-- nil (or an unrecognised name) -> nil -> both hands.
	sync_skins(player, listname and SLOT_OF_LIST[listname] and listname or nil)
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
-- Ability entitlement and representation normalization.
--
local function in_kit(def, class)
	return def.universal or def.class == class
end

function grug_abilities.is_unlocked(player, ability_id)
	local def = grug_abilities.registered[ability_id]
	if not def or not in_kit(def, grug_classes.get_class(player)) then
		return false
	end
	if def.talent_gated then
		return grug_classes.talent_rank(player, def.talent or def.id) > 0
	end
	return true
end

function grug_abilities.unlocked_ids(player)
	local result = {}
	local function append(def)
		if grug_abilities.is_unlocked(player, def.id) then
			result[#result + 1] = def.id
		end
	end
	for _, def in ipairs(grug_abilities.universal) do append(def) end
	for _, def in ipairs(grug_abilities.by_class[grug_classes.get_class(player)] or {}) do
		append(def)
	end
	return result
end

function grug_abilities.stack_for(player, ability_id)
	local def = grug_abilities.registered[ability_id]
	if not def or not grug_abilities.is_unlocked(player, ability_id) then return nil end
	local stack = ItemStack("grug_abilities:" .. ability_id)

	apply_skin(stack, def, skin_source_cache(player)(def))
	if def.slot ~= "offhand" then apply_swing_caps(stack, def, player) end
	grug_abilities.update_stack_description(stack, def, player)
	return stack
end

local function allowed_storage(listname)
	if listname == "main" then return true end
	if not core.global_exists("grug_inventory") then return false end
	for i = 1, grug_inventory.BAG_COUNT do
		if listname == grug_inventory.content_list(i) then return true end
	end
	return false
end

local META_INITIAL_KIT = "grug_abilities:initial_kit_given"

-- Character creation runs after the faction starter supplies were added to
-- main. Insert each base ability at its kit position and shift those supplies
-- right, preserving every carried stack. Later class changes keep the older
-- add-to-first-free-slot behavior and never rearrange an established inventory.
local function insert_initial_ability(inv, index, stack)
	local size = inv:get_size("main")
	local empty
	for slot = index, size do
		if inv:get_stack("main", slot):is_empty() then
			empty = slot
			break
		end
	end
	if not empty then return false end
	for slot = empty, index + 1, -1 do
		inv:set_stack("main", slot, inv:get_stack("main", slot - 1))
	end
	inv:set_stack("main", index, stack)
	return true
end

function grug_abilities.normalize_kit(player)
	local inv = player:get_inventory()
	local have, equipment_changed = {}, false
	for listname, list in pairs(inv:get_lists()) do
		for i, stack in ipairs(list) do
			local def = item_defs[stack:get_name()]
			if def then
				if not allowed_storage(listname) or
						not grug_abilities.is_unlocked(player, def.id) or have[def.id] then
					inv:set_stack(listname, i, ItemStack(""))
					if equipment_list[listname] then equipment_changed = true end
				else
					have[def.id] = true
					local fresh = grug_abilities.stack_for(player, def.id)
					if fresh and fresh:to_string() ~= stack:to_string() then
						inv:set_stack(listname, i, fresh)
					end
				end
			end
		end
	end
	if equipment_changed then grug_inventory.equipment_changed(player) end
end

local function grant_initial_kit(player)
	local inv = player:get_inventory()
	local meta = player:get_meta()
	local arrange_initial = meta:get_int(META_INITIAL_KIT) == 0
	local complete = true
	for index, ability_id in ipairs(grug_abilities.unlocked_ids(player)) do
		local def = grug_abilities.registered[ability_id]
		if not def.talent_gated then
			local stack = grug_abilities.stack_for(player, ability_id)
			local exists = false
			for _, listname in ipairs(representation_lists()) do
				if inv:contains_item(listname, "grug_abilities:" .. ability_id) then exists = true end
			end
			if stack and not exists then
				if arrange_initial then
					complete = insert_initial_ability(inv, index, stack) and complete
				else
					local slot = inv:get_stack("main", index)
					if slot:is_empty() then
						inv:set_stack("main", index, stack)
					else
						complete = inv:add_item("main", stack):is_empty() and complete
					end
				end
			end
		end
	end
	if arrange_initial and complete then meta:set_int(META_INITIAL_KIT, 1) end
end

grug_classes.register_on_class_chosen(function(player, class_id)
	grug_abilities.normalize_kit(player)
	grant_initial_kit(player)
	refill_mana(player)
	clamp_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

-- Talent formulas share the same def.values accessors as casts. The callback
-- exists in grug_classes and fires after its first consumer has applied the
-- changed stats, so descriptions see the final value.
if grug_classes.register_on_talents_changed then
	grug_classes.register_on_talents_changed(function(player)
		grug_abilities.normalize_kit(player)
		sync_descriptions(player)
		clamp_mana(player)
		hud_update(player)
	end)
end

-- Pool-changing statuses follow the talent refresh path: clamp the private
-- mana ledger first, then redraw the exact resource bar once.
grug_core.register_on_status_modifiers_changed(function(player)
	clamp_mana(player)
	hud_update(player)
end)

--
-- Rage generation (classes.md §1/§3): one accepted authoritative swing grants
-- RAGE_PER_SWING through finish_authoritative_swing; native packets deal
-- nothing and ability punches grant none. An accepted hit also refreshes the
-- enemy lock; immunity and sub-1 damage are not landed hits.
--

grug_core.register_on_player_hit_mob(function(player, mob_ent, damage)
	if math.floor(damage or 0) >= 1 and mob_ent.object and
			(mob_ent.health or 0) > 0 then
		grug_abilities.set_target(player, mob_ent.object, false)
	end
end)

--
-- PvP melee (combat_stats.md §2). A direct native packet (a swing item, a
-- tool, the fist) is acquisition/input only and is always suppressed here;
-- the nested authoritative punch from attempt_swing is the one damage path:
-- one full slot-fed swing, whatever the hand holds.
--
-- MODE_OR composition (reference_projects/luanti/src/script/cpp_api/
-- s_player.cpp:63): ANY callback returning true marks the punch handled
-- and the engine's own damage is suppressed (player_sao.cpp:482-490).
-- Same-faction pairs are grug_factions' handler (its true suppresses
-- before ours could matter); hostile pairs are ours. Neither vetoes the
-- other — this one never returns true outside the hostile path.
--
-- Knockback: builtin's own on_punchplayer (builtin/game/knockback.lua:25-48)
-- runs before this one and pushes off the ENGINE's `damage` argument (the
-- pre-pipeline hitparams.hp). Whether a punch pushes at all is decided there,
-- by grug_core.knockback_pushes (Round 37): only an authoritative swing on a
-- player this hitter may harm, never a refused or suppressed packet.
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
	if grug_core.is_stunned(hitter) and not grug_core.in_ability_punch then
		return true
	end
	if hitter == player or player:get_hp() <= 0 then
		return
	end
	if grug_core.in_ability_punch then
		return
	end
	-- Gathering tools never authorize native PvP damage or Strength bonuses.
	if core.get_item_group(hitter:get_wielded_item():get_name(),
			"grug_gathering_tool") > 0 then return true end
	-- A mounted hitter is refused before it can claim a swing or refresh
	-- targeting (attempt_swing refuses mounted attacks as well).
	local mounts = rawget(_G, "grug_mounts")
	if mounts and mounts.is_mounted and mounts.is_mounted(hitter) then
		return true
	end
	local authoritative_token = grug_core.claim_authoritative_swing(
		hitter, player)
	if not authoritative_token and grug_core.authoritative_swing_active(hitter) then
		-- The outer exact-target entry has already claimed its one token. Never
		-- let a synchronous same-attacker punch become a second damage/proc path.
		return true
	end
	if not authoritative_token then
		-- The handler sets the enemy/ally lock as appropriate. A direct hostile
		-- packet sets one latch for the next throttled attack pass even after release;
		-- suppress original engine damage for every native packet, including
		-- neutral targets.
		grug_core.handle_native_swing_input(hitter, player)
		return true
	end
	if not grug_factions.hostile(hitter, player) then
		-- Factionless/neutral pairs keep the engine's damage, exactly as
		-- before this WP: hostile() requires BOTH sides to have a faction
		-- (grug_factions/init.lua:87-91), so two factionless players are
		-- neutral, not hostile. Same-faction pairs are grug_factions' to
		-- suppress.
		return
	end
	-- Impact re-check (pvp-plan ruling 5): the swing chose a flagged pair, but
	-- nothing may land once either side lost the flag. Nothing is paid: the
	-- proc context is prepared only below.
	if not grug_pvp.can_harm(hitter, player) then
		return true
	end

	-- The claimed token is the swing (Round 37, CMB-01): the Strike fallback
	-- with Loose or a cast skill wielded is the same transaction as a wielded
	-- swing skill, with its melee_damage_add, weapon wear and trinket proc.
	-- The transaction was scaled once before target:punch.
	local proc_context = grug_core.prepare_native_melee(hitter, player,
		authoritative_token)
	if not proc_context then
		return true
	end
	local crit_damage, _, critical = grug_core.roll_melee_crit(
		hitter, proc_context.scaled_damage)
	local raw = grug_core.apply_player_armor(player, crit_damage,
		grug_core.get_player_level(hitter))
	local applied = math.floor(raw)
	local landed = false
	if applied >= 1 then
		local hp_before = player:get_hp()
		-- set_hp with the punch reason routes through the central hp-change
		-- modifier ONCE (player_sao.cpp:519): dodge happens there and the
		-- absorb shield follows. Armor already ran above, so the official
		-- custom_type skips ONLY that step.
		player:set_hp(hp_before - applied, {
			type = "punch",
			object = hitter,
			custom_type = grug_core.ARMOR_APPLIED_CUSTOM_TYPE,
		})
		landed = player:get_hp() < hp_before
	end
	if landed then
		if critical then
			grug_core.emit_melee_crit(player:get_pos())
		end
		if player:get_hp() > 0 then
			grug_abilities.set_target(hitter, player, false)
		end
		grug_core.mark_in_combat(hitter)
	end
	grug_core.finish_native_melee(proc_context, {
		landed = landed,
		damage = raw,
		proc_extra = 0,
		grant_rage = true,
	})
	-- The engine's own damage is suppressed on the hostile path ALWAYS —
	-- even when nothing landed (applied 0, absorbed, dodged): the
	-- pipeline is ours now.
	return true
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" then
		grug_abilities.add_rage(player, grug_abilities.RAGE_PER_HIT_TAKEN
			+ (grug_classes.get_race_perk(player, "rage_per_hit_taken_bonus") or 0)
			+ grug_classes.get_talent_bonus(player, "rage_per_hit_taken_add"))
	end
end, false)

local SWING_STEP = 0.05

local function weapon_clock_ready(player, selected)
	if not selected or player:get_hp() <= 0 then
		return false
	end
	local name = player:get_player_name()
	local entry = swing_progress[name]
	if not entry then
		return true
	end
	-- The equipment-change callback below re-arms a concrete swap immediately.
	-- Do not copy the equipped ItemStack in this 20 Hz HUD check; readiness
	-- needs only the already-authoritative due time.
	return core.get_us_time() >= entry.next_due
end

-- The crosshair state overlay refreshes on its own, slower beat (Round 30,
-- perf review #8): its rays are the costly part of this pass, while input
-- and the weapon-ready ring stay on every pass.
local CROSSHAIR_STEP = 0.15

-- The contextual input owner drives the same authoritative swing transaction.
local swing_step_acc = 0
local crosshair_acc = 0
core.register_globalstep(function(dtime)
	swing_step_acc = swing_step_acc + dtime
	crosshair_acc = crosshair_acc + dtime
	if swing_step_acc < SWING_STEP then return end
	swing_step_acc = 0
	if not grug_abilities.input then return end
	local crosshair_due = crosshair_acc >= CROSSHAIR_STEP
	if crosshair_due then crosshair_acc = crosshair_acc % CROSSHAIR_STEP end
	for _, player in ipairs(core.get_connected_players()) do
		grug_abilities.input.step(player)
		set_ready_reticle(player, weapon_clock_ready(player, selected_swing_def(player)))
		-- Target/interaction crosshair state: one hand-reach ray, plus one
		-- skill ray while a targeted skill is selected; packets only on change.
		if crosshair_due then grug_abilities.crosshair.update(player) end
	end
end)

--
-- Regen / decay ticker (0.5 s): mana follows the level-linear absolute
-- curve; rage decays 5/s out of combat (combat_stats §5, classes.md §1). The
-- skill-name watcher and the HUD bars share this one throttled pass (the
-- cooldown overlay has its own, cooldown_hud.lua); the attack/input pass
-- above uses the 0.05 s threshold required for prompt release and
-- click-latch input; an actual pass still waits for the next engine step
-- (currently often 0.09 s).
--

local acc = 0

core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < 0.5 then
		return
	end
	local elapsed = acc
	acc = 0
	watch_wield()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local res = resource_of(player)
		if res == "mana" then
			local max = grug_classes.get_max_mana(player)
			local cur = math.min(mana[name] or 0, max)
			local rate = grug_abilities.mana_regen_rate(player,
				grug_core.in_combat(player))
			local new = math.min(max, cur + rate * elapsed)
			if math.floor(new) ~= math.floor(mana[name] or 0) then
				mana[name] = new
				hud_update(player)
			else
				mana[name] = new
			end
		elseif res == "rage" and not grug_core.in_combat(player) then
			local cur = rage[name] or 0
			if cur > 0 then
				local new = math.max(0, cur
					- grug_abilities.RAGE_DECAY_PER_SECOND * elapsed)
				rage[name] = new
				if math.floor(new) ~= math.floor(cur) then
					hud_update(player)
				end
			end
		end
		-- The HUD bars ride this existing pass rather than a second
		-- globalstep (AGENTS.md's throttling rule). It is what makes the
		-- breath bar possible at all -- breath has no change callback in the
		-- Lua API -- and it is the authority that corrects the hit-point
		-- prediction the hpchange logger draws. Every write inside is gated
		-- on the drawn value, so an unchanged player costs zero packets.
		hud_update(player, true)
	end
end)

--
-- Player lifecycle
--

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local layout = grug_core.hud_layout
	-- The replacement and the removal in one place: the ruling of 2026-09-16
	-- rejects the half-heart statbars, and the bubbles go with them because
	-- `hud_set_flags` is the only call that hides either. Doing this AFTER
	-- the bars exist means the player is never without a health display.
	bar_huds[name] = {
		life = add_bar(player, "life"),
		secondary = add_bar(player, "secondary"),
		breath = add_bar(player, "breath"),
	}
	player:hud_set_flags({healthbar = false, breathbar = false})
	skillname_huds[name] = {token = 0, id = player:hud_add(
		layout.text_element("skill", {number = 0xffffff, text = ""}))}
	ready_reticle_huds[name] = {visible = false, id = player:hud_add(
		layout.image_element("reticle", {text = "",
			z_index = grug_abilities.crosshair.Z_READY}))}
	rage[name] = 0
	refill_mana(player)
	grug_abilities.normalize_kit(player)
	-- Watcher baseline AFTER the kit sync, so the snapshot is the post-grant
	-- wielded slot. Recording is feedback-free by design: nothing changed,
	-- so no "Strike" popup on login.
	wield_watch[name] = {
		index = player:get_wield_index(),
		item = player:get_wielded_item():get_name(),
	}
	hud_update(player)
end)

core.register_on_dieplayer(function(player)
	-- Player GUIDs survive respawn, while ObjectRefs can survive long enough for
	-- the killing callback to resume. Clear every owner's lock synchronously;
	-- the accepted swing's proc is already held in its local context.
	invalidate_target_locks(player)
	clear_swing_progress(player)
	cast_intervals[player:get_player_name()] = nil
	targets[player:get_player_name()] = nil
end)

core.register_on_respawnplayer(function(player)
	clear_swing_progress(player)
	cast_intervals[player:get_player_name()] = nil
	targets[player:get_player_name()] = nil
	refill_mana(player)
	clamp_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	-- Reconnecting with the same name creates a new combat identity for locks.
	invalidate_target_locks(player)
	clear_swing_progress(player)
	mana[name] = nil
	rage[name] = nil
	cooldowns[name] = nil
	cast_intervals[name] = nil
	charges[name] = nil
	targets[name] = nil
	bar_huds[name] = nil
	predicted_hp[name] = nil
	skillname_huds[name] = nil
	ready_reticle_huds[name] = nil
	wield_watch[name] = nil
	dirty[name] = nil
end)

-- A real upward transition fills mana after the earlier stats callback has
-- recomputed final pools. Join/recalculation/downward callbacks only clamp;
-- rage is deliberately untouched.
grug_xp.register_on_level_change(function(player, old_level, new_level)
	sync_descriptions(player)
	if old_level ~= nil and new_level > old_level and player:get_hp() > 0 then
		refill_mana(player)
	else
		clamp_mana(player)
	end
	hud_update(player)
end)

-- Generic casts and released arrows share the actual melee deadline.
grug_abilities.delay_strike = dofile(core.get_modpath(core.get_current_modname()) ..
	"/strike_delay.lua")(swing_progress)

-- Pure Blink and Charge targeting (map access injectable for probes).
local destinations = dofile(core.get_modpath(core.get_current_modname()) ..
	"/blink.lua")
grug_abilities.blink_destination = destinations.blink
grug_abilities.charge_destination = destinations.charge
-- Crosshair state overlay and the progress ring; scout.lua (bow draw) and
-- input.lua (eating) drive the ring.
grug_abilities.crosshair = dofile(core.get_modpath(core.get_current_modname()) ..
	"/crosshair.lua")({
	selected = function(player) return item_defs[player:get_wielded_item():get_name()] end,
})
dofile(core.get_modpath(core.get_current_modname()) .. "/kits.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/scout.lua")

-- Transaction seams retain the existing authorities. No alternate damage
-- or digging implementation is introduced by contextual dispatch.
grug_abilities.input = dofile(core.get_modpath(core.get_current_modname()) ..
	"/input.lua")({
	selected = function(player) return item_defs[player:get_wielded_item():get_name()] end,
	swing = function(player, def) return attempt_swing(player, def, true, false) end,
	-- Refusal messages (nil = go): the input gate asks these before it
	-- reaches try_cast or the swing, so it reports the reason itself.
	cast_refusal = cast_refusal,
	swing_refusal = function(player, def)
		if not grug_abilities.charge_ready(player, def) then
			return def.name .. " is not ready."
		end
		local cost = grug_abilities.cost_for(player, def.cost, def.id)
		if not affordable(player, cost) then
			return "Not enough " .. (cost.mana and "mana" or "rage") .. "."
		end
		return nil
	end,
	delay_strike = grug_abilities.delay_strike,
	within_hand_reach = within_hand_reach,
})
