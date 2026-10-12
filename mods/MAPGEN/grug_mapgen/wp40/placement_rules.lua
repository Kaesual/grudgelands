-- Round 46 seed-dependent POI placement: the rules per kind (data; the
-- mechanism is `placement.lua`, the design note round46-plan.md §4.2).
--
-- One entry per placed template id (the anchor's kind; its fitting profile
-- lives in `source/simple_map.lua` anchor_profiles). Every kind shares the
-- rules of `placement.lua`'s header: its own zone with ZONE_MARGIN, on
-- land, a dry core and the river guard (F3), relief under the core within
-- `relief` (never above the terrain field's bowl threshold), the gaps to
-- every anchor and to the towns, the middle-road corridor and the row's
-- level band. An entry adds:
--   relief     highest minus lowest natural ground under the building core
--   dry        nodes of dry ground round the core
--   spacing    centre distance to every other placed POI
--   hills      prefers ground the terrain round it (this reach) rises above
--   near_water inland water within this many nodes of the core: required in
--              the first two relaxation steps, preferred after
--   patrol     the rare patrol points (`source.rare_patrol_shape`) stand on
--              dry land in the zone
--   fortress   the PvP fortress rule: on its faction's side of the middle
--              road's axis x = 0 (Accord east, Throng west; the gate faces
--              the road, `r7_settlement.pvp_gate_turns`), |x| in [min, max]
--   camp       the PvP camp rule: its own faction's half of its zone (Accord
--              z < 0) at least `half` off z = 0, at its catalogue levels
--              (`r31_pvp_catalog.camp_levels`), BOAT_GAP from a boat path's
--              mainland end
--   pvp        PvP POIs keep PVP_SPACING_MIN from each other on every step
-- Plain Lua 5.1, no globals.
local R = {}

R.KINDS = {
	village = {relief = 12, dry = 12, spacing = 192},
	outpost = {relief = 16, dry = 8, spacing = 160},
	bandit_home = {relief = 16, dry = 8, spacing = 160},
	bandit_frontier = {relief = 16, dry = 8, spacing = 160},
	mine = {relief = 20, dry = 8, spacing = 160, hills = 96},
	mirefolk = {relief = 10, dry = 6, spacing = 160, near_water = 64},
	clash = {relief = 20, dry = 8, spacing = 160},
	rare_route = {relief = 28, dry = 4, spacing = 96, patrol = true},
	pvp_fortress = {relief = 12, dry = 12, spacing = 160, pvp = true,
		fortress = {min = 88, max = 448}},
	pvp_camp_low = {relief = 16, dry = 8, spacing = 160, pvp = true, camp = {half = 16}},
	pvp_camp_high = {relief = 16, dry = 8, spacing = 160, pvp = true, camp = {half = 16}},
}

-- The order kinds are placed in within one pass (the larger and the more
-- constrained first); a kind missing here follows them by template id.
R.KIND_ORDER = {"pvp_fortress", "pvp_camp_high", "pvp_camp_low", "village", "mine",
	"outpost", "bandit_home", "bandit_frontier", "mirefolk", "clash", "rare_route"}

-- The relaxation steps, tried in order until one finds a candidate:
-- band slack (thirds; a war camp's levels), relief factor, spacing factor,
-- zone margin (nodes). Never relaxed: the own zone, land, the dry core and
-- F3, the relief cap, the town gaps, the fortress side, the camp half.
R.STEPS = {
	{band = 0, relief = 1, spacing = 1, margin = 24},
	{band = 1, relief = 1, spacing = 1, margin = 24},
	{band = 1, relief = 1.5, spacing = 1, margin = 24},
	{band = 1, relief = 1.5, spacing = 0.75, margin = 16},
	{band = 2, relief = 2, spacing = 0.5, margin = 8},
	{band = 2, relief = 3, spacing = 0.25, margin = 0},
}
-- The step number a row takes when no step found a place (the last resort:
-- a dry core anywhere in its zone), and when not even that exists (a wet
-- core, reported as [GRUG-SEVERE]).
R.LAST_RESORT, R.WET_RESORT = 7, 8

R.ANCHOR_GAP = 16          -- fitting squares apart, every pair of anchors
R.TOWN_GAP = 128           -- ... and this far from a start town's or capital's square (PL-5)
R.PVP_SPACING_MIN = 120    -- PvP POIs apart, centre to centre (pvp-plan ruling 21)
R.BOAT_GAP = 128           -- a war camp from a boat path's mainland end
R.WATER_REACH = 24         -- the core's fitted height stays above water this close
R.FINALISTS = 8            -- passing candidates the seeded pick chooses among
R.EXACT_MAX = 400          -- candidates the exact checks try per step at most
-- The middle road's corridor (Round 29): a POI in these zones keeps
-- |x| >= max(min, core / 2 + reserve) off the axis x = 0 (the router's own
-- reserve of 10 round a core plus its free band AXIS_FREE 48).
R.CORRIDOR = {min = 80, reserve = 58, zones = {"elandor_highcourt",
	"elandor_ashenward_march", "kragmar_gor_drazhak", "kragmar_bannerbreak_mesa",
	"front_broken_causeway", "front_shattered_line"}}

return R
