return function(storage)
local checks = 0
local function check(value, label)
	assert(value, label)
	checks = checks + 1
end
local INPUT = "grug_r13_stations_probe:input"
local OUTPUT = "grug_r13_stations_probe:output"
local FUEL = "grug_r13_stations_probe:fuel"
local JAR = "grug_r13_stations_probe:jar"
local root = {x = 30000, y = 30000, z = 30000}
local vm = core.get_voxel_manip()
vm:read_from_map(root, vector.add(root, 15))
local fake = {}
local shown = {}
local old_player = core.get_player_by_name
core.get_player_by_name = function(name) return fake[name] or old_player(name) end
core.show_formspec = function(name, form, spec) shown[name] = spec end
core.is_protected = function(pos, name) return fake[name] and fake[name].protected or false end
grug_xp.get_level = function(player) return player.level or 1 end
local function player(name, offset, qualified)
	local p = {name = name, position = vector.add(root, {x = offset, y = 0, z = 0})}
	local meta_pos = vector.add(root, {x = offset, y = 3, z = 0})
	core.set_node(meta_pos, {name = "default:stone"})
	local meta = core.get_meta(meta_pos)
	local inv = core.create_detached_inventory("r13_main_" .. name, {}, name)
	inv:set_size("main", 32)
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return self.position end
	function p:get_hp() return 20 end
	function p:get_meta() return meta end
	function p:get_inventory() return inv end
	if qualified then
		meta:set_string("grug_jobs:primary:1", "weaponsmith")
		meta:set_int("grug_jobs:level:weaponsmith", 1)
	end
	fake[name] = p
	return p
end
local alice = player("r13_alice", 0, true)
local bob = player("r13_bob", 1, false)
local carol = player("r13_carol", 2, true)
local function station(offset, kind, personal)
	local pos = vector.add(root, {x = offset, y = 0, z = 2})
	local node = grug_jobs.station_info(kind).node
	core.set_node(pos, {name = node})
	core.registered_nodes[node].on_construct(pos)
	if personal then grug_jobs.register_public_position(kind, pos) end
	return pos, core.registered_nodes[node]
end
local function open(pos, p)
	grug_jobs.workspaces.open(pos, p)
	local id = assert(shown[p.name]):match("list%[detached:([^;]+);")
	return core.get_inventory({type = "detached", name = id}), core.detached_inventories[id], id
end
local function fields(p, value)
	for _, callback in ipairs(core.registered_on_player_receive_fields) do
		if callback(p, "grug_jobs:workspace", value) then return end
	end
end
local function put(inv, cb, list, index, item, p)
	local stack = ItemStack(item)
	check(cb.allow_put(inv, list, index, stack, p) == stack:get_count(), "put permitted")
	inv:set_stack(list, index, stack)
	cb.on_put(inv, list, index, stack, p)
end
-- Engine order: destination allow_put, source allow_take; actual movement;
-- source on_take, destination on_put. Native InvRefs perform actual movement.
local function take(inv, cb, list, count, p, destination_limit)
	local offered = inv:get_stack(list, 1)
	offered:set_count(math.min(count, offered:get_count()))
	local source_limit = cb.allow_take(inv, list, 1, offered, p)
	local amount = math.min(offered:get_count(), source_limit, destination_limit or count)
	if amount <= 0 then return 0 end
	local remaining = inv:get_stack(list, 1)
	local moved = remaining:take_item(amount)
	local rest = p:get_inventory():add_item("main", moved)
	assert(rest:is_empty(), "fixture destination must fit")
	inv:set_stack(list, 1, remaining)
	cb.on_take(inv, list, 1, moved, p)
	return amount
end
if storage:get_int("restart_expected") == 1 then
	local hearth = vector.add(root, {x = 7, y = 0, z = 2})
	grug_jobs.register_public_position("furnace", hearth)
	check(core.get_meta(hearth):get_string("grug_jobs:station_id") ~= "", "physical identity survives engine restart")
	local inv = open(hearth, alice)
	check(inv:contains_item("dst", "grug_cooking:bread"), "personal finished item survives engine restart")
	check(inv:contains_item("dst", JAR), "fuel replacement survives engine restart")
	check(inv:is_empty("src") and inv:is_empty("fuel"), "restart does not restore consumed ingredients")
	local record = core.deserialize(core.get_meta(hearth):get_string("grug_jobs:workspace:" .. alice.name))
	check(record.process.fuel >= 0 and record.process.fuel <= 5, "process state survives engine restart")
	core.log("action", "R13 STATIONS RESTART PASS assertions=" .. checks .. " interpreter=" .. jit.version)
	return
end
local pos, def = station(0, "forge", false)
local source = core.get_meta(pos):get_inventory()
source:set_stack("craft", 1, INPUT .. " 2")
local ai, ac = open(pos, alice)
local bi, bc = open(pos, bob)
local ci, cc = open(pos, carol)
check(ai:get_stack("output", 1):get_count() == 4, "qualified preview")
check(bi:is_empty("output"), "unqualified empty preview")
check(ci:get_stack("output", 1):get_count() == 4, "concurrent qualified preview")
check(ac.allow_take(ai, "output", 1, ai:get_stack("output", 1), bob) == 0, "detached callback owner")
check(ac.allow_move(ai, "output", 1, "craft", 1, 4, alice) == 0, "same-inventory output move denied")
check(take(ai, ac, "output", 4, alice, 0) == 0, "destination refusal moves nothing")
check(source:get_stack("craft", 1):get_count() == 2 and grug_jobs.crafts_in_tier(alice, "weaponsmith") == 0,
	"destination refusal consumes and credits nothing")
check(take(ai, ac, "output", 4, alice, 2) == 2, "destination limits to partial")
check(source:get_stack("craft", 1):get_count() == 1, "one material debit")
check(grug_jobs.crafts_in_tier(alice, "weaponsmith") == 1, "one progress credit")
check(ai:get_stack("output", 1):get_count() == 2, "produced remainder")
fields(alice, {quit = true})
ai, ac = open(pos, alice)
check(ai:get_stack("output", 1):get_count() == 2, "remainder survives close/reopen")
alice:get_meta():set_string("grug_jobs:primary:1", "")
check(take(ai, ac, "output", 2, alice) == 2, "already-crafted remainder survives profession loss")
check(source:get_stack("craft", 1):get_count() == 1, "remainder does not consume again")
check(ai:is_empty("output"), "profession loss removes next preview")
check(take(ci, cc, "output", 4, carol) == 4, "second qualified collector crafts last recipe")
check(source:is_empty("craft"), "shared materials empty")
check(bc.allow_take(bi, "output", 1, ItemStack(OUTPUT), bob) == 0, "stale/ineligible output refused")
source:set_stack("craft", 1, INPUT)
def.on_metadata_inventory_put(pos)
carol.position = vector.add(root, 100)
check(cc.allow_take(ci, "output", 1, ItemStack(OUTPUT), carol) == 0, "distance revalidated")
carol.position = vector.add(root, 1)
carol.protected = true
check(cc.allow_take(ci, "output", 1, ItemStack(OUTPUT), carol) == 0, "area access revalidated")
carol.protected = false
source:set_stack("craft", 1, "")
check(cc.allow_take(ci, "output", 1, ItemStack(OUTPUT), carol) == 0, "outdated preview revalidated")
local personal, pdef = station(2, "forge", true)
alice:get_meta():set_string("grug_jobs:primary:1", "weaponsmith")
ai, ac = open(personal, alice)
put(ai, ac, "craft", 1, INPUT .. " 3", alice)
bi, bc = open(personal, bob)
check(bi:is_empty("craft"), "personal inventory isolated")
check(pdef.allow_metadata_inventory_take(personal, "craft", 1, ItemStack(INPUT), alice) == 0, "authored nodemeta bypass denied")
check(not pdef.can_dig(personal, alice), "authored digging denied")
check(#pdef.on_blast(personal) == 0 and core.get_node(personal).name == "grug_jobs:forge", "authored blast denied")
fields(alice, {quit = true})
-- A complete native metadata serialization/restore simulates mapblock storage.
local saved = core.get_meta(personal):to_table()
core.get_meta(personal):from_table(saved)
ai, ac = open(personal, alice)
check(ai:get_stack("craft", 1):get_count() == 3, "personal persistence restored")
local other = station(4, "forge", true)
ai, ac = open(other, alice)
check(ai:is_empty("craft"), "physical-station inventories distinct")
ai, ac = open(personal, alice)
core.remove_node(personal)
core.set_node(personal, {name = "grug_jobs:forge"})
pdef.on_construct(personal)
check(ac.allow_take(ai, "craft", 1, ItemStack(INPUT), alice) == 0, "replacement node invalidates view")
-- Universal finishing uses the same native evaluator for personal and shared.
local auto = dofile(core.get_modpath("grug_jobs") .. "/automatic.lua")
local furnace, fdef = station(3, "furnace", false)
local fi = core.get_meta(furnace):get_inventory()
fi:set_stack("src", 1, "grug_cooking:wild_grain 2")
fi:set_stack("fuel", 1, FUEL)
check(fdef.on_timer(furnace, 10) == false, "exact fuel boundary stops after complete batch")
check(fi:contains_item("dst", "grug_cooking:bread 2"), "universal bread completed")
check(fi:contains_item("dst", JAR), "fuel replacement preserved")
check(fdef.allow_metadata_inventory_take(furnace, "dst", 1, ItemStack("grug_cooking:bread"), bob) == 1, "unqualified furnace collection")
check(grug_jobs.crafts_in_tier(bob, "cooking") == 0, "automatic finish grants no progress")
local persisted = {fuel = 4, progress = 2, recipe = "grug_cooking:bread\0" .. "5\0grug_cooking:wild_grain"}
fi:set_stack("src", 1, "grug_cooking:wild_grain")
fi:set_stack("fuel", 1, "")
auto.advance("furnace", fi, persisted, 3)
check(fi:contains_item("dst", "grug_cooking:bread 3") and persisted.fuel == 1, "partial process resumes once")
for index = 1, 4 do fi:set_stack("dst", index, INPUT .. " 99") end
fi:set_stack("src", 1, "grug_cooking:wild_grain")
fi:set_stack("fuel", 1, FUEL)
auto.advance("furnace", fi, {}, 100000)
check(fi:get_stack("src", 1):get_count() == 1 and fi:get_stack("fuel", 1):get_count() == 1, "full output preserves input and unlit fuel")
local brew, bdef = station(5, "brewing_stand", false)
local brew_inv = core.get_meta(brew):get_inventory()
local row = grug_alchemy.CATALOG[1]
brew_inv:set_stack("mixture", 1, row.mixture)
brew_inv:set_stack("fuel", 1, "default:coal_lump")
bdef.on_timer(brew, 5)
check(brew_inv:contains_item("output", "grug_alchemy:" .. row.id), "mixture universally finishes")
check(brew_inv:is_empty("mixture"), "one mixture consumed")
check(bdef.allow_metadata_inventory_take(brew, "output", 1, ItemStack("grug_alchemy:" .. row.id), bob) == 1, "brewing no output profession gate")
local brewing_recipe = grug_jobs.recipe_for_output("grug_alchemy:" .. row.id, "brewing_stand")
check(brewing_recipe.automatic_finish and grug_jobs.can_craft_recipe(bob, brewing_recipe), "automatic recipe permission universal")
local preparation = grug_jobs.recipe_for_output(row.mixture, "grid")
check(not grug_jobs.can_craft_recipe(bob, preparation), "mixture preparation remains qualified")
check(core.get_craft_result({method = "normal", width = 3,
	items = {ItemStack(row.inputs[1]), ItemStack(row.inputs[2]), ItemStack(row.inputs[3])}}).item:get_name() == row.mixture,
	"actual engine mixture preparation route")
local dual, ddef = station(6, "dual_furnace", false)
local di = core.get_meta(dual):get_inventory()
local alloy = grug_smelting.RECIPES[1]
di:set_stack("input", 1, alloy.inputs[1]) di:set_stack("input", 2, alloy.inputs[2])
di:set_stack("fuel", 1, "default:coal_lump")
ddef.on_timer(dual, alloy.time)
check(di:contains_item("output", alloy.output) and di:is_empty("input"), "dual furnace exact pair completion")
-- Review regression: the destination is written before source on_take.
local backpos, backdef = station(0, "forge", false)
local back = core.get_meta(backpos):get_inventory()
back:set_stack("craft", 1, INPUT)
back:set_stack("craft", 2, JAR)
ai, ac = open(backpos, alice)
local function return_to_inputs(count, slot)
	local offered = ai:get_stack("output", 1)
	offered:set_count(count)
	assert(backdef.allow_metadata_inventory_put(backpos, "craft", slot, offered, alice) == count)
	assert(ac.allow_take(ai, "output", 1, offered, alice) == count)
	local remaining = ai:get_stack("output", 1)
	local moved = remaining:take_item(count)
	ai:set_stack("output", 1, remaining)
	back:set_stack("craft", slot, moved)
	ac.on_take(ai, "output", 1, moved, alice)
	backdef.on_metadata_inventory_put(backpos)
end
return_to_inputs(1, 3)
check(back:get_stack("craft", 3):get_count() == 1 and
	back:get_stack("craft", 1):is_empty() and back:get_stack("craft", 2):is_empty(),
	"single output returned to shared input survives ingredient debit")
back:set_stack("craft", 3, "") back:set_stack("craft", 1, INPUT)
backdef.on_metadata_inventory_put(backpos)
local before_credit = grug_jobs.crafts_in_tier(alice, "weaponsmith")
return_to_inputs(2, 2)
check(back:get_stack("craft", 2):get_count() == 2 and ai:get_stack("output", 1):get_count() == 2,
	"partial output returned to shared input preserves both halves")
check(take(ai, ac, "output", 2, alice) == 2 and
	grug_jobs.crafts_in_tier(alice, "weaponsmith") == before_credit + 1,
	"returned partial output still credits exactly one craft")

-- Settle old contents before allowing mutations, even after an inaccessible view.
local old_clock, old_meta = core.get_gametime, core.get_meta
local clock, writes, private = 100, 0, {}
local idlepos = station(1, "furnace", true)
core.get_gametime = function() return clock end
core.get_meta = function(pos)
	local actual = old_meta(pos)
	if not vector.equals(pos, idlepos) then return actual end
	return setmetatable({}, {__index = function(_, method)
		return function(_, ...)
			local args = {...}
			if method == "mark_as_private" then private[args[1]] = true end
			if method == "set_string" and args[1]:find("grug_jobs:workspace:", 1, true) == 1 then
				assert(private[args[1]], "workspace must be private before first write")
				writes = writes + 1
			end
			return actual[method](actual, unpack(args))
		end
	end})
end
local tick
for _, callback in ipairs(core.registered_globalsteps) do
	if debug.getinfo(callback, "S").source:match("/grug_jobs/workspaces%.lua$") then tick = callback end
end
assert(tick, "workspace globalstep found")
ai, ac = open(idlepos, alice)
alice.position = vector.add(root, 100)
clock = 160 tick(1)
alice.position = vector.new(root)
put(ai, ac, "src", 1, "grug_cooking:wild_grain", alice)
put(ai, ac, "fuel", 1, FUEL, alice)
tick(1)
check(ai:is_empty("dst"), "new input does not receive inaccessible idle time")
clock = 164 tick(1)
check(not ai:contains_item("dst", "grug_cooking:bread"), "four actual seconds cannot finish five-second recipe")
clock = 165 tick(1)
check(ai:contains_item("dst", "grug_cooking:bread"), "five actual seconds finish one recipe")
clock = 170 tick(1)
local stable_writes = writes
clock = 200 tick(1)
clock = 230 tick(1)
check(writes == stable_writes, "idle viewer clock does not repeatedly write node metadata")
check(private["grug_jobs:workspace:" .. alice.name], "durable personal record marked private")
fields(alice, {quit = true})
core.get_gametime, core.get_meta = old_clock, old_meta

-- Personal catch-up uses persisted server time, not player uptime.
local hearth = station(7, "furnace", true)
local record = {lists = {src = {"grug_cooking:wild_grain"}, fuel = {FUEL}, dst = {"", "", "", ""}},
	process = {last = core.get_gametime() - 5}}
core.get_meta(hearth):set_string("grug_jobs:workspace:" .. alice.name, core.serialize(record))
ai, ac = open(hearth, alice)
check(ai:contains_item("dst", "grug_cooking:bread") and ai:is_empty("src"), "personal elapsed server-time catchup")
fields(alice, {quit = true})
ai, ac = open(hearth, alice)
check(ai:contains_item("dst", "grug_cooking:bread") and ai:get_stack("dst", 1):get_count() == 1, "catchup does not repeat after reopen")
storage:set_int("restart_expected", 1)
core.log("action", "R13 STATIONS PASS assertions=" .. checks .. " interpreter=" .. jit.version)

end
