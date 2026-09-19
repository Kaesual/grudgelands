--
-- The settlements' NPC roster: one socket-driven placement engine
-- (docs/design/settlements.md "Settlement NPCs";
-- docs/research/wp13-npc-sockets-contract.md sections 3 and 4).
--
-- WHAT STANDS WHERE comes entirely out of the `grug_core` socket registry, so
-- moving a guard post is a blueprint edit and nothing here changes:
--   guard_post    a faction guard holding an authored post
--   guard_patrol  ONE guard per LOOP, walking that loop's waypoints
--   idle          flair villagers (start_villagers.lua). An idle socket with
--                 `spawn = false` is a SPARE: a wander target of the amble that
--                 nobody is ever placed on, so a settlement offers more places
--                 to stand than it has people (playtest round 2).
--   work          the same villager entity at a WORKPLACE (playtest round 3):
--                 it never leaves the socket and plays the animation its
--                 `activity` names. Residents split 80/20 static/walking by the
--                 deterministic rule of contract section 8.3 -- see
--                 WALKER_EVERY below.
--   quest         the quest shell (start_villagers.lua)
--   vendor        resolved by grug_traders, which owns vendors
--   king          one race king plus the four royal hall guards
--   waypoint      nothing (WP17's travel pad)
--
-- IT SERVES EVERY REGISTERED SETTLEMENT, not only the six starts. A capital
-- registers under its own key when its core lands, and three things about a
-- capital are different from a start; everything else is the same code:
--
--   1. WHEN. A start is placed when `grug_core.start_ready(race)` reports its
--      128 x 128 envelope prepared, which the server does at startup. Capitals
--      are NOT preloaded, so a capital is placed the first time its area is
--      actually emerged or loaded -- the anchor's own node answering at all is
--      the gate -- and its far plots follow on the heartbeat as a player walks
--      up to them. Nothing waits for the whole 512 envelope: `serve` already
--      skips a socket whose node is not loaded and keeps it pending.
--   2. HOW MANY LOOPS. A start has one patrol loop. Highcourt's core has five
--      (the city ring and one per gate tower) and its district one more, so a
--      waypoint's `group` is what decides which loop it belongs to, and each
--      loop carries its own guard, booked on its own first waypoint.
--   3. HOW FAR A VILLAGER WANDERS. A capital's idle spots are spread over 300
--      nodes, and one villager walking between all of them is not flair. The
--      spots are grouped by the composition they came from -- the registry
--      prefixes a district plot's socket ids with the plot id -- so a villager
--      wanders its own plot or the core, never the whole city.
--
-- WHY A REGISTRY-DRIVEN WATCH AND NOT A GUARD BANNER PLUS camps.lua
-- (the choice the work package asked to make, and the reasons it went this
-- way -- all four are blocking, not aesthetic):
--
--   1. A banner is a CELL. Every blueprint cell is an identity byte
--      (`r7_settlement.lua` hashes schema, bounds, palette and cells), so six
--      banners would move six frozen settlement identities, the R7 manifest
--      SHA and every piece of engine evidence recorded against them. Sockets
--      are landmarks and move none of it. `tools/wp13/blueprint_kat.lua` even
--      refuses a `grug_nodes:guard_banner` cell outright ("decorative
--      spawner") -- the blueprint side is closed by assertion.
--   2. camps.lua places its members at a RANDOM free spot in a radius
--      (`free_spot_near`). A start guard has an authored post and an authored
--      facing; "somewhere within 15 nodes of the banner, looking anywhere" is
--      not that, and teaching the camp mechanism exact positions plus facings
--      would be a second placement engine inside it.
--   3. The camp patrol route comes from `grug_core.outpost_at` /
--      `outpost_patrol_target`, i.e. the 24 authenticated OUTPOST anchors. A
--      start is not an outpost, so a banner there gets no route at all
--      (`assign_patrol` returns early) and the authored 4..6 waypoint loop
--      would have no way in.
--   4. A banner is written by mapgen, so it would drag the whole WP13 engine
--      gate (`tools/wp13/run_engine.sh`, four worlds, two seeds) behind every
--      NPC change. Nothing here touches what the mapgen writes.
--
-- What IS reused from the camp mechanism is its MODEL: world.md section 4a's
-- respawn slots. One slot per guard socket, refilled 180-360 s after that
-- guard dies, and a dormant settlement's owed refill is simply late, never
-- lost -- the same rhythm camps.lua gives an outpost.
--
-- PERSISTENCE AND IDEMPOTENCE: one mod-storage marker per socket.
--
--   A marker is set the moment an NPC is placed at its socket and cleared
--   only by that NPC's death. So a restart places nothing: the entities came
--   back with their mapblocks (all five families are `type = "npc"`, which
--   mobs_redo never expires or unloads away -- see start_villagers.lua and
--   vendors.lua for the api.lua evidence), and the markers say so.
--
--   The alternative -- decide by scanning for an existing entity near the
--   socket -- cannot be used as the primary gate here, and the reason is the
--   engine, not taste: `core.get_objects_inside_radius` only ever sees
--   ACTIVATED objects, and a mapblock is activated by a player being near it,
--   not by being loaded. Placement runs when `grug_core.start_ready(race)`
--   reports the area prepared, which is exactly when the blocks are loaded
--   and no player is anywhere near them, so on the second boot that scan
--   would find nothing at all and duplicate the entire roster -- forever,
--   because npc entities never expire. vendors.lua avoids that by only ever
--   looking at slots close to a player; a start roster that may only appear
--   once a player walks up cannot be placed at start-ready at all.
--
--   The scan is still used, as a SECOND gate before every placement: if the
--   marker is missing but the entity BOOKED ON THAT SOCKET exists anyway (a
--   marker lost to an admin edit), the marker is restored instead of a twin
--   being spawned.
--
--   OCCUPANCY IS AN IDENTITY QUESTION, NOT A POSITION ONE, and getting that
--   wrong is what the 2026-09-15 playtest found. The first version asked
--   `get_objects_inside_radius(socket, 8)`, i.e. "is my NPC standing ON its
--   socket right now" -- which a guard walking its patrol loop and a villager
--   ambling between idle spots both answer NO. The heartbeat then freed the
--   marker and placed a twin, every five seconds, for every NPC that was not
--   at home: after a while a start had about fifty guards walking through it.
--   So a settlement is scanned ONCE per heartbeat around its anchor, out to its
--   furthest socket plus SCAN_MARGIN, and every entity carrying this
--   settlement's key is matched to the socket it is BOOKED ON
--   (`_grug_socket`), wherever it happens to stand. That map -- `held` -- is
--   what answers both questions the pass asks.
--
--   THREE THINGS BOUND THE POPULATION, and the marker alone does not:
--     1. the marker, which is what makes a restart place nothing;
--     2. the identity scan, which REMOVES a second entity found on a socket
--        that is already held -- this is what heals a world that already has
--        twins;
--     3. `grug_mobs.start_npc_claim`, which every family calls on activation,
--        so a twin arriving with its mapblock removes itself at once instead of
--        waiting for a heartbeat.
--   Plus the hard cap in `place`: a settlement already holding as many NPCs as
--   its roster has places nothing more, whatever its markers say.
--
--   AND THE CONTEST BETWEEN TWO NPCs ON ONE SOCKET IS DECIDED BY AGE, never by
--   which of them activated second (`placed_at`). That is what makes even a
--   misfired strike cheap: the fresh replacement is the one that goes, and the
--   original keeps its wound, its dwell and its place in the loop.
--
--   WHOSE MAPBLOCK HAS TO BE ACTIVE is a separate question from where the socket
--   is, and the review of this round caught it: see `strikeable`.
--
--   Guards are the one family that must come back after a death, so their
--   marker is cleared from `on_die` together with a due time; nothing else
--   here is mortal (every other family cancels every punch).
--
--   AND A MARKER IS NEVER LEFT STANDING ALONE. `on_die` is reached only from
--   `check_for_death` (api.lua:887-975), so it is not the only way an entity
--   can leave: `/clearobjects`, the `mob_active_limit` removal inside
--   `mob_activate` (api.lua:3638-3769) and a shutdown between the mod-storage
--   flush and the map flush all end with a marker and no NPC, and without a
--   re-check that socket would stay empty for the life of the world. So a pass
--   over a socket whose own mapblock is ACTIVE -- the only state in which the
--   scan can answer at all -- also frees a marked socket that nothing holds,
--   once FREE_STRIKES passes running have agreed. That is the exact mirror of
--   the second gate.
--
-- WHY `core.add_entity` AND NOT `grug_mobs.add_mob`: `mobs:add_mob` refuses
-- whenever no player is inside the active area (api.lua:4121-4213,
-- `count_mobs` -> `is_pla`) because it is the ABM spawner's own gate. Authored
-- settlement content decides its own position -- the same rule the start
-- footprint refusal states for camps, guards and rares -- and the whole point
-- of placing at start-ready is that the prepared area has no player in it.
-- The collision-box lift `add_mob` performs is kept (`place_on_ground`).
--

local storage = grug_mobs.storage

-- The placement retry heartbeat.
local PLACE_INTERVAL = 5
-- How far outside its own sockets a settlement's NPCs may be and still count as
-- present. A guard may be dragged `_grug_leash_range` = 30 nodes from its post
-- before it turns round, a patroller is between waypoints by definition, and a
-- villager is somewhere between two idle spots half the time.
local SCAN_MARGIN = 48
-- How many consecutive heartbeats a marked socket must read as EMPTY -- with its
-- own mapblock active, so that the answer is real -- before the marker is freed.
-- One heartbeat is not proof: an NPC whose own mapblock happens to be inactive
-- at that moment is not in the environment at all and cannot be seen from
-- anywhere, and freeing on the first miss is how a twin gets placed.
local FREE_STRIKES = 3
-- One guard respawn slot, world.md section 4a's guard rhythm (the same
-- GUARD_RESPAWN_MIN/MAX camps.lua uses for an outpost picket).
local RESPAWN_MIN, RESPAWN_MAX = 180, 360
-- The post tick: once a second, like every other ambient movement here, and
-- two nodes of slack so a nudged guard is not permanently walking home.
local POST_TICK = 1
local POST_SLACK = 2
-- The post walk's own two stages of patrol.lua's stuck rescue. Deliberately the
-- same numbers as the route's first and third stage: a guard is a guard, and the
-- one difference is that a post has no next waypoint to skip to.
local POST_STALL_PATH = 20
local POST_STALL_SNAP = 90
--
-- THE 80/20 SPLIT (contract section 8.3, user ruling of playtest round 3).
--
-- Nothing about it is authored. Among a settlement's resident spawn sockets in
-- AUTHORED order, every WALKER_EVERY-th `idle` spawn socket -- starting with
-- the first -- hosts a walker; every `work` socket and every other `idle`
-- socket hosts a static resident. Deterministic, so the same settlement gets
-- the same people whatever order the map happens to load in, and so a census
-- taken twice says the same thing.
--
-- Spares are NOT residents and take no place in the count: `spawn = false`
-- means "a destination, never a home" (section 6), and counting them would
-- shift every later socket's parity for a reason that has nothing to do with
-- who lives there.
--
local WALKER_EVERY = 5
--
-- HOW FAR A WALKER GOES FROM HOME, in nodes. Contract section 8.3 leaves the
-- bound to this lane and asks for it to be measured and stated.
--
-- 20 is measured: the six starts' idle sockets sit 9 to 24 nodes apart --
-- Hearthpine's walker at (-16, 4) is 9.4 nodes from its nearest spare, 13.3
-- from the workyard, 19.7 from the forge spare and 22.8 to 23.5 from the plaza
-- pair -- so a bound of 20 leaves every walker two to four destinations around
-- its own socket while cutting the cross-settlement march that had a villager
-- spend most of its life in transit (and, in a capital, walking a plot's whole
-- length between two doorsteps).
--
-- HORIZONTAL, like every other "am I where I belong" rule in this mod
-- (aggro.lua's evade and its roam cap), and a resident ALWAYS keeps its own
-- socket in its ring whatever the radius says -- a ring of one is a resident
-- that stands still, which is a legal outcome and never an empty ring.
--
local WALK_RADIUS = 20
--
-- HOW SHORT A WALKER'S RING MAY BE. A ring of one is a walker that never
-- moves (`next_spot` returns the index it was given when the ring is shorter
-- than two), which is the one outcome the 80/20 rule may not produce -- and
-- Stillgrave shipped exactly that until the review caught it. Three, so a
-- walker has two destinations rather than one to bounce off; the top-up in
-- `bounded_spots` reaches for it and settles for whatever the composition can
-- actually offer.
--
local WALK_MIN_RING = 3

--
-- Role resolvers. A role with no resolver is a socket nobody stands on
-- (`king`, `waypoint`), which is not an error.
--
-- resolver(socket, start) -> entity name, or nil
--   socket — the world-space socket copy from grug_core
--   start  — {race_id, faction_id, key, anchor}
--
local resolvers = {}

--
-- WHAT TO RE-APPLY AFTER `install` HAS WRITTEN ITS FIELDS.
--
-- `core.add_entity` activates the entity synchronously, so `after_activate`
-- has already run by the time `install` writes `_grug_start`, `_grug_socket`
-- and the rest. Two things already exist for exactly that reason -- the
-- authored facing and the settlement's own name for its people -- and the
-- review of round 3 found a third: a profession vendor is DRAWN as the race of
-- the settlement it stands in, resolved from `_grug_start`, so on its first
-- placement it was composed before that field existed and came out human.
--
-- A registry rather than a call into `grug_traders`: this mod may not depend on
-- that one, and a future family with the same ordering problem says so here
-- instead of editing `place`.
--
local restylers = {}

function grug_mobs.register_start_npc_restyle(fn)
	if type(fn) ~= "function" then
		error("grug_mobs.register_start_npc_restyle: function expected", 0)
	end
	restylers[#restylers + 1] = fn
end

function grug_mobs.register_start_socket_role(role, resolver)
	if type(role) ~= "string" or role == "" or type(resolver) ~= "function" then
		error("grug_mobs.register_start_socket_role: arguments differ", 0)
	end
	if resolvers[role] then
		error("grug_mobs.register_start_socket_role: " .. role ..
			" is already owned", 0)
	end
	resolvers[role] = resolver
end

grug_mobs.register_start_socket_role("guard_post", function(socket, start)
	return "grug_mobs:guard_" .. start.faction_id
end)
grug_mobs.register_start_socket_role("guard_patrol", function(socket, start)
	return "grug_mobs:guard_" .. start.faction_id
end)
grug_mobs.register_start_socket_role("idle", function(socket, start)
	return "grug_mobs:villager_" .. start.race_id
end)
-- A WORKPLACE IS A RESIDENT'S SOCKET, not a family of its own: the same
-- villager entity stands at the forge, at the counter and on the bench, and
-- what it does there comes out of the socket's `activity` (contract section
-- 8.1). One entity per race keeps the nametag rule, the non-combatant flag and
-- the claim registry exactly as they are.
grug_mobs.register_start_socket_role("work", function(socket, start)
	return "grug_mobs:villager_" .. start.race_id
end)
grug_mobs.register_start_socket_role("quest", function(socket, start)
	return "grug_mobs:elder_" .. start.race_id
end)
grug_mobs.register_start_socket_role("king", function(socket, start)
	return "grug_mobs:king_" .. start.race_id
end)

--
-- State
--

-- One row per registered settlement; `slots` are the sockets something stands
-- on. Keyed by the settlement key, which is the unique identity (a race id is
-- not: it has a start and a capital).
local rows = {}
local by_key = {}

-- Which log family a role reports under.
local FAMILY = {guard_post = "guards", guard_patrol = "guards",
	idle = "flair", work = "flair", trainer = "flair", vendor = "vendor",
	quest = "quest", king = "royal"}
local FAMILY_ORDER = {"guards", "flair", "vendor", "quest", "royal"}

local ROYAL_GUARD_SOCKET = {
	throne_guard_west = true, throne_guard_east = true,
	door_guard_west = true, door_guard_east = true,
}

-- Which NPC family (start_villagers.lua) a role is nametagged as. A work
-- resident is a villager with a workplace, so it is named like one.
local NAMED_FAMILY = {idle = "villager", work = "villager", trainer = "trainer",
	quest = "elder"}

--
-- THE CLAIM REGISTRY: settlement key -> socket id -> the luaentity holding that
-- socket. Runtime only and deliberately so -- it is a view of what is ACTIVE
-- right now, while the markers are what persists.
--
-- The luaentity TABLE is the identity, never an ObjectRef comparison: the table
-- is certainly unique per mob, and a mob whose object has gone is recognized by
-- `get_pos()` answering nil.
--
local held = {}

local function holder_alive(entity, key, socket_id)
	return entity ~= nil and entity._grug_start == key and
		entity._grug_socket == socket_id and entity.object ~= nil and
		entity.object:get_pos() ~= nil
end

--
-- WHICH OF TWO NPCs ON ONE SOCKET IS THE ORIGINAL: the one placed first.
--
-- `_grug_placed_at` is the gametime `install` stamped on it, a plain number, so
-- it survives unload/reload with the mob. An entity without one (nothing this
-- engine placed) counts as the newest, which keeps every contest decided in
-- favour of a real placement.
--
-- Age and not distance-to-socket, because what is at stake is STATE: the older
-- NPC is the one carrying the wound, the dwell and the position in its patrol
-- loop, and a fresh full-HP replacement standing on the socket must never be the
-- one that survives.
--
local function placed_at(entity)
	local stamp = entity and entity._grug_placed_at
	if type(stamp) ~= "number" then return math.huge end
	return stamp
end

local function claims_of(key)
	local slots = held[key]
	if not slots then
		slots = {}
		held[key] = slots
	end
	return slots
end

--
-- Called by every settlement NPC family on activation (guard.lua's tick,
-- start_villagers.lua's and vendors.lua's after_activate). Returns false when
-- the caller has removed itself, in which case its activation must do nothing
-- else.
--
-- One socket is ONE lease. Two entities booked on it can only come from a world
-- that lost a marker while its NPC lived, so one of them goes -- and it is
-- always the YOUNGER one (`placed_at` above), never whichever happened to
-- activate second. That is what heals such a world without throwing a wounded
-- guard away, and it is why a strike that does misfire costs a transient spare
-- and no state.
--
-- Returns false when the CALLER has removed itself, in which case its activation
-- must do nothing else.
--
function grug_mobs.start_npc_claim(entity)
	if type(entity) ~= "table" then
		return true
	end
	local key, socket_id = entity._grug_start, entity._grug_socket
	if type(key) ~= "string" or type(socket_id) ~= "string" then
		return true -- not a settlement NPC at all (an outpost guard)
	end
	local slots = claims_of(key)
	local other = slots[socket_id]
	if other ~= nil and other ~= entity and
			holder_alive(other, key, socket_id) then
		if placed_at(entity) < placed_at(other) then
			-- The arrival is the original; the sitting holder is the spare.
			core.log("warning", "[grug_mobs] start npcs " .. key ..
				": the newer " .. tostring(other.name) .. " on socket " ..
				socket_id .. " gave way to the one that was placed first")
			if other.object then
				mobs:remove(other, true)
			end
			slots[socket_id] = entity
			return true
		end
		core.log("warning", "[grug_mobs] start npcs " .. key .. ": a second " ..
			tostring(entity.name) .. " activated on socket " .. socket_id ..
			" and removed itself")
		if entity.object then
			mobs:remove(entity, true)
		end
		return false
	end
	slots[socket_id] = entity
	return true
end

-- The marker is keyed by the SETTLEMENT KEY, not the race: every race has a
-- start and a capital, so a race is not a unique settlement (the sockets
-- contract's own rule) and two settlements of one race would otherwise share
-- one marker for every socket id they happen to share.
local function placed_key(settlement_key, socket_id)
	return "startnpc:" .. settlement_key .. ":" .. socket_id
end

local function due_key(settlement_key, socket_id)
	return "startnpcdue:" .. settlement_key .. ":" .. socket_id
end

local function mark_placed(row, slot)
	slot.placed = true
	slot.due = nil
	storage:set_string(placed_key(row.key, slot.id), "1")
	storage:set_string(due_key(row.key, slot.id), "")
	row.pending = row.pending - 1
	row.placed_count[slot.family] = row.placed_count[slot.family] + 1
end

-- The marker outlived its NPC: free the socket and queue it again. `due` is
-- what a DEATH books (a respawn slot); an entity that simply is not there any
-- more is refilled at once, because nothing was earned by its absence.
local function mark_free(row, slot, due)
	slot.placed = false
	slot.due = due
	-- The next NPC on this socket is a different one, so whatever the last one
	-- was doing when it went out of memory is no longer interesting
	-- (see `strikeable`).
	slot.away_x = nil
	storage:set_string(placed_key(row.key, slot.id), "")
	storage:set_string(due_key(row.key, slot.id), due and tostring(due) or "")
	row.pending = row.pending + 1
	row.placed_count[slot.family] = row.placed_count[slot.family] - 1
end

--
-- Row construction (after every mod has loaded, so grug_traders has claimed
-- the `vendor` role and every entity is registered).
--

-- Which composition a socket belongs to. The registry prefixes a district
-- plot's socket ids with the plot id and a slash (`r7_settlement.M.sockets`),
-- so the part before the first slash is the composition, and a socket with no
-- slash belongs to the settlement's own core or pad.
local function composition_of(socket_id)
	return socket_id:match("^([^/]+)/") or "-"
end

--
-- A SOCKET AT A DOOR FACES AWAY FROM IT (playtest round 1, generalized in round
-- 2, 2026-09-15).
--
-- A socket's `dir` is measured at the feature it stands on -- that is what the
-- blueprint authored and what every other role wants -- but an NPC on a doorstep
-- whose face is the door shows the street its back, which is what the player
-- walking up the street actually sees. So the CONSUMER turns a door-tagged
-- socket round; the blueprint data keeps meaning one thing, and no future
-- composition can forget the rule.
--
-- ROUND 1 RESTRICTED THIS TO `idle` AND THAT WAS THE DEFECT ROUND 2 FOUND: all
-- seven quest sockets (the six Village Elders and Highcourt's chapel Elder)
-- stand on a doorstep facing the door, and the role test left every one of them
-- with its back to the street. The rule belongs to the TAG, which is where the
-- geometry is described, not to the role, which is what the NPC does; the seven
-- quest sockets now carry `door` and any future role placed at a door inherits
-- the turn by saying so.
--
-- Sockets are not identity bytes, so editing the seven socket tables to author
-- the reversed facing instead would have been legal -- but it would be seven
-- files, ~40 entries and one more thing to get right per new settlement, and the
-- authored `dir` would then no longer mean "the feature this socket belongs to".
--
local FACE_AWAY_TAGS = {door = true}
local TWO_PI = 2 * math.pi

-- EVERY tag is scanned, not only the first. `tags` is a LIST in the contract and
-- the first entry is merely the one the spoken line reads off (`_grug_idle_tag`);
-- a socket authored as `{"bench", "door"}` stands at a door just as much as one
-- authored the other way round, and reading `tags[1]` alone would silently turn
-- the rule off for it.
local function socket_face_yaw(socket)
	local yaw = socket.yaw
	local tags = socket.tags
	local away = false
	if tags then
		for index = 1, #tags do
			if FACE_AWAY_TAGS[tags[index]] then away = true end
		end
	end
	if away then
		yaw = yaw + math.pi
		if yaw >= TWO_PI then
			yaw = yaw - TWO_PI
		end
	end
	return yaw
end

-- Is this settlement a race's START or its CAPITAL? The registry is keyed by
-- settlement and carries the fitted anchor it compiled against; grug_core
-- publishes both authoritative anchors for a race, so the anchor is what
-- answers, and nothing here has to restate a roster or trust a naming
-- convention.
local function settlement_kind(record, faction_id)
	local function same(published)
		return type(published) == "table" and published.x == record.anchor.x and
			published.y == record.anchor.y and published.z == record.anchor.z
	end
	if same(grug_core.start_anchor(faction_id, record.race_id)) then
		return "start"
	end
	if same(grug_core.capital_anchor(faction_id, record.race_id)) then
		return "capital"
	end
	return nil
end

local function build_rows()
	local identities = grug_core.start_identities()
	local faction_of = {}
	for index = 1, #identities do
		faction_of[identities[index].race_id] = identities[index].faction_id
	end
	local settlements = grug_core.settlement_socket_settlements()
	for index = 1, #settlements do
		local record = settlements[index]
		local faction_id = faction_of[record.race_id]
		local sockets = grug_core.settlement_sockets_at(record.key)
		-- The registry compiled its world positions against the anchor the
		-- settlement WRITER uses; the preload, the arrival and the capital
		-- authority use the ones the consumer payload publishes. They are the
		-- same anchor, and if they ever were not, every NPC in this settlement
		-- would stand at a different height from the buildings -- so the kind is
		-- DECIDED by that comparison, once per settlement at load, and a
		-- settlement that matches neither published anchor is a defect rather
		-- than a settlement placed against a guess.
		local kind = faction_id and settlement_kind(record, faction_id) or nil
		if not faction_id then
			core.log("error", "[grug_mobs] settlement npcs: no faction for race " ..
				record.race_id)
		elseif not kind then
			core.log("error", "[grug_mobs] settlement npcs: " .. record.key ..
				" socket anchor " .. core.pos_to_string(record.anchor) ..
				" is neither the published start nor the published capital anchor" ..
				" of " .. record.race_id)
		elseif #sockets == 0 then
			core.log("warning", "[grug_mobs] settlement npcs: " .. record.key ..
				" exports no socket")
		else
			local settlement = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, kind = kind, anchor = record.anchor}
			local row = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, kind = kind, anchor = record.anchor,
				slots = {}, by_socket = {}, pending = 0, idle_groups = {},
				patrols = {}, totals = {}, placed_count = {}, spare_count = 0,
				-- socket id -> true for the residents that WALK (section 8.3),
				-- plus the two counts a census reports the share from.
				walkers = {}, walker_count = 0, resident_count = 0,
				scan_radius = SCAN_MARGIN}
			-- The ordinal of the current `idle` SPAWN socket in authored order,
			-- which is what the every-fifth rule counts.
			local resident_idle = 0
			-- The patrol loops and the idle spots first: both are read by every
			-- entity the row places, so they are built before the slots. A loop
			-- is named by its waypoints' `group`, which is how a capital carries
			-- six of them without this file knowing there are six.
			local loops, loop_order = {}, {}
			-- socket id -> its place in its composition's spot ring.
			local spot_index = {}
			for _, socket in ipairs(sockets) do
					-- The identity scan's radius: every socket this settlement has --
					-- patrol waypoints included, because that is where its guard
					-- walks -- plus the margin a leashed fight or an amble adds.
					-- Computed here so a capital's district plots widen it and a
					-- start's 128-node pad does not.
				local sdx = socket.pos.x - record.anchor.x
				local sdy = socket.pos.y - record.anchor.y
				local sdz = socket.pos.z - record.anchor.z
				local reach = math.sqrt(sdx * sdx + sdy * sdy + sdz * sdz) +
					SCAN_MARGIN
				if reach > row.scan_radius then
					row.scan_radius = reach
				end
				if socket.role == "guard_patrol" then
					local loop = loops[socket.group]
					if not loop then
						loop = {by_order = {}, size = 0}
						loops[socket.group] = loop
						loop_order[#loop_order + 1] = socket.group
					end
					if loop.by_order[socket.order] then
						core.log("error", "[grug_mobs] settlement npcs: " .. record.key ..
							" repeats patrol order " .. socket.order .. " in loop " ..
							socket.group)
					end
					loop.by_order[socket.order] = socket
					if socket.order > loop.size then loop.size = socket.order end
				elseif socket.role == "idle" then
					-- EVERY idle socket is a wander target, spare ones included:
					-- `spawn = false` decides who is PLACED (the second pass
					-- below), never where a villager may walk. The index a spot
					-- gets here is the index `_grug_idle_spot` means, so it is
					-- recorded here as well -- deriving it from a count of the
					-- placed sockets instead is what would silently point every
					-- villager at the wrong spot the moment a spare sits in front
					-- of it in the authored order.
					local group = composition_of(socket.id)
					local spots = row.idle_groups[group]
					if not spots then
						spots = {}
						row.idle_groups[group] = spots
					end
					spots[#spots + 1] = {
						x = socket.pos.x, y = socket.pos.y, z = socket.pos.z,
						yaw = socket_face_yaw(socket),
						tag = socket.tags and socket.tags[1] or nil,
						-- A SPARE is the only spot a STATIC resident is allowed
						-- to hop to, so the ring has to know which of its
						-- entries are spares (see `bounded_spots`).
						spare = socket.spawn == false or nil,
					}
					spot_index[socket.id] = #spots
					if socket.spawn == false then
						row.spare_count = row.spare_count + 1
					else
						-- THE EVERY-FIFTH RULE, in authored order and over the
						-- `idle` SPAWN sockets only.
						resident_idle = resident_idle + 1
						row.resident_count = row.resident_count + 1
						if (resident_idle - 1) % WALKER_EVERY == 0 then
							row.walkers[socket.id] = true
							row.walker_count = row.walker_count + 1
						end
					end
				elseif socket.role == "work" and socket.spawn ~= false then
					-- A workplace is a resident and never a walker.
					row.resident_count = row.resident_count + 1
				end
			end
			for _, group in ipairs(loop_order) do
				local loop = loops[group]
				local points = {}
				for order = 1, loop.size do
					local socket = loop.by_order[order]
					if socket then
						points[#points + 1] = {x = socket.pos.x, z = socket.pos.z}
					end
				end
				row.patrols[group] = points
			end
			for family_index = 1, #FAMILY_ORDER do
				row.totals[FAMILY_ORDER[family_index]] = 0
				row.placed_count[FAMILY_ORDER[family_index]] = 0
			end
			for _, socket in ipairs(sockets) do
				local resolver = resolvers[socket.role]
				-- A patrol loop carries ONE guard, booked on its first
				-- waypoint; the rest of the loop is route data. A SPARE socket
				-- carries nobody at all (`spawn = false`): it is a destination
				-- the amble may use and never a home, so the roster -- and with
				-- it every marker, the hard cap and every census -- counts only
				-- the sockets something is actually placed on.
				local carries = resolver ~= nil and socket.spawn ~= false and
					(socket.role ~= "guard_patrol" or socket.order == 1)
				if carries then
					local entity
					if kind == "capital" and socket.role == "guard_post" and
							ROYAL_GUARD_SOCKET[socket.id] then
						entity = "grug_mobs:royal_guard_" .. record.race_id
					else
						entity = resolver(socket, settlement)
					end
					if type(entity) ~= "string" or
							not core.registered_entities[entity] then
						core.log("error", "[grug_mobs] settlement npcs: " ..
							record.key .. " socket " .. socket.id ..
							" resolves to no registered entity (" ..
							tostring(entity) .. ")")
					else
						local group = composition_of(socket.id)
						local slot = {
							id = socket.id, role = socket.role, entity = entity,
							family = FAMILY[socket.role] or "flair",
							group = socket.group, composition = group,
							pos = {x = socket.pos.x, y = socket.pos.y,
								z = socket.pos.z},
							yaw = socket_face_yaw(socket),
							tag = socket.tags and socket.tags[1] or nil,
							-- The closed vocabulary of contract section 8.2,
							-- already validated by the registry: a typo is a
							-- build error there and never reaches this file.
							activity = socket.activity,
							profession = socket.profession,
							idle_index = spot_index[socket.id],
							placed = storage:get_string(
								placed_key(record.key, socket.id)) == "1",
						}
						if not slot.placed then
							local due = tonumber(storage:get_string(
								due_key(record.key, socket.id)))
							slot.due = due
							row.pending = row.pending + 1
						end
						row.totals[slot.family] = row.totals[slot.family] + 1
						if slot.placed then
							row.placed_count[slot.family] =
								row.placed_count[slot.family] + 1
						end
						row.slots[#row.slots + 1] = slot
						row.by_socket[socket.id] = slot
					end
				end
			end
			rows[#rows + 1] = row
			by_key[row.key] = row
		end
	end
end

--
-- Placement
--

--
-- ONE IDENTITY SCAN PER SETTLEMENT PER PASS (see the header). Returns
--   claims  socket id -> the luaentity booked on it, wherever it stands, and
--   total   how many of this settlement's NPCs are standing in the scanned
--           volume at all -- which is what the hard cap in `place` reads.
--
-- A SECOND entity found on a socket that is already held is REMOVED here. That
-- is the heal for a world the pre-fix heartbeat already filled with twins: the
-- markers cannot tell them apart, the sockets can.
--
local function scan_row(row)
	local slots = claims_of(row.key)
	local claims, total = {}, 0
	local objects = core.get_objects_inside_radius(row.anchor, row.scan_radius)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		-- The settlement KEY, which is what `install` writes: a race has a start
		-- AND a capital, so comparing the race here would make every socket of
		-- both read as held by the other one's NPC.
		if entity and entity._grug_start == row.key then
			local socket_id = entity._grug_socket
			local slot = socket_id and row.by_socket[socket_id]
			if slot and entity.name == slot.entity then
				local first = claims[socket_id]
				if first == nil then
					claims[socket_id] = entity
					-- Seen alive, so it is not away with an unloaded mapblock.
					slot.away_x = nil
					total = total + 1
				elseif first ~= entity then
					-- One socket is one lease, and the YOUNGER of the two goes
					-- (`placed_at`): a fresh replacement must never displace the
					-- NPC that carries the wound and the route. `mobs:remove`
					-- rather than `object:remove` for mobs_redo's own active-mob
					-- bookkeeping.
					local keep, drop = first, entity
					if placed_at(entity) < placed_at(first) then
						keep, drop = entity, first
					end
					claims[socket_id] = keep
					slot.away_x = nil
					core.log("warning", "[grug_mobs] start npcs " .. row.key ..
						": a second " .. entity.name ..
						" was booked on socket " .. socket_id ..
						" and was removed")
					mobs:remove(drop, true)
				end
			end
		end
	end
	-- An NPC that is active but OUTSIDE the scanned volume still exists, so its
	-- socket is not free: keep the claim it made on activation. (A guard dragged
	-- past SCAN_MARGIN by a running fight is the case.)
	for socket_id, entity in pairs(slots) do
		if claims[socket_id] == nil and
				holder_alive(entity, row.key, socket_id) then
			claims[socket_id] = entity
			total = total + 1
		end
	end
	held[row.key] = claims
	return claims, total
end

--
-- CAN THE SCAN ANSWER FOR THIS SOCKET AT ALL? An object exists in the
-- environment only while its mapblock is ACTIVE, and a mapblock is activated by
-- a player being near it (or by a forceload) -- not by being loaded. At
-- start-ready the whole 128 x 128 envelope is loaded and nobody is in it, so
-- nothing can be seen and therefore nothing may be freed.
--
-- `compare_block_status` asks that question directly. The first version
-- approximated it with "a player within 24 nodes", which is neither necessary
-- (a forceload activates too) nor sufficient (the engine's activation radius is
-- a setting, not 24).
--
local function socket_seeable(pos)
	return core.compare_block_status(pos, "active") == true
end

--
-- MAY THIS PASS STRIKE A MARKED SOCKET THAT NOTHING HOLDS?
--
-- THE SOCKET'S OWN MAPBLOCK BEING ACTIVE IS NECESSARY AND NOT SUFFICIENT, and
-- reading it as sufficient was a defect of its own, found by the review of this
-- round (2026-09-15). `compare_block_status` answers for the block containing the
-- position it is handed (`ServerEnvironment::getBlockStatus`,
-- serverenvironment.cpp:1159-1172) and `active_block_range` defaults to four
-- mapblocks = 64 nodes, while Highcourt's ring loop spans about a hundred: a
-- player at the south gate leaves the north-west patroller's OWN block inactive.
-- Its object is then not in the environment at all -- `get_pos()` nil, so no
-- claim -- while the socket it is booked on is active, and striking on that alone
-- replaces a guard that is merely out of range.
--
-- The engine says which of the two it is, so we do not have to guess:
-- `on_deactivate(self, removal)` distinguishes "removed" from "its mapblock was
-- unloaded" (lua_api.md: object callbacks). The unload case records WHERE the NPC
-- went out of memory -- a position whose block is inactive by construction at
-- that moment -- and the socket is then struck only once THAT block is active
-- again, because an NPC still on disk comes back with its own block. An NPC we
-- have no such record for is one the engine never told us about, which is the
-- `/clearobjects` case (`mode = "full"` deliberately calls no callback), and
-- there the socket's own block is the whole test.
--
-- `start_npc_claim`'s age rule is the backstop under all of it: if a strike ever
-- does misfire, the fresh replacement is the entity that goes.
--
local function strikeable(slot)
	if not socket_seeable(slot.pos) then
		return false
	end
	if slot.away_x == nil then
		return true
	end
	return socket_seeable({x = slot.away_x, y = slot.away_y, z = slot.away_z})
end

--
-- The deactivation record above. Installed on mobs_redo's SHARED mob class,
-- which is what makes it one hook for all five families. The engine looks the
-- callback up on the entity's table, which reaches `mob_class` through its
-- metatable (api.lua `mob_class_meta`). Chaining keeps the earlier progression
-- lifecycle cleanup and any future shared callback in the same path.
--
local function track_deactivation(entity, removal)
	local key, socket_id = entity._grug_start, entity._grug_socket
	if type(key) ~= "string" or type(socket_id) ~= "string" then
		return
	end
	local row = by_key[key]
	local slot = row and row.by_socket[socket_id]
	if not slot or claims_of(key)[socket_id] ~= entity then
		return -- not this socket's holder (a spare on its way out)
	end
	if removal then
		-- Gone for good: the marker may be freed on the ordinary strike rule.
		slot.away_x = nil
		return
	end
	local pos = entity.object and entity.object:get_pos()
	if pos then
		slot.away_x, slot.away_y, slot.away_z = pos.x, pos.y, pos.z
	end
end

local old_on_deactivate = mobs.mob_class.on_deactivate
mobs.mob_class.on_deactivate = function(self, removal)
	track_deactivation(self, removal)
	if old_on_deactivate then
		return old_on_deactivate(self, removal)
	end
end

--
-- THE RING A RESIDENT IS HANDED, bounded by `WALK_RADIUS` around its own
-- socket (contract section 8.3). Two shapes, and the difference IS the 80/20
-- rule on the idle side:
--
--   * a WALKER gets every spot of its composition within the radius -- homes
--     and spares alike -- which is the round-1 amble with a leash on it;
--   * a STATIC resident gets its own socket and the SPARES within the radius
--     and nothing else, so its rare hop is always to a place nobody lives and
--     never a trade of doorsteps with the neighbour. That is the user's "at
--     most a rare short hop on the spare ring".
--
-- The home spot is ALWAYS in the ring, whatever the radius says, and the index
-- returned is its place in the new list -- the amble reads `_grug_idle_spot`
-- as an index INTO THE RING it was given, so filtering the ring without
-- re-basing the index is exactly how everybody would end up pointed at the
-- wrong spot.
--
local function bounded_spots(group, home_index, walker)
	local home = group[home_index]
	if not home then
		local out = {}
		for index = 1, #group do
			local spot = group[index]
			out[index] = {x = spot.x, y = spot.y, z = spot.z, yaw = spot.yaw,
				tag = spot.tag, spare = spot.spare}
		end
		return out, home_index or 1
	end
	--
	-- THE RADIUS IS A PREFERENCE, NOT A WALL, and that is the fix for the
	-- defect the review of this round found: Stillgrave's walker stands at
	-- `idle_warden_door` and its nearest other idle socket is 27.7 nodes away,
	-- so a hard radius handed it a ring of ONE -- and `next_spot` returns the
	-- same index for ever when the ring is shorter than two. The settlement
	-- shipped with zero moving residents and every other test passed.
	--
	-- So the radius decides who is IN by default, and a walker whose ring came
	-- out shorter than WALK_MIN_RING then takes the nearest eligible spots
	-- until it reaches that size or the composition runs out. The bound is
	-- still what shapes an ordinary walker's route -- in five of the six starts
	-- nothing is topped up at all -- and it can no longer produce a walker with
	-- nowhere to walk.
	--
	-- A STATIC resident is deliberately NOT topped up: a ring of one is a
	-- resident that stands at its door for the life of the world, which is
	-- exactly what four residents in five are supposed to do.
	--
	local keep = {}
	local shortfall = {}
	for position = 1, #group do
		if position == home_index then
			keep[position] = true
		else
			local spot = group[position]
			local dx, dz = spot.x - home.x, spot.z - home.z
			local d2 = dx * dx + dz * dz
			local eligible = walker == true or spot.spare == true
			if eligible and d2 <= WALK_RADIUS * WALK_RADIUS then
				keep[position] = true
			elseif eligible then
				shortfall[#shortfall + 1] = {position = position, d2 = d2}
			end
		end
	end
	local kept = 0
	for _ in pairs(keep) do kept = kept + 1 end
	if walker == true and kept < WALK_MIN_RING and #shortfall > 0 then
		-- Nearest first, and the AUTHORED POSITION breaks a tie: two spots at
		-- the same distance must not be chosen by table order.
		table.sort(shortfall, function(a, b)
			if a.d2 ~= b.d2 then return a.d2 < b.d2 end
			return a.position < b.position
		end)
		for index = 1, #shortfall do
			if kept >= WALK_MIN_RING then break end
			keep[shortfall[index].position] = true
			kept = kept + 1
		end
	end
	--
	-- Emitted in AUTHORED ORDER whatever order they were chosen in: the amble
	-- advances by exactly one index, so the ring's order is what spreads the
	-- residents out, and `_grug_idle_spot` is an index into this list.
	--
	local out, index = {}, 1
	for position = 1, #group do
		if keep[position] then
			local spot = group[position]
			out[#out + 1] = {x = spot.x, y = spot.y, z = spot.z,
				yaw = spot.yaw, tag = spot.tag, spare = spot.spare}
			if position == home_index then index = #out end
		end
	end
	return out, index
end

local function install_profession_trainer_name(entity, profession)
	local jobs = rawget(_G, "grug_jobs")
	local definition = jobs and type(jobs.PROFESSIONS) == "table" and
		jobs.PROFESSIONS[profession]
	if not definition or type(definition.name) ~= "string" or
			definition.name == "" then return false end
	entity._grug_npc_name = definition.name .. " Trainer"
	return true
end

grug_mobs.install_profession_trainer_name = install_profession_trainer_name

function grug_mobs.install_profession_trainer(entity, slot)
	entity._grug_profession = slot.profession
	install_profession_trainer_name(entity, slot.profession)
	entity._grug_walker = false
end

-- Every field installed here is a plain number, string or flat table, so it
-- survives unload/reload inside the mob's staticdata (AGENTS.md's WP6 rule:
-- never an ObjectRef, never a function).
local function install(entity, row, slot)
	-- The settlement KEY, not the race: `start_guard_died` looks the row up by
	-- it, and a race has two settlements. The field name is the one guard.lua
	-- already reads.
	entity._grug_start = row.key
	entity._grug_socket = slot.id
	-- When this NPC was placed, so a contest over one socket can be decided by
	-- age instead of by which of the two activated second (`placed_at`). Plain
	-- number, so it survives unload/reload with the mob.
	entity._grug_placed_at = core.get_gametime()
	-- THE NAMETAG FOLLOWS THE SETTLEMENT, NOT THE RACE (playtest round 1): one
	-- villager entity serves a race's start AND its capital, so a name that
	-- hangs on the race put "Dawnmere Farmer" in the middle of Highcourt. The
	-- name is resolved once, here, and persists with the entity;
	-- start_villagers.lua owns what a settlement's people are called.
	local named = NAMED_FAMILY[slot.role]
	if named and grug_mobs.settlement_npc_name then
		entity._grug_npc_name = grug_mobs.settlement_npc_name(row.key, row.kind,
			row.race_id, named)
	end
	-- The facing to re-assert on every activation: mob_activate hands every mob
	-- a random yaw (api.lua:3638-3769), so an authored one has to be written back.
	-- The two families with a tick of their own do it there; the quest shell has
	-- none and restores it from `after_activate`.
	entity._grug_face_yaw = slot.yaw
	-- WHAT KIND OF SOCKET THIS IS, as a plain string on the entity. Read by the
	-- engine probe's census and by anything that has an ObjectRef and wants to
	-- know what the NPC is for without a second lookup into this file's rows.
	entity._grug_socket_role = slot.role
	if slot.role == "king" or slot.entity:find("grug_mobs:royal_guard_", 1, true) then
		entity._grug_boss_id = "king:" .. row.race_id
		entity._grug_royal_race = row.race_id
	end
	if slot.role == "guard_post" then
		-- `_grug_home` is where aggro.lua's evade runs a guard back to after a
		-- chase; the post fields are what guard.lua's tick holds it at while
		-- idle. Deliberately NO `_grug_camp_pos`: that field switches on
		-- aggro.lua's 20-node camp roam cap, which would be a second, looser
		-- owner of the same behaviour.
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
		-- Horizontal only, like every other "am I where I belong" rule in this
		-- mod (aggro.lua's evade and its roam cap): a guard standing on the
		-- step above its post is not off it. The full position lives in
		-- `_grug_home`.
		if not slot.entity:find("grug_mobs:royal_guard_", 1, true) then
			entity._grug_post_x = slot.pos.x
			entity._grug_post_z = slot.pos.z
			entity._grug_post_yaw = slot.yaw
		end
	elseif slot.role == "guard_patrol" then
		-- guard.lua's own tick walks `_grug_patrol_route` through
		-- `grug_mobs.route_tick`, and aggro.lua exempts a route carrier from
		-- both the leash and the roam cap -- being away from the post IS its
		-- job. Its own copy of the points, because `wp` lives in that table, and
		-- its OWN LOOP's points: a capital has one per gate tower besides the
		-- city ring, and mixing them would walk a guard off a wall walk.
		local loop = row.patrols[slot.group] or {}
		local points = {}
		for index = 1, #loop do
			points[index] = {x = loop[index].x, z = loop[index].z}
		end
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
		entity._grug_patrol_route = {points = points, wp = 1}
	elseif slot.role == "idle" then
		-- Its own composition's spots, so a district villager keeps to its plot
		-- and a core villager to the core -- and, since round 3, only the ones
		-- within WALK_RADIUS of its own socket, with a static resident's ring
		-- narrowed to the spares (see `bounded_spots`).
		local walker = row.walkers[slot.id] == true
		local spots, index = bounded_spots(
			row.idle_groups[slot.composition] or {}, slot.idle_index, walker)
		entity._grug_idle_spots = spots
		entity._grug_idle_spot = index
		entity._grug_idle_tag = slot.tag
		-- A plain boolean, so the 80/20 decision survives unload/reload with
		-- the mob and no activation re-derives it from a socket list.
		entity._grug_walker = walker
	elseif slot.role == "work" then
		-- A WORKPLACE. The resident never leaves it, so it is handed no ring at
		-- all: a nil `_grug_idle_spots` is what routes `resident_tick` to the
		-- work tick's cheap path rather than to the amble (start_villagers.lua
		-- keys that off the activity, and this is the second half of the same
		-- statement -- there is nowhere to amble to).
		entity._grug_work_activity = slot.activity
		entity._grug_work_x = slot.pos.x
		entity._grug_work_z = slot.pos.z
		entity._grug_walker = false
		--
		-- The spoken line still follows the socket's first tag, exactly as an
		-- idle socket's does -- AND FALLS BACK TO THE ACTIVITY (wave 2), which
		-- is the only role where there is a second thing to say.
		--
		-- Why: `tags` is optional on a `work` socket and an untagged one would
		-- otherwise answer the settlement's generic `default` line while
		-- standing at a grave, a cauldron or a rock face. The activity is
		-- REQUIRED there (contract section 8.1) and names exactly that feature,
		-- so it is the better key when the author gave none -- and
		-- `start_villagers.lua`'s LINES carries one per race per activity. A
		-- tagged socket is unchanged, so every `work` socket on main keeps the
		-- line it has.
		--
		entity._grug_idle_tag = slot.tag or slot.activity
	elseif slot.role == "king" then
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
	elseif slot.role == "trainer" then
		grug_mobs.install_profession_trainer(entity, slot)
	end
end

local function place(row, slot)
	local object = core.add_entity(slot.pos, slot.entity)
	if not object then return false end
	local entity = object:get_luaentity()
	if not entity then
		-- The engine took the position but the entity did not come up (a
		-- mobs_redo removal path). Nothing to configure and nothing to mark.
		return false
	end
	-- The ground correction mobs:add_mob skips (init.lua place_on_ground).
	grug_mobs.place_on_ground(object, slot.pos)
	install(entity, row, slot)
	grug_mobs.face_yaw(entity, slot.yaw)
	-- Both of these exist because `core.add_entity` activates the entity
	-- synchronously: its `after_activate` has already run, with none of the
	-- fields `install` has just written. The facing is one, the settlement's own
	-- name for its people is the other.
	if grug_mobs.start_npc_retag then
		grug_mobs.start_npc_retag(entity)
	end
	-- And whatever else has to be decided from the fields `install` just wrote
	-- (see `register_start_npc_restyle`): today that is the profession
	-- vendors' skin, which follows the settlement and not the entity.
	for index = 1, #restylers do
		restylers[index](entity)
	end
	-- Claim the socket at once. The families claim on activation, which for THIS
	-- entity happened before it had a socket at all.
	grug_mobs.start_npc_claim(entity)
	slot.away_x = nil
	return true
end

-- Is this settlement's area prepared? A start has the preload's own answer; a
-- capital is not preloaded at all, so what says "the area exists now" is its
-- anchor column answering with a real node. `get_node_or_nil` is nil for an
-- unloaded block and "ignore" for a loaded but ungenerated one, and the anchor
-- of a capital always carries the guard banner the anchor writer put there, so
-- a generated capital cannot answer "air" by accident either.
local function settlement_ready(row)
	if row.kind == "start" then return grug_core.start_ready(row.race_id) end
	local node = core.get_node_or_nil(row.anchor)
	return node ~= nil and node.name ~= "ignore"
end

--
-- ONE PASS OVER A SETTLEMENT. The same pass serves the start-ready trigger and
-- the heartbeat, because what a pass may do is decided PER SOCKET and not per
-- caller: a socket whose node is loaded can be filled, a socket whose mapblock
-- is active can also be freed. At start-ready the envelope is loaded and nobody
-- is in it, so the second half of that is simply false everywhere -- which is
-- exactly the old "the ready pass never frees anything", without a flag.
--
-- THE MARKER IS NOT ALLOWED TO OUTLIVE ITS NPC, and `on_die` alone does not
-- guarantee that: it is reached only from `check_for_death` (api.lua:887-975),
-- so `/clearobjects`, the `mob_active_limit` removal inside `mob_activate`
-- (api.lua:3638-3769) and a shutdown between the mod-storage flush and the map
-- flush all leave a marker with nothing standing on it -- and that socket would
-- then never refill again for the life of the world.
--
-- But a socket that reads empty ONCE is not proof of that, and believing it was
-- the round-1 defect: FREE_STRIKES consecutive passes must agree, each of them
-- with the socket's own mapblock active.
--
local function serve(row)
	if not settlement_ready(row) then return 0, 0 end
	local claims, live = scan_row(row)
	local now = core.get_gametime()
	local wall_now = os.time()
	local new, freed = 0, 0
	for index = 1, #row.slots do
		local slot = row.slots[index]
		local occupied = claims[slot.id] ~= nil
		if slot.placed then
			if occupied then
				slot.strikes = 0
			elseif strikeable(slot) then
				slot.strikes = (slot.strikes or 0) + 1
				if slot.strikes >= FREE_STRIKES then
					core.log("warning", "[grug_mobs] start npcs " .. row.key ..
						": socket " .. slot.id .. " is marked but empty; " ..
						slot.entity .. " is gone and the slot is queued again")
					mark_free(row, slot, nil)
					slot.strikes = 0
					freed = freed + 1
				end
			end
		end
		local due_now = slot.due and slot.due > 1000000000 and wall_now or now
		if not slot.placed and (not slot.due or due_now >= slot.due) then
			if occupied then
				-- The second gate: the marker was lost, the NPC was not.
				core.log("warning", "[grug_mobs] start npcs " .. row.key ..
					": " .. slot.entity .. " already stands at socket " ..
					slot.id .. " without a marker; marker restored")
				mark_placed(row, slot)
			else
				local node = core.get_node_or_nil(slot.pos)
				if node and node.name ~= "ignore" then
					if live >= #row.slots then
						-- THE HARD CAP: a settlement never holds more NPCs than
						-- it has sockets, whatever its markers say -- the
						-- round-1 defect grew a start's watch to about fifty.
						-- Deliberately a belt-and-braces ASSERTION: while the
						-- claim map is keyed per socket and `scan_row` removes
						-- the second holder, `live` cannot reach the roster size
						-- in a pass where THIS socket is unheld, so the branch
						-- should be unreachable. It costs one comparison and it
						-- fires loudly if that keying is ever broken again,
						-- which is exactly the defect's own shape.
						core.log("error", "[grug_mobs] start npcs " .. row.key ..
							": " .. live .. " NPCs already stand in a roster of " ..
							#row.slots .. "; socket " .. slot.id ..
							" is left empty")
					elseif place(row, slot) then
						mark_placed(row, slot)
						live = live + 1
						new = new + 1
						core.log("action", "[grug_mobs] start npcs " .. row.key ..
							": " .. slot.entity .. " placed at socket " ..
							slot.id .. " " .. core.pos_to_string(slot.pos))
					end
				end
			end
		end
	end
	return new, freed
end

--
-- What is actually standing in a settlement right now, by identity: the roster
-- size, how many sockets are marked, and how many NPCs the last scan found.
-- Read by the engine probe and safe to call from anywhere (it is a pure read of
-- the claim registry the heartbeat maintains).
--
function grug_mobs.start_npc_census()
	local out = {}
	for index = 1, #rows do
		local row = rows[index]
		local claims, live = claims_of(row.key), 0
		for socket_id, entity in pairs(claims) do
			if holder_alive(entity, row.key, socket_id) then live = live + 1 end
		end
		local marked, owed = 0, 0
		for slot_index = 1, #row.slots do
			local slot = row.slots[slot_index]
			if slot.placed then
				marked = marked + 1
			elseif slot.due then
				-- A socket whose NPC DIED and whose refill has been booked
				-- (world.md section 4a). It is legitimately empty until the
				-- slot falls due, which is the one reason a healthy settlement
				-- may hold fewer NPCs than its roster -- so a consumer can
				-- subtract it instead of loosening its own assertion.
				owed = owed + 1
			end
		end
		out[#out + 1] = {key = row.key, race_id = row.race_id, kind = row.kind,
			roster = #row.slots, marked = marked, live = live,
			-- Idle sockets nothing is ever placed on (`spawn = false`): wander
			-- targets, so they are part of what the settlement OFFERS and no
			-- part of what it HOLDS. The probe reads both.
			spare = row.spare_count,
			-- The 80/20 split as the KAT and the load probe judge it
			-- (contract section 8.3): how many residents this settlement has
			-- and how many of them walk. Both are decided once at load from
			-- the authored order, so they are properties of the settlement and
			-- not of who happens to be standing in it right now.
			residents = row.resident_count,
			walkers = row.walker_count,
			-- Sockets waiting on a booked respawn (see above).
			owed = owed}
	end
	return out
end

-- The countable per-settlement line every engine boot is read from.
local function log_row(row, new)
	local parts = {}
	for index = 1, #FAMILY_ORDER do
		local family = FAMILY_ORDER[index]
		parts[#parts + 1] = family .. " " .. row.placed_count[family] .. "/" ..
			row.totals[family]
	end
	core.log("action", "[grug_mobs] start npcs " .. row.race_id .. " " ..
		row.key .. ": " .. table.concat(parts, " ") .. " new " .. new ..
		" pending " .. row.pending .. " spare " .. row.spare_count ..
		" residents " .. row.resident_count ..
		" walkers " .. row.walker_count)
end

--
-- Triggers
--
-- 1. A settlement becomes ready. For a START that is the preload reporting its
--    whole 128 x 128 envelope loaded, so the roster is placed in one pass with
--    no player anywhere near it; this is also the pass whose log line proves a
--    restart places nothing. For a CAPITAL, which is never preloaded, it is the
--    first heartbeat that finds its anchor column loaded -- i.e. the first time
--    a player's arrival has actually emerged the place -- and the same
--    no-player pass then fills every socket whose own node is already loaded.
-- 2. The heartbeat: whatever the ready pass could not place (a node that was
--    not loaded after all, which for a capital is most of its district), every
--    guard respawn slot that has fallen due, and the re-check that frees a
--    marker whose NPC is really gone.
--
-- NEITHER TRIGGER ASKS ABOUT PLAYERS. What a pass may do is decided per socket
-- by the map itself (`serve`): loaded is what allows a placement, active is what
-- allows a marker to be freed. A capital is emerged by whoever walks there, and
-- equally by an admin's forceload or a headless probe -- and the first version's
-- "no player connected, return" made both the retry and the re-check dead code
-- on a server nobody was logged in to, which is also every engine probe.
--

local ready_served = {}

local function serve_ready_settlements(served)
	for index = 1, #rows do
		local row = rows[index]
		if not ready_served[row.key] and settlement_ready(row) then
			ready_served[row.key] = true
			local new = serve(row)
			if served then served[row.key] = true end
			log_row(row, new)
		end
	end
end

local accumulator = 0

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < PLACE_INTERVAL then return end
	accumulator = 0
	local served = {}
	serve_ready_settlements(served)
	for index = 1, #rows do
		local row = rows[index]
		-- Every row, every heartbeat, and not only the ones with something
		-- pending: a full row is exactly where a marker without an NPC hides.
		-- A row the readiness pass has just served in this same heartbeat is
		-- skipped -- one identity scan per settlement per heartbeat is the
		-- budget.
		if not served[row.key] then
			local new, freed = serve(row)
			if new > 0 or freed > 0 then log_row(row, new) end
		end
	end
end)

core.register_on_mods_loaded(function()
	build_rows()
	-- The preload reports progress from a deferred job, never from inside an
	-- emerge callback (starts_preload.lua), so reacting here is safe; a start
	-- that was already ready before this registration is caught by the
	-- first-step sweep below.
	grug_core.register_on_starts_progress(function()
		serve_ready_settlements(nil)
	end)
	core.after(0, function()
		serve_ready_settlements(nil)
	end)
end)

--
-- The post guard's idle behaviour, called from guard.lua's own tick for the
-- guards that carry a post (an outpost guard carries none and keeps
-- aggro.lua's camp roam cap instead).
--
function grug_mobs.start_post_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_post_acc = (temp.grug_post_acc or 0) + dtime
	if temp.grug_post_acc < POST_TICK then return end
	temp.grug_post_acc = 0
	-- Idle only: fighting, fleeing and flopping own the movement, and an
	-- evading guard is already running home on aggro.lua's stricter target.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	if temp.grug_evading then
		grug_mobs.stall_clear(self)
		return
	end
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	local dx = self._grug_post_x - pos.x
	local dz = self._grug_post_z - pos.z
	if dx * dx + dz * dz > POST_SLACK * POST_SLACK then
		-- THE WALK HOME GETS THE SAME THREE-STAGE RESCUE THE PATROL HAS
		-- (patrol.lua, playtest round 1): a post is a standing position, so a
		-- guard that cannot get back to it is a guard that is missing from the
		-- gate. Stage 2 has nothing to skip to here -- a post is one point --
		-- so this is stage 1 (the pathfinder) and stage 3 (the out-of-sight
		-- snap, which lands exactly on the authored post).
		local stalled, total = grug_mobs.stall_clock(self, self._grug_post_x,
			self._grug_post_z, pos, POST_TICK)
		if total >= POST_STALL_SNAP and
				grug_mobs.snap_try(self, pos, self._grug_post_x,
					self._grug_post_z, POST_TICK, POST_STALL_SNAP) then
			return
		end
		if stalled >= POST_STALL_PATH and grug_mobs.path_nudge(self,
				self._grug_post_x, self._grug_post_z, pos) then
			return
		end
		grug_mobs.walk_toward(self, self._grug_post_x, self._grug_post_z, pos)
		return
	end
	grug_mobs.stall_clear(self)
	self.state = "stand"
	self:set_velocity(0)
	grug_mobs.face_yaw(self, self._grug_post_yaw or 0)
end

--
-- A start guard died: free its slot and book the refill (world.md section 4a
-- -- one slot, 180-360 s, and a settlement nobody is standing in simply gets
-- its guard back late rather than never).
--
function grug_mobs.start_guard_died(self)
	local row = by_key[self._grug_start]
	local slot = row and row.by_socket[self._grug_socket]
	if not slot or not slot.placed then return end
	mark_free(row, slot,
		core.get_gametime() + math.random(RESPAWN_MIN, RESPAWN_MAX))
	core.log("action", "[grug_mobs] start npcs " .. row.key .. ": socket " ..
		slot.id .. " lost its guard, refill due at " .. slot.due)
end

local ROYAL_HOLD = 2147483647

local function royal_slots(row)
	local result = {}
	for index = 1, #row.slots do
		local slot = row.slots[index]
		if slot.role == "king" or
				slot.entity:find("grug_mobs:royal_guard_", 1, true) then
			result[#result + 1] = slot
		end
	end
	return result
end

-- A fallen retinue member stays down for the current attempt.  The king's
-- full reset restores all four slots together; killing the king instead books
-- one shared absolute wall-clock timestamp for the complete five-NPC group.
function grug_mobs.royal_guard_died(self)
	local row = by_key[self._grug_start]
	local slot = row and row.by_socket[self._grug_socket]
	if slot and slot.placed then mark_free(row, slot, ROYAL_HOLD) end
end

function grug_mobs.royal_encounter_reset(self)
	local row = by_key[self._grug_start]
	if not row then return end
	local claims = claims_of(row.key)
	for _, slot in ipairs(royal_slots(row)) do
		if slot.role ~= "king" then
			local holder = claims[slot.id]
			if holder and holder.object then holder.object:remove() end
			claims[slot.id] = nil
			if slot.placed then mark_free(row, slot, nil) else
				slot.due = nil
				storage:set_string(due_key(row.key, slot.id), "")
			end
		end
	end
	if grug_mobs.boss_attempt_reset then
		grug_mobs.boss_attempt_reset(self._grug_boss_id)
	end
end

function grug_mobs.royal_king_died(self)
	local row = by_key[self._grug_start]
	if not row then return end
	local due = os.time() + 15 * 60
	local claims = claims_of(row.key)
	for _, slot in ipairs(royal_slots(row)) do
		local holder = claims[slot.id]
		if slot.role ~= "king" and holder and holder.object then
			holder.object:remove()
		end
		claims[slot.id] = nil
		if slot.placed then mark_free(row, slot, due) else
			slot.due = due
			storage:set_string(due_key(row.key, slot.id), tostring(due))
		end
	end
end
