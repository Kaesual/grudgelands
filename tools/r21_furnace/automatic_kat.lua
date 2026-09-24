local repo = assert(arg[1], "repository root required")

local definitions = {
	log = {groups = {tree = 1}}, coal = {groups = {}}, charcoal = {groups = {}},
	illegal = {groups = {}}, ore = {groups = {}}, bar = {groups = {}},
	a = {groups = {}}, b = {groups = {}}, alloy = {groups = {}},
	brewinput = {groups = {}}, brewfuel = {groups = {}}, potion = {groups = {}}, jar = {groups = {}},
}

local Stack = {}
Stack.__index = Stack
local function stack(value)
	if getmetatable(value) == Stack then return setmetatable({name=value.name,count=value.count},Stack) end
	local name, count = tostring(value or ""):match("^(%S+)%s*(%d*)$")
	if not name or name == "" then name, count = "", 0 else count = tonumber(count) or 1 end
	return setmetatable({name=name,count=count},Stack)
end
function Stack:get_name() return self.name end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.name == "" or self.count <= 0 end
function Stack:to_string() return self:is_empty() and "" or self.name .. (self.count > 1 and " " .. self.count or "") end
function Stack:take_item(count)
	local taken = math.min(self.count, count or 1)
	local result = stack(self.name .. " " .. taken)
	self.count = self.count - taken
	if self.count == 0 then self.name = "" end
	return result
end
function Stack:add_item(other)
	local incoming = stack(other)
	if incoming:is_empty() then return incoming end
	if self:is_empty() then self.name,self.count=incoming.name,incoming.count;return stack("") end
	if self.name == incoming.name then self.count=self.count+incoming.count;return stack("") end
	return incoming
end

local Inventory = {}
Inventory.__index = Inventory
local function inventory(sizes)
	local lists = {}
	for name, size in pairs(sizes) do
		lists[name] = {}; for i=1,size do lists[name][i]=stack("") end
	end
	return setmetatable({lists=lists},Inventory)
end
function Inventory:get_list(name)
	local result={};for i=1,#self.lists[name] do result[i]=stack(self.lists[name][i]) end
	return result
end
function Inventory:set_list(name, values)
	self.lists[name] = {}; for i=1,#values do self.lists[name][i]=stack(values[i]) end
end
function Inventory:get_stack(name,index) return stack(self.lists[name][index]) end
function Inventory:set_stack(name,index,value) self.lists[name][index]=stack(value) end

local env = setmetatable({_G=false,ItemStack=stack},{__index=_G});env._G=env
env.core = {
	get_item_group=function(name,group) return definitions[name] and definitions[name].groups[group] or 0 end,
	get_craft_result=function(def)
		local input=def.items and def.items[1] and def.items[1]:get_name() or ""
		if def.method=="cooking" and input=="ore" then
			local remaining=stack(def.items[1]);remaining:take_item(1)
			return {time=10,item=stack("bar")},{items={remaining}}
		end
		if def.method=="fuel" and input=="brewfuel" then
			return {time=5,item=stack(""),replacements={stack("jar")}},
				{items={stack("")}}
		end
		return {time=0,item=stack(""),replacements={}},{items={stack(input)}}
	end,
}
env.grug_smelting={match=function(a,b)
	if (a=="a" and b=="b") or (a=="b" and b=="a") then
		return {output="alloy",time=4}
	end
end}
env.grug_brewing={match=function(name)
	if name=="brewinput" then return {output="potion",time=5} end
end}
local chunk=assert(loadfile(repo.."/mods/PLAYER/grug_jobs/automatic.lua"));setfenv(chunk,env)
local automatic=chunk()
local function check(value,message) assert(value,"r21 furnace: "..message) end

check(automatic.fuel_time("furnace",stack("log"))==15,"log duration")
check(automatic.fuel_time("dual_furnace",stack("coal"))==0,"fixture coal alias must be rejected")
check(automatic.fuel_time("furnace",stack("default:coal_lump"))==80,"coal duration")
check(automatic.fuel_time("furnace",stack("grug_smelting:charcoal"))==80,"charcoal duration")
check(automatic.fuel_time("furnace",stack("illegal"))==0,"illegal fuel accepted")

local inv=inventory({src=1,fuel=1,dst=4})
inv:set_stack("fuel",1,"log 2")
local state={}
automatic.advance("furnace",inv,state,10)
check(inv:get_stack("fuel",1):get_count()==2 and (state.fuel or 0)==0,"fuel-only ignition")
inv:set_stack("src",1,"ore 2")
automatic.advance("furnace",inv,state,10)
check(inv:get_stack("dst",1):get_name()=="bar" and state.fuel==5 and state.fuel_total==15,
	"normal furnace work")

-- A lit piece burns while output is blocked, without taking another unit.
for index=1,4 do inv:set_stack("dst",index,"illegal") end
automatic.advance("furnace",inv,state,3)
check(state.fuel==2 and inv:get_stack("fuel",1):get_count()==1,"blocked burn semantics")

-- Exact exhaustion immediately acquires the next piece when work can continue.
for index=1,4 do inv:set_stack("dst",index,"") end
automatic.advance("furnace",inv,state,2)
check(state.fuel==15 and inv:get_stack("fuel",1):is_empty(),"same-tick seamless refuel")

local dual=inventory({input=2,fuel=1,output=2})
dual:set_stack("input",1,"a");dual:set_stack("input",2,"b")
dual:set_stack("fuel",1,"grug_smelting:charcoal")
local dual_state={}
automatic.advance("dual_furnace",dual,dual_state,4)
check(dual:get_stack("output",1):get_name()=="alloy" and dual_state.fuel==76,
	"dual furnace work")
local fuel_fraction,progress_fraction=automatic.fractions("dual_furnace",dual,dual_state)
check(fuel_fraction==0.95 and progress_fraction==0,"fractions")

local brewing=inventory({mixture=1,fuel=1,output=2})
brewing:set_stack("mixture",1,"brewinput");brewing:set_stack("fuel",1,"brewfuel")
local brewing_state={}
automatic.advance("brewing_stand",brewing,brewing_state,5)
check(brewing:get_stack("output",1):get_name()=="jar" and
	brewing:get_stack("output",2):get_name()=="potion","brewing replacements preserved")

print("r21_furnace_automatic_kat\tpass")
