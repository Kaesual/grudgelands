local root=assert(arg[1],"repository root required")
io.write(assert(loadfile(root.."/tools/r8_mob1/bosses_kat.lua"))()(root))
