-- Biome layer of the two continents (docs/design/biomes_mobs.md §1.3).
--
-- Kragmar (Throng) is the northern continent (z positive), Elandor (Accord)
-- the southern one (z negative). Every band is authored ONCE in Throng
-- coordinates; `register_mirrored` registers the Throng biome as authored
-- and the Accord biome with the cuboid mirrored at z = 0. The two
-- continents never touch, so a mirrored pair may share heat/humidity
-- points.
--
-- Inside a continent the band cuboids overlap WIDELY (150-500 nodes) on
-- purpose: in an overlap the heat/humidity voronoi decides per position,
-- which yields the recurring settled/wild patch mosaic of §1.4 instead of
-- hard seams. The climate noise that makes the outermost points (90/90,
-- 15/45, 60/95) reachable, and the blend noise that frays the voronoi
-- borders, are set in init.lua.
--
-- THE CAPITAL GUARANTEE (world.md §3, decided 2026-08-08). Every capital
-- must sit in its own race biome. Climate-point tuning cannot do that: with
-- spread 1000 over a 3000x1600 continent there are only ~5 independent
-- large-octave samples per continent, so the climate at a capital is a coin
-- flip of the world seed (measured: the intended biome won at 22-63 % of 400
-- seeds at four of the six anchors). The cuboid test, in contrast, runs
-- BEFORE any noise is read (`BiomeGenOriginal::calcBiomeFromNoise`,
-- mg_biome.cpp:238-244 filters on the raw integer position), so geometry is
-- a containment proof and seed-robust.
--
-- Hence the CARVE BOX below: inside |x| <= CARVE_X, CARVE_Z_MIN <= |z| <=
-- CARVE_Z_MAX no band may be eligible except the one that owns the capital
-- it contains. That leaves a guaranteed radius CAPITAL_R = 200 around every
-- one of the six anchors in which exactly ONE registration is eligible, so
-- the voronoi has nothing to choose from.
--
-- LANDMINE (AGENTS.md): ore/decoration defs whose `biomes` names do not
-- resolve are silently unrestricted world-wide -- decorations.lua and
-- ores.lua may only name biomes registered in this file. The carve splits
-- three bands into SIBLING registrations (grug_savanna/_front/_back,
-- grug_meadows/_front/_back, grug_deep_forest/_front/_east), and a sibling
-- is a new biome NAME: every deco list that named the parent must name all
-- of its slabs, or the deco vanishes from the slabs it does not name.

local X_HALF = grug_core.CONTINENT_X_HALF -- 1500
local Z_MIN = grug_core.CONTINENT_Z_MIN -- 100
local Z_MAX = grug_core.CONTINENT_Z_MAX -- 1700

-- Guaranteed radius around every capital anchor (world.md §3). The
-- theoretical maximum is 274 -- two neighbouring capitals are 550 apart --
-- and 200 is the value D1 picked: it costs a 1600 x 600 carve box per
-- continent (~20 % of the land), which is exactly the civilization gradient
-- of world.md §1 ("safe core + inner ring carry the settled race biomes").
local CAPITAL_R = 200
-- |x| of the two side capitals; the centre pair sits at x = 0.
local SIDE_X = math.abs(grug_core.capitals.dwarf.x) -- 550

-- The carve box. Half-width 800 = SIDE_X + CAPITAL_R + 50 nodes of slack;
-- z 600..1200 brackets the capital row at |z| = 900 with the same slack.
local CARVE_X = 800
local CARVE_Z_MIN = 600
local CARVE_Z_MAX = 1200

-- Derived band edges -- all four follow from the carve box and CAPITAL_R,
-- nothing here is a free number:
--   * WILD_X: the side WILD bands must leave the carve box entirely.
--   * BELT_X: inside the box the centre band must stop one node short of the
--     side capitals' boxes, whose inner edge is SIDE_X - CAPITAL_R = 350.
--   * SETTLED_X: the side SETTLED bands must stop one node short of the
--     centre capital's box, whose outer edge is CAPITAL_R = 200. Note this
--     is NOT the centre band's own edge (349): letting the two overlap by
--     149 nodes inside the belt keeps the border a voronoi mosaic. Making
--     them merely contiguous at +-350 would satisfy the guarantee too, but
--     would draw a brand-new ruler-straight 600-node cuboid face per side
--     per continent right between the capitals -- and no blend noise can
--     soften a cuboid face (it is tested before the climate is read).
--   * WILD_Z_MIN: the centre BACK-country band must leave the box in z.
local WILD_X = CARVE_X + 1 -- 801
local BELT_X = SIDE_X - CAPITAL_R - 1 -- 349
local SETTLED_X = CAPITAL_R + 1 -- 201
local WILD_Z_MIN = CARVE_Z_MAX + 1 -- 1201
-- Front slab of the centre band: from the war coast up to the carve box.
local FRONT_Z_MAX = CARVE_Z_MIN - 1 -- 599

-- Lowest y of the land biomes; y 1..4 belongs to the beach, y <= 3 to the
-- ocean (both cover the soft coastline the ocean mask carves, structures.lua).
local LAND_Y_MIN = 4
local SKY = 31000

local dungeon_nodes = {
	node_dungeon = "default:cobble",
	node_dungeon_alt = "default:mossycobble",
	node_dungeon_stair = "stairs:stair_cobble",
}

-- One half of a mirrored pair. `def` is always authored in THRONG
-- coordinates (z positive); side = -1 mirrors the cuboid to Elandor.
local function register_side(def, side)
	local z_min, z_max = def.z_min, def.z_max
	if side < 0 then
		z_min, z_max = -def.z_max, -def.z_min
	end
	core.register_biome({
		name = def.name,
		node_top = def.top,
		depth_top = def.top_depth or 1,
		node_filler = def.filler,
		depth_filler = def.filler_depth or 3,
		node_dust = def.dust,
		node_riverbed = "default:sand",
		depth_riverbed = 2,
		node_dungeon = dungeon_nodes.node_dungeon,
		node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
		node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
		min_pos = {x = def.x_min, y = def.y_min or LAND_Y_MIN, z = z_min},
		max_pos = {x = def.x_max, y = def.y_max or SKY, z = z_max},
		heat_point = def.heat,
		humidity_point = def.humidity,
	})
end

-- Registers one row of the §1.3 table: the Throng biome plus its Accord
-- mirror. Each side carries its OWN name, climate point and (where the
-- table says so) its own x/z range -- the bands are only geometrically
-- mirrored, never identical.
local function register_mirrored(row)
	if row.throng then
		register_side(row.throng, 1)
	end
	if row.accord then
		register_side(row.accord, -1)
	end
end

--
-- Center band: Orc savanna (T) / Human meadows (A), plus their wild
-- back-country variants badlands (T) / deep forest (A).
--
-- NB the settled cuboids start at Z_MIN (100) instead of the table's 160:
-- the war coast (|z| 100..300) does carry land above y = 4 wherever the
-- coast noise inset is small, and a z-range starting at 160 would leave
-- that land without ANY biome (bare stone, no decorations, no spawn
-- surface). Same reason for every band below.
--
-- THREE SLABS instead of one cuboid (the carve, see the header): the belt
-- slab is narrow (|x| <= 349) so it cannot reach the side capitals, while
-- the front and back slabs keep the band's full |x| <= 700 outside the carve
-- box -- that is where the wide (499-node) centre<->side overlaps of §1.3
-- live (the shipped single cuboid only had 201). Inside the belt the overlap
-- is 149 nodes, the widest the guarantee allows: measured that is worth
-- ~4700 nodes of wandering border against the contiguous +-350 alternative,
-- but it is still too narrow for the spread-1000 climate field to cross
-- INSIDE it often, so most of the belt border does sit on one of its two
-- faces. Cuboids cannot do better; only R itself could buy more.
--

register_mirrored({
	throng = {
		name = "grug_savanna",
		top = "default:dry_dirt_with_dry_grass",
		filler = "default:dry_dirt",
		x_min = -BELT_X, x_max = BELT_X,
		z_min = CARVE_Z_MIN, z_max = CARVE_Z_MAX,
		heat = 85, humidity = 35,
	},
	accord = {
		name = "grug_meadows",
		top = "default:dirt_with_grass",
		filler = "default:dirt",
		x_min = -BELT_X, x_max = BELT_X,
		z_min = CARVE_Z_MIN, z_max = CARVE_Z_MAX,
		heat = 50, humidity = 40,
	},
})

register_mirrored({
	throng = {
		name = "grug_savanna_front",
		top = "default:dry_dirt_with_dry_grass",
		filler = "default:dry_dirt",
		x_min = -700, x_max = 700, z_min = Z_MIN, z_max = FRONT_Z_MAX,
		heat = 85, humidity = 35,
	},
	accord = {
		name = "grug_meadows_front",
		top = "default:dirt_with_grass",
		filler = "default:dirt",
		x_min = -700, x_max = 700, z_min = Z_MIN, z_max = FRONT_Z_MAX,
		heat = 50, humidity = 40,
	},
})

register_mirrored({
	throng = {
		name = "grug_savanna_back",
		top = "default:dry_dirt_with_dry_grass",
		filler = "default:dry_dirt",
		x_min = -700, x_max = 700, z_min = WILD_Z_MIN, z_max = 1500,
		heat = 85, humidity = 35,
	},
	accord = {
		name = "grug_meadows_back",
		top = "default:dirt_with_grass",
		filler = "default:dirt",
		x_min = -700, x_max = 700, z_min = WILD_Z_MIN, z_max = 1500,
		heat = 50, humidity = 40,
	},
})

-- grug_deep_forest used to be ONE wide Accord biome spanning the human
-- back-country AND the elf band (§1.3 note): it loses to the settled points
-- inside core/inner and wins uncontested beyond them. It is the only band
-- whose cuboid needs a HOLE IN THE MIDDLE -- the carve box sits inside it on
-- all four sides -- and one box cannot express that, so it ships as three
-- registrations: the back slab (paired with badlands below, same role), the
-- front slab, and the east wing that keeps the elf band covered.
--
-- CLIMATE POINT 95/15 -> 75/20 (D2, 2026-08-08). An overlap only becomes a
-- patch mosaic if BOTH points are reachable by the local noise. Measured
-- over the land columns the field has mean 60.9 / 48.8 and sigma 14.7 /
-- 16.8, so 95/15 sat 2.3 / -2.0 sigma out: badlands never won inside its
-- 300-node overlap with the savanna back slab and the border collapsed onto
-- the savanna cuboid face at z = 1501 as a straight line. 75/20 is still the
-- driest point on the continent and still hot (+1 sigma), but it is 32
-- climate units from the field mean instead of 48. It keeps exactly 18.0
-- units of separation from grug_savanna (85/35) -- the same separation as
-- the tightest pre-existing pair (elf forest / deep forest), which is the
-- floor below which a border starts to salt-and-pepper.
--
register_mirrored({
	throng = {
		name = "grug_badlands",
		top = "grug_nodes:mesa_clay",
		filler = "grug_nodes:mesa_clay",
		x_min = -700, x_max = 700, z_min = WILD_Z_MIN, z_max = Z_MAX,
		heat = 75, humidity = 20,
	},
	accord = {
		name = "grug_deep_forest",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = -900, x_max = X_HALF, z_min = WILD_Z_MIN, z_max = Z_MAX,
		heat = 60, humidity = 75,
	},
})

register_mirrored({
	accord = {
		name = "grug_deep_forest_front",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = -900, x_max = X_HALF, z_min = Z_MIN, z_max = FRONT_Z_MAX,
		heat = 60, humidity = 75,
	},
})

register_mirrored({
	accord = {
		name = "grug_deep_forest_east",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = WILD_X, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 60, humidity = 75,
	},
})

--
-- West band: Undead blight (T) / Dwarf pine hills (A), wild variants
-- bone forest (T) / crags (A).
--

register_mirrored({
	throng = {
		name = "grug_blight",
		top = "grug_nodes:blight_dirt",
		filler = "default:dirt",
		x_min = -1250, x_max = -SETTLED_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 25, humidity = 20,
	},
	accord = {
		name = "grug_pine_hills",
		top = "default:dirt_with_coniferous_litter",
		filler = "default:dirt",
		x_min = -1250, x_max = -SETTLED_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 30, humidity = 60,
	},
})

-- NOT moved by D2 (checked 2026-08-08): bone forest 15/45 and blight 25/20
-- are both ~46 climate units from the field mean, i.e. the only pair in the
-- world that already contests its overlap symmetrically -- pulling either one
-- inward would simply hand the whole Throng west to the winner.
register_mirrored({
	throng = {
		name = "grug_bone_forest",
		top = "grug_nodes:dirt_with_bone_litter",
		filler = "default:dirt",
		x_min = -X_HALF, x_max = -WILD_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 15, humidity = 45,
	},
	accord = {
		-- Gravel tops over stone: the bare high crags of the Dwarf band.
		--
		-- CLIMATE POINT 10/30 -> 25/35 (D2, 2026-08-08, same reasoning as
		-- badlands above). 10/30 was -3.5 / -1.1 sigma from the field mean,
		-- which is why crags <-> pine hills had the full overlap AND the
		-- single worst straight line in the world (the whole x = -1250 face).
		-- 25/35 sits 38.5 units from the mean against pine hills' 32.9, so
		-- the two now split their 450-node overlap almost evenly instead of
		-- one of them taking all of it: measured, the border splits 672
		-- nodes on the x = -1250 face and 600 on the x = -800 face with real
		-- mosaic in between, where it used to be 1132 straight nodes on one
		-- face. Not moved further (the paper floated 35/40): past ~30/38
		-- crags gets CLOSER to the field mean than pine hills and takes over
		-- the dwarf band. Separation from pine hills (30/60) is 25.5.
		name = "grug_crags",
		top = "default:gravel",
		filler = "default:gravel",
		filler_depth = 2,
		x_min = -X_HALF, x_max = -WILD_X, z_min = Z_MIN, z_max = Z_MAX,
		y_max = 79,
		heat = 25, humidity = 35,
	},
})

-- Cheap alpine cap (WP18 addition, not in the §1.3 table): the crags cuboid
-- and climate point once more, snow-topped above y = 80, so the high peaks
-- read as alpine without any extra noise machinery.
register_mirrored({
	accord = {
		name = "grug_crags_snowy",
		top = "default:snowblock",
		filler = "default:gravel",
		filler_depth = 2,
		dust = "default:snow",
		x_min = -X_HALF, x_max = -WILD_X, z_min = Z_MIN, z_max = Z_MAX,
		y_min = 80,
		heat = 25, humidity = 35,
	},
})

--
-- East band: Troll jungle edge (T) / Elf forest (A), wild variants
-- deep jungle (T) / jungle fringe (A, the same nodes as the troll jungle
-- one-to-one, §8.4).
--

register_mirrored({
	throng = {
		name = "grug_jungle_edge",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = SETTLED_X, x_max = 1250, z_min = Z_MIN, z_max = Z_MAX,
		heat = 80, humidity = 70,
	},
	accord = {
		name = "grug_elf_forest",
		top = "grug_nodes:dirt_with_silver_litter",
		filler = "default:dirt",
		x_min = SETTLED_X, x_max = 1250, z_min = Z_MIN, z_max = Z_MAX,
		heat = 70, humidity = 60,
	},
})

-- NOT moved by D2 either. deep jungle 90/90 wins its own flank strip
-- (x 1251..1500) uncontested, so its distance from the field mean costs it
-- nothing. grug_jungle_fringe 85/85 is the one point where that is NOT true:
-- it shares its whole cuboid with the deep-forest east wing, whose 60/75 sits
-- far closer to the mean, so the fringe wins only 0.08 % of the land -- the
-- Accord side effectively has no jungle fringe at all. That is PRE-EXISTING
-- (measured the same on the shipped registrations) and it is not fixable by
-- moving the point: any point close enough to the mean to beat 60/75 is no
-- longer a rainforest climate. The fix is geometric (cap the east wing at
-- x 1250 and leave the flank strip to the fringe) and belongs to its own
-- pass -- it changes shares, level continuity (§1.5) and the T3 herb supply.
register_mirrored({
	throng = {
		name = "grug_deep_jungle",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = WILD_X, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 90, humidity = 90,
	},
	accord = {
		name = "grug_jungle_fringe",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = 1150, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 85, humidity = 85,
	},
})

--
-- Universal biomes. A biome name can only be registered once, so the three
-- shared ones get ONE registration with a z-symmetric cuboid instead of a
-- mirrored pair (doc delta to §1.3, which lists them per continent).
--

-- Swamp pockets: low terrain anywhere on either continent. The extreme
-- humidity point keeps them rare and tied to the wet noise regions.
--
-- ACCEPTED RESIDUAL OF THE CAPITAL GUARANTEE (D5, world.md §3): swamp and
-- beach are the only land biomes NOT carved -- they are universal and
-- x/z-unlimited, so a capital whose terrain surface lands at y <= 6 can
-- still come up swamp (or beach at y <= 4) instead of its race biome.
-- Measured over 50 seeds: ~30 % of the +-200 box at y 5..6, ~75 % at y 4.
-- Accepted rather than split both into z-slabs as well: the terrain
-- baseline is lifted 6..10 nodes above sea level (init.lua), so a capital
-- that low is a corner case, and the fix would cost six more registrations
-- plus their deco lists.
core.register_biome({
	name = "grug_swamp",
	node_top = "grug_nodes:mud",
	depth_top = 1,
	node_filler = "grug_nodes:mud",
	depth_filler = 2,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	min_pos = {x = -X_HALF, y = 1, z = -Z_MAX},
	max_pos = {x = X_HALF, y = 6, z = Z_MAX},
	heat_point = 60,
	humidity_point = 95,
})

-- Shoreline fringe. The ocean mask carves a wandering coastline INSIDE the
-- continent rectangle: the coast noise insets the rectangle by 0..150 nodes
-- and the waterline sits ~30 nodes further in, so the shore wanders up to
-- ~180 nodes deep and the sand-capped beach band up to ~190. The beach
-- therefore covers the whole outer band of the rectangle, not just its edge.
core.register_biome({
	name = "grug_beach",
	node_top = "default:sand",
	depth_top = 1,
	node_filler = "default:sand",
	depth_filler = 2,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	min_pos = {x = -X_HALF, y = 1, z = -Z_MAX},
	max_pos = {x = X_HALF, y = 4, z = Z_MAX},
	heat_point = 50,
	humidity_point = 55,
})

-- ONE sand-bottom ocean for the whole world, x/z UNLIMITED (doc delta to
-- §1.3, which caps it at the continent rectangles): the strait, the coastal
-- ocean and the open sea are all outside every land cuboid, and without an
-- unlimited ocean they would have no biome at all -- no seabed filler, no
-- dungeon nodes, no cave liquid.
core.register_biome({
	name = "grug_ocean",
	node_top = "default:sand",
	depth_top = 1,
	node_filler = "default:sand",
	depth_filler = 3,
	node_riverbed = "default:sand",
	depth_riverbed = 2,
	node_cave_liquid = "default:water_source",
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	vertical_blend = 1,
	y_max = 3,
	y_min = -255,
	heat_point = 50,
	humidity_point = 50,
})

-- One shared underground biome below everything (cave content).
core.register_biome({
	name = "grug_underground",
	node_cave_liquid = {"default:water_source", "default:lava_source"},
	node_dungeon = dungeon_nodes.node_dungeon,
	node_dungeon_alt = dungeon_nodes.node_dungeon_alt,
	node_dungeon_stair = dungeon_nodes.node_dungeon_stair,
	y_max = -256,
	y_min = -31000,
	heat_point = 50,
	humidity_point = 50,
})
