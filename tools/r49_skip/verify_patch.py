#!/usr/bin/env python3
"""Build the disposable GAME_PATCH of the lane SKIP verification boot.

Round 49 lane SKIP (tools/r49_skip/run_verify.sh). The patch touches only the
staged game copy of tools/luanti_headless.sh: in r7_mapgen.lua the refinement
still asks both untouched-chunk tests (air_chunks.lua), but runs the full
writer on EVERY chunk. For a chunk a test would skip it compares the whole
VoxelManip -- content, param2 and light of the chunk and its 16-node shell --
before and after the writer, and logs one line per chunk:

  [r49skip] chunk X,Y,Z skip=deep|air|none decide_us=.. full_us=.. result=..
            dd=.. dp=.. dl=.. vol=..

(dd/dp/dl: differing content/param2/light entries; -1 when not compared).

Usage: verify_patch.py > patch
"""
import difflib
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
NAME = 'mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua'

OLD = '''	if air_chunks.below(minp, maxp) then return end
	if air_chunks.untouched(minp, maxp, get_heightmap) then return end
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
end
'''

NEW = '''	local r49_t0 = core.get_us_time()
	local r49_skip = air_chunks.below(minp, maxp) and "deep" or
		(air_chunks.untouched(minp, maxp, get_heightmap) and "air" or "none")
	local r49_t1 = core.get_us_time()
	local d0, p0, l0
	if r49_skip ~= "none" then
		d0, p0, l0 = vmanip:get_data(), vmanip:get_param2_data(), vmanip:get_light_data()
	end
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	local r49_t2 = core.get_us_time()
	local dd, dp, dl = -1, -1, -1
	if d0 then
		local d1, p1, l1 = vmanip:get_data(), vmanip:get_param2_data(), vmanip:get_light_data()
		dd, dp, dl = 0, 0, 0
		if #d1 ~= #d0 or #p1 ~= #p0 or #l1 ~= #l0 then dd = -2 end
		for i = 1, #d0 do
			if d0[i] ~= d1[i] then dd = dd + 1 end
			if p0[i] ~= p1[i] then dp = dp + 1 end
			if l0[i] ~= l1[i] then dl = dl + 1 end
		end
	end
	core.log("action", ("[r49skip] chunk %d,%d,%d skip=%s decide_us=%d full_us=%d " ..
		"result=%s dd=%d dp=%d dl=%d vol=%d"):format(minp.x, minp.y, minp.z, r49_skip,
		r49_t1 - r49_t0, r49_t2 - r49_t1, tostring(result), dd, dp, dl, d0 and #d0 or 0))
	if type(result) ~= "string" then fail("writer result differs") end
end
'''


def main():
    with open(os.path.join(REPO, NAME)) as handle:
        before = handle.read()
    if before.count(OLD) != 1:
        sys.exit('instrumentation anchor changed in ' + NAME)
    after = before.replace(OLD, NEW, 1)
    sys.stdout.write(''.join(difflib.unified_diff(
        before.splitlines(True), after.splitlines(True), 'a/' + NAME, 'b/' + NAME)))


if __name__ == '__main__':
    main()
