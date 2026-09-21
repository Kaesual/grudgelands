return function()
local checks = 0
local function check(value, label)
	assert(value, label)
	checks = checks + 1
end
local root = {x=30000,y=30000,z=30000}
core.get_voxel_manip():read_from_map(root, vector.add(root, 15))
local fake, shown = {}, {}
local old_player = core.get_player_by_name
core.get_player_by_name = function(name) return fake[name] or old_player(name) end
core.show_formspec = function(name, form, spec) shown[name] = spec end
core.chat_send_player = function() end
core.is_protected = function() return false end
grug_xp.get_level = function(player) return player.level end
local function player(name, offset, profession, tier)
	local position = vector.add(root, {x=offset,y=0,z=0})
	local at = vector.add(position, {x=0,y=3,z=0})
	core.set_node(at, {name="default:stone"})
	local meta = core.get_meta(at)
	local inv = core.create_detached_inventory("r13_combined_" .. name, {}, name)
	inv:set_size("main",32)
	inv:set_size("craft",9)
	for _, slot in ipairs(grug_inventory.equipment_slots) do inv:set_size(slot.list,1) end
	inv:set_size(grug_inventory.QUIVER_LIST,8)
	local p = {name=name,level=60}
	function p:is_player() return true end
	function p:get_player_name() return name end
	function p:get_pos() return position end
	function p:get_hp() return 100 end
	function p:get_meta() return meta end
	function p:get_inventory() return inv end
	if profession then
		meta:set_string("grug_jobs:primary:1",profession)
		meta:set_int("grug_jobs:level:" .. profession,tier)
	end
	fake[name] = p
	return p
end
local smith = player("combined_smith",0,"weaponsmith",1)
smith.level = 1
local catalog = grug_jobs.basics_presentation.counts()
check(catalog.general + catalog.profession == 656,"strict catalog route count")
local seen, count = {}, 0
for profession in pairs(grug_jobs.PROFESSIONS) do
	for _, record in ipairs(grug_jobs.book_records(smith,profession)) do
		if record.operation == "enchant" then
			check(not seen[record.id],"book operation collapsed/duplicated")
			seen[record.id] = true
			check(record.enchant_value == grug_items.enchant_value(record.enchant_stat,record.tier),
				"book fixed value missing")
			check(record.label and record.family and record.hint:find("item tier",1,true),
				"book family/minimum tier missing")
			count = count + 1
		end
	end
end
check(count == 456 and #grug_jobs.station_operations() == 456,"all named book operations")
for _, operation in ipairs(grug_jobs.station_operations()) do check(seen[operation.id],"operation absent in book") end
local function fields(p,value)
	for _, callback in ipairs(core.registered_on_player_receive_fields) do
		if callback(p,"grug_jobs:workspace",value) then return end
	end
	error("workspace handler missing")
end
local function station(offset,kind)
	local pos = vector.add(root,{x=offset,y=0,z=2})
	local name = grug_jobs.station_info(kind).node
	core.set_node(pos,{name=name})
	core.registered_nodes[name].on_construct(pos)
	return pos,core.get_meta(pos):get_inventory()
end
local forge, source = station(0,"forge")
local target = ItemStack("grug_gear:sword_bronze")
check(grug_core.can_use_item_level(smith,target),"definition Bronze level-one gate")
check(grug_items.crafted_output(target,smith),"Bronze crafted initialization")
check(target:get_meta():get_int("grug_req_level") == 1 and grug_core.can_use_item_level(smith,target),
	"metadata Bronze level-one gate")
target:set_wear(12345)
target:get_meta():set_string("_grug_repair_item_id","combined-real-stack")
target:get_meta():set_int("_grug_wear_remainder",321)
local function select_index(p,station_id,id)
	local index = 1
	for _, recipe in ipairs(grug_jobs.station_operations(station_id)) do
		if grug_jobs.can_craft_recipe(p,recipe) then
			index = index + 1
			if recipe.id == id then return index end
		end
	end
	error("operation selection unavailable: " .. id)
end
local function apply(pos,inventory,p,item,id,expect_success)
	local recipe = assert(grug_jobs.station_operation(id))
	inventory:set_list("craft",{})
	inventory:set_stack("craft",1,item)
	for index,token in ipairs(recipe.flat_inputs) do inventory:set_stack("craft",index+1,token) end
	p:get_inventory():set_list("main",{})
	grug_jobs.workspaces.open(pos,p)
	fields(p,{operation=tostring(select_index(p,recipe.station,id))})
	local view_name = assert(shown[p.name]):match("list%[detached:([^;]+);")
	local view = assert(core.get_inventory({type="detached",name=view_name}))
	local preview = view:get_stack("output",1)
	local before = grug_jobs.crafts_in_tier(p,recipe.profession)
	fields(p,{apply=true})
	if not expect_success then
		check(p:get_inventory():is_empty("main") and inventory:get_stack("craft",1):equals(item),
			"refused operation changed target/output")
		check(grug_jobs.crafts_in_tier(p,recipe.profession) == before,"refused operation credited progress")
		for index,token in ipairs(recipe.flat_inputs) do
			check(inventory:get_stack("craft",index+1):get_name() == token,"refused operation consumed material")
		end
		return item
	end
	local actual = p:get_inventory():get_stack("main",1)
	check(not preview:is_empty() and actual:equals(preview),"Apply differs from exact preview")
	check(inventory:is_empty("craft"),"Apply did not debit exact input/materials")
	check(grug_jobs.crafts_in_tier(p,recipe.profession) == before + 1,"Apply credit not exactly one")
	return actual
end
local suffix = "enchant:melee_weapon:suffix:str:t1"
local pref = "enchant:melee_weapon:prefix:dex:t1"
local replacement = "enchant:melee_weapon:prefix:attack_speed_percent:t1"
local item = apply(forge,source,smith,target,suffix,true)
item = apply(forge,source,smith,item,pref,true)
item = apply(forge,source,smith,item,replacement,true)
local affixes = grug_items.get_affixes(item)
check(#affixes == 2 and affixes[1].stat == "attack_speed_percent" and affixes[2].stat == "str",
	"replacement mutated opposite channel")
check(item:get_wear() == 12345 and item:get_meta():get_int("_grug_wear_remainder") == 321 and
	item:get_meta():get_string("_grug_repair_item_id") == "combined-real-stack","Apply lost wear/identity")
check(grug_core.can_use_item_level(smith,item),"enchanted Bronze level-one gate")
apply(forge,source,smith,item,replacement,false)
apply(forge,source,smith,item,"enchant:melee_weapon:prefix:str:t1",false)
local jeweller = player("combined_goldsmith",2,"goldsmith",1)
local bench,jewel_source = station(2,"jewellers_bench")
local jewelry = ItemStack(grug_gear.trinket_item("last_light",1))
check(grug_items.crafted_output(jewelry,jeweller),"jewelry base craft")
check(#grug_items.get_affixes(jewelry) == 0 and jewelry:get_meta():get_int("grug_quality") == 1,
	"jewelry base not Common/empty")
local special = jewelry:get_definition()._grug_trinket_special
jewelry = apply(bench,jewel_source,jeweller,jewelry,"enchant:trinket:suffix:crit_percent:t1",true)
jewelry = apply(bench,jewel_source,jeweller,jewelry,"enchant:trinket:prefix:int:t1",true)
check(jewelry:get_wear() == 0 and jewelry:get_meta():get_string("description"):find(special,1,true),
	"jewelry authored special changed")
-- Real gear scaling, metadata and equipment aggregation; only talent/status
-- inputs are controlled to reproduce the frozen Protection calibration.
local tank = player("combined_tank",4,"armorsmith",6)
local tinv = tank:get_inventory()
for _,slot in ipairs({"head","chest","legs","feet"}) do
	local stack = ItemStack("grug_gear:" .. slot .. "_metal_abyssal_steel")
	stack:get_meta():set_int("grug_ilvl",75)
	stack:get_meta():set_string("grug_ench",core.serialize({{channel="prefix",stat="armor_rating",value=6,tier=6}}))
	tinv:set_stack("grug_" .. slot,1,stack)
end
local shield = ItemStack("grug_gear:shield_abyssal_steel")
shield:get_meta():set_int("grug_ilvl",75)
shield:get_meta():set_string("grug_ench",core.serialize({{channel="prefix",stat="armor_rating",value=6,tier=6}}))
tinv:set_stack("grug_offhand",1,shield)
local old_rank,old_bonus,old_status = grug_classes.talent_rank,grug_classes.get_talent_bonus,grug_core.status_modifier_sum
local emergency = 0
grug_classes.talent_rank = function(p,key) if p == tank and key == "unbroken" then return 1 end return old_rank(p,key) end
grug_classes.get_talent_bonus = function(p,key)
	if p == tank then return key == "armor_percent_add" and 5 or (key == "armor_rating_add_low_hp" and emergency or 0) end
	return old_bonus(p,key)
end
grug_core.status_modifier_sum = function(p,key) if p == tank and key == "armor" then return 4 end return old_status(p,key) end
check(grug_inventory.get_equipped_armor(tank) == 71,"concrete ilvl75 armor set")
check(grug_items.get_equipment_armor_rating_bonus(tank) == 71,"concrete ilvl75 shield")
local rating = grug_core.get_armor_rating(tank)
check(math.abs(rating - 298.65) < 0.0001,"Protection calibrated armor rating")
emergency = 15
check(math.abs(grug_core.get_armor_rating(tank) - 313.65) < 0.0001,"Protection emergency rating")
-- Broken quiver contents remain retrievable but are neither usable nor refillable.
local archer = player("combined_archer",6)
local ainv = archer:get_inventory()
local quiver = ItemStack("grug_inventory:quiver")
quiver:set_wear(65535)
ainv:set_stack("grug_offhand",1,quiver)
ainv:set_stack(grug_inventory.QUIVER_LIST,1,"grug_gear:arrow" .. " 12")
check(grug_inventory.ammo_count(archer) == 0 and not grug_inventory.consume_ammo(archer,1),
	"broken quiver still provides ammo")
local function allowed(action,info)
	local count = info.count or info.stack:get_count()
	for _,callback in ipairs(core.registered_allow_player_inventory_actions) do
		local value = callback(archer,action,ainv,info)
		if value then count = math.min(count,value) end
	end
	return count
end
check(allowed("put",{listname=grug_inventory.QUIVER_LIST,index=2,stack=ItemStack("grug_gear:arrow")}) == 0,
	"broken quiver accepts refill")
local take_info = {listname=grug_inventory.QUIVER_LIST,index=1,stack=ainv:get_stack(grug_inventory.QUIVER_LIST,1)}
check(allowed("take",take_info) == 12,"broken quiver blocks retrieval")
ainv:set_stack(grug_inventory.QUIVER_LIST,1,"")
check(ainv:add_item("main",take_info.stack):is_empty() and grug_inventory.ammo_count(archer) == 12,
	"retrieved arrows are not usable from main")
-- A stale source take must be refused if its allow callback first settles
-- automatic work. The fresh result can then be taken at the same clock time.
local cook = player("combined_cook",8)
local hearth = station(8,"furnace")
grug_jobs.register_public_position("furnace",hearth)
local old_clock, clock = core.get_gametime, 100
core.get_gametime = function() return clock end
core.get_meta(hearth):set_string("grug_jobs:workspace:" .. cook.name,core.serialize({
	lists={src={"grug_cooking:wild_grain"},fuel={"default:coal_lump"},dst={"","","",""}},
	process={last=100}}))
grug_jobs.workspaces.open(hearth,cook)
local detached_name = assert(shown[cook.name]):match("list%[detached:([^;]+);")
local cooking_inv = core.get_inventory({type="detached",name=detached_name})
local callbacks = core.detached_inventories[detached_name]
local stale_grain = cooking_inv:get_stack("src",1)
clock = 105
check(callbacks.allow_take(cooking_inv,"src",1,stale_grain,cook) == 0,
	"settled automatic source allowed stale transfer")
check(cooking_inv:is_empty("src") and cooking_inv:contains_item("dst","grug_cooking:bread"),
	"allow-time settlement failed to finish bread")
local bread = cooking_inv:get_stack("dst",1)
check(callbacks.allow_take(cooking_inv,"dst",1,bread,cook) == bread:get_count(),
	"fresh same-time destination retry refused")
check(cook:get_inventory():add_item("main",bread):is_empty(),"fresh take destination capacity")
cooking_inv:set_stack("dst",1,"")
callbacks.on_take(cooking_inv,"dst",1,bread,cook)
check(cook:get_inventory():contains_item("main","grug_cooking:bread") and cooking_inv:is_empty("dst"),
	"fresh retry did not transfer exactly one finished item")
core.get_gametime = old_clock
core.log("action","R13 INTEGRATION PASS assertions=" .. checks .. " catalog=656 book_operations=456 native_apply=5 interpreter=" .. jit.version)
end
