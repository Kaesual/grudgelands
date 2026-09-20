-- Deterministic three-of-four conceptual equipment-vendor rotation.
return function(repo)
	local names={"core","grug_traders","grug_gear","grug_items","grug_money",
		"grug_xp","ItemStack","PcgRandom","os"}
	local saved={}; for _,name in ipairs(names) do saved[name]=rawget(_G,name) end
	local function restore() for _,name in ipairs(names) do rawset(_G,name,saved[name]) end end
	local function fail(message) restore(); error("r10 vendor rotation: "..message,0) end
	local clock=0
	os={time=function() return clock end}
	core={registered_items={},register_on_mods_loaded=function() end,
		colorize=function(_,v)return v end,log=function()end}
	local roller=false
	function core.global_exists(name) return name=="grug_items" and roller end
	function PcgRandom(seed)
		local state=seed%2147483647
		return {next=function(_,low,high)
			state=(state*48271)%2147483647
			return low+(state%(high-low+1))
		end}
	end
	function ItemStack(name)
		local ints={}
		return {get_meta=function() return {set_int=function(_,k,v)ints[k]=v end,
			set_string=function()end} end}
	end
	grug_items={roll_enchants=function() return true end}
	grug_money={}; grug_xp={get_level=function()return 60 end}
	local fixed={}; for index=1,13 do fixed[index]="test:fixed"..index end
	local extras={}; for _,family in ipairs({"dagger","greataxe","staff","wand","bow"}) do
		extras[#extras+1]="test:"..family.."_bronze"
	end
	local all={}; for _,v in ipairs(fixed)do all[#all+1]=v end
	for _,v in ipairs(extras)do all[#all+1]=v end
	grug_gear={BRACKETS={{ilvl=3}},catalog={{fixed=fixed,extras=extras,all=all}},
		get_price=function()return 50 end,bracket_for_level=function()return 1 end,
		weapon_item=function(family)return "test:"..family.."_bronze" end}
	for _,name in ipairs(all)do core.registered_items[name]={description=name} end
	grug_traders={}
	local ok,problem=pcall(dofile,repo.."/mods/ENTITIES/grug_traders/stock.lua")
	if not ok then fail(problem) end
	local caster_seen={}; local uncommon=0
	for hour=1,120 do
		clock=hour*3600
		roller=hour>60
		local shelf=grug_traders.bracket_stock(17,1)
		if #shelf~=16 then fail("shelf is not 13 fixed + 3 rotating") end
		local conceptual={}; local caster_count=0
		for index=14,16 do
			local entry=shelf[index]
			if entry.uncommon then uncommon=uncommon+1 else
				local family=entry.item:match("test:([a-z]+)_bronze")
				if family=="wand" then
					caster_count=caster_count+1; caster_seen[family]=true; family="caster1h"
				end
				if conceptual[family] then fail("conceptual family duplicated") end
				conceptual[family]=true
			end
		end
		if not roller and caster_count>1 then fail("multiple caster 1H forms on shelf") end
	end
	if not caster_seen.wand then
		fail("active caster sub-selection omitted wand")
	end
	if uncommon==0 or uncommon>=60 then fail("one-in-five Uncommon exception absent") end
	restore()
	return "r10_vendor\t13+3\tfour concepts\tcaster deterministic\tUncommon retained\tPASS\n"
end
