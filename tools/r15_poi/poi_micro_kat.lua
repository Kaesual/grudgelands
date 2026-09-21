-- Portable bounded KAT for the Round 15 POI blueprints.
-- Suitable for the repository's one final PUC/LuaJIT parity process.

local repo=(arg and arg[1]) or "."
local wp40=repo.."/mods/MAPGEN/grug_mapgen/wp40"
core=core or {get_modpath=function(name)
	assert(name=="grug_mapgen"); return repo.."/mods/MAPGEN/grug_mapgen"
end}

local registry=dofile(repo.."/tools/wp13/stub_registry.lua").load(repo).nodes
local settlement=dofile(wp40.."/r7_settlement.lua")
local wanted={
	anchor_013="quest_steward",anchor_015="quest_steward",anchor_017="quest_steward",
	anchor_019="quest_steward",anchor_021="quest_steward",anchor_023="quest_steward",
	anchor_025="quest_scout",anchor_029="quest_scout",anchor_033="quest_scout",
	anchor_037="quest_scout",anchor_041="quest_scout",anchor_045="quest_scout",
	anchor_049="quest_captive",anchor_051="quest_captive",anchor_053="quest_captive",
	anchor_055="quest_captive",anchor_057="quest_captive",anchor_059="quest_captive"}
local displays={}
dofile(repo.."/mods/MAPGEN/grug_mapgen/poi_displays.lua")({register_node=function(name,def)
	assert(def.diggable==false and def.drop=="" and def.buildable_to==false)
	assert(def.floodable==false and def.groups.not_in_creative_inventory==1)
	for group in pairs(def.groups) do assert(group=="not_in_creative_inventory") end
	displays[name]=def
end})
local count,total,checksum=0,0,0
local silhouettes={}
local function digest(value)
	for i=1,#value do checksum=(checksum*131+value:byte(i))%2147483647 end
end
local function key(x,y,z) return x..":"..y..":"..z end
for _,profile in ipairs(settlement.roster) do
	local socket_id=wanted[profile.anchor_id]
	if socket_id then
		local source=dofile(wp40.."/"..profile.blueprint_file)()
		local prepared=settlement.prepare(profile,source,function() return string.rep("x",32) end)
		assert(#prepared.blueprints==1 and prepared.blueprints[1].descriptor.kind=="anchor")
		local blueprint=prepared.blueprints[1]
		local low,high=-12,11
		if socket_id=="quest_scout" then low,high=-8,7 end
		assert(blueprint.bounds.min.x==low and blueprint.bounds.max.x==high)
		assert(blueprint.bounds.min.z==low and blueprint.bounds.max.z==high)
		local cells={}
		local shape=0
		digest(profile.key.."\n")
		for _,cell in ipairs(source.cells) do
			assert(cell.x>=low and cell.x<=high and cell.z>=low and cell.z<=high)
			cells[key(cell.x,cell.y,cell.z)]=cell.name
			if cell.y>0 and cell.name~="air" then
				shape=(shape*131+(cell.x+12)*997+cell.y*31+cell.z+12)%2147483647
			end
			digest(table.concat({cell.x,cell.y,cell.z,cell.name,cell.param2},"\t").."\n")
			assert(cell.name=="air" or registry[cell.name] or displays[cell.name],"unregistered "..cell.name)
			if cell.name:match("^grug_mapgen:poi_display_") then assert(displays[cell.name]) end
		end
		assert(not silhouettes[shape],"repeated occupied-cell composition")
		silhouettes[shape]=profile.key
		local function at(x,y,z) return cells[key(x,y,z)] end
		assert(at(0,0,0)~="air")
		for y=1,3 do assert(at(0,y,0)=="air") end
		-- Prove every NPC can walk from the arrival crossing with two-node
		-- clearance; this catches walls/roof supports blocking story sockets.
		local start_z=profile.reserve_anchor_root and -1 or 0
		local queue={{x=0,z=start_z}}
		local reachable={[key(0,0,start_z)]=true}
		local cursor=1
		while queue[cursor] do
			local q=queue[cursor]; cursor=cursor+1
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
				local x,z=q.x+d[1],q.z+d[2]
				local k=key(x,0,z)
				if not (profile.reserve_anchor_root and x==0 and z==0) and
					not reachable[k] and at(x,0,z) and at(x,0,z)~="air" and
					at(x,1,z)=="air" and at(x,2,z)=="air" then
					reachable[k]=true; queue[#queue+1]={x=x,z=z}
				end
			end
		end
		-- A bounded three-dimensional walk checks interiors, including stilt stairs.
		local walk,front={[key(0,1,start_z)]=true},{{x=0,y=1,z=start_z}}
		local head=1
		while front[head] do
			local q=front[head]; head=head+1
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do for dy=-1,1 do
				local x,y,z=q.x+d[1],q.y+dy,q.z+d[2]
				local k=key(x,y,z)
				if y>=1 and y<=8 and not walk[k] and at(x,y-1,z) and at(x,y-1,z)~="air"
					and at(x,y,z)=="air" and at(x,y+1,z)=="air"
					and not (profile.reserve_anchor_root and x==0 and z==0) then
					walk[k]=true; front[#front+1]={x=x,y=y,z=z}
				end
			end end
		end
		-- Every core edge has a walkable connection to the arrival, independent of
		-- which side the authoritative existing spur reaches. No terrain is guessed.
		for _,edge in ipairs({{low,0},{high,0},{0,low},{0,high}}) do
			assert(reachable[key(edge[1],0,edge[2])],"blocked fitted-core approach "..profile.key)
		end
		local structures=assert(source.landmarks.structures)
		assert(#structures>=2)
		local unique={}
		for _,structure in ipairs(structures) do
			unique[structure.w..":"..structure.d..":"..structure.h]=true
			if structure.kind=="canopy" and structure.label~="lookout roof" then
				assert(at(structure.x,1,structure.z-structure.d)=="air" and
					at(structure.x,2,structure.z-structure.d)=="air","blocked canopy entry "..profile.key..":"..structure.label)
			end
			local inside=structure.interior
			if inside then assert(walk[key(inside.x,inside.y,inside.z)],profile.key..": inaccessible "..structure.label) end
		end
		local dimensions=0; for _ in pairs(unique) do dimensions=dimensions+1 end
		assert(dimensions>=2,"repeated structure sizes "..profile.key)

		for _,cell in ipairs(source.cells) do
			if cell.name=="default:ladder_wood" then
				assert(cell.param2==4 and at(cell.x,cell.y,cell.z+1)~="air","unsupported lookout ladder")
				assert(cell.y==1 or at(cell.x,cell.y-1,cell.z)=="default:ladder_wood","broken ladder run")
				if at(cell.x,cell.y+1,cell.z)~="default:ladder_wood" then
					-- The topmost ladder must open inward onto supported two-node
					-- standing space. Checking every ladder catches later overlays.
					local support=registry[at(cell.x,cell.y,cell.z+1)]
					assert(support and support.walkable~=false,"unsupported lookout landing "..profile.key)
					assert(at(cell.x,cell.y+1,cell.z+1)=="air" and
						at(cell.x,cell.y+2,cell.z+1)=="air","blocked lookout landing "..profile.key)
				end
			elseif cell.name=="grug_decor:xdecor_lantern" or cell.name=="grug_decor:xdecor_candle" then
				assert(at(cell.x,cell.y-1,cell.z) and at(cell.x,cell.y-1,cell.z)~="air","unsupported light")
			end
		end
		local sockets=assert(blueprint.landmarks.sockets)
		local found,local_giver
		for _,socket in ipairs(sockets) do
			assert(socket.role=="quest" or socket.role=="idle" or
				socket.role=="guard_post")
			assert(reachable[key(socket.x,0,socket.z)], "unreachable socket "..profile.key..":"..socket.id)
			digest(table.concat({socket.id,socket.role,socket.x,socket.y,socket.z},"\t").."\n")
			if socket.id==socket_id then found=socket end
			if socket.id=="quest_local" then local_giver=socket end
		end
		assert(found and found.role=="quest")
		if socket_id=="quest_steward" then assert(local_giver and local_giver.role=="quest") end
		if socket_id~="quest_steward" then
			assert(profile.reserve_anchor_root==true,
				"functional outpost/camp root is not reserved")
		end
		if socket_id=="quest_captive" then
			assert(found.x*found.x+found.z*found.z>12*12,
				"captive overlaps the hostile spawn radius")
			assert(found.x==10 and found.z==10)
		end
		count=count+1
		total=total+#source.cells
		wanted[profile.anchor_id]=nil
	end
end
for anchor in pairs(wanted) do error("missing POI "..anchor,0) end
assert(count==18)
io.write(table.concat({"r15_poi_v1",count,total,checksum},"\t"),"\n")
