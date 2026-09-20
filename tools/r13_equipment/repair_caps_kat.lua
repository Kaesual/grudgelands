local repo = assert(arg[1], "repository path required")
local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}; for k,v in pairs(t) do c[k] = copy(v) end
	return setmetatable(c, getmetatable(t))
end
local function equal(a,b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local definitions = {
	["test:sword"] = {groups = {grug_equip_weapon = 1}, price = 100},
	["test:chest"] = {groups = {grug_equip_chest = 1}, price = 500},
	["test:hoe"] = {groups = {hoe = 1}, price = 5},
	["test:quiver"] = {groups = {grug_equip_offhand = 1, grug_quiver = 1}},
	["test:skill"] = {groups = {grug_ability = 1}},
	["test:unpriced"] = {groups = {grug_equip_weapon = 1}},
}
local Stack = {}; Stack.__index = Stack
local function stack(value)
	local result = type(value) == "table" and copy(value) or
		{name = value or "", wear = 0, count = value and value ~= "" and 1 or 0,
			meta = {}, caps = {damage_groups = {fleshy = 0}}}
	return setmetatable(result, Stack)
end
function Stack:is_empty() return self.name == "" or self.count == 0 end
function Stack:get_name() return self.name end
function Stack:get_count() return self.count end
function Stack:get_definition() return definitions[self.name] or {} end
function Stack:get_wear() return self.wear end
function Stack:set_wear(wear) self.wear = wear end
function Stack:get_description() return self.name end
function Stack:equals(other) return equal(self,other) end
function Stack:get_meta()
	local values = self.meta
	return {
		get_int = function(_, k) return tonumber(values[k]) or 0 end,
		set_int = function(_, k, v) values[k] = tostring(v) end,
		get_string = function(_, k) return values[k] or "" end,
		set_string = function(_, k, v) values[k] = v ~= "" and v or nil end,
		set_tool_capabilities = function(_, value) self.caps = copy(value) end,
	}
end
_G.ItemStack = stack
local forms, receivers = {}, {}
_G.core = {
	register_on_joinplayer = function() end, register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end, register_chatcommand = function() end,
	register_on_player_receive_fields = function(f) receivers[#receivers+1] = f end,
	formspec_escape = function(s) return s end, chat_send_player = function() end,
	show_formspec = function(_,name,content) forms[#forms+1] = {name,content} end,
	deserialize = function(value) return copy(value) end,
}
local lists, writes, fail_at = {}, 0, nil
local inv = {}
function inv:get_list(name) return copy(lists[name] or {}) end
function inv:get_size(name) return #(lists[name] or {}) end
function inv:get_stack(name,index) return stack((lists[name] or {})[index] or "") end
function inv:set_stack(name,index,item)
	writes = writes + 1
	if fail_at == writes then return false end
	lists[name][index] = stack(item); return true
end
local funds, hp, position, faction = 1000, 100, {x=0,y=0,z=0}, "accord"
local player = {
	is_player = function() return true end, get_hp = function() return hp end,
	get_player_name = function() return "owner" end,
	get_inventory = function() return inv end, get_pos = function() return position end,
	get_meta = function() return {
		get_int = function() return funds end, set_int = function(_,_,n) funds=n end} end,
}
local socket = {id = "smith", role = "trainer", profession = "weaponsmith",pos={x=0,y=0,z=0}}
local npc = {_grug_start="highcourt",_grug_socket="smith",_grug_socket_role="trainer",
	_grug_profession="weaponsmith"}
local npc_pos, live = {x=0,y=0,z=0}, true
npc.object = {get_pos=function() return live and npc_pos or nil end,
	get_luaentity=function() return live and npc or nil end}
_G.grug_core = {
	settlement_socket_settlements = function() return {{key="highcourt",race_id="human"}} end,
	settlement_sockets_at = function() return {socket} end,
}
local notices = 0
_G.grug_inventory = {
	equipment_slots={{list="grug_weapon"},{list="grug_chest"}}, BAG_COUNT=1,
	content_list=function() return "bag" end,
	is_equipment_list=function(s) return s=="grug_weapon" or s=="grug_chest" end,
	equipment_changed=function() notices=notices+1 end,
}
_G.grug_gear = {reference_purchase_price = function(item)
	local p=item:get_definition().price
	if not p then return nil end
	return p*(({[0]=1,[1]=1,[2]=3,[3]=6})[item:get_meta():get_int("grug_quality")])
end}
_G.grug_jobs={PROFESSIONS={weaponsmith={},cooking={}}}
_G.grug_classes={registered_races={human={faction="accord"}}}
_G.grug_factions={get_faction=function() return faction end}
_G.grug_repair={}
dofile(repo.."/mods/PLAYER/grug_money/init.lua")
dofile(repo.."/mods/ITEMS/grug_repair/service.lua")
dofile(repo.."/mods/ITEMS/grug_repair/providers.lua")
local function damaged(name,wear)
	local s=stack(name);s:set_wear(wear);s.meta.affixes="preserve me";return s
end
local function reset()
	lists={main={damaged("test:hoe",65535),stack("test:quiver"),damaged("test:skill",32000)},
		grug_weapon={damaged("test:sword",32768)},grug_chest={damaged("test:chest",65535)},
		bag={damaged("test:sword",65535)}}
	funds=1000;writes=0;fail_at=nil;notices=0
end
local provider={kind="trainer",entity=npc,object=npc.object,settlement="highcourt",
	socket="smith",profession="weaponsmith"}
reset()
lists.grug_weapon[1].caps = {full_punch_interval=0.5, damage_groups={fleshy=10}}
local quote = assert(grug_repair.quote(player,provider))
assert(grug_repair.apply(player,quote))
assert(lists.grug_weapon[1].caps.full_punch_interval == 0.5,
 "partial repair must retain active enchant capabilities")
assert(lists.grug_weapon[1]:get_wear() == 0)
reset()
lists.grug_weapon[1].wear = 65535
lists.grug_weapon[1].caps = {damage_groups={fleshy=0}}
lists.grug_weapon[1].meta._grug_repair_caps = {full_punch_interval=0.5,damage_groups={fleshy=10}}
quote = assert(grug_repair.quote(player,provider))
assert(grug_repair.apply(player,quote))
assert(lists.grug_weapon[1].caps.full_punch_interval == 0.5,
 "broken repair must restore saved enchanted capabilities")
assert(lists.grug_weapon[1].meta._grug_repair_caps == nil)
io.write("PASS partial repair preserves active capabilities; broken repair restores snapshot\n")
