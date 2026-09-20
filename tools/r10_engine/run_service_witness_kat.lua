local root=assert(arg[1],"root required")
local scratch=assert(arg[2],"scratch required")
local result=assert(loadfile(root.."/tools/r10_engine/service_witness_kat.lua"))()(root,scratch)
io.write(result,"\n")
