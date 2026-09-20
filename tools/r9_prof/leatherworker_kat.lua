-- Superseded catalog shape: Round 10 split smith ownership, universal feedstocks
-- and station operations are covered by the current independent contract.
return function(repo)
	return dofile(repo .. "/tools/r10_equip/profession_contract_kat.lua")(repo)
end
