from pathlib import Path
import shutil
out=Path('/tmp/grug-sampling-audit-harness/tools/wp40/profile/probe/init.lua');s=out.read_text()
s=s.replace('\tlocal ordinal_by_cid, vocabulary = {}, {}','\tlocal ordinal_by_cid, vocabulary, resource_cids = {}, {}, {}',1)
s=s.replace('\t\tordinal_by_cid[cid] = ordinal','''		ordinal_by_cid[cid] = ordinal
		if (core.registered_nodes[name].groups or {}).grug_resource then
			local resource = grug_materials.resource_for_node(name)
			if resource then resource_cids[cid] = resource.key end
		end''',1)
s=s.replace('\t\tcontent = nil\n', '''		local counts = {}
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				local host = core.get_content_id(grug_materials.stratum_node_for(y))
				for x = minp.x, maxp.x do
					local index = area:index(x, y, z)
					local resource = resource_cids[content[index]]
					if resource then
						counts[resource] = (counts[resource] or 0) + 1
						content[index] = host
					end
				end
			end
		end
		local normalized = digest_channel(content, area, minp, maxp, 4, true)
		local keys = {}
		for key in pairs(counts) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			log({"phase=" .. phase, "event=ore_count", "case=" .. case.id,
				"resource=" .. key, "nodes=" .. counts[key]})
		end
		content = nil
''',1)
s=s.replace('\t\tvm:close()','''		log({"phase=" .. phase, "event=normalized_owner", "case=" .. case.id,
			"normalized=" .. normalized, "param2=" .. param2_digest,
			"light=" .. light_digest})
		vm:close()''',1);out.write_text(s)
for label,source in [('baseline','/tmp/grug-throughput-baseline-game'),('sampler','/tmp/grug-resource-sampling')]:
 dst=Path('/tmp/grug-sampling-audit-'+label+'-game');dst.mkdir()
 for name in ['mods','game.conf','minetest.conf']:
  src=Path(source)/name
  if src.is_dir(): shutil.copytree(src,dst/name)
  else: shutil.copy(src,dst/name)
 p=dst/'mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua';s=p.read_text()
 marker='\n'+ ('\t'*9 if label=='baseline' else '\t'*10)+'if ledger then\n'
 a=s.index(marker,s.index('local next_root_rank = 1',s.index('local function apply_impl')))
 indent='\t'*(9 if label=='baseline' else 10)
 log='''if call_mode == "production" then
	core.log("action", table.concat({"GRUG_RESOURCE_AUDIT", resource.key,
		cell_x, cell_y, cell_z, tier, band, eligible, budget, planned,
		accepted, collisions, shortfall, placed}, "\\t"))
end'''
 s=s[:a]+'\n'+'\n'.join(indent+l for l in log.splitlines())+s[a:];p.write_text(s)
