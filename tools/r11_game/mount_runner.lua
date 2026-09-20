local root=assert(arg[1],"repository root required")
io.write(assert(loadfile(root.."/tools/r9_mounts/mounts_kat.lua"))()(root,
 {compact=true}))
