-- Direct stable-query spawn gates. Existing ABM node/biome whitelists own
-- surface habitat after R7; only policies with an independent R4 authority
-- remain here. In particular, this module must not recreate the retired
-- core/inner/outer/coast surface-ring buckets from level ranges.

local VALID_DOMAINS = {
	contested = true,
	underground = true,
}

function grug_mobs.compile_spawn_domains(domains, mob_name)
	if type(domains) ~= "table" or #domains == 0 then
		error("[grug_mobs] invalid spawn domains for " .. mob_name)
	end
	local result = {}
	for i = 1, #domains do
		local domain = domains[i]
		if not VALID_DOMAINS[domain] or result[domain] then
			error("[grug_mobs] invalid spawn domain for " .. mob_name ..
				": " .. tostring(domain))
		end
		result[domain] = true
	end
	return result
end

function grug_mobs.spawn_domain_at(pos)
	if pos.y < -40 then
		return "underground"
	end
	if grug_zones.pvp_rule_at(pos) == "contested" then
		return "contested"
	end
	return nil
end

function grug_mobs.spawn_domains_allow(domains, pos)
	return domains[grug_mobs.spawn_domain_at(pos)] == true
end
