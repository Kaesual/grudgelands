return function(repo)
	return assert(loadfile(repo ..
		"/tools/r10_farm/farming_completion_kat.lua"))()(repo)
end
