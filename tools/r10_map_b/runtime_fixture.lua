-- Full real runtime assembly for LuaJIT only, including actual settlement palette.
return function(repo, seed)
 local common=dofile(repo.."/tools/wp40/r6/common.lua")
 local _,api,projection,sha=dofile(repo.."/tools/r10_map_b/content_fixture.lua")(repo)
 local registry=dofile(repo.."/tools/wp13/stub_registry.lua").load(repo)
 for name,def in pairs(registry.nodes) do
  if not api.registered_nodes[name] then api.registered_nodes[name]=def end
 end
 local names,cids={},{}
 for name in pairs(api.registered_nodes) do names[#names+1]=name end
 table.sort(names)
 for index,name in ipairs(names) do cids[name]=index end
 function api.get_content_id(name) return assert(cids[name],"runtime fixture unknown node "..name) end
 function api.get_name_from_content_id(cid) return names[cid] end
 api.CONTENT_AIR=cids.air;api.CONTENT_IGNORE=cids.ignore
 function api.sha256(bytes,raw) local digest=sha(bytes);return raw and digest or common.hex(digest) end
 local settings={mg_name="v7",water_level="1",mapgen_limit="31007",chunksize="5",
  mgv7_dungeon_ymin="-31000",mgv7_dungeon_ymax="-193",
  mg_flags="biomes,caves,decorations,dungeons,light,ores",
  mgv7_spflags="mountains, ridges, nofloatlands, caverns",seed=seed or "4151598227737528026"}
 function api.get_mapgen_setting(name) return settings[name] end
 api.settings={get=function(_,name) if name=="num_emerge_threads" then return "1" end end}
 function api.read_schematic(path) return common.read_mts(path) end
 function api.get_mapgen_object(name)
  assert(name=="heightmap");local result={};for i=1,6400 do result[i]=-31007 end;return result
 end
 return api,projection
end
