--
-- Elite/rare wind-up telegraph (docs/design/combat_stats.md §3 readability
-- rules: "elites telegraph: 2 s wind-up (stop, sound, !! nametag, particle
-- burst) then a x3 cone hit — the same mechanic later scales up to bosses").
--
-- Automatic for every mob whose tier is "elite" or "rare" (levels.lua sets
-- self._grug_tier). No def opt-in, no per-mob code: init.lua's do_custom
-- wrapper calls grug_mobs.telegraph_tick once per step, exactly like
-- leash_tick.
--
-- TIMING (all counted in self.temp, i.e. runtime only — a wind-up never
-- survives an unload, which is the point):
--   * grug_tg_engaged  seconds spent in MELEE combat (state "attack" with a
--                      target inside 2x reach). Reset whenever combat
--                      stops. The first wind-up needs FIRST_DELAY of this,
--                      so a fight always opens with normal swings.
--   * grug_tg_cd       cooldown counting down after each resolved wind-up;
--                      the next one may start INTERVAL seconds later.
--   * grug_tg_left     remaining wind-up time; non-nil == winding up.
--
-- Deliberately NOT core.after: the mob can die, be unloaded or leash-reset
-- inside the two seconds (levels.lua/aggro.lua carry the same rule). A
-- countdown that ticks in do_custom simply stops existing with the entity.
--

local WINDUP = 2 -- s of wind-up before the hit lands
local INTERVAL = 10 -- s between two wind-ups
local FIRST_DELAY = 4 -- s of melee combat before the first wind-up
local DAMAGE_MULT = 3 -- combat_stats §3: the cone hit is x3 damage
local RANGE_BONUS = 1.5 -- m of reach the cone adds on top of self.reach
-- Cone half-angle: cos(45 deg). A 90 deg wide frontal cone — wide enough to
-- read as "in front of it", narrow enough that stepping aside is a real
-- dodge. Compared against the horizontal (x/z) direction only, so height
-- differences never save or doom anyone.
local CONE_COS = 0.7071

-- Facing direction of the mob. mobs_redo stores a model-orientation offset
-- in self.rotate (radians, api.lua:3229) and subtracts it when aiming
-- (yaw_to_pos, api.lua:557) — so the direction the mob actually looks at is
-- object yaw + rotate, the same sum set_velocity uses (api.lua:347).
local function facing_dir(self)
	local yaw = self.object:get_yaw() or 0
	return core.yaw_to_dir(yaw + (self.rotate or 0))
end

-- Short, loud warning burst at the mob. ~0.4 s so it is gone well before
-- the hit lands and can never accumulate.
local function windup_particles(self)
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	core.add_particlespawner({
		amount = 24,
		time = 0.4,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.7, 0.2, -0.7),
			max = vector.offset(pos, 0.7, 1.8, 0.7)},
		vel = {min = vector.new(-0.5, 1, -0.5), max = vector.new(0.5, 3, 0.5)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 2.5, max = 4},
		texture = "default_item_smoke.png^[multiply:#ff5a1e",
		glow = 8,
	})
end

local function start_windup(self)
	-- root() is exactly a self-root with a reload-safe countdown that ticks
	-- in the same do_custom (init.lua): the mob stops dead for the wind-up
	-- and heals itself out of the effect even if it is unloaded meanwhile.
	grug_mobs.root(self, WINDUP)
	self.temp.grug_telegraph = true
	if type(self.update_tag) == "function" then
		self:update_tag() -- levels.lua tag_text prefixes "!! "
	end
	windup_particles(self)
	-- TODO(WP6 sounds): a wind-up growl belongs here; all WP6 mob sounds are
	-- deferred to one pass, see BACKLOG.
	self.temp.grug_tg_left = WINDUP
end

-- The payoff: everyone still standing in the frontal cone, in range and in
-- LINE OF SIGHT eats 3x damage. Stepping out of the cone, out of range or
-- behind cover during the two seconds is a clean miss — that IS the mechanic,
-- so nothing here re-checks the target.
-- The mob's own target may have died or logged out; bystanders still get
-- hit.
local function resolve(self)
	local pos = self.object and self.object:get_pos()
	if not pos then
		return
	end
	local range = (self.reach or 2) + RANGE_BONUS
	local dmg = math.max(1, math.floor((self.damage or 1) * DAMAGE_MULT + 0.5))
	local dir = facing_dir(self)
	local players = core.get_connected_players()
	for i = 1, #players do
		local p = players[i]
		local pp = p:get_pos()
		-- Players this mob may not target at all are not collateral either:
		-- the SAME veto general_attack consumes (init.lua's
		-- `_grug_ignore_player` — own-faction/factionless players for a
		-- faction NPC, unprovoked truce players at night). Without it an
		-- elite GUARD would slam its own faction's players standing next to
		-- it, which no acquisition path would ever have allowed.
		if pp and p:get_hp() > 0
				and not (self._grug_ignore_player and
					self:_grug_ignore_player(p))
				and vector.distance(pos, pp) <= range then
			local dx, dz = pp.x - pos.x, pp.z - pos.z
			local len = math.sqrt(dx * dx + dz * dz)
			-- Standing exactly inside the mob has no direction; count it as
			-- a hit rather than letting it divide by zero.
			local in_cone = len < 0.01 or
				(dx / len) * dir.x + (dz / len) * dir.z >= CONE_COS
			-- TERRAIN DODGE. The cone is a geometric test, so without this a
			-- player who ducked behind a rock, a tree trunk or a wall corner
			-- inside the two seconds still ate the x3 hit — and "step out of
			-- the way during the wind-up" is the advertised mechanic
			-- (combat_stats §3 readability rules), not a suggestion. A blocked
			-- player is a clean miss, exactly like one who left the cone.
			-- Cost is bounded: at most a handful of players are within a
			-- 3.5 m radius, and this only runs on the frame a wind-up
			-- resolves (once per 10 s per elite).
			if in_cone and core.line_of_sight(vector.offset(pos, 0, 1, 0),
					vector.offset(pp, 0, 1, 0)) then
				-- Full punch interval 1.4 like grug_core's ability damage:
				-- armor groups, the central dodge roll and absorb shields
				-- all apply (grug_core/combat.lua:442ff).
				p:punch(self.object, 1.4, {
					full_punch_interval = 1.4,
					damage_groups = {fleshy = dmg},
				}, nil)
			end
		end
	end
end

-- Called every step from init.lua's do_custom wrapper (guarded there by the
-- tier, so normal mobs never enter this function).
function grug_mobs.telegraph_tick(self, dtime)
	local tier = self._grug_tier
	if tier ~= "elite" and tier ~= "rare" then
		return
	end
	self.temp = self.temp or {}
	local t = self.temp

	if t.grug_tg_left then
		t.grug_tg_left = t.grug_tg_left - dtime
		if t.grug_tg_left > 0 then
			return
		end
		t.grug_tg_left = nil
		resolve(self)
		t.grug_telegraph = nil
		if type(self.update_tag) == "function" then
			self:update_tag() -- drop the "!! " prefix again
		end
		t.grug_tg_cd = INTERVAL
		return
	end

	-- Not winding up: are we in MELEE combat? A dogshoot elite at range or a
	-- mob still closing in must not wind up into empty air.
	if self.state ~= "attack" or not self.attack then
		t.grug_tg_engaged = nil
		return
	end
	local pos = self.object and self.object:get_pos()
	local tpos = self.attack:get_pos()
	if not pos or not tpos then
		return
	end
	if vector.distance(pos, tpos) > (self.reach or 2) * 2 then
		return -- in combat but out of melee: hold the engagement clock
	end
	t.grug_tg_engaged = (t.grug_tg_engaged or 0) + dtime
	if t.grug_tg_engaged < FIRST_DELAY then
		return
	end
	t.grug_tg_cd = (t.grug_tg_cd or 0) - dtime
	if t.grug_tg_cd > 0 then
		return
	end
	start_windup(self)
end
