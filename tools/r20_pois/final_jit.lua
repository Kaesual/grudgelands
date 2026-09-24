-- Final-only bounded real catalog/manifest/planner gate. No VM population,
-- engine run, seed fleet, copied manifest receipt or historical full suites.
local repo=assert(arg[1],"repository root required")
local out=assert(arg[2],"existing output directory required")
assert(rawget(_G,"jit"),"large real construction is LuaJIT-only")
local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
local api,projection=dofile(repo.."/tools/r10_map_b/runtime_fixture.lua")(repo,"4151598227737528026")
-- Include the real immutable scenery definitions before constructing content IDs.
dofile(repo.."/mods/MAPGEN/grug_mapgen/poi_displays.lua")({register_node=function(name,def)
	api.registered_nodes[name]=def
end})
local names,cids={},{}
for name in pairs(api.registered_nodes) do names[#names+1]=name end
table.sort(names)
for i,name in ipairs(names) do cids[name]=i end
function api.get_content_id(name) return assert(cids[name],"unregistered "..name) end
function api.get_name_from_content_id(cid) return names[cid] end
api.CONTENT_AIR,api.CONTENT_IGNORE=cids.air,cids.ignore
local raw_sha=function(bytes) return api.sha256(bytes,true) end
local catalog=dofile(repo.."/mods/ITEMS/grug_gathering/catalog.lua")
local runtime=dofile(dir.."/r7_runtime.lua")(api,dir,repo.."/mods/BASE/default/schematics",projection,catalog)
-- This invokes the actual constructor, strict r7_manifest.new/validate and
-- real decoded MTS / source anchor roster, once for the entire final process.
local built=runtime.build(dofile(dir.."/r7_native.lua").identities())
assert(built.manifest.sha256)
print("manifest\t"..built.manifest.sha256)
local settlement=dofile(dir.."/r7_settlement.lua")
assert(#settlement.roster==100,"all 100 existing anchors must have art")
local function key(x,y,z) return x..":"..y..":"..z end
local representatives={[14]=true,[16]=true,[18]=true,[24]=true,[27]=true,[39]=true,
	[48]=true,[50]=true,[61]=true,[67]=true,[71]=true,[87]=true,[89]=true,[91]=true,[100]=true}
local families,host_count,site_count,building_count={},0,0,0
local report=assert(io.open(out.."/catalog.tsv","w"))
report:write("id\tbuildings\thost\tsha256\n")
local options={full_seed=built.full_seed,raw_sha256=raw_sha}
for _,profile in ipairs(settlement.roster) do
	if profile.art then
		local spec=profile.art
		local source=dofile(dir.."/"..profile.blueprint_file)(options,profile)
		local prepared=settlement.prepare(profile,source,raw_sha)
		local cells={}
		for _,cell in ipairs(source.cells) do
			assert(cell.name=="air" or api.registered_nodes[cell.name],"unregistered "..cell.name)
			cells[key(cell.x,cell.y,cell.z)]=cell
		end
		local function at(x,y,z) return cells[key(x,y,z)] end
		local function solid(cell)
			if not cell then return false end
			if cell.name=="air" then return false end
			return api.registered_nodes[cell.name].walkable~=false
		end
		local function open(x,y,z)
			local feet,head=at(x,y,z),at(x,y+1,z)
			return feet and head and not solid(feet) and not solid(head) and solid(at(x,y-1,z))
		end
		for x=-2,2 do for z=-2,2 do
			assert(open(x,1,z),profile.key..": actor/host clearance")
		end end
		local reach,queue={[key(0,1,-1)]=true},{{0,1,-1}}
		local cursor=1
		while queue[cursor] do
			local q=queue[cursor];cursor=cursor+1
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do for dy=-1,1 do
				local x,y,z=q[1]+d[1],q[2]+dy,q[3]+d[2];local k=key(x,y,z)
				if not reach[k] and open(x,y,z) then reach[k]=true;queue[#queue+1]={x,y,z} end
			end end
		end
		assert(#source.landmarks.structures==#spec.buildings)
		if #spec.buildings>0 then assert(#spec.buildings>=2) end
		if spec.kind=="village" then assert(#spec.buildings>=4 and #spec.buildings<=6) end
		for _,building in ipairs(source.landmarks.structures) do
			local p,e=building.interior,building.entry
			assert(reach[key(p.x,p.y,p.z)],profile.key..": inaccessible "..building.label)
			local dx=(building.entry_turn==0 or building.entry_turn==2) and 1 or 0
			local dz=1-dx
			for step=0,1 do
				assert(open(e.x+dx*step,e.y,e.z+dz*step),profile.key..": two-node entrance blocked")
				assert(reach[key(e.x+dx*step,e.y,e.z+dz*step)],profile.key..": unreachable entrance")
			end
		end
		local edge=false
		for k in pairs(reach) do
			local x,y,z=k:match("(-?%d+):(-?%d+):(-?%d+)")
			x,z=tonumber(x),tonumber(z)
			if x==source.bounds.min.x or x==source.bounds.max.x or z==source.bounds.min.z or z==source.bounds.max.z then edge=true end
		end
		assert(edge,profile.key..": no connection to perimeter")
		local anchor=assert(built.zones_session.anchor(profile.zone_id,profile.slot))
		local sockets=settlement.sockets(prepared,anchor)
		assert(#sockets==(spec.host and 1 or 0))
		if spec.host then
			assert(sockets[1].id=="quest_host" and sockets[1].role=="quest")
			assert(reach[key(sockets[1].x,sockets[1].y,sockets[1].z)])
			host_count=host_count+1
		end
		site_count=site_count+1;building_count=building_count+#spec.buildings
		families[spec.kind]=(families[spec.kind] or 0)+1
		report:write(profile.anchor_id,"\t",#spec.buildings,"\t",tostring(spec.host),"\t",prepared.blueprints[1].identity.sha256,"\n")
		if representatives[spec.number] then
			local f=assert(io.open(out.."/"..profile.anchor_id..".tsv","w"))
			f:write("# ",profile.label,"\n")
			for _,cell in ipairs(source.cells) do
				if cell.name~="air" then f:write(table.concat({cell.x,cell.y,cell.z,cell.name,cell.param2},"\t"),"\n") end
			end
			f:close()
		end
		-- One representative per construction family is projected across TWO
		-- adjacent owners. Plans come from the real session.plan_slice consumer;
		-- only the final write sink is captured, with an existing actor sentinel.
		if families[spec.kind]==1 then
			local config=settlement.config(prepared,built.content.settlement,raw_sha)
			local tail=config.new({zones_session=built.zones_session})
			local written={}
			written[key(anchor.x,anchor.y+1,anchor.z)]="ACTOR_ROOT"
			for side=1,2 do
				local minp={x=anchor.x+(side==1 and source.bounds.min.x or 0),y=anchor.y,z=anchor.z+source.bounds.min.z}
				local maxp={x=anchor.x+(side==1 and -1 or source.bounds.max.x),y=anchor.y+spec.height,z=anchor.z+source.bounds.max.z}
				local plan,generation=built.session.plan_slice(minp,maxp)
				tail:bind_plan(minp,maxp,plan,generation)
				local function inside(x,y,z) return x>=minp.x and x<=maxp.x and y>=minp.y and y<=maxp.y and z>=minp.z and z<=maxp.z end
				tail:settle({plan=plan,generation=generation,inside_owner=inside,
					write_hearthpine=function(x,y,z,cid,param2)
						assert(inside(x,y,z));local k=key(x,y,z)
						assert(not written[k],profile.key..": duplicate/root write")
						written[k]={name=api.get_name_from_content_id(cid),param2=param2}
					end})
			end
			for _,cell in ipairs(source.cells) do
				local actual=written[key(anchor.x+cell.x,anchor.y+cell.y,anchor.z+cell.z)]
				if cell.x==0 and cell.y==1 and cell.z==0 then assert(actual=="ACTOR_ROOT")
				else assert(actual and actual.name==cell.name and actual.param2==cell.param2,profile.key..": clipped projection differs") end
			end
			print("projection\t"..spec.kind.."\t"..profile.anchor_id.."\t2 owners")
		end
	end
end
report:close()
assert(site_count==70 and host_count==30)
assert(families.village==6 and families.outpost==18 and families.bandit_frontier==6)
assert(families.mine==6 and families.mirefolk==4 and families.apex_mine==2)
assert(families.clash==16 and families.dragon==2 and families.rare_route==10)
-- Civic cooks use the real start patch and real selected service plot builder.
-- Capital envoy sockets are existing core actors, not additional spawns.
local cook_plots={highcourt="homes_bakehouse",dur_brannoc="terrace_bakehouse",
	lethariel="market_bakehouse",nhal_veyr="homes_mourners_hall",
	gor_drazhak="warren_cook_court",kezamba="shore_smokehouse"}
local envoy_sockets={highcourt="chapel_quest",dur_brannoc="ancestor_hall_quest",
	lethariel="star_hall_quest",nhal_veyr="vigil_hall_quest",
	gor_drazhak="skull_hall_quest",kezamba="shrine_quest"}
local civic_count=0
local function clear_standing(source,x,y,z,label)
	local map={};for _,cell in ipairs(source.cells) do map[key(cell.x,cell.y,cell.z)]=cell.name end
	for height=y,y+1 do
		local name=map[key(x,height,z)]
		assert(name=="air" or (name and api.registered_nodes[name] and api.registered_nodes[name].walkable==false),label..": cook body blocked")
	end
	local floor=map[key(x,y-1,z)]
	assert(floor and floor~="air" and api.registered_nodes[floor].walkable~=false,label..": cook has no floor")
end
for _,profile in ipairs(settlement.roster) do
	if profile.slot=="start" or profile.slot=="capital" then
		local source=dofile(dir.."/"..profile.blueprint_file)(options,profile)
		if type(source)=="function" then source=source(options) end
		if profile.slot=="start" then
			source=dofile(dir.."/r20_civic.lua")(source,profile)
			local z=(profile.race=="dwarf" or profile.race=="human" or profile.race=="elf") and 13 or -13
			clear_standing(source,2,1,z,profile.key);civic_count=civic_count+1
		else
			local core_source=source.core.build()
			local envoy=false
			for _,socket in ipairs(core_source.landmarks.sockets) do
				if socket.id==envoy_sockets[profile.key] then assert(socket.role=="quest");envoy=true end
			end
			assert(envoy,profile.key..": missing existing envoy socket")
			local found=false
			for _,plot in ipairs(source.plots) do
				if plot.id==cook_plots[profile.key] then
					local art=plot.build();local socket_found=false
					for _,socket in ipairs(art.landmarks.sockets) do
						if socket.id==plot.id.."_quest_cook" then
							assert(socket.role=="quest");clear_standing(art,socket.x,socket.y,socket.z,profile.key)
							socket_found=true
						end
					end
					assert(socket_found,profile.key..": cook socket missing");found=true
				end
			end
			assert(found,profile.key..": Cooking plot missing");civic_count=civic_count+1
		end
	end
end
assert(civic_count==12)
print("civic\tPASS\t12 cooks / 6 existing envoys")
print("round20-pois\tPASS\tsites="..site_count.."\thosts="..host_count.."\tbuildings="..building_count)
