-- Exercise the real lazy settlement bind/settle path after CITY decoration.
local root=assert(arg[1],"usage: lazy_test.lua REPO")
local wp=root.."/mods/MAPGEN/grug_mapgen/wp40"
local settlement=dofile(wp.."/r7_settlement.lua")
local sha=dofile(root.."/tools/wp40/r6/common.lua").new_sha256()
local profile
for _,row in ipairs(settlement.roster) do if row.key=="copperfell_village" then profile=row break end end
assert(profile and profile.lazy)
local source=dofile(wp.."/"..profile.blueprint_file)()
local prepared=settlement.prepare(profile,source,sha)
assert(prepared.blueprints[1].cells==nil,"fixture did not prepare lazily")
local refs={};for i,name in ipairs(prepared.palette) do refs[name]=i end
local content={schema="grug_wp13_settlement_content_v1",content_names=prepared.palette,content_ref=function(name)return refs[name]end,resolve=function(ref,param2)return 1000+ref,param2 end}
local config=settlement.config(prepared,content,sha)
local tail=config.new({zones_session={anchor=function(zone,slot)assert(zone==profile.zone_id and slot==profile.slot);return{id=profile.anchor_id,numeric_id=profile.numeric_id,x=0,y=0,z=0}end}})
local plan={};tail:bind_plan({x=-20,y=-10,z=-20},{x=20,y=30,z=20},plan,1)
local writes=0
local ledger=tail:settle({plan=plan,generation=1,min_x=-20,max_x=20,min_y=-10,max_y=30,min_z=-20,max_z=20,inside_owner=function()return true end,write_hearthpine=function()writes=writes+1 end})
local metrics=tail:metrics()
assert(writes>0 and ledger.written==writes,"lazy settle wrote nothing")
assert(metrics.build_calls==1,"lazy cells did not rebuild exactly once")
io.write("R75 CITY LAZY PASS writes="..writes.."\n")

-- A real decorated capital plot with a non-zero turn must rotate the new
-- facedir wall detail with its support. This uses the same lazy config,
-- bind_plan, cells_of and settle path as production.
local highcourt
for _,row in ipairs(settlement.roster) do if row.key=="highcourt" then highcourt=row break end end
assert(highcourt and highcourt.lazy)
local kit=dofile(wp.."/r7_capital_blueprint.lua").kit("highcourt")
local plot
for _,row in ipairs(kit.plots) do if row.id=="market_workshop" then plot=row break end end
assert(plot,"rotated fixture plot missing")
local one=settlement.prepare_plot(highcourt,plot,sha)
one.descriptor.offset={x=0,z=0};one.descriptor.base_y=0;one.descriptor.turns=1
local capital={schema="grug_wp13_settlement_prepared_v1",profile=highcourt,
	blueprints={one},palette=one.palette}
local capital_refs={};for i,name in ipairs(capital.palette) do capital_refs[name]=i end
local capital_content={schema="grug_wp13_settlement_content_v1",content_names=capital.palette,
	content_ref=function(name)return capital_refs[name]end,
	resolve=function(ref,param2)return 2000+ref,param2 end}
local rotated=settlement.config(capital,capital_content,sha).new({
	zones_session={anchor=function()return{id=highcourt.anchor_id,numeric_id=highcourt.numeric_id,
		x=highcourt.x,y=0,z=highcourt.z}end},
	planner_source={column_values_at=function()return nil,nil,nil,nil,nil,0,nil end,
		road_column_at=function()return"surface",0 end}})
local capital_plan={}
rotated:bind_plan({x=highcourt.x-20,y=-10,z=highcourt.z-20},
	{x=highcourt.x+20,y=30,z=highcourt.z+20},capital_plan,2)
local written={}
rotated:settle({plan=capital_plan,generation=2,min_x=highcourt.x-20,max_x=highcourt.x+20,
	min_y=-10,max_y=30,min_z=highcourt.z-20,max_z=highcourt.z+20,
	inside_owner=function()return true end,
	write_hearthpine=function(x,y,z,cid,param2,ref)
		written[x..":"..y..":"..z]={name=capital.palette[ref],param2=param2}
	end})
local catalog=dofile(wp.."/city_decor_catalog.lua")
local placement
for _,row in ipairs(catalog.highcourt.market_workshop) do
	for _,p in ipairs(row.placements) do if p.node=="grug_decor:city_tool_board" then placement=p end end
end
assert(placement,"rotated fixture detail missing")
local rot=dofile(wp.."/../wp13/plot_approach.lua").rot
local x,z=rot(placement.x,placement.z,1)
local detail=written[(highcourt.x+x)..":"..placement.y..":"..(highcourt.z+z)]
assert(detail and detail.name==placement.node and detail.param2==(placement.param2+1)%4,
	"decorated facedir did not rotate with its district")
local sx,sz=rot(placement.x+placement.support_dx,placement.z+placement.support_dz,1)
local support=written[(highcourt.x+sx)..":"..placement.y..":"..(highcourt.z+sz)]
assert(support and support.name==placement.support,"rotated detail lost its wall support")

local function verify_painting_turn()
	local painting_plot
	for _,row in ipairs(kit.plots) do
		if row.id=="homes_house_gable" then painting_plot=row break end
	end
	assert(painting_plot,"rotated painting fixture plot missing")
	local prepared_plot=settlement.prepare_plot(highcourt,painting_plot,sha)
	prepared_plot.descriptor.offset={x=0,z=0}
	prepared_plot.descriptor.base_y=0
	prepared_plot.descriptor.turns=3
	local prepared={schema="grug_wp13_settlement_prepared_v1",profile=highcourt,
		blueprints={prepared_plot},palette=prepared_plot.palette}
	local refs={};for i,name in ipairs(prepared.palette) do refs[name]=i end
	local channel={schema="grug_wp13_settlement_content_v1",content_names=prepared.palette,
		content_ref=function(name)return refs[name]end,
		resolve=function(ref,param2)return 3000+ref,param2 end}
	local tail=settlement.config(prepared,channel,sha).new({
		zones_session={anchor=function()return{id=highcourt.anchor_id,
			numeric_id=highcourt.numeric_id,x=highcourt.x,y=0,z=highcourt.z}end},
		planner_source={column_values_at=function()return nil,nil,nil,nil,nil,0,nil end,
			road_column_at=function()return"surface",0 end}})
	local plan={}
	tail:bind_plan({x=highcourt.x-20,y=-10,z=highcourt.z-20},
		{x=highcourt.x+20,y=30,z=highcourt.z+20},plan,3)
	local cells={}
	tail:settle({plan=plan,generation=3,min_x=highcourt.x-20,max_x=highcourt.x+20,
		min_y=-10,max_y=30,min_z=highcourt.z-20,max_z=highcourt.z+20,
		inside_owner=function()return true end,
		write_hearthpine=function(x,y,z,cid,param2,ref)
			cells[x..":"..y..":"..z]={name=prepared.palette[ref],param2=param2}
		end})
	local p
	for _,row in ipairs(catalog.highcourt.homes_house_gable) do
		for _,candidate in ipairs(row.placements) do
			if candidate.node=="grug_decor:city_painting_highcourt" then p=candidate end
		end
	end
	assert(p,"rotated painting detail missing")
	local px,pz=rot(p.x,p.z,3)
	local detail_cell=cells[(highcourt.x+px)..":"..p.y..":"..(highcourt.z+pz)]
	assert(detail_cell and detail_cell.name==p.node and
		detail_cell.param2==(p.param2+3)%4,"painting did not rotate with its district")
	local wx,wz=rot(p.x+p.support_dx,p.z+p.support_dz,3)
	local wall=cells[(highcourt.x+wx)..":"..p.y..":"..(highcourt.z+wz)]
	assert(wall and wall.name==p.support,"rotated painting lost its wall support")
end
verify_painting_turn()
local parts=dofile(wp.."/../wp13/parts.lua")
assert(parts.param2_kind("grug_decor:city_painting_highcourt")==parts.FACEDIR and
	parts.param2_kind("grug_decor:city_cottages_barrel_lying")==parts.FACEDIR and
	parts.param2_kind("grug_decor:city_xdecor_workbench")==parts.FACEDIR and
	parts.param2_kind("grug_decor:city_xdecor_candle")==parts.WALLMOUNTED and
	parts.param2_kind("grug_decor:city_xdecor_curtain_open")==parts.WALLMOUNTED and
	parts.param2_kind("grug_decor:city_unknown_full_cube")==parts.NONE,
	"city clone param2 classifications differ")
io.write("R75 CITY ROTATED LAZY PASS "..placement.node.."\n")
