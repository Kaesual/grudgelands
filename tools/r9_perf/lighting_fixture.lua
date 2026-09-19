-- Compact final-byte coverage of explicit R5 delegation and outer validation.
return function(repo)
	local result = dofile(repo .. "/tools/r9_perf/writer_equivalence.lua")(
		repo, nil, true, true)
	dofile(repo .. "/tools/wp40/quality/gravewood_writer_fixture.lua")(
		repo, repo, false, true)
	return "r9_perf_lighting\tdelegation=pass outer_invalid_context=fail_closed\n" .. result
end
