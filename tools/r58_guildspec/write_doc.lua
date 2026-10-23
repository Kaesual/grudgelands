-- Round 58 lane GUILDSPEC: the spec's generated model tables.
--
--   luajit tools/r58_guildspec/write_doc.lua REPO [--check]
--
-- Replaces the block between "<!-- generated: guild-model -->" and
-- "<!-- end generated -->" in docs/design/miners_guild.md with the yield
-- model's tables (model.lua) at the catalogue's numbers. --check writes
-- nothing and raises (exit 1) when the block is stale (the fixture runs the same
-- comparison).

local M = {}

M.DOC = "/docs/design/miners_guild.md"
M.OPEN = "<!-- generated: guild-model -->"
M.CLOSE = "<!-- end generated -->"

-- The doc text with a fresh block, and whether it differed.
function M.render(repo)
	local model = dofile(repo .. "/tools/r58_guildspec/model.lua")
	local handle = assert(io.open(repo .. M.DOC, "rb"))
	local text = handle:read("*a")
	handle:close()
	local first = assert(text:find(M.OPEN, 1, true), "no generated block in " .. M.DOC)
	local last = assert(text:find(M.CLOSE, first, true), "unclosed generated block")
	local fresh = text:sub(1, first - 1) .. M.OPEN .. "\n" .. model.markdown(model.run(repo)) ..
		"\n" .. text:sub(last)
	return fresh, fresh ~= text
end

if arg and arg[0] and arg[0]:match("write_doc%.lua$") and arg[1] then
	local fresh, stale = M.render(arg[1])
	if arg[2] == "--check" then
		if stale then error("STALE " .. M.DOC .. ": run luajit tools/r58_guildspec/write_doc.lua REPO", 0) end
		print("current " .. M.DOC)
		return M
	end
	if stale then
		local out = assert(io.open(arg[1] .. M.DOC, "wb"))
		out:write(fresh)
		out:close()
	end
	print((stale and "wrote " or "unchanged ") .. M.DOC)
end

return M
