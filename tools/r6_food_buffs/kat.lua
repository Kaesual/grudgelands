-- The Round 6 food contract was replaced whole by Food v2. Keep the old gate
-- entrypoint useful without preserving the retired production API.

return function(root)
	return dofile(root .. "/tools/r7_food/kat.lua")(root)
end
