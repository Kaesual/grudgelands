return function(root)
	local registered
	core = {
		register_craftitem = function(_, def) registered = def end,
		chat_send_player = function() end,
	}
	local values = {}
	local player = {hp = 50}
	function player:is_player() return true end
	function player:get_player_name() return "hero" end
	function player:get_hp() return self.hp end
	function player:get_properties() return {hp_max = 100} end
	function player:get_meta()
		return {
			get_string = function(_, key) return values[key] or "" end,
			set_string = function(_, key, value) values[key] = value end,
		}
	end
	local amount_seen, bonus_calls = 0, 0
	grug_core = {
		heal_player = function(_, _, amount) amount_seen = amount end,
		trinket_instant_potion = function(_, amount)
			bonus_calls = bonus_calls + 1
			return amount * 1.1
		end,
	}
	grug_traders = {}
	dofile(root .. "/mods/ENTITIES/grug_traders/potion.lua")
	local stack = {count = 1}
	function stack:take_item(count) self.count = self.count - count end
	assert(registered.on_use(stack, player) == stack)
	assert(amount_seen == 17 and bonus_calls == 1 and stack.count == 0)
	assert(grug_traders.potion_cooldown_left(player) > 0)
	return "r10_potion|base=15|loop=17|bonus_calls=1\n"
end
