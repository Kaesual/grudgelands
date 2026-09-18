return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("absolute repository root required", 0)
	end
	local mutation = os.getenv("R8_ALCH_MUTATION") or ""
	local queue = {}
	local player = {
		name = "tester", hp = 10,
		get_player_name = function(self) return self.name end,
		get_hp = function(self) return self.hp end,
		set_hp = function(self, hp) self.hp = hp end,
	}
	core = {
		register_on_leaveplayer = function() end,
		is_player = function(candidate) return candidate == player end,
		get_player_by_name = function(name)
			return name == player.name and player or nil
		end,
		after = function(_, fn) queue[#queue + 1] = fn end,
		get_connected_players = function() return {} end,
	}
	vector = {distance = function() return 0 end, offset = function(pos) return pos end}
	grug_core = {
		mark_in_combat = function() end,
		get_move_modifier = function() return nil end,
		set_move_modifier = function() end,
	}
	grug_mobs = {}
	dofile(root .. "/mods/ENTITIES/grug_mobs/verbs.lua")
	grug_mobs.poison_player(player, 3, 2, 1)
	if not grug_mobs.is_poisoned(player) then
		error("R8-ALCH poison KAT: application not tracked", 0)
	end
	if mutation ~= "poison_clear" then grug_mobs.clear_poison(player) end
	local index = 1
	while queue[index] do queue[index]() index = index + 1 end
	if player.hp ~= 10 or grug_mobs.is_poisoned(player) then
		error("R8-ALCH poison KAT: Antivenom did not cancel chain", 0)
	end
	return "R8-ALCH poison KAT PASS chains=cancelled exact=all\n"
end
