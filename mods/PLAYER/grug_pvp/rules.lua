-- Pure PvP flag rules (docs/planning/pvp-plan.md §2 rulings 1-10 and 16, §4).
-- No engine calls: init.lua hands in the per-player record, the zone answers
-- of a position and the clock (whole seconds, os.time()), so the portable test
-- (tools/r31_pvp/portable_test.lua) drives the same code.
--
-- A record is {loc = false | "contested" | "enemy", button_until = s,
-- contact_at = s}. Absolute times, so offline time counts.

local R = {}

R.BUTTON_SECONDS = 60 -- ruling 2: the button flags for 60 s from the press
R.CONTACT_FLAG_SECONDS = 60 -- ruling 2: contact keeps the flag for 60 s
R.PVP_COMBAT_SECONDS = 10 -- ruling 8: PvP combat after the last contact
R.CREDIT_SECONDS = 15 -- rulings 9/16: landed damage that earns the kill

function R.new_record()
	return {loc = false, button_until = 0, contact_at = 0}
end

-- The territory at a position for a player of `own_faction` (rulings 2 and
-- 3; since Round 32 also the zone banner's status, grug_map location.lua).
-- `pvp_rule` and `faction_here` are grug_zones' answers for the position:
-- "contested" on contested ground (the 31-60 zones, the islands, land at
-- y <= -501), "enemy" in the other faction's peaceful territory, "friendly"
-- in the own; nil in deep ocean and the dragon channels (nil rule) and for a
-- player without a faction.
function R.territory(pvp_rule, faction_here, own_faction)
	if not own_faction then
		return nil
	end
	if pvp_rule == "contested" then
		return "contested"
	end
	if pvp_rule == "peaceful" then
		if faction_here and faction_here ~= own_faction then
			return "enemy"
		end
		return "friendly"
	end
	return nil
end

-- The location flag after one sample: contested ground and enemy territory
-- flag, own peaceful territory clears, no territory keeps the previous value.
function R.location(previous, pvp_rule, faction_here, own_faction)
	local territory = R.territory(pvp_rule, faction_here, own_faction)
	if territory == nil then
		return previous
	end
	return territory ~= "friendly" and territory or false
end

function R.flagged(rec, now)
	return rec.loc ~= false or now < rec.button_until or
		now < rec.contact_at + R.CONTACT_FLAG_SECONDS
end

function R.pvp_combat(rec, now)
	return now < rec.contact_at + R.PVP_COMBAT_SECONDS
end

-- {flagged, reason, seconds_left, pvp_combat}. The reason is the strongest
-- one that keeps the flag: the location first (no countdown), then whichever
-- of the button and the contact timer runs longer.
function R.state(rec, now)
	local state = {flagged = false, pvp_combat = R.pvp_combat(rec, now)}
	if rec.loc then
		state.flagged = true
		state.reason = rec.loc == "enemy" and "location_enemy" or
			"location_contested"
		return state
	end
	local button = rec.button_until - now
	local contact = rec.contact_at + R.CONTACT_FLAG_SECONDS - now
	if button > 0 or contact > 0 then
		state.flagged = true
		if button >= contact then
			state.reason, state.seconds_left = "button", button
		else
			state.reason, state.seconds_left = "contact", contact
		end
	end
	return state
end

-- The part of a state the change callbacks report.
function R.same_state(a, b)
	return a ~= nil and b ~= nil and a.flagged == b.flagged and
		a.reason == b.reason and a.pvp_combat == b.pvp_combat
end

function R.press_button(rec, now)
	rec.button_until = now + R.BUTTON_SECONDS
end

function R.contact(rec, now)
	rec.contact_at = now
end

-- Ruling 10: death clears the button, the contact and the location flag.
function R.clear(rec)
	rec.loc, rec.button_until, rec.contact_at = false, 0, 0
end

-- Ruling 1, for an enemy player pair: both must be flagged.
function R.can_harm(attacker, target, now)
	return R.flagged(attacker, now) and R.flagged(target, now)
end

-- Ruling 6, for an own-faction pair: an unflagged helper never supports a
-- flagged player.
function R.can_support(helper, target, now)
	return R.flagged(helper, now) or not R.flagged(target, now)
end

-- Ruling 9: logout in PvP combat while flagged is death.
function R.logout_death(rec, now)
	return R.flagged(rec, now) and R.pvp_combat(rec, now)
end

-- Rulings 9/16: the names in `damagers` (name -> time of the last landed
-- hit) that landed damage within the last 15 s, sorted.
function R.credited(damagers, now)
	local names = {}
	for name, at in pairs(damagers or {}) do
		if now - at <= R.CREDIT_SECONDS then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- The ruling-16 counters, in the PvP tab's order.
R.STAT_KEYS = {"kills", "killing_blows", "deaths", "guards", "captains",
	"generals", "kings"}
-- count_npc_kill kinds -> counter.
R.NPC_COUNTER = {guard = "guards", captain = "captains",
	general = "generals", king = "kings"}

return R
