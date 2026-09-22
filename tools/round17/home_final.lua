-- Included once in the coordinator's integrated final PUC/LuaJIT fixture.
return function(repo)
 return dofile(repo.."/tools/round17/home_sources.lua")(repo) ..
  dofile(repo.."/tools/round17/home_micro.lua")(repo) ..
  dofile(repo.."/tools/wp13/start_npcs_kat.lua")(repo)
end
