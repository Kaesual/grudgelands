-- Round 36 lane W: the decor kit for POIs, start towns and capitals.
--
-- Two things, both data driven and built on the WP13 dressing vocabulary so
-- a POI is dressed in the same hand as the start towns:
--
--   * PIECES, small authored props (a well, a crafting corner, a lantern
--     post, a battlefield's banner pole, a lair's nest ...). A piece is called
--     as `M.piece(brush, kind, x, z, face)`; (x, z) is its anchor cell on the
--     ground course and `face` the facedir its front looks along (0 = +z,
--     1 = +x, 2 = -z, 3 = -x). Every node comes from the race's WP13 palette
--     (`palette.lua`) or the race row of `RACE` below, so a dwarf well looks
--     dwarf.
--   * HOUSE DRESSING, the small touches a building gets from its own door,
--     walls and windows: a torch beside the door where it has none, a barrel
--     or a bench on the door's wall, flowers under a window, a wood pile or a
--     barrel against a side wall (`M.dress_house`).
--
-- Pieces write into a `M.view` over a plain put/get builder (the Round 14
-- and Round 20 POIs); the house touches also into a WP13 buffer. A WP13
-- buffer refuses a lying log (`parts.param2_kind` knows no log as facedir),
-- so the pieces that lay one (palisade, fallen banner, burnt cart, remains,
-- ore cart) are for the views. Pure Lua 5.1, no engine calls,
-- no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local palettes = dofile(directory .. "/palette.lua")

	local M = {}

	-- Per race, the few decor nodes a WP13 palette does not bind: the plant a
	-- house keeps under its window (the race's own `flower` where it has
	-- one), the colour of its war banners and the soil of a fresh grave.
	M.RACE = {
		dwarf = {pot = "grug_decor:xdecor_potted_geranium",
			pot_alt = "grug_decor:xdecor_potted_dandelion_white",
			banner = "wool:red", grave = "default:gravel"},
		human = {banner = "wool:red", grave = "default:gravel"},
		elf = {banner = "wool:green", grave = "default:silver_sand"},
		undead = {pot = "grug_decor:xdecor_potted_tulip_black",
			pot_alt = "grug_decor:xdecor_potted_viola",
			banner = "wool:black", grave = "grug_nodes:blight_dirt"},
		orc = {pot = "grug_decor:xdecor_potted_tulip",
			pot_alt = "grug_decor:xdecor_potted_rose",
			banner = "wool:red", grave = "default:gravel"},
		troll = {pot = "grug_decor:xdecor_potted_chrysanthemum_green",
			pot_alt = "grug_decor:xdecor_potted_dandelion_yellow",
			banner = "wool:green", grave = "default:gravel"},
	}

	-- The nodes the pieces name directly (no palette role carries them).
	local N = {
		mat = "grug_decor:cottages_straw_mat",
		bones = "grug_nodes:bone_pile",
		cobweb = "grug_decor:xdecor_cobweb",
		shrub = "default:dry_shrub",
		char = "default:coalblock",
		ash = "default:gravel",
		mud = "grug_nodes:mud",
		candle = "grug_decor:xdecor_candle",
	}
	M.NODES = N

	-- A WP13 buffer view over a builder that only has `put(x, y, z, name,
	-- param2)` and `get(x, y, z) -> cell or nil`. A missing param2 takes the
	-- engine's own placement value, as `Buffer:put` does.
	function M.view(put, get)
		local view = {}
		function view:put(x, y, z, name, param2)
			put(x, y, z, name, param2 or parts.place_param2(name))
		end
		function view:at(x, y, z) return get(x, y, z) end
		function view:fill(x1, y1, z1, x2, y2, z2, name, param2)
			for z = z1, z2 do for y = y1, y2 do for x = x1, x2 do
				self:put(x, y, z, name, param2)
			end end end
		end
		function view:clear(x1, y1, z1, x2, y2, z2)
			self:fill(x1, y1, z1, x2, y2, z2, parts.AIR, 0)
		end
		return view
	end

	-- A brush: where the pieces paint and with what.
	--   buf      a WP13 buffer or `M.view`
	--   race     the composition's race
	--   palette  optional WP13 palette (default: the race's own)
	--   lights   optional list the light cells are appended to
	function M.brush(buf, race, palette, lights)
		local extra = M.RACE[race]
		if extra == nil then error("decor kit: unknown race " .. tostring(race), 0) end
		return {buf = buf, race = race, palette = palette or palettes.new(race),
			extra = extra, lights = lights or {}}
	end

	local function empty(buf, x, y, z)
		local cell = buf:at(x, y, z)
		return cell == nil or cell.name == parts.AIR
	end

	local function light(brush, x, y, z)
		brush.lights[#brush.lights + 1] = {x = x, y = y, z = z}
	end

	-- A log lying along the step (dx, dz).
	local function lying(dx)
		return dx ~= 0 and 12 or 4
	end

	-- The plant a race keeps in a pot: its own flowers, else the kit's.
	local function pot(brush, alt)
		local p = brush.palette
		if alt then
			return p.maybe("flower_alt") or p.maybe("flower") or brush.extra.pot_alt or
				brush.extra.pot
		end
		return p.maybe("flower") or brush.extra.pot
	end
	M.pot = pot

	-- The pieces. `at(u, v)` turns piece-local offsets (u to the right of the
	-- front, v along it) into world x, z.
	local P = {}
	M.PIECES = P

	local function frame(x, z, face)
		local fx, fz = parts.facedir_step(face)
		local rx, rz = parts.facedir_step(face + 1)
		return function(u, v) return x + u * rx + v * fx, z + u * rz + v * fz end, rx, rz
	end

	local function seat(brush, x, z, face)
		local bench = brush.palette.maybe("bench_seat")
		if bench then
			brush.buf:put(x, 1, z, bench, (face + 2) % 4)
		else
			parts.seat(brush.buf, brush.palette, x, 1, z, face)
		end
	end

	-- Settlement pieces --------------------------------------------------

	-- A dry draw well with its lamp (dressing.well), 3 x 3 round (x, z).
	function P.well(brush, x, z)
		dressing.well(brush.buf, brush.palette, x, z, brush.lights)
	end

	-- A lantern post: the race's hanging lamp under an arm, or a torch post.
	function P.lamp(brush, x, z)
		dressing.lantern_post(brush.buf, brush.palette, x, z, brush.lights)
	end

	-- A torch on a short post.
	function P.torch(brush, x, z)
		dressing.path_light(brush.buf, brush.palette, x, z, brush.lights)
	end

	-- A bench of `len` (default 3) seats looking along `face`.
	function P.bench(brush, x, z, face, len)
		local at = frame(x, z, face)
		for u = 0, (len or 3) - 1 do
			local cx, cz = at(u, 0)
			seat(brush, cx, cz, face)
		end
	end

	-- Stores: a barrel, two stacked and one with a board on it in a row, one
	-- barrel behind them.
	function P.stores(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		local ax, az = at(-1, 0)
		buf:put(ax, 1, az, p.node("storage"))
		ax, az = at(0, 0)
		buf:put(ax, 1, az, p.node("storage"))
		buf:put(ax, 2, az, p.node("storage"))
		ax, az = at(1, 0)
		buf:put(ax, 1, az, p.node("storage"))
		buf:put(ax, 2, az, p.node("table_top"))
		ax, az = at(0, -1)
		buf:put(ax, 1, az, p.node("storage"))
	end

	-- A crafting corner: the race's workbench between a wood pile and a
	-- barrel of stock, a table to set work down on.
	function P.craft(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		local cx, cz = at(0, 0)
		buf:put(cx, 1, cz, p.node("workbench"))
		cx, cz = at(1, 0)
		parts.table_cell(buf, p, cx, 1, cz)
		cx, cz = at(-1, 0)
		buf:put(cx, 1, cz, p.node("tree_log"))
		buf:put(cx, 2, cz, p.node("tree_log"))
		buf:put(cx, 3, cz, p.node("roof_slab"))
		cx, cz = at(2, 0)
		buf:put(cx, 1, cz, p.node("storage"))
	end

	-- A purposeful wood pile of `len` (default 3) along the right hand.
	function P.woodpile(brush, x, z, face, len)
		local at = frame(x, z, face)
		for u = 0, (len or 3) - 1 do
			local cx, cz = at(u, 0)
			brush.buf:put(cx, 1, cz, brush.palette.node("tree_log"))
			brush.buf:put(cx, 2, cz, brush.palette.node("tree_log"))
			brush.buf:put(cx, 3, cz, brush.palette.node("roof_slab"))
		end
	end

	-- A flower bed of (2w+1) x 3 round (x, z): a kerb sown with the race's
	-- pot plants (dressing.flower_bed), its own pots where the palette has
	-- none.
	function P.flowers(brush, x, z, face, w)
		w = w or 2
		local at = frame(x, z, face)
		local x1, z1 = at(-w, -1)
		local x2, z2 = at(w, 1)
		local lx, hx = math.min(x1, x2), math.max(x1, x2)
		local lz, hz = math.min(z1, z2), math.max(z1, z2)
		local p = brush.palette
		for cz = lz, hz do for cx = lx, hx do
			if cx == lx or cx == hx or cz == lz or cz == hz then
				brush.buf:put(cx, 1, cz, p.node("planter"))
			else
				brush.buf:put(cx, 1, cz, p.node("planter_soil"))
				brush.buf:put(cx, 2, cz, pot(brush, (cx + cz) % 2 == 1))
			end
		end end
	end

	-- A kitchen garden: furrows and crop rows where the race ploughs, a
	-- planted bed of tufts where it does not, (2w+1) x 4, behind a short
	-- fence on its front edge.
	function P.garden(brush, x, z, face, w)
		w = w or 2
		local at = frame(x, z, face)
		local x1, z1 = at(-w, 0)
		local x2, z2 = at(w, -3)
		local lx, hx = math.min(x1, x2), math.max(x1, x2)
		local lz, hz = math.min(z1, z2), math.max(z1, z2)
		local p = brush.palette
		if p.maybe("crop") then
			dressing.crop_rows(brush.buf, p, lx, lz, hx, hz,
				(face % 2 == 0) and "z" or "x")
		else
			for cz = lz, hz do for cx = lx, hx do
				brush.buf:put(cx, 0, cz, p.node("planter_soil"))
				if (cx + cz) % 2 == 0 then
					local name = p.node((cx * 3 + cz) % 4 == 0 and "fern" or "grass_tuft")
					brush.buf:put(cx, 1, cz, name, parts.place_param2(name))
				end
			end end
		end
		for u = -w, w do
			local cx, cz = at(u, 1)
			brush.buf:put(cx, 1, cz, p.node("fence"))
		end
	end

	-- A hand cart along the right hand (dressing.handcart): bearers, the
	-- wheels where the race has them, a barrel riding on it.
	function P.cart(brush, x, z, face)
		local _, rx = frame(x, z, face)
		dressing.handcart(brush.buf, brush.palette, x, z, rx ~= 0 and "x" or "z")
	end

	-- A stack of bales (human, orc) or a covered crate.
	function P.bales(brush, x, z)
		if not dressing.bale_stack(brush.buf, brush.palette, x, z, 2) then
			dressing.crates(brush.buf, brush.palette, x, z, 0)
		end
	end

	-- A notice post.
	function P.sign(brush, x, z)
		dressing.signpost(brush.buf, brush.palette, x, z)
	end

	-- Battlefield pieces -------------------------------------------------

	-- A banner pole: a post with the race's colours hanging off its head and
	-- a torch on top.
	function P.banner(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for y = 1, 4 do buf:put(x, y, z, p.node("post")) end
		local cx, cz = at(1, 0)
		buf:put(cx, 4, cz, brush.extra.banner)
		parts.floor_torch(buf, p, x, 5, z)
		light(brush, x, 5, z)
	end

	-- A banner thrown down: its pole lying along the right hand, the cloth
	-- crumpled on the ground at its head.
	function P.fallen_banner(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = 0, 2 do
			local cx, cz = at(u, 0)
			buf:put(cx, 1, cz, p.node("post"), lying(rx))
		end
		local cx, cz = at(3, 0)
		buf:put(cx, 1, cz, N.mat)
		cx, cz = at(3, 1)
		buf:put(cx, 1, cz, N.mat)
	end

	-- A broken palisade along the right hand: stakes of uneven height, one
	-- gap, and the stake that fell lying in front.
	local STAKES = {3, 3, 2, 0, 3}
	function P.palisade(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		local cap = p.maybe("stake_cap")
		for u = 0, #STAKES - 1 do
			local h = STAKES[u + 1]
			local cx, cz = at(u, 0)
			for y = 1, h do buf:put(cx, y, cz, p.node("post")) end
			if cap and h >= 2 then buf:put(cx, h + 1, cz, cap) end
		end
		for u = 1, 2 do
			local cx, cz = at(u, 1)
			buf:put(cx, 1, cz, p.node("post"), lying(rx))
		end
	end

	-- A weapon rack: two uprights under a slab cap with shafts stood
	-- between them.
	function P.rack(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = -1, 1 do
			local cx, cz = at(u, 0)
			if u == 0 then
				buf:put(cx, 1, cz, p.node("table_leg"))
				buf:put(cx, 2, cz, p.node("table_leg"))
			else
				buf:put(cx, 1, cz, p.node("post"))
				buf:put(cx, 2, cz, p.node("post"))
			end
			buf:put(cx, 3, cz, p.node("roof_slab"))
		end
	end

	-- Fresh graves: `n` (default 3) mounds of turned earth two nodes long,
	-- side by side, each with a marker post at its head, a candle on one.
	function P.graves(brush, x, z, face, n)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for i = 0, (n or 3) - 1 do
			for v = 0, 1 do
				local cx, cz = at(i * 2, -v)
				buf:put(cx, 0, cz, brush.extra.grave)
			end
			local hx, hz = at(i * 2, 1)
			buf:put(hx, 1, hz, p.node("low_wall"))
			if i == 1 then
				buf:put(hx, 2, hz, N.candle, 1)
				light(brush, hx, 2, hz)
			end
		end
	end

	-- A burnt cart: a charred bed along the right hand on ash, a barrel
	-- rolled off it.
	function P.burnt_cart(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local buf = brush.buf
		for u = -1, 3 do for v = -1, 1 do
			local cx, cz = at(u, v)
			if (u + v) % 2 == 0 or (u >= 0 and u <= 2 and v == 0) then
				buf:put(cx, 0, cz, N.ash)
			end
		end end
		for u = 0, 2 do
			local cx, cz = at(u, 0)
			buf:put(cx, 1, cz, N.char)
		end
		local cx, cz = at(1, 1)
		buf:put(cx, 1, cz, brush.palette.node("storage"))
		cx, cz = at(3, -1)
		buf:put(cx, 1, cz, brush.palette.node("post"), lying(rx))
	end

	-- A scatter of fallen masonry.
	function P.rubble(brush, x, z, face)
		local at = frame(x, z, face)
		local name = brush.palette.maybe("castle_rubble") or brush.palette.node("rubble")
		for _, c in ipairs({{0, 0, 2}, {1, 0, 1}, {0, 1, 1}, {-1, -1, 1}}) do
			local cx, cz = at(c[1], c[2])
			for y = 1, c[3] do brush.buf:put(cx, y, cz, name) end
		end
	end

	-- A dead camp fire: an ash pit in a ring of stones, one charred log.
	function P.ashpit(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = -1, 1 do for v = -1, 1 do
			local cx, cz = at(u, v)
			if u == 0 and v == 0 then
				buf:put(cx, 0, cz, N.ash)
			elseif (u + v) % 2 ~= 0 then
				buf:put(cx, 1, cz, p.node("low_wall"))
			end
		end end
		local cx, cz = at(0, 0)
		buf:put(cx, 1, cz, N.char)
	end

	-- Lair pieces --------------------------------------------------------

	-- Gnawed bones on a few cells.
	function P.bones(brush, x, z, face)
		local at = frame(x, z, face)
		for _, c in ipairs({{0, 0}, {1, 1}, {-1, 1}, {2, -1}}) do
			local cx, cz = at(c[1], c[2])
			brush.buf:put(cx, 1, cz, N.bones)
		end
	end

	-- A nest: a bed of straw in a ring of dry brush, bones in it.
	function P.nest(brush, x, z)
		for dz = -1, 1 do for dx = -1, 1 do
			if dx == 0 or dz == 0 then
				brush.buf:put(x + dx, 1, z + dz, N.mat)
			else
				brush.buf:put(x + dx, 1, z + dz, N.shrub)
			end
		end end
		brush.buf:put(x, 1, z, N.bones)
	end

	-- Webs strung between two stakes.
	function P.webs(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for _, u in ipairs({-1, 1}) do
			local cx, cz = at(u, 0)
			for y = 1, 3 do buf:put(cx, y, cz, p.node("post")) end
		end
		local cx, cz = at(0, 0)
		buf:put(cx, 2, cz, N.cobweb)
		buf:put(cx, 3, cz, N.cobweb)
		cx, cz = at(0, 1)
		buf:put(cx, 1, cz, N.cobweb)
	end

	-- Claw scrapes: three furrows of bare ground torn into the turf.
	function P.scrape(brush, x, z, face)
		local at = frame(x, z, face)
		local bare = brush.palette.node("ground_bare")
		for u = 0, 2 do for v = 0, 2 do
			local cx, cz = at(u * 2, v + u % 2)
			brush.buf:put(cx, 0, cz, bare)
		end end
	end

	-- What the beast left of a traveller: a cart shaft lying in the grass,
	-- the barrel it carried, bones.
	function P.remains(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local p = brush.palette
		for u = 0, 1 do
			local cx, cz = at(u, 0)
			brush.buf:put(cx, 1, cz, p.node("post"), lying(rx))
		end
		local cx, cz = at(1, 1)
		brush.buf:put(cx, 1, cz, p.node("storage"))
		cx, cz = at(-1, 1)
		brush.buf:put(cx, 1, cz, N.bones)
	end

	-- A den: a low shelter of piled stone, its roof a stone lip over the
	-- open front, bones at its mouth.
	function P.den(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		local stone = p.node("foundation")
		for u = -1, 1 do
			for v = -1, 0 do
				local cx, cz = at(u, v)
				if u ~= 0 or v == -1 then
					for y = 1, 2 do buf:put(cx, y, cz, stone) end
				end
				buf:put(cx, 3, cz, v == -1 and stone or p.node("chimney_cap"))
			end
		end
		local cx, cz = at(0, 1)
		buf:put(cx, 1, cz, N.bones)
	end

	-- Work pieces (mines, camps) -----------------------------------------

	-- An ore heap of the race's rubble.
	function P.ore_heap(brush, x, z, face)
		local at = frame(x, z, face)
		local name = brush.palette.node("rubble")
		for _, c in ipairs({{0, 0, 2}, {1, 0, 1}, {-1, 0, 1}, {0, 1, 1}}) do
			local cx, cz = at(c[1], c[2])
			for y = 1, c[3] do brush.buf:put(cx, y, cz, name) end
		end
	end

	-- An ore cart: two bearers along the right hand loaded with rubble,
	-- the wheels where the race has them.
	function P.ore_cart(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = 0, 1 do
			local cx, cz = at(u, 0)
			buf:put(cx, 1, cz, p.node("tree_log"), lying(rx))
			buf:put(cx, 2, cz, p.node("rubble"))
			local wx, wz = at(u, -1)
			parts.wall_prop(buf, p, "wheel", wx, 1, wz, cx - wx, 0, cz - wz)
		end
	end

	-- A drying rack (dressing.drying_rack), 3 along the right hand: rope
	-- lines where the race has rope, a hide (its rug cloth) hung under the
	-- beam where it has not.
	function P.drying(brush, x, z, face)
		local _, rx, rz = frame(x, z, face)
		if rx < 0 or rz < 0 then x, z = x + rx * 2, z + rz * 2 end
		local ax = rx ~= 0 and 1 or 0
		if dressing.drying_rack(brush.buf, brush.palette, x, z, 3,
				ax == 1 and "x" or "z") == 0 then
			brush.buf:put(x + ax, 3, z + 1 - ax, brush.palette.node("rug"))
		end
	end

	-- A carved totem (dressing.totem).
	function P.totem(brush, x, z)
		dressing.totem(brush.buf, brush.palette, x, z, 3)
	end

	-- A patch of mud with reed baskets (barrels) and a mat on it.
	function P.baskets(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = -1, 1 do for v = 0, 1 do
			local cx, cz = at(u, v)
			buf:put(cx, 0, cz, N.mud)
		end end
		local cx, cz = at(-1, 0)
		buf:put(cx, 1, cz, p.node("storage"))
		cx, cz = at(0, 1)
		buf:put(cx, 1, cz, p.node("storage"))
		cx, cz = at(1, 0)
		buf:put(cx, 1, cz, N.mat)
	end

	-- A lean-to: three posts on the back line under a sloping slab roof,
	-- a mat and a barrel under it (a bandit's or a prospector's shelter).
	function P.lean_to(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		for u = -1, 1 do
			local bx, bz = at(u, -1)
			if u ~= 0 then
				for y = 1, 2 do buf:put(bx, y, bz, p.node("post")) end
			end
			buf:put(bx, 3, bz, p.node("roof_slab"))
			local fx, fz = at(u, 0)
			buf:put(fx, 2, fz, p.node("roof_slab"))
			if u ~= 0 then buf:put(fx, 1, fz, p.node("table_leg")) end
		end
		local cx, cz = at(0, -1)
		buf:put(cx, 1, cz, N.mat)
		cx, cz = at(0, 0)
		buf:put(cx, 1, cz, N.mat)
	end

	-- The apex camps' sample wall: two posts carrying a shelf of the race's
	-- display stone, and six display squares in front of it. Ordinary
	-- masonry, never a collectible gem or a resource root. The display node
	-- comes from the composition (`brush.display`).
	function P.samples(brush, x, z, face)
		local at = frame(x, z, face)
		local p, buf = brush.palette, brush.buf
		local display = assert(brush.display, "decor kit: samples need brush.display")
		for _, u in ipairs({-1, 1}) do
			local cx, cz = at(u, 0)
			for y = 1, 3 do buf:put(cx, y, cz, p.node("post")) end
		end
		local cx, cz = at(0, 0)
		buf:put(cx, 1, cz, p.node("roof_slab"))
		buf:put(cx, 2, cz, display)
		buf:put(cx, 3, cz, p.node("roof_slab"))
		for u = -1, 1 do
			local sx, sz = at(u, 1)
			for y = 1, 2 do buf:put(sx, y, sz, display) end
		end
	end

	-- A sorting table: a trestle counter of three with a barrel at its end.
	function P.counter(brush, x, z, face)
		local at, rx = frame(x, z, face)
		local ex, ez = at(2, 0)
		dressing.counter(brush.buf, brush.palette, math.min(x, ex), math.min(z, ez), 3,
			rx ~= 0 and "x" or "z")
		local cx, cz = at(3, 0)
		brush.buf:put(cx, 1, cz, brush.palette.node("storage"))
	end

	function M.piece(brush, kind, x, z, face, size)
		local fn = P[kind]
		if fn == nil then error("decor kit: unknown piece " .. tostring(kind), 0) end
		fn(brush, x, z, face or 0, size)
	end

	-- An AUTHORED piece, which must land whole on open ground: it is built
	-- into an overlay first, and every cell it writes is checked before any
	-- reaches the composition. `rules`:
	--   ground    set of node names that are open ground: a cell on the
	--             ground course may only replace one, and every standing
	--             cell at y = 1 must stand on one
	--   reserved  set of "x:z" keys no standing cell may take (sockets,
	--             door approaches, the central actor clearance)
	--   inside    function(x, y, z) -> true when the cell is inside the
	--             composition's authored volume
	--   keep      optional set of "x:z" keys no cell at any height may take
	--   label     the composition, for the error
	-- Raises naming the piece and the cell when anything differs, so a
	-- misplaced row is an authoring error, never a hole in the scene.
	function M.place(brush, row, rules)
		local kind, x, z = row[1], row[2], row[3]
		local real = brush.buf
		local order, seen = {}, {}
		local over = M.view(function(cx, cy, cz, name, param2)
			local k = cx .. ":" .. cy .. ":" .. cz
			if not seen[k] then order[#order + 1] = k end
			seen[k] = {x = cx, y = cy, z = cz, name = name, param2 = param2}
		end, function(cx, cy, cz)
			return seen[cx .. ":" .. cy .. ":" .. cz] or real:at(cx, cy, cz)
		end)
		brush.buf = over
		local ok, err = pcall(M.piece, brush, kind, x, z, row[4], row[5])
		brush.buf = real
		local function refuse(why)
			error("decor kit: " .. tostring(rules.label) .. ": piece " .. tostring(kind) ..
				" at " .. x .. "," .. z .. " " .. why, 0)
		end
		if not ok then refuse(tostring(err)) end
		for _, k in ipairs(order) do
			local c = seen[k]
			if not rules.inside(c.x, c.y, c.z) then
				refuse("leaves the composition at " .. c.x .. "," .. c.y .. "," .. c.z)
			end
			if rules.keep and rules.keep[c.x .. ":" .. c.z] then
				refuse("touches the kept column " .. c.x .. "," .. c.z)
			end
			local old = real:at(c.x, c.y, c.z)
			if c.y <= 0 then
				if c.y < 0 or old == nil or not rules.ground[old.name] then
					refuse("rewrites " .. (old and old.name or "nothing") .. " at " ..
						c.x .. "," .. c.y .. "," .. c.z)
				end
			elseif c.name ~= parts.AIR then
				if old ~= nil and old.name ~= parts.AIR then
					refuse("takes " .. old.name .. " at " .. c.x .. "," .. c.y .. "," .. c.z)
				end
				if rules.reserved[c.x .. ":" .. c.z] then
					refuse("takes the reserved cell " .. c.x .. "," .. c.z)
				end
				if c.y == 1 then
					local below = real:at(c.x, 0, c.z)
					if below == nil or not rules.ground[below.name] then
						refuse("stands on " .. (below and below.name or "nothing") .. " at " ..
							c.x .. "," .. c.z)
					end
				end
			end
		end
		for _, k in ipairs(order) do
			local c = seen[k]
			real:put(c.x, c.y, c.z, c.name, c.param2)
		end
	end

	-- The reserved cells in front of a doorway: `depth` cells straight out
	-- of each of its cells. (x, z) are the door cells, (ox, oz) the outward
	-- step.
	function M.reserve_door(reserved, cells, ox, oz, depth)
		for _, c in ipairs(cells) do
			for k = 1, depth or 2 do
				reserved[(c[1] + ox * k) .. ":" .. (c[2] + oz * k)] = true
			end
		end
		return reserved
	end

	-- House dressing -----------------------------------------------------

	-- Is the cell a window? Panes (`xpanes:`), glass and the troll bars.
	local WINDOW = {["default:glass"] = true, ["grug_decor:darkage_wood_bars"] = true,
		["grug_decor:cottages_glass_pane"] = true,
		["grug_decor:cottages_glass_pane_side"] = true}
	function M.is_window(name)
		return WINDOW[name] == true or name:sub(1, 7) == "xpanes:"
	end

	-- One building as the dressing reads it:
	--   room     interior box {min = {x, z}, max = {x, z}}: the walls are its
	--            ring one node out
	--   floor_y  the floor course inside (windows at floor_y + 2)
	--   ground_y the ground course outside (props stand at ground_y + 1)
	--   doors    the door cells {{x = , z = }, ...} in the wall ring
	--   seed     a number that varies the touches between buildings
	-- `opts`:
	--   ground   set of node names that are open ground (a prop never stands
	--            on a path, a plaza or a floor)
	--   blocked  set of "x:z" keys no prop may take (sockets, approaches)
	--   wall_light  true when the door already has its torch (WP13 houses)
	-- Returns the number of touches written.
	local SIDES = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
	function M.dress_house(brush, house, opts)
		local buf, p = brush.buf, brush.palette
		local x1, z1 = house.room.min.x - 1, house.room.min.z - 1
		local x2, z2 = house.room.max.x + 1, house.room.max.z + 1
		local fy, gy = house.floor_y or 0, house.ground_y or 0
		local blocked = opts.blocked or {}
		local seed = house.seed or parts.position_hash(x1, z1)
		local door_at = {}
		for _, d in ipairs(house.doors or {}) do door_at[d.x .. ":" .. d.z] = true end
		local taken = {}
		local function ground_ok(x, z)
			local g = buf:at(x, gy, z)
			return g ~= nil and opts.ground[g.name] == true
		end
		-- An outside cell a prop may take: open ground, two free courses,
		-- nothing reserved, not in front of a door.
		local function free(x, z)
			local key = x .. ":" .. z
			if blocked[key] or taken[key] then return false end
			return ground_ok(x, z) and empty(buf, x, gy + 1, z) and empty(buf, x, gy + 2, z)
		end
		-- A solid prop must leave the lane past it open: the cell beyond it
		-- is free ground too.
		local function free_solid(x, z, ox, oz)
			return free(x, z) and ground_ok(x + ox, z + oz) and
				empty(buf, x + ox, gy + 1, z + oz)
		end
		local function take(x, z) taken[x .. ":" .. z] = true end
		-- the wall run of side s: cells (wall x, wall z, outward ox, oz)
		local function run(s)
			local o = SIDES[s]
			local cells = {}
			if o[2] ~= 0 then
				local wz = o[2] < 0 and z1 or z2
				for x = x1 + 1, x2 - 1 do cells[#cells + 1] = {x, wz} end
			else
				local wx = o[1] < 0 and x1 or x2
				for z = z1 + 1, z2 - 1 do cells[#cells + 1] = {wx, z} end
			end
			return cells, o[1], o[2]
		end
		-- block the two cells in front of every door
		local door_side
		for s = 1, 4 do
			local cells, ox, oz = run(s)
			for _, c in ipairs(cells) do
				if door_at[c[1] .. ":" .. c[2]] then
					door_side = door_side or s
					for k = 1, 2 do take(c[1] + ox * k, c[2] + oz * k) end
				end
			end
		end
		local count = 0
		-- 1. the door: a torch beside it, a barrel, crates or a bench on its
		-- wall two cells along.
		if door_side then
			local cells, ox, oz = run(door_side)
			local first, last
			for i, c in ipairs(cells) do
				if door_at[c[1] .. ":" .. c[2]] then
					first = first or i
					last = i
				end
			end
			local sides = (seed % 2 == 0) and {-1, 1} or {1, -1}
			if not opts.wall_light then
				for _, sgn in ipairs(sides) do
					local c = cells[sgn < 0 and first - 1 or last + 1]
					if c and parts.solid_at(buf, c[1], fy + 2, c[2]) and
							not blocked[(c[1] + ox) .. ":" .. (c[2] + oz)] and
							empty(buf, c[1] + ox, fy + 2, c[2] + oz) then
						parts.wall_torch(buf, p, c[1] + ox, fy + 2, c[2] + oz, -ox, 0, -oz)
						light(brush, c[1] + ox, fy + 2, c[2] + oz)
						count = count + 1
						break
					end
				end
			end
			for _, sgn in ipairs(sides) do
				local c = cells[sgn < 0 and first - 2 or last + 2]
				if c then
					local ex, ez = c[1] + ox, c[2] + oz
					local kind = seed % 3
					if kind == 0 and free_solid(ex, ez, ox, oz) then
						buf:put(ex, gy + 1, ez, p.node("storage"))
					elseif kind == 1 and free_solid(ex, ez, ox, oz) then
						buf:put(ex, gy + 1, ez, p.node("storage"))
						buf:put(ex, gy + 2, ez, p.node("storage"))
					elseif kind == 2 and free(ex, ez) then
						buf:put(ex, gy + 1, ez, pot(brush, true))
					else
						c = nil
					end
					if c then
						take(ex, ez)
						count = count + 1
						break
					end
				end
			end
		end
		-- 2. flowers under the windows: on at most two walls, a pot under
		-- each pane of the wall's first window and one beside it.
		local walls = 0
		for s = 1, 4 do
			if walls >= 2 then break end
			local cells, ox, oz = run(s)
			local planted = 0
			for i, c in ipairs(cells) do
				local w = buf:at(c[1], fy + 2, c[2])
				if planted < 3 and w and M.is_window(w.name) then
					local ex, ez = c[1] + ox, c[2] + oz
					if free(ex, ez) then
						buf:put(ex, gy + 1, ez, pot(brush, (i + seed) % 2 == 0))
						take(ex, ez)
						planted = planted + 1
						local n = cells[i + 1]
						local nw = n and buf:at(n[1], fy + 2, n[2])
						if n and not (nw and M.is_window(nw.name)) and
								free(n[1] + ox, n[2] + oz) then
							buf:put(n[1] + ox, gy + 1, n[2] + oz, pot(brush, (i + seed) % 2 == 1))
							take(n[1] + ox, n[2] + oz)
							planted = planted + 1
						end
					end
				elseif planted > 0 then
					break
				end
			end
			if planted > 0 then
				walls = walls + 1
				count = count + planted
			end
		end
		-- 3. a side wall (not the door's): a short wood pile or a barrel
		-- against it, near the back corner.
		for k = 1, 4 do
			local s = (seed + k) % 4 + 1
			if s ~= door_side then
				local cells, ox, oz = run(s)
				local n = #cells
				local placed = false
				for _, i in ipairs({n - 1, 2}) do
					local a, b = cells[i], cells[i + 1]
					if a and b then
						local ax, az = a[1] + ox, a[2] + oz
						local bx, bz = b[1] + ox, b[2] + oz
						if (seed % 2 == 0) and free_solid(ax, az, ox, oz) and
								free_solid(bx, bz, ox, oz) then
							for _, q in ipairs({{ax, az}, {bx, bz}}) do
								buf:put(q[1], gy + 1, q[2], p.node("tree_log"))
								buf:put(q[1], gy + 2, q[2], p.node("tree_log"))
								buf:put(q[1], gy + 3, q[2], p.node("roof_slab"))
								take(q[1], q[2])
							end
							placed = true
						elseif free_solid(ax, az, ox, oz) then
							buf:put(ax, gy + 1, az, p.node("storage"))
							take(ax, az)
							placed = true
						end
					end
					if placed then break end
				end
				if placed then
					count = count + 1
					break
				end
			end
		end
		return count
	end

	-- The houses of a WP13 composition from its own records: one entry per
	-- closed room, with the door cells that lie in its wall ring (a door
	-- belongs to the room whose wall it is in, whatever its id says).
	function M.houses_from(rooms, doors)
		local out = {}
		for _, room in ipairs(rooms) do
			if room.closed then
				local x1, z1 = room.min.x - 1, room.min.z - 1
				local x2, z2 = room.max.x + 1, room.max.z + 1
				local list = {}
				for _, d in ipairs(doors) do
					local on_x = (d.x == x1 or d.x == x2) and d.z > z1 and d.z < z2
					local on_z = (d.z == z1 or d.z == z2) and d.x > x1 and d.x < x2
					if on_x or on_z then list[#list + 1] = {x = d.x, z = d.z} end
				end
				out[#out + 1] = {room = room, doors = list, floor_y = room.min.y or 0,
					ground_y = 0}
			end
		end
		return out
	end

	-- Every closed room of a WP13 composition gets its touches: `ground` the
	-- extra open-ground names beside the palette's own (a house's apron),
	-- `sockets` the composition's sockets, which stay free with the cell
	-- in front of each. The door torches are the houses' own.
	function M.dress_rooms(buf, palette, rooms, doors, sockets, ground)
		local brush = M.brush(buf, palette.race, palette)
		local opts = {ground = M.open_ground(palette, ground), wall_light = true,
			blocked = M.blocked_sockets(sockets)}
		local count = 0
		for _, house in ipairs(M.houses_from(rooms, doors)) do
			count = count + M.dress_house(brush, house, opts)
		end
		return count
	end

	-- Room boxes from a stamped part's `room_corner` points (pairs of
	-- opposite corners), as the plot builders publish them.
	function M.rooms_from_corners(corners)
		local rooms = {}
		for index = 1, #(corners or {}), 2 do
			local a, b = corners[index], corners[index + 1]
			rooms[#rooms + 1] = {
				min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
				max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
				closed = a.closed}
		end
		return rooms
	end

	-- The open ground of a WP13 palette: what a prop may stand on. A WP13
	-- house stands in a one-node apron of its own foundation; callers pass
	-- that name in `extra` so the touches may stand on it.
	function M.open_ground(palette, extra)
		local set = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare"}) do
			local name = palette.maybe(role)
			if name then set[name] = true end
		end
		for _, name in ipairs(extra or {}) do set[name] = true end
		return set
	end

	-- Every socket cell and the cell in front of it, as `blocked` keys.
	function M.blocked_sockets(sockets, into)
		into = into or {}
		for _, s in ipairs(sockets or {}) do
			into[s.x .. ":" .. s.z] = true
			local dir = s.dir
			if dir then into[(s.x + dir.x) .. ":" .. (s.z + dir.z)] = true end
		end
		return into
	end

	return M
end

return loader
