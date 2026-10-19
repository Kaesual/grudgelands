-- Round 52 PFX: every card's emitters against the real particle helper.
--
--   luajit tools/r52_pfx/check_limits.lua      (from the repository root;
--   tools/bin/lua51 works too)
--
-- Loads mods/CORE/grug_core/particles.lua and particle_effects.lua with a
-- minimal engine stub, then for every card of emitters.lua (written by
-- effects.py):
--   * particles.check, the helper's own budget rules (MAX_TIME 1 s per
--     spawner, MAX_COUNT 128 per emitter, MAX_EXPTIME 3 s, never attached,
--     never private), must pass;
--   * a "keep" card must equal the shipped catalogue entry of its id field
--     for field (a function effect evaluated with the card's sample frame);
--     a card that only changes the colour ("retint", or a keep whose colour
--     comes from frame.color) must equal it in every field but the colour.
-- Ends with an error (exit status 1) on any failure. Pure Lua 5.1, no world, no engine.

core = {
	settings = {get = function() return nil end},
	log = function(level, text) io.stderr:write(level .. ": " .. text .. "\n") end,
	yaw_to_dir = function() return {x = 1, y = 0, z = 0} end,
}
vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
grug_core = {}

dofile("mods/CORE/grug_core/particles.lua")
dofile("mods/CORE/grug_core/particle_effects.lua")
local particles = grug_core.particles
local cards = dofile("tools/r52_pfx/emitters.lua")

local function equal(a, b, skip_color)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		if type(a) == "number" then
			return math.abs(a - b) < 1e-6
		end
		return a == b
	end
	for key, value in pairs(a) do
		if not (skip_color and key == "color") and not equal(value, b[key], skip_color) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil and not (skip_color and key == "color") then
			return false
		end
	end
	return true
end

local failures, checked, compared = 0, 0, 0
for _, card in ipairs(cards) do
	checked = checked + 1
	local problem = particles.check(card.emitters)
	if problem then
		failures = failures + 1
		print("FAIL " .. card.key .. ": " .. problem)
	end
	if card.status == "keep" or card.status == "retint" then
		local shipped = particles.registered(card.id)
		if type(shipped) == "function" then
			shipped = shipped(card.sample)
		end
		compared = compared + 1
		local skip = card.status == "retint" or card.frame_color
		if not shipped then
			failures = failures + 1
			print("FAIL " .. card.key .. ": no shipped effect " .. card.id)
		elseif not equal(card.emitters, shipped, skip) then
			failures = failures + 1
			print("FAIL " .. card.key .. ": differs from the shipped " .. card.id)
		end
	end
end
print(string.format("%d cards checked against particles.check, %d compared with the shipped catalogue, %d failures",
	checked, compared, failures))
if failures > 0 then
	error(failures .. " card(s) fail the particle helper's rules", 0)
end
