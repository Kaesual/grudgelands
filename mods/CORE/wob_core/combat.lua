-- Damage pipeline & combat state (docs/design/classes.md §2,
-- combat_stats.md §2/§4). Ability damage and heals run through the helpers
-- here so crit/dodge rolls and (later) threat live in one place. The threat
-- functions are WP4 stubs — WP6 replaces them with the real threat table.

--
-- Stat accessors. Stubs so wob_core stays free of player-mod dependencies;
-- wob_classes overrides them at load time (same pattern as
-- wob_core.get_player_faction).
--

function wob_core.get_crit_chance(player)
	return 0
end

function wob_core.get_dodge_chance(player)
	return 0
end

--
-- Combat state: in combat = dealt or received damage in the last 5 s.
-- Shared definition for resource regen (WP4), recovery (combat_stats §5)
-- and mob leashing (WP6).
--

wob_core.COMBAT_TIMEOUT = 5

local last_combat = {} -- player name -> us timestamp of the last hit

function wob_core.mark_in_combat(player)
	last_combat[player:get_player_name()] = core.get_us_time()
end

function wob_core.in_combat(player)
	local t = last_combat[player:get_player_name()]
	return t ~= nil and
		(core.get_us_time() - t) < wob_core.COMBAT_TIMEOUT * 1e6
end

core.register_on_leaveplayer(function(player)
	last_combat[player:get_player_name()] = nil
end)

--
-- Threat stubs (combat_stats §4). Abilities already report their threat;
-- WP6 implements the mob-side threat table on top of these entry points.
--

-- Extra ability threat against one mob (amount already multiplied, e.g.
-- damage ×3 for tank abilities).
function wob_core.add_threat(mob_ent, player, amount)
end

-- Healing threat: 0.5×healing to all mobs in combat with the group (30 m).
function wob_core.add_heal_threat(healer, target, amount)
end

--
-- Player hit mob hook: fired by wob_mobs' do_punch wrapper for every player
-- punch that reaches a mob (rage generation, combat marking, later threat).
-- func(player, mob_ent, damage)
--

local hit_mob_callbacks = {}

function wob_core.register_on_player_hit_mob(func)
	table.insert(hit_mob_callbacks, func)
end

function wob_core.run_player_hit_mob(player, mob_ent, damage)
	wob_core.mark_in_combat(player)
	for _, func in ipairs(hit_mob_callbacks) do
		func(player, mob_ent, damage)
	end
end

--
-- Dealing ability damage. Rolls the attacker's crit (×1.5) and — against
-- players — the target's dodge, then applies the result via object:punch
-- with a full punch interval (factor 1), so armor groups, knockback and
-- mob death handling (XP/loot via on_death) keep working.
-- opts: {threat_mult = n} extra threat factor (tank abilities ×3).
-- Returns the damage dealt (0 on dodge).
--

local function crit_particles(pos)
	core.add_particlespawner({
		amount = 8,
		time = 0.15,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.4, 0.6, -0.4),
			max = vector.offset(pos, 0.4, 1.4, 0.4)},
		vel = {min = vector.new(-1, 1, -1), max = vector.new(1, 3, 1)},
		exptime = {min = 0.3, max = 0.6},
		size = {min = 2, max = 3},
		texture = "default_item_smoke.png^[multiply:#ffd100",
	})
end

-- True while an ability punch is running — lets the rage-on-hit hook skip
-- ability hits (rage comes from auto-attacks only, classes.md §1) and the
-- central dodge modifier skip the roll (abilities pre-roll it below).
wob_core.in_ability_punch = false

function wob_core.deal_ability_damage(attacker, target, amount, opts)
	opts = opts or {}
	if target:is_player() then
		-- Friendly fire: defense in depth — the ability kits filter their
		-- targets already, but never let same-faction damage through here.
		if attacker:is_player() then
			local af = wob_core.get_player_faction(attacker:get_player_name())
			local tf = wob_core.get_player_faction(target:get_player_name())
			if af and tf and af == tf then
				return 0
			end
		end
		-- Dodge is pre-rolled here for ability punches so the return value
		-- and the threat report reflect what actually landed; the central
		-- modifier skips the roll while in_ability_punch is set.
		if math.random() < wob_core.get_dodge_chance(target) then
			core.chat_send_player(target:get_player_name(),
				core.colorize("#aaaaaa", "You dodge!"))
			wob_core.mark_in_combat(attacker)
			wob_core.mark_in_combat(target)
			return 0
		end
	end
	if math.random() < wob_core.get_crit_chance(attacker) then
		amount = math.floor(amount * 1.5)
		crit_particles(target:get_pos())
	end
	wob_core.mark_in_combat(attacker)
	-- pcall + flag restore: an error mid-punch must not leave the sticky
	-- flag set (that would silently kill rage generation server-wide).
	wob_core.in_ability_punch = true
	local ok, err = pcall(target.punch, target, attacker, 1.4, {
		full_punch_interval = 1.4,
		damage_groups = {fleshy = amount},
	}, nil)
	wob_core.in_ability_punch = false
	if not ok then
		core.log("warning", "[wob_core] ability punch failed: " .. tostring(err))
		return 0
	end
	local ent = target:get_luaentity()
	if ent then
		wob_core.add_threat(ent, attacker, amount * (opts.threat_mult or 1))
	end
	return amount
end

--
-- Healing a player. Rolls the healer's crit (×1.5), clamps to max HP and
-- reports heal threat. Returns the effective healing done.
--

function wob_core.heal_player(healer, target, amount)
	local hp = target:get_hp()
	if hp <= 0 then
		return 0
	end
	if math.random() < wob_core.get_crit_chance(healer) then
		amount = math.floor(amount * 1.5)
		crit_particles(target:get_pos())
	end
	local max_hp = target:get_properties().hp_max
	local effective = math.min(amount, max_hp - hp)
	if effective > 0 then
		target:set_hp(hp + effective)
		wob_core.add_heal_threat(healer, target, effective)
	end
	return effective
end

--
-- Central dodge roll for punches against players (mob melee, PvP) plus
-- combat marking. Runs as an hp change modifier so a dodge cancels the
-- whole hit before armor/sounds.
--

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" then
		wob_core.mark_in_combat(player)
		-- Ability punches pre-roll dodge in deal_ability_damage.
		if not wob_core.in_ability_punch and
				math.random() < wob_core.get_dodge_chance(player) then
			core.chat_send_player(player:get_player_name(),
				core.colorize("#aaaaaa", "You dodge!"))
			return 0
		end
	end
	return hp_change
end, true)
