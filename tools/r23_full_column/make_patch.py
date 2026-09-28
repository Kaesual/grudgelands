#!/usr/bin/env python3
"""Build the disposable GAME_PATCH for a bounded full-column engine run.

The patch touches only the staged game copy of tools/luanti_headless.sh:

* minetest.conf: full-world preparation on, harness settings appended.
* preparation_plan.lua: bounds = the measurement region; starts whose
  readiness envelope lies outside it are dropped instead of asserted.
* starts_preload.lua: one log line per committed tile.
* r7_mapgen.lua: one log line per generated chunk (engine gap, fast-path
  decision cost, full-path cost, result, heightmap summary). With --verify
  every chunk runs the full writer, and for chunks the fast path would skip,
  the whole VoxelManip (content, param2, light: chunk and shell) is compared
  before and after the full writer.

Usage: make_patch.py --region X_MIN,X_MAX,Z_MIN,Z_MAX --stop-after SECONDS
       [--verify] [--geo] > patch
"""
import argparse
import difflib
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


def replace_once(source, old, new, name):
    if source.count(old) != 1:
        sys.exit('instrumentation anchor changed in %s: %r' % (name, old[:80]))
    return source.replace(old, new, 1)


def conf(source, args):
    source = replace_once(source, 'grug_prepare_full_world = false\n',
                          'grug_prepare_full_world = true\n', 'minetest.conf')
    return source + ('\n# Round 23 bounded measurement run (disposable)\n'
                     'r23_stop_after = %d\nr23_verify = %s\nr23_geo = %s\n' %
                     (args.stop_after, 'true' if args.verify else 'false',
                      'true' if args.geo else 'false'))


def plan(source, args):
    x0, x1, z0, z1 = args.region
    source = replace_once(
        source,
        'M.bounds = {x_min = -3600 - OCEAN_MARGIN, x_max = 3600 + OCEAN_MARGIN,\n'
        '\tz_min = -3200 - OCEAN_MARGIN, z_max = 3200 + OCEAN_MARGIN}',
        'M.bounds = {x_min = %d, x_max = %d, z_min = %d, z_max = %d} -- r23 region'
        % (x0, x1, z0, z1), 'preparation_plan.lua')
    source = replace_once(
        source,
        '\t\t\tassert(row.min.x >= plan.bounds.min.x and row.max.x <= plan.bounds.max.x and\n'
        '\t\t\t\trow.min.z >= plan.bounds.min.z and row.max.z <= plan.bounds.max.z,\n'
        '\t\t\t\t"Full preparation bounds omit a start envelope")\n'
        '\t\t\tplan.starts[#plan.starts+1] = row\n',
        '\t\t\tif row.min.x >= plan.bounds.min.x and row.max.x <= plan.bounds.max.x and\n'
        '\t\t\t\t\trow.min.z >= plan.bounds.min.z and row.max.z <= plan.bounds.max.z then\n'
        '\t\t\t\tplan.starts[#plan.starts+1] = row\n'
        '\t\t\tend\n', 'preparation_plan.lua')
    return source


def preload(source, args):
    source = replace_once(
        source,
        '\t\tstate.selection = selection_copy(row.selection)\n'
        '\t\tlocal completed = plan_api.complete(state)\n',
        '\t\tstate.selection = selection_copy(row.selection)\n'
        '\t\tlocal r23_tile = state.selection\n'
        '\t\tlocal completed = plan_api.complete(state)\n'
        '\t\tif completed and r23_tile then\n'
        '\t\t\tcore.log("action", ("[r23p] tile %d/%d x=%d z=%d y_min=%d y_max=%d us=%d"):format(\n'
        '\t\t\t\tstate.cursor, state.total, r23_tile.x, r23_tile.z, r23_tile.y_min,\n'
        '\t\t\t\tr23_tile.y_max, core.get_us_time()))\n'
        '\t\tend\n', 'starts_preload.lua')
    return source


MAPGEN_OLD = '''	if air_chunks.untouched(minp, maxp, get_heightmap) then return end
	local plan, generation = built.session.plan_slice(minp, maxp)
	local result = built.writer.apply(vmanip, minp, maxp, plan, generation)
	if type(result) ~= "string" then fail("writer result differs") end
end)'''

MAPGEN_NEW = '''	local r23_t0 = core.get_us_time()
	local r23_fast = air_chunks.untouched(minp, maxp, get_heightmap)
	local r23_t1 = core.get_us_time()
	local hm = get_heightmap()
	local hm_top, hm_bottom, hm_ground = -31007, 31007, 0
	for i = 1, #hm do
		local v = hm[i]
		if v > hm_top then hm_top = v end
		if v < hm_bottom then hm_bottom = v end
		if v >= minp.y then hm_ground = hm_ground + 1 end
	end
	local result, full_us, dd, dp, dl = "skipped", 0, -1, -1, -1
	local d0, p0, l0
	if r23_fast and r23_verify then
		d0, p0, l0 = vmanip:get_data(), vmanip:get_param2_data(), vmanip:get_light_data()
	end
	if not r23_fast or r23_verify then
		local t = core.get_us_time()
		local plan, generation = built.session.plan_slice(minp, maxp)
		result = built.writer.apply(vmanip, minp, maxp, plan, generation)
		full_us = core.get_us_time() - t
		if type(result) ~= "string" then fail("writer result differs") end
	end
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
	core.log("action", ("[r23c] gen %d,%d,%d fast=%d gap_us=%d decide_us=%d full_us=%d result=%s hm_ground=%d hm_top=%d hm_bottom=%d dd=%d dp=%d dl=%d vol=%d"):format(
		minp.x, minp.y, minp.z, r23_fast and 1 or 0, r23_last and (r23_t0 - r23_last) or -1,
		r23_t1 - r23_t0, full_us, result, hm_ground, hm_top, hm_bottom, dd, dp, dl,
		d0 and #d0 or 0))
	r23_last = core.get_us_time()
end)'''


def mapgen(source, args):
    source = replace_once(source, MAPGEN_OLD, MAPGEN_NEW, 'r7_mapgen.lua')
    return replace_once(
        source, 'local function get_heightmap() return core.get_mapgen_object("heightmap") end\n',
        'local function get_heightmap() return core.get_mapgen_object("heightmap") end\n'
        'local r23_verify = core.settings:get_bool("r23_verify", false)\n'
        'local r23_last\n', 'r7_mapgen.lua')


FILES = [
    ('minetest.conf', conf),
    ('mods/CORE/grug_core/preparation_plan.lua', plan),
    ('mods/CORE/grug_core/starts_preload.lua', preload),
    ('mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua', mapgen),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--region', required=True,
                        type=lambda s: [int(v) for v in s.split(',')])
    parser.add_argument('--stop-after', type=int, required=True)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--geo', action='store_true')
    args = parser.parse_args()
    assert len(args.region) == 4 and args.region[0] < args.region[1] and \
        args.region[2] < args.region[3]
    out = []
    for name, edit in FILES:
        with open(os.path.join(REPO, name)) as handle:
            before = handle.read()
        after = edit(before, args)
        out.extend(difflib.unified_diff(
            before.splitlines(True), after.splitlines(True),
            'a/' + name, 'b/' + name))
    sys.stdout.write(''.join(out))


if __name__ == '__main__':
    main()
