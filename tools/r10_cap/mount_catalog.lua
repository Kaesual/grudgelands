-- LuaJIT-only export of the actual display appearance catalog.
local repo=assert(arg[1])
grug_mounts={}
dofile(repo..'/mods/PLAYER/grug_mounts/catalog.lua')
local keys={}
for key in pairs(grug_mounts.MODELS) do keys[#keys+1]=key end
table.sort(keys)
for _,key in ipairs(keys) do
 local m=grug_mounts.MODELS[key]
 print(key,m.mesh,m.visual_size.x,m.animation.stand[1],table.concat(m.textures,'|'))
end
