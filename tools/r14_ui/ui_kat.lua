local root = (... or "."):gsub("/+$", "")
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local pages, joins, leaves, inventory_callbacks, steps = {}, {}, {}, {}, {}
local change = {quests = {}, parties = {}}
local journal = {hud_enabled = true, tracked = {"q1", "q2", "q3"}, quests = {}}
for i = 1, 20 do
	journal.quests[i] = {id = "q" .. i, title = "Quest " .. i,
		description = "A journal description", ready = i == 1, npc = "npc:home",
		objectives = {{type = "kill", mobs = {"mobs:named_threat"}, count = i, required = 20}},
		rewards = {xp = 10, copper = 5, items = {"items:reward 2"}}}
end
local party = {leader = "P1", members = {}}
for i = 1, 10 do party.members[i] = {name = "P" .. i, online = i < 10, hp = 10 + i, hp_max = 20} end
local player = {name = "P1", changes = {}, added = {}}
function player:get_player_name() return self.name end
function player:hud_add(def) self.added[#self.added + 1] = def; return #self.added end
function player:hud_change(id, field, value) self.changes[#self.changes + 1] = {id, field, value};self.added[id][field]=value end
function player:hud_remove(id) self.added[id].removed=true end
local current_page
core = {
	registered_items = {['items:reward'] = {description = "Reward"}},
	registered_entities = {['mobs:named_threat'] = {description = "Named Threat"}},
	formspec_escape = function(value) return tostring(value):gsub("([,;])", "\\%1") end,
	explode_textlist_event = function() return {type = "CHG", index = 1} end,
	register_on_mods_loaded = function(callback) callback() end,
	register_on_joinplayer = function(callback) joins[#joins + 1] = callback end,
	register_on_leaveplayer = function(callback) leaves[#leaves + 1] = callback end,
	register_on_player_inventory_action = function(callback) inventory_callbacks[#inventory_callbacks + 1] = callback end,
	register_globalstep = function(callback) steps[#steps + 1] = callback end,
	get_connected_players = function() return {player} end,
	get_player_by_name = function(name) return name == player.name and player or nil end,
}
function ItemStack(item)
	local name, count = item:match("^(%S+)%s*(%d*)$")
	return {get_name = function() return name end, get_count = function() return tonumber(count) or 1 end}
end
sfinv = {pages = {}, pages_unordered = {{name = "grug_skills:skills"}}}
function sfinv.register_page(name, def) def.name = name; sfinv.pages[name] = def; sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def end
function sfinv.make_formspec(_, _, content) return content end
function sfinv.get_page() return current_page end
function sfinv.set_page(_, page) current_page = page end
grug_inventory = {wrap_text = function(text, width)
	local out, line = {}, ""
	for word in text:gmatch("%S+") do
		if #line > 0 and #line + #word + 1 > width then out[#out + 1], line = line, word
		else line = line == "" and word or line .. " " .. word end
	end
	out[#out + 1] = line
	return table.concat(out, "\n")
end}
grug_money = {format = function(value) return value .. " copper" end}
grug_core = {}
dofile(root .. "/mods/CORE/grug_core/hud_layout.lua")
grug_quests = {
	registered_npcs = {['npc:home'] = {title = "Home Keeper"}},
	journal = function() return journal end,
	register_on_change = function(callback) change.quests[#change.quests + 1] = callback end,
	set_hud_enabled = function(_, enabled) journal.hud_enabled = enabled end,
	set_tracked = function() return true end,
	abandon = function(_, id) check(id == "q1", "selected quest id"); return true end,
}
grug_parties = {
	view = function() return party end, pending = function() return {} end,
	invitations_enabled = function() return true end, hud_enabled = function() return true end,
	register_on_change = function(callback) change.parties[#change.parties + 1] = callback end,
	invite = function(actor, target) check(actor == player and target == "P2", "authenticated invite"); return true, "sent" end,
	set_invitations_enabled = function() return true, "changed" end,
	set_hud_enabled = function() return true, "changed" end,
	accept = function() return true, "joined" end, decline = function() return true, "declined" end,
	leave = function() return true, "left" end, kick = function() return true, "removed" end,
	transfer_leader = function() return true, "transferred" end,
}

dofile(root .. "/mods/PLAYER/grug_quests/ui.lua")
dofile(root .. "/mods/PLAYER/grug_quests/hud.lua")
dofile(root .. "/mods/PLAYER/grug_parties/ui.lua")
dofile(root .. "/mods/PLAYER/grug_parties/hud.lua")
local qpage, ppage = sfinv.pages['grug_quests:quests'], sfinv.pages['grug_parties:group']
local qform = qpage:get(player, {})
check(qform:find("Active quests: 20/20", 1, true), "full quest journal")
check(qform:find("Named Threat", 1, true), "explicit kill target")
check(qform:find("Ready to return", 1, true), "ready return state")
local quest_context = {grug_quest_selected = "q1", grug_quest_abandon = "q1"}
qpage:on_player_receive_fields(player, quest_context, {grug_quest_confirm = "Confirm"})
local pform = ppage:get(player, {})
check(pform:find("P10  Offline", 1, true), "offline party row")
check(not pform:find("Mana", 1, true), "no party mana")
ppage:on_player_receive_fields(player, {}, {grug_party_invite = "Invite", grug_party_invite_name = "P2", grug_party_invites = "true"})
for _, callback in ipairs(joins) do callback(player) end
for _, callback in ipairs(steps) do callback(0.5) end
check(#player.added == 31, "quest plus ten graphical party rows")
local quest_text, party_text = player.added[1].text, ""
for _, def in ipairs(player.added) do if def.type == "text" then party_text=party_text..def.text.."\n" end end
local quest_lines = 0; for _ in (quest_text .. "\n"):gmatch(".-\n") do quest_lines = quest_lines + 1 end
check(quest_lines <= 9, "three wrapped quest blocks fit reservation")
check(party_text:find("P10 %[Offline%]"), "maximum party HUD")
check(not party_text:find("Mana", 1, true), "HUD omits mana")
check(player.added[3].type=="image" and player.added[4].type=="image", "real HP images")
local packets=#player.changes
for _, callback in ipairs(steps) do callback(0.5) end
check(#player.changes==packets, "unchanged HUD sends no packet")
party.members[1].hp=5
for _, callback in ipairs(steps) do callback(0.5) end
check(player.added[4].scale.x==45, "HP loss shrinks graphical bar")
local pending={{inviter="Alpha",expires_in=100},{inviter="Beta",expires_in=100}}
grug_parties.pending=function() return pending end
local context={grug_party_inviter="Beta"}
local form=ppage:get(player,context)
check(form:find("100s);2;false]",1,true), "pending highlight follows actual selected inviter")
pending={{inviter="Alpha",expires_in=99}}
ppage:get(player,context)
check(context.grug_party_inviter=="Alpha", "expired selection reconciles")
-- Rendered identity survives membership/journal reordering before an event.
local member_context={grug_party_member="P2"}
ppage:get(player,member_context)
local initial=party.members[1]
table.remove(party.members,1)
ppage:on_player_receive_fields(player,member_context,{grug_party_members="CHG:1"})
check(member_context.grug_party_member==initial.name,"member click uses rendered name")
local quest_context2={}
qpage:get(player,quest_context2)
local first_quest=journal.quests[1]
table.remove(journal.quests,1)
qpage:on_player_receive_fields(player,quest_context2,{grug_quest_list="CHG:1"})
check(quest_context2.grug_quest_selected==first_quest.id,"quest click uses rendered id")
party=nil
for _, callback in ipairs(steps) do callback(0.5) end
check(player.added[2].removed and player.added[31].removed,"ungrouped removes party rows")
print(("r14_ui checks=%d quest_lines=%d party_members=%d"):format(checks, quest_lines, 10))
