local root = arg[1] or "."
local callbacks = {}
core = {registered_items={ ["test:ore"]={description="Ore"}, ["test:bar"]={description="Bar"}},
	registered_nodes={ ["default:furnace"]={} },
	formspec_escape=function(v) return tostring(v) end,
	get_all_craft_recipes=function(name) if name=="test:bar" then return {{method="cooking",width=1,items={"test:ore"},output="test:bar"}} end return {} end,
	register_on_mods_loaded=function(fn) callbacks.mods_loaded=fn end,
	register_on_player_receive_fields=function(fn) callbacks.fields=fn end,
	register_on_leaveplayer=function() end, show_formspec=function() end,
	get_item_group=function() return 0 end,
}
sfinv={pages={['sfinv:crafting']={}},override_page=function(_,d) sfinv.page=d end,
	make_formspec=function(_,_,content) return content end,set_page=function() end}
grug_jobs={PROFESSIONS={},PRIMARY_SLOTS=2,STATIONS={furnace={node="default:furnace"}},
	_item_name=function(v) return tostring(v):match("^([^%s]+)") end,
	_flatten_inputs=function(v) return v end, recipe_for_craft=function() return nil end,
	recipes_for=function() return {} end, has=function() return false end,
	basics_presentation={bind=function(rows) for _,r in ipairs(rows) do r.basics_presentation={starter=true} end return rows end},
	recipe_discovered=function() return true end, primary_at=function() return nil end}
dofile(root.."/mods/PLAYER/grug_jobs/ui.lua")
local player={get_player_name=function() return "formspec" end}
local fs=grug_jobs.book_formspec(player,"general")
assert(fs:find("item_image[4.18,7.38;0.72,0.72;default:furnace]",1,true),"furnace not below arrow")
assert(fs:find("Acquire the main material to reveal more recipes.",1,true),"discovery guidance missing")
assert(not fs:find("item_image[0.25,6.55;0.85,0.85;default:furnace]",1,true),"old left station icon remains")
print("R12 RECIPES formspec PASS furnace-below-arrow guidance")
