local repo=assert(arg[1])
local env=setmetatable({grug_mounts={}},{__index=_G})
local load=assert(loadfile(repo..'/mods/PLAYER/grug_mounts/catalog.lua'))
setfenv(load,env);load()
for _,key in ipairs({'t1_accord','t1_throng','human','dwarf','elf','undead','orc','troll'})do
 local model=env.grug_mounts.MODELS[key]
 print(key,model.mesh,model.visual_size.x,model.animation.move[1],model.animation.move[2])
end
