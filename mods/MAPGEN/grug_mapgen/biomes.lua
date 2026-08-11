-- Biome layer of the two continents (docs/design/biomes_mobs.md §1.3).
--
-- Kragmar (Throng) is the northern continent (z positive), Elandor (Accord)
-- the southern one (z negative). Every band is authored ONCE in Throng
-- coordinates; `register_mirrored` registers the Throng biome as authored
-- and the Accord biome with the cuboid mirrored at z = 0. The two
-- continents never touch, so a mirrored pair may share heat/humidity
-- points.
--
-- Inside a continent the band cuboids overlap WIDELY (101-450 nodes in x, up
-- to 500 in z) on purpose: in an overlap the heat/humidity voronoi decides
-- per position, which yields the recurring settled/wild patch mosaic of §1.4
-- instead of hard seams. The climate noise that makes the outermost points
-- reachable -- as of WP36 those are grug_jungle_fringe 85/85,
-- grug_deep_jungle 80/88, grug_swamp 60/95 and grug_bone_forest 15/45; the
-- old extremes 95/15, 10/30 (D2) and 90/90 (WP36) are retired, see the
-- blocks below -- and the blend noise that frays the voronoi borders, are
-- set in init.lua.
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
-- bands into SIBLING registrations (grug_deep_forest/_front/_east,
-- grug_badlands/_east), and a sibling is a new biome NAME: every deco list
-- that named the parent must name all of its slabs, or the deco vanishes
-- from the slabs it does not name.
--
-- SECOND LANDMINE, same shape but on the MOB side (biomes_mobs.md §1.5,
-- re-derived by WP36): a sibling costs nothing there as long as it carries
-- its parent's `node_top` -- the spawn gate is `node_top x zone`, never a
-- biome name. A NEW `node_top`, however, is a brand-new set of
-- biome x zone cells with no rows at all. grug_crags_snowy is the standing
-- warning (added in WP18, no spawn row listed default:snowblock, the whole
-- biome was mob-free until WP6); grug_nodes:dirt_with_canopy_litter below is
-- the second case and its rows were derived with it.

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
--   * CENTER_X: the centre band must stop one node short of the side
--     capitals' boxes, whose inner edge is SIDE_X - CAPITAL_R = 350.
--   * SETTLED_X: the side SETTLED bands must stop one node short of the
--     centre capital's box, whose outer edge is CAPITAL_R = 200. Note this
--     is NOT the centre band's own edge (349): letting the two overlap by
--     149 nodes keeps the border a voronoi mosaic. Making them merely
--     contiguous at +-350 would satisfy the guarantee too, but would draw a
--     brand-new ruler-straight 1600-node cuboid face per side per continent
--     right between the capitals -- and no blend noise can soften a cuboid
--     face (it is tested before the climate is read).
--   * WILD_Z_MIN: the centre BACK-country band must leave the box in z.
local WILD_X = CARVE_X + 1 -- 801
local CENTER_X = SIDE_X - CAPITAL_R - 1 -- 349
local SETTLED_X = CAPITAL_R + 1 -- 201
local WILD_Z_MIN = CARVE_Z_MAX + 1 -- 1201
-- Front slab of the DEEP FOREST (the only band with a hole in the middle):
-- from the war coast up to the carve box.
local FRONT_Z_MAX = CARVE_Z_MIN - 1 -- 599

-- Outer x edge of the side bands and of the deep forest -- i.e. of every
-- cuboid that reaches the flanks except the four FLANK-STRIP biomes
-- themselves. The strips x -1500..-1251 (bone forest / crags) and
-- x 1251..1500 (deep jungle / jungle fringe) belong to those biomes ALONE on
-- both continents, and that uncontested strip is the only reason their four
-- extreme climate points (15/45, 25/35, 80/88, 85/85 -- the deep jungle's was
-- 90/90 until WP36) are visible at all:
-- every one of them sits further from the field mean than the biome it would
-- otherwise have to outvote.
local BAND_X_MAX = 1250

-- Lowest y of the land biomes; y 1..4 belongs to the beach, y <= 3 to the
-- ocean (both cover the soft coastline the ocean mask carves -- the mask
-- geometry lives in geometry.lua since WP36, the carve in
-- ocean_mask_mapgen.lua; it was all structures.lua before that).
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
-- ONE cuboid, narrowed to |x| <= 349 (the carve, see the header) and spanning
-- the whole z range of the continent. z_max was 1500 before the rework, which
-- left the wild back-country band the strip |z| 1501..1700 uncontested -- and
-- made the face at z = 1501 a 733-node straight line (measured). Z_MAX instead
-- lets the band contest the whole back country against badlands / deep forest,
-- which is what the patch model of §1.4 asks for anyway; it removes 910 nodes
-- of straight border (12 334 -> 11 424 over 5 seeds) and costs the badlands
-- nothing measurable (0.81 % of the land before the rework, 1.95 % now).
--
-- D4 TRIED AND ROLLED BACK (2026-08-08). The carve only needs the band to be
-- narrow INSIDE the box (|z| 600..1200), so it first shipped as three slabs:
-- a narrow belt slab plus a front and a back slab that kept the band's
-- original |x| <= 700 and therefore a 499-node centre<->side overlap outside
-- the box. That bought wider mosaics but paid for them with four brand-new
-- ruler-straight cuboid faces at |z| = 599 and |z| = 1200 -- right across the
-- middle of both continents, the one line every player walks. Measured over 5
-- seeds with everything else held equal, the three slabs cost exactly 1 500
-- nodes of straight ground border (13 834 vs 12 334) plus 1 592 nodes of
-- deco-only border, i.e. ~3/4 of the whole regression the carve introduced.
-- The overlap is now 149 nodes EVERYWHERE, which is the accepted price: only
-- a smaller CAPITAL_R could buy a wider one, and straight lines were the
-- complaint that started this rework. Do not re-propose the slabs.
--

register_mirrored({
	throng = {
		name = "grug_savanna",
		top = "default:dry_dirt_with_dry_grass",
		filler = "default:dry_dirt",
		x_min = -CENTER_X, x_max = CENTER_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 85, humidity = 35,
	},
	accord = {
		name = "grug_meadows",
		top = "default:dirt_with_grass",
		filler = "default:dirt",
		x_min = -CENTER_X, x_max = CENTER_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 50, humidity = 40,
	},
})

-- grug_deep_forest used to be ONE wide Accord biome spanning the human
-- back-country AND the elf band (§1.3 note): it loses to the settled points
-- inside core/inner and wins uncontested beyond them. It is the only band
-- whose cuboid needs a HOLE IN THE MIDDLE -- the carve box sits inside it on
-- all four sides -- and one box cannot express that, so it ships as three
-- registrations: the back slab (paired with badlands below, same role), the
-- front slab, and the east wing that keeps the elf band covered. That split
-- is required by the CARVE, not by D4, and stays.
--
-- x_max BAND_X_MAX, NOT X_HALF (2026-08-08). All three used to reach x 1500
-- and thereby swallowed grug_jungle_fringe whole: 60/75 sits 12 climate units
-- from the field mean, 85/85 sits 43, so the fringe won 0.08 % of the land and
-- the Accord east flank was deep forest -- no crimson-lotus T3 source on the
-- Accord side (biomes_mobs §2/§6) and Silkfang (§3.3) patrolling outside its
-- named habitat. Capping all three at the settled bands' own outer edge hands
-- the flank strip x 1251..1500 to the fringe uncontested, exactly mirroring
-- deep jungle on the Throng side, and leaves x 1150..1250 as a contested
-- overlap. Measured over 8 seeds: fringe 0.08 % -> 2.71 % of the land (deep
-- jungle, its mirror, has 3.13 %), deep forest 9.9 % -> 8.1 %, T3 lotus supply
-- 3.21 % -> 5.84 %. It costs 393 nodes of straight border (11 031 -> 11 424
-- over 5 seeds) -- 335 for the east wing, 58 for the front/back caps; capping
-- only the east wing would have left the fringe contested wherever
-- |z| <= 599 or |z| >= 1201, i.e. exactly on the two coasts. This is
-- Accord-only: grug_deep_forest has no Throng mirror (the Throng centre-back
-- wild is grug_badlands).
--
-- CLIMATE POINT 95/15 -> 75/20 (D2, 2026-08-08). An overlap only becomes a
-- patch mosaic if BOTH points are reachable by the local noise. Measured
-- over the land columns. NB the field mean is a PER-SEED draw (~50/51
-- +-8.8 over 30 seeds, range 26..67); the numbers below were derived from
-- one seed's 60.9 / 48.8 and are therefore indicative, not robust. sigma
-- 16.8, so 95/15 sat 2.3 / -2.0 sigma out: badlands never won inside its
-- overlap with the savanna and the border collapsed onto the savanna cuboid
-- face as a straight line. 75/20 is still the driest point on the continent
-- and still hot (+1 sigma), but it is 32 climate units from the field mean
-- instead of 48. It keeps exactly 18.0 units of separation from grug_savanna
-- (85/35) -- the same separation as the tightest pre-existing pair (elf
-- forest / deep forest), which is the floor below which a border starts to
-- salt-and-pepper.
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
		x_min = -900, x_max = BAND_X_MAX, z_min = WILD_Z_MIN, z_max = Z_MAX,
		heat = 60, humidity = 75,
	},
})

register_mirrored({
	accord = {
		name = "grug_deep_forest_front",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = -900, x_max = BAND_X_MAX, z_min = Z_MIN, z_max = FRONT_Z_MAX,
		heat = 60, humidity = 75,
	},
})

-- THE EAST WING, both continents (the throng half added by WP36,
-- 2026-08-08). The Accord's centre-back wild (grug_deep_forest) reaches into
-- the ELF band with this slab; until WP36 the Throng's centre-back wild
-- (grug_badlands) had no such wing, so between x 801 and 1250 the only wild
-- registration on the Throng side was grug_deep_jungle -- which then shared
-- its top with grug_jungle_edge (see the deep-jungle block below), leaving
-- 41 % of the continent with a single eligible visual. This block is the
-- empty half of that pair, filled.
--
-- DESIGN DELTA, flagged (docs/design/biomes_mobs.md §1.2/§2 called
-- grug_badlands "band-specific ... Orc area only", the same words used for
-- grug_crags). It is not band-specific any more, exactly as
-- grug_deep_forest is not: a centre-back wild with an east wing is what the
-- Accord has shipped since the carve, and this is its mirror. The doc rows
-- were updated in the same change.
--
-- WHY THE BADLANDS AND NOT A BONE-FOREST WING. §3.2 pairs grug_deep_forest
-- with grug_bone_forest ("universal forest, Throng look"), so a
-- grug_bone_forest_east was the other candidate. Measured over 12 seeds it
-- takes 62.4 % of the x 801..1250 strip and pushes grug_jungle_edge down to
-- 29.3 %, i.e. it would flip the whole Troll east band into a grey dead
-- forest -- its 15/45 point is simply far closer to the field mean than
-- 80/70, and a slab must share its parent's point (grug_deep_forest{,_front,
-- _east} and grug_crags{,_snowy} all do). grug_badlands' 75/20 measures at
-- 35.6 % of the strip against jungle edge 52.5 %, which is within a point of
-- the Accord mirror (grug_deep_forest_east + its siblings 36.1 %, elf forest
-- 54.3 %). Same node, same flora, same mob roster as the parent, so no spawn
-- row, no ore row and no new climate point are needed.
register_mirrored({
	throng = {
		name = "grug_badlands_east",
		top = "grug_nodes:mesa_clay",
		filler = "grug_nodes:mesa_clay",
		x_min = WILD_X, x_max = BAND_X_MAX, z_min = Z_MIN, z_max = Z_MAX,
		heat = 75, humidity = 20,
	},
	accord = {
		name = "grug_deep_forest_east",
		top = "grug_nodes:dirt_with_forest_litter",
		filler = "default:dirt",
		x_min = WILD_X, x_max = BAND_X_MAX, z_min = Z_MIN, z_max = Z_MAX,
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
		x_min = -BAND_X_MAX, x_max = -SETTLED_X, z_min = Z_MIN, z_max = Z_MAX,
		heat = 25, humidity = 20,
	},
	accord = {
		name = "grug_pine_hills",
		top = "default:dirt_with_coniferous_litter",
		filler = "default:dirt",
		x_min = -BAND_X_MAX, x_max = -SETTLED_X, z_min = Z_MIN, z_max = Z_MAX,
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
-- deep jungle (T) / jungle fringe (A).
--
-- WP36 shipped the fringe with the grug_jungle_edge top while the old design
-- phrase "the troll jungle" was ambiguous. The named-zone target has since
-- resolved that ambiguity: WP40 assigns grug_jungle_fringe the deep-jungle
-- canopy-litter top (docs/design/biomes_mobs.md §1.3). This legacy global
-- biome registry stays unchanged until WP40 replaces its placement model.
--

register_mirrored({
	throng = {
		name = "grug_jungle_edge",
		top = "default:dirt_with_rainforest_litter",
		filler = "default:dirt",
		x_min = SETTLED_X, x_max = BAND_X_MAX, z_min = Z_MIN, z_max = Z_MAX,
		heat = 80, humidity = 70,
	},
	accord = {
		name = "grug_elf_forest",
		top = "grug_nodes:dirt_with_silver_litter",
		filler = "default:dirt",
		x_min = SETTLED_X, x_max = BAND_X_MAX, z_min = Z_MIN, z_max = Z_MAX,
		heat = 70, humidity = 60,
	},
})

-- grug_jungle_fringe's point NOT MOVED: it lives off its flank strip. 85/85
-- is one of the two points furthest from the field mean (per-seed draw, see
-- the note at the top of this file), so it cannot win a contested overlap
-- against anything: it exists only because x 1251..1500 (BAND_X_MAX + 1
-- upward) is its alone. The Accord half only got that strip on 2026-08-08,
-- when the three deep-forest registrations were capped at BAND_X_MAX -- until
-- then they reached x 1500 and the fringe won 0.08 % of the land, i.e. the
-- Accord east flank was deep forest and the Accord had no crimson-lotus T3
-- source at all (see the deep-forest block above). x_min stays at 1150, i.e.
-- 101 nodes further in than the strip, so the inner border is still a voronoi
-- mosaic against elf forest and deep forest rather than a bare cuboid face.
--
-- grug_deep_jungle: OWN node_top AND OWN CLIMATE POINT since WP36
-- (2026-08-08). Two separate defects, one block.
--
--  1. THE TOP. It used to ship `default:dirt_with_rainforest_litter`, the
--     same top as grug_jungle_edge (x 201..1250) -- and nothing else reaches
--     x 350..1500 outside |z| 1201..1700. Measured with tools/biomecheck:
--     41.1 % of Throng land had exactly ONE eligible node_top, against
--     29.5 % of the Accord land, whose mirror position carries
--     grug_deep_forest_east with a different top. The fringe keeps the
--     rainforest litter -- that is what WP36 SHIPS. WP40's decided target is
--     the deep-jungle canopy-litter top; see the east-band header above.
--     Until then this is the only mirrored pair whose two halves differ,
--     which is what every other pair in this file already does.
--
--  2. THE POINT, 90/90 -> 80/88. 90/90 sat +1.8 / +2.2 sigma from the field
--     mean and lost EVERY contested column: measured over 12 seeds it won
--     0.00 % of the land inside x <= 1250, i.e. the whole biome was the
--     uncontested flank strip and nothing else. 80/88 is exactly 18.0
--     climate units from grug_jungle_edge (80/70) -- the hard floor of §1.3,
--     the same separation grug_badlands keeps against grug_savanna -- so the
--     border between them is the single line humidity = 79, which the blend
--     noise (scale 4, i.e. at most 8 units of displacement per axis, well
--     under half the floor) frays into a mosaic. Separation from grug_swamp
--     (60/95, shares y 4..6 with this cuboid) is 21.2, from grug_beach
--     (50/55, shares y = 4) 44.6, from grug_badlands_east (75/20) 68.2.
--     Result over 12 seeds (this world's seed plus the first eleven of
--     tools/biomecheck/crossseed.py's deterministic list; re-measured
--     2026-08-08 after three conflicting figures had been written down):
--     0.1 % -> 6.9 % of its OWN land sits inside the contested x <= 1250,
--     0.0 % -> 2.7 % of that strip is won against grug_jungle_edge, and the
--     total land share goes 5.30 % -> 5.84 %. Same numbers in
--     biomes_mobs.md §1.3/§1.4 -- do not let them drift apart again.
register_mirrored({
	throng = {
		name = "grug_deep_jungle",
		top = "grug_nodes:dirt_with_canopy_litter",
		filler = "default:dirt",
		x_min = WILD_X, x_max = X_HALF, z_min = Z_MIN, z_max = Z_MAX,
		heat = 80, humidity = 88,
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
