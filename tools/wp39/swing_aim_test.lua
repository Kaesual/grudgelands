-- Focused plain-Lua-5.1 loader test for WP39's real held-swing integration.

local repo = arg[1] or "."
local now = 0
local ray_queue = {}
local ray_calls = 0
local globalsteps = {}
local joins = {}
local mods_loaded = {}
local native_input_handler
local melee_prepare
local melee_finish

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
function vector.add(a, b) return {x = a.x+b.x, y = a.y+b.y, z = a.z+b.z} end
function vector.subtract(a, b) return {x = a.x-b.x, y = a.y-b.y, z = a.z-b.z} end
function vector.multiply(a, n) return {x = a.x*n, y = a.y*n, z = a.z*n} end
function vector.offset(a, x, y, z) return {x = a.x+x, y = a.y+y, z = a.z+z} end
function vector.distance(a, b)
	local x, y, z = a.x-b.x, a.y-b.y, a.z-b.z
	return math.sqrt(x*x+y*y+z*z)
end
function vector.normalize(a)
	local n = vector.distance(a, {x=0,y=0,z=0})
	return n > 0 and {x=a.x/n,y=a.y/n,z=a.z/n} or {x=0,y=0,z=0}
end
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.round(a) return vector.new(a) end

local Stack = {}
Stack.__index = Stack
local function copy_table(src)
	local out = {}
	for k, v in pairs(src or {}) do out[k] = v end
	return out
end
function ItemStack(value)
	local stack = setmetatable({name = "", wear = 0, meta = {}}, Stack)
	if getmetatable(value) == Stack then
		stack.name, stack.wear = value.name, value.wear
		stack.meta = copy_table(value.meta)
		stack.caps = value.caps
	elseif type(value) == "string" then
		stack.name = value
	end
	return stack
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:equals(other) return self.name == other.name end
function Stack:get_wear() return self.wear end
function Stack:set_wear(wear) self.wear = wear end
function Stack:get_definition() return core.registered_items[self.name] or {} end
function Stack:get_tool_capabilities()
	return self.caps or (self:get_definition().tool_capabilities) or
		{full_punch_interval=0.9, damage_groups={fleshy=1}}
end
function Stack:get_meta()
	local owner = self
	return {
		get_string = function(_, key) return owner.meta[key] or "" end,
		set_string = function(_, key, value) owner.meta[key] = value end,
		get_float = function(_, key) return tonumber(owner.meta[key]) or 0 end,
		set_float = function(_, key, value) owner.meta[key] = value end,
		set_tool_capabilities = function(_, caps) owner.caps = caps end,
		set_wear_bar_params = function(_, value) owner.meta.wear_bar = value end,
	}
end

local callbacks = {leave={}, die={}, respawn={}, hpchange={}, punchplayer={}}
core = {
	registered_items = {
		["test:weapon"] = {type="tool", inventory_image="weapon.png",
			tool_capabilities={full_punch_interval=1, damage_groups={fleshy=5}}},
	},
	registered_nodes = {stone={walkable=true}},
	get_us_time = function() return now end,
	get_current_modname = function() return "grug_abilities" end,
	get_modpath = function(name)
		if name == "grug_abilities" then return repo .. "/mods/PLAYER/grug_abilities" end
		return repo .. "/mods/CORE/grug_core"
	end,
	register_tool = function(name, def)
		def.type = "tool"
		core.registered_items[name] = def
	end,
	register_globalstep = function(fn) globalsteps[#globalsteps+1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins+1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave+1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die+1] = fn end,
	register_on_respawnplayer = function(fn) callbacks.respawn[#callbacks.respawn+1] = fn end,
	register_on_player_hpchange = function(fn) callbacks.hpchange[#callbacks.hpchange+1] = fn end,
	register_on_punchplayer = function(fn) callbacks.punchplayer[#callbacks.punchplayer+1] = fn end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded+1] = fn end,
	register_on_player_inventory_action = function() end,
	register_allow_player_inventory_action = function() end,
	get_connected_players = function() return {} end,
	global_exists = function() return false end,
	raycast = function()
		ray_calls = ray_calls + 1
		local hits = table.remove(ray_queue, 1) or {}
		local index = 0
		return function() index=index+1 return hits[index] end
	end,
	get_node_or_nil = function(pos) return {name=pos.name or "stone"} end,
	after = function() end,
	log = function() end,
	add_particle = function() end,
	add_particlespawner = function() end,
	get_objects_inside_radius = function() return {} end,
	get_player_by_name = function() return nil end,
	colorize = function(_, text) return text end,
	chat_send_player = function() end,
}

grug_classes = {
	registered_classes = {warrior={name="Warrior"}},
	get_class_def = function() return {resource="rage"} end,
	get_class = function() return "warrior" end,
	get_max_mana = function() return 0 end,
	get_race_perk = function() return nil end,
	get_melee_bonus = function() return 0 end,
	get_spell_power_bonus = function() return 0 end,
	register_on_class_chosen = function() end,
}
grug_factions = {
	get_faction = function(obj) return obj.faction end,
	hostile = function(a, b) return a.faction and b.faction and a.faction ~= b.faction end,
	same_faction = function(a, b) return a.faction and a.faction == b.faction end,
}
grug_xp = {register_on_level_change=function() end}
grug_mobs = {slow=function() end, root=function() end}

local authoritative
local reset_count = 0
grug_core = {
	get_player_faction = function(name) return name == "hero" and "accord" or "throng" end,
	get_equipped_weapon = function() return ItemStack("test:weapon") end,
	get_equipped_offhand = function() return ItemStack("") end,
	get_melee_bonus = function() return 0 end,
	reset_accumulated_melee = function() reset_count = reset_count + 1 end,
	register_native_melee_handler = function(prepare, finish)
		melee_prepare, melee_finish = prepare, finish
	end,
	prepare_native_melee = function(player, target, fraction, token)
		return melee_prepare(player, target, fraction, token)
	end,
	finish_native_melee = function(context, result)
		return context and melee_finish(context, result)
	end,
	register_native_swing_input_handler = function(fn) native_input_handler = fn end,
	register_ordinary_melee_input_handler = function() end,
	register_on_equipment_change = function() end,
	register_on_player_hit_mob = function() end,
	combat_debug_enabled = function() return false end,
	combat_debug_due = function() return false end,
	combat_debug_log = function() error("disabled debug formatted") end,
	mark_in_combat = function() end,
	in_combat = function() return false end,
	invalidate_melee_target = function() end,
	apply_player_armor = function(_, damage) return damage end,
	roll_melee_crit = function(_, damage) return damage, 1, false end,
	emit_melee_crit = function() end,
	add_threat = function() end,
	get_armor_percent = function() return 0 end,
	ARMOR_APPLIED_CUSTOM_TYPE = "test",
}
function grug_core.begin_authoritative_swing(player, target, context)
	if authoritative then return nil end
	authoritative = {player=player,target=target,context=context,claimed=false}
	return authoritative
end
function grug_core.claim_authoritative_swing(player, target)
	if authoritative and not authoritative.claimed and authoritative.player == player
			and authoritative.target == target then
		authoritative.claimed = true
		return authoritative
	end
end
function grug_core.authoritative_swing_active(player)
	return authoritative and (not player or authoritative.player == player) or false
end
function grug_core.valid_authoritative_swing(token, player, target)
	return token == authoritative and token.claimed and token.player == player
		and token.target == target
end
function grug_core.get_authoritative_swing_context(token)
	return token == authoritative and token.claimed and token.context or nil
end
function grug_core.end_authoritative_swing(token)
	if authoritative == token then authoritative=nil return true end
	return false
end

dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")

local inventory = {main={}, writes=0}
for i=1,32 do inventory.main[i]=ItemStack("") end
inventory.main[1] = ItemStack("grug_abilities:strike")
function inventory:get_lists() return {main=self.main} end
function inventory:get_list(name) return self[name] end
function inventory:get_stack(name, index) return ItemStack(self[name][index]) end
function inventory:set_stack(name, index, stack)
	self.writes=self.writes+1 self[name][index]=ItemStack(stack)
end
function inventory:get_size(name) return #self[name] end
function inventory:add_item(name, stack)
	for i=1,#self[name] do if self[name][i]:is_empty() then self:set_stack(name,i,stack) return end end
end

local hero = {name="hero", faction="accord", hp=20, dig=false, wield=1,
	huds={}, hud_changes=0, pos={x=0,y=0,z=0}}
function hero:get_player_name() return self.name end
function hero:get_pos() return self.pos end
function hero:get_properties() return {eye_height=1.5, hp_max=20} end
function hero:get_eye_offset() return {x=0,y=0,z=0} end
function hero:get_look_dir() return {x=0,y=0,z=1} end
function hero:get_look_horizontal() return 0 end
function hero:get_hp() return self.hp end
function hero:is_player() return true end
function hero:get_inventory() return inventory end
function hero:get_wield_index() return self.wield end
function hero:get_wielded_item() return inventory:get_stack("main", self.wield) end
function hero:get_player_control() return {dig=self.dig} end
function hero:hud_add(def)
	local id=#self.huds+1 self.huds[id]=copy_table(def) return id
end
function hero:hud_change(id, key, value)
	self.hud_changes=self.hud_changes+1 self.huds[id][key]=value
end

local function enemy(name)
	local ent={name=name,_cmi_is_mob=true,_grug_faction="throng",health=20}
	local obj={name=name,faction="throng",pos={x=0,y=1,z=3},ent=ent,
		punches=0,accept=true,landed=true}
	function obj:get_pos() return self.pos end
	function obj:is_player() return false end
	function obj:get_luaentity() return self.ent end
	function obj:punch(hitter, _, _, _)
		self.punches=self.punches+1
		local token=grug_core.claim_authoritative_swing(hitter,self)
		local context=grug_core.prepare_native_melee(hitter,self,1,token)
		if self.accept then
			grug_core.finish_native_melee(context,{landed=self.landed,damage=5,grant_rage=true})
		end
	end
	return obj
end
local a, b = enemy("mob:a"), enemy("mob:b")
local item_ent={name="__builtin:item",picked=0}
function item_ent:on_punch() self.picked=self.picked+1 end
local item={pos={x=0,y=0,z=2}}
function item:get_pos() return self.pos end
function item:is_player() return false end
function item:get_luaentity() return item_ent end

local function pointed(obj, distance)
	return {type="object",ref=obj,intersection_point={x=0,y=1.5,z=distance or 2}}
end
local function queue(...)
	for i=1,select("#",...) do ray_queue[#ray_queue+1]=select(i,...) end
end

dofile(repo .. "/mods/PLAYER/grug_abilities/init.lua")
for _, fn in ipairs(mods_loaded) do fn() end
for _, fn in ipairs(joins) do fn(hero) end
core.get_connected_players = function() return {hero} end
inventory.writes=0

local function swing_step()
	-- First registered globalstep is the real 0.05 s held-swing pass.
	globalsteps[1](0.05)
end
local reticle
for _, def in ipairs(hero.huds) do if def.type == "image" then reticle=def end end
assert(reticle and reticle.text == "")

-- Ready aim miss retains readiness and shows the ring; only the fresh-press
-- loot ray plus one due combat ray ran, with no inventory write.
hero.dig=true
queue({}, {})
swing_step()
assert(a.punches == 0 and reticle.text == "grug_abilities_weapon_ready.png")
assert(inventory.writes == 0 and ray_calls == 2)

-- The first later ray target consumes readiness and hides the ring.
now=100000
queue({pointed(a)})
swing_step()
assert(a.punches == 1 and reticle.text == "")
local rays_after_hit=ray_calls

-- An early held pass performs no combat ray at all.
now=500000
swing_step()
assert(a.punches == 1 and ray_calls == rays_after_hit)

-- Due empty aim keeps ready; a later hostile consumes it.
now=1100000
queue({})
swing_step()
assert(a.punches == 1 and reticle.text == "grug_abilities_weapon_ready.png")
now=1150000
queue({pointed(a)})
swing_step()
assert(a.punches == 2 and reticle.text == "")

-- Native packet target is UI/latch input only; current ray target wins.
hero.dig=false
now=2100000
assert(native_input_handler(hero,a) == true)
queue({pointed(b)})
swing_step()
assert(a.punches == 2 and b.punches == 1)

-- A long step starts at most one attack; no backlog replay.
hero.dig=true
now=5500000
queue({pointed(a)}, {pointed(a)}) -- fresh loot bridge, then combat aim
local before=a.punches
swing_step()
assert(a.punches == before+1)

-- Fresh-press builtin loot pickup consumes only the loot ray and never swings.
hero.dig=false
swing_step()
hero.dig=true
now=6500000
queue({pointed(item)})
before=a.punches+b.punches
local rays_before=ray_calls
swing_step()
assert(item_ent.picked == 1 and a.punches+b.punches == before)
assert(ray_calls == rays_before+1)

-- A valid post-aim callback refusal still consumes cadence.
hero.dig=false
swing_step()
hero.dig=true
now=7500000
a.accept=false
queue({pointed(a)}, {pointed(a)})
before=a.punches
swing_step()
assert(a.punches == before+1 and reticle.text == "")
rays_before=ray_calls
now=7600000
swing_step()
assert(a.punches == before+1 and ray_calls == rays_before)

assert(inventory.writes == 0)
print("swing_aim_test: ok")
