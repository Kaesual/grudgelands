-- Disposable real-client capture driver. Only staged in a throwaway game/world.
-- Game forms and data are real; the platform and NPC ObjectRef stand-in make
-- the same scene repeatable without depending on spawn timing or mouse input.
local NAME, P = "grugcap", "[uifidelity] "
local state = {phase = "wait", clock = 0, index = 1}
local settle = tonumber(core.settings:get("uifidelity_settle")) or 3
local base, chest
local scenes = string.split(core.settings:get("uifidelity_scenes") or "dark,bright", ",")
local pages = {"inventory", "stats", "effects", "achievements", "talents", "crafting", "craft_details", "craft_group", "craft_queue", "craft_enchant", "craft_upgrade", "party", "map", "map_zones",
 "help_start", "help_quests", "help_basics", "help_mail", "help_formulas", "help_about", "help_sound",
 "admin_mail", "admin_compose", "creative_all", "creative_nodes", "creative_tools", "creative_craftitems", "creative_food",
 "chest", "locked_chest", "furnace", "personal_furnace", "dual_furnace", "personal_dual_furnace", "bookshelf", "vessels", "claim", "claim_travel", "claim_belongings",
 "quest", "vendor", "vendor_gear", "vendor_sell", "vendor_guild", "vendor_exchange", "repair", "crown", "profession", "alchemy", "riding", "shipwright", "innkeeper", "waystone", "lift", "housing",
 "mail_letters", "mail_delete", "mail_write", "mail_announcements", "mail_admin", "creation", "preparing", "welcome", "quickbar", "withdraw", "sign", "book", "mob_spawner", "mob_texture"}
local only = core.settings:get("uifidelity_only") or ""
if only ~= "" then pages = string.split(only, ",") end
local ids = {inventory = "grug_inventory:inventory", stats = "grug_inventory:character", effects = "grug_inventory:character", achievements = "grug_inventory:character",
 talents = "grug_classes:talents", crafting = "sfinv:crafting", party = "grug_parties:group", admin_mail = "grug_mail:admin"}
local last_form, last_fs, shot_name
local original_show = core.show_formspec
function core.show_formspec(name, form, fs)
 if name == NAME and fs ~= "" then last_form, last_fs = form, fs end
 return original_show(name, form, fs)
end
local function log(s) core.log("action", P .. s) end
local function submit(player, form, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, form, fields) then return end
	end
end
local protected = grug_core.interaction_protected
function grug_core.interaction_protected(pos, name)
	if chest and vector.equals(vector.round(pos), chest) then return false end
	return protected(pos, name)
end
local function scene(player, bright)
	for x = -18, 18 do for z = -18, 18 do
		core.set_node(vector.offset(base, x, -1, z), {name = bright and "default:snowblock" or "default:stone"})
	end end
	core.set_timeofday(bright and 0.5 or 0)
	player:override_day_night_ratio(bright and 1 or 0.18)
	player:set_sky({type = "plain", base_color = bright and "#d5e4ef" or "#101824", clouds = false})
	player:set_pos(base)
	player:set_look_horizontal(0)
	player:set_look_vertical(0.28)
end
local function quest(player, ready)
	local sockets = {}
	for socket in pairs(grug_quests.npc_by_socket) do sockets[#sockets + 1] = socket end
	table.sort(sockets)
	for _, socket in ipairs(sockets) do
		local id = grug_quests.npc_by_socket[socket]
		local npc = grug_quests.registered_npcs[id]
		if socket:match("^dawnmere/") and grug_factions.serves(npc.faction, player) and
				#grug_quests.npc_quests(player, id) > 0 then
			local start, key = socket:match("^(.-)/(.*)$")
			local entity = {_grug_start = start, _grug_socket = key,
				object = {is_valid = function() return true end, get_pos = function() return base end}}
			if ready then
                local rows=grug_quests.npc_quests(player,id)
                for _,row in ipairs(rows) do
                    local def=grug_quests.registered_quests[row.id]
                    if row.status=="available" and #def.rewards.choices>0 then
                        assert(grug_quests.accept(player,row.id,id))
                        local active=grug_quests.active_entry(player,row.id)
                        for _,objective in ipairs(grug_quests.variant_of(def,active).objectives) do
                            assert(objective.type=="kill", "capture choice quest must use kills")
                            local names={};for name in pairs(objective.name_set) do names[#names+1]=name end;table.sort(names)
                            for _=1,objective.count do grug_quests.credit_kill(player,{description=names[1]},base) end
                        end
                        assert(grug_quests.status(player,row.id)=="ready")
                        assert(grug_quests.open_npc(player,entity,row.id,nil,1))
                        return
                    end
                end
                error("capture choice quest unavailable")
            end
            assert(grug_quests.open_npc(player, entity))
			log("quest giver " .. id)
			return
		end
	end
	error("No real human-start quest giver available")
end
local function node_window(player, node_name)
 local pos = vector.offset(base, 2, 0, 1)
 core.set_node(pos, {name = node_name})
 local def = assert(core.registered_nodes[node_name], node_name)
 if def.on_construct then def.on_construct(pos) end
 local inv = core.get_meta(pos):get_inventory()
 if inv:get_size("main") > 0 then inv:add_item("main", "default:wood 32") end
 if inv:get_size("src") > 0 then inv:add_item("src", "default:iron_lump 12") end
 if inv:get_size("fuel") > 0 then inv:add_item("fuel", "default:coal_lump 8") end
 core.get_meta(pos):set_string("owner", NAME)
 if def.on_rightclick then def.on_rightclick(pos, core.get_node(pos), player, ItemStack(""), {type="node",under=pos,above=vector.offset(pos,0,1,0)})
 else error("no rightclick: " .. node_name) end
end
local function form(fs) core.show_formspec(NAME, "grug_probe_ui_dialogs:preview", fs) end
local function inventory_page(player, id, change)
 sfinv.set_page(player, id)
 local ctx = sfinv.get_or_create_context(player)
 if change then change(ctx) end
 form(sfinv.get_formspec(player, ctx))
end
local function show(player, kind)
 if last_form then submit(player, last_form, {quit = "true"}) end
 submit(player, "grug_map:window", {quit = "true"})
 core.close_formspec(NAME, "")
 last_form, last_fs = nil, nil
 player:set_pos(base)
 core.set_player_privs(NAME, {interact=true,shout=true,protection_bypass=true,server=true,
  creative=kind:match("^creative_") and true or nil,mail_admin=kind:match("^admin_") and true or nil})
 local C = grug_core.capture
 if kind == "admin_compose" then
  inventory_page(player,"grug_mail:admin")
  local ctx=sfinv.get_or_create_context(player)
  sfinv.pages["grug_mail:admin"]:on_player_receive_fields(player,ctx,{mail_admin_new="true"})
  form(sfinv.get_formspec(player,ctx))
 elseif ids[kind] then
  inventory_page(player, ids[kind], function(ctx)
   if kind == "stats" or kind == "effects" or kind == "achievements" then ctx.grug_character_tab = kind end
  end)
 elseif kind:match("^help_") then
  inventory_page(player, "grug_inventory:help", function(ctx) ctx.grug_help_section = kind:sub(6) end)
 elseif kind:match("^creative_") then inventory_page(player, "creative:" .. kind:sub(10))
 elseif kind:match("^craft_") then
  if kind=="craft_busy" then
   player:get_inventory():add_item("main","default:wood 99")
   local recipe=assert(grug_jobs.recipes_for_output("default:stick")[1])
   assert(grug_jobs.start_job(player,recipe.id,30))
   assert(grug_jobs.start_job(player,recipe.id,5))
  end
  inventory_page(player, "sfinv:crafting", function(ctx)
   local recipe
   for _, row in ipairs(grug_jobs.recipes_for_output("grug_cooking:raw_stew_pot")) do recipe = row end
   if not recipe then
    for _, row in ipairs(grug_jobs.recipes_for_output("default:stick")) do recipe = row end
   end
   assert(recipe, "capture recipe")
   local st = {slot=recipe.area == "cooking" and 2 or 1,page=1,search="",typed="",only=false,qty="1",rows={},selected=recipe.id}
   ctx.grug_craft = st
   if kind == "craft_details" or kind == "craft_group" then
    grug_jobs.open_recipe_details(st, {kind="recipe",id=recipe.id})
    if kind == "craft_group" then table.insert(st.details.pages,{kind="group",group="wood",n=1,page=1}) end
   else st.slot=3; st.box = ({craft_queue="queue",craft_busy="queue",craft_enchant="enchant",craft_upgrade="upgrade"})[kind] end
  end)
 elseif kind == "chest" then node_window(player,"default:chest")
 elseif kind == "locked_chest" then node_window(player,"default:chest_locked")
 elseif kind == "furnace" then node_window(player,"default:furnace")
 elseif kind == "personal_furnace" or kind == "personal_dual_furnace" then
  local station = kind == "personal_furnace" and "furnace" or "dual_furnace"
  local pos=vector.offset(base,3,0,1)
  local node=station == "furnace" and "default:furnace" or "grug_smelting:dual_furnace"
  core.set_node(pos,{name=node});local def=core.registered_nodes[node];if def.on_construct then def.on_construct(pos) end
  grug_jobs.register_public_position(station,pos)
  assert(grug_jobs.workspaces.open(pos,player))
 elseif kind == "dual_furnace" then node_window(player,"grug_smelting:dual_furnace")
 elseif kind == "bookshelf" then node_window(player,"default:bookshelf")
 elseif kind == "vessels" then node_window(player,"vessels:shelf")
 elseif kind == "sign" then node_window(player,"default:sign_wall_wood")
 elseif kind == "mob_spawner" then node_window(player,"mobs:spawner")
 elseif kind == "quest" or kind == "quest_ready" then quest(player,kind=="quest_ready")
 elseif kind == "map" or kind == "map_zones" then
  grug_map.window.open(player)
  if kind == "map_zones" then submit(player, grug_map.window.FORMNAME,{grug_map_layer_zones="true"}) end
 elseif kind:match("^vendor") then
  local vendor = "grug_traders:vendor_race_human"
  if not grug_traders.get_vendor(vendor) then
   for _, key in ipairs({"human_quartermaster","quartermaster","human"}) do
    if grug_traders.get_vendor(key) then vendor=key;break end
   end
  end
  if kind == "vendor_guild" or kind == "vendor_exchange" then vendor="grug_traders:vendor_camp" end
  assert(grug_traders.get_vendor(vendor), "missing vendor " .. vendor)
  grug_traders.open(player,vendor,base,"accord")
  if kind == "vendor_gear" then submit(player,last_form,{tab_1="true"}) end
  if kind == "vendor_sell" then submit(player,last_form,{mode_sell="true"}) end
  if kind == "vendor_guild" then grug_guild.add(player,2500,"capture"); submit(player,last_form,{mode_buy="true"}) end
 elseif kind == "repair" then
  local quote={items={},total=0,provider={kind="camp_vendor"}}
  for i,stack in ipairs(player:get_inventory():get_list("main")) do
   if grug_repair.eligible(stack) and stack:get_wear()>0 then
    local price=assert(grug_repair.cost(stack));quote.items[#quote.items+1]={expected=stack,price=price,list="main",index=i};quote.total=quote.total+price
   end
  end
  form(C.repair({quote=quote,page=1}))
 elseif kind == "crown_empty" then
  for list,items in pairs(player:get_inventory():get_lists()) do
   for index in ipairs(items) do player:get_inventory():set_stack(list,index,"") end
  end
  grug_traders.open_crownbinder(player,"Crownbinder",base,"accord")
 elseif kind == "crown" then grug_traders.open_crownbinder(player,"Crownbinder",base,"accord")
 elseif kind == "profession" or kind == "alchemy" then grug_jobs.open_trainer(player,kind == "alchemy" and "alchemist" or "weaponsmith",base)
 elseif kind == "riding" or kind == "shipwright" then
  local service=grug_mounts.SERVICES[kind == "riding" and "riding_trainer" or "shipwright"]
  local rows={}
  for i,id in ipairs(service.tiers) do
   local tier=grug_mounts.TIERS[id];local mode,price=grug_mounts.tier_state(player,id)
   local previous=grug_mounts.TIERS[service.tiers[i-1] or 0]
   rows[#rows+1]={id=id,name=tier.name,level=tier.level,state=mode,price=price and grug_money.format(price),previous=previous and previous.name}
  end
  form(grug_mounts.trainer_formspec(rows,nil,service))
 elseif kind == "innkeeper" then form(C.innkeeper(player,assert(grug_home.location("dawnmere"))))
 elseif kind == "waystone" then form(C.waystone(player))
 elseif kind == "lift" then
  local camp, rooms
  for _, row in ipairs(grug_mapgen.mining_camps.camps) do
   if row.faction == "accord" then camp=row;break end
  end
  assert(camp,"capture camp")
  rooms={{level=0,label="Surface"}}
  for _,room in ipairs(grug_mapgen.guild_rooms.rooms_for_camp(camp.id)) do rooms[#rooms+1]={level=room.tier,label=("Level %d (%d)"):format(room.tier,room.floor_y),room=room} end
  form(C.lift({camp=camp,level=0,levels=rooms}))
 elseif kind == "housing" then form(C.housing({},player))
 elseif kind:match("^claim") then
  grug_housing.storage:set_string("recovered:" .. NAME .. ":999:1", "default:coal_lump 20")
  grug_housing.recovered.clean_pass(999)
  C.stone_inventory(NAME)
  local claim={id="capture",owner=NAME,center=base,activated_at=os.time()-86400,placed_at=os.time()-86400,paid_until=os.time()+86400*20,permissions={Adventurer="interact"}}
  local session={tab=kind=="claim" and "main" or kind=="claim_travel" and "waypoints" or "belongings"}
  form(C.stone(player,claim,session))
 elseif kind:match("^mail_") then
  node_window(player,grug_mail.MAILBOX_NODE)
  local session=assert(grug_mail.session(NAME))
  session.tab=kind == "mail_delete" and "letters" or kind:sub(6)
  local letters=grug_mail.store.box(NAME).letters
  if #letters>0 then session.selected.letters=letters[1].id end
  if kind == "mail_delete" then session.dialog="delete" end
  form(grug_mail.window_formspec(player,session))
 elseif kind == "creation" then form(C.creation({faction="accord",race="human",class="warrior",look=grug_visuals.get_look(player)}))
 elseif kind == "preparing" then form(C.preparing({mode="full",percent=63,eta_seconds=480,ready=false}))
 elseif kind == "welcome" then form(grug_inventory.welcome_formspec(player))
 elseif kind == "quickbar" then
  grug_mounts.purchase(player,1); grug_mounts.purchase(player,5)
  grug_quickbar.open(player)
 elseif kind == "withdraw" then grug_money.show_withdraw(player)
 elseif kind == "book" then
  local book=ItemStack("default:book_written");book:get_meta():from_table({fields={owner=NAME,title="Field notes",text="A journey begins in Dawnmere.\nFollow the road and speak to the people you meet.",page="1",page_max="1",text_len="2"}})
  player:set_wielded_item(book)
  core.registered_items[book:get_name()].on_use(book,player)
 elseif kind == "mob_texture" then
  local user=setmetatable({get_player_control=function() return {sneak=true} end},{__index=function(_,key) return function(_,...) return player[key](player,...) end end})
  local obj={get_luaentity=function() return {base_texture={"grug_player_human.png"}} end}
  core.registered_items["mobs:mob_reset_stick"].on_use(ItemStack("mobs:mob_reset_stick"),user,{type="object",ref=obj})
 else error("unknown capture " .. kind) end
end
core.register_globalstep(function(dt)
	state.clock = state.clock + dt
	if state.clock < 0.5 then return end
	local elapsed = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		state.phase = "emerge"
		base = vector.offset(vector.round(player:get_pos()), 0, 20, 0)
		core.emerge_area(vector.offset(base, -20, -2, -20), vector.offset(base, 20, 5, 20), function(_, _, left)
			if left ~= 0 then return end
			player = core.get_player_by_name(NAME)
			if not player then return end
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			player:hud_set_flags({hotbar = false, crosshair = false, wielditem = false, minimap = false})
			grug_xp.set_xp(player, grug_xp.xp_for_level(30))
			grug_jobs.admin_set(player, "weaponsmith", 3, 1)
			local inv = player:get_inventory()
			for _, item in ipairs({"default:wood 32", "default:cobble 48", "default:coal_lump 24",
				"default:stick 12", "default:apple 8", "default:paper 5", "default:book 2"}) do
				inv:add_item("main", item)
			end
			chest = vector.offset(base, 2, 0, 1)
			core.set_node(chest, {name = "default:chest"})
			core.get_meta(chest):get_inventory():add_item("main", "default:wood 48")
			grug_money.add(player, 50000)
            for _, item in ipairs({"grug_gear:sword_steel","grug_gear:chest_steel","grug_gear:head_steel"}) do
                if core.registered_items[item] then
                    local stack=grug_items.make_stack(item,25,nil,player);stack:set_wear(30000);inv:add_item("main",stack)
                end
            end
            grug_mail.send_system(NAME,"npc","Mariel Waybook","The road ahead","Your journey leads beyond Dawnmere. Keep these supplies close, and visit the Quartermaster before you leave.",{"default:torch 12"})
            local file=assert(io.open(core.get_worldpath() .. "/ui_capture_manifest.json","w"));file:write(core.write_json({pages=pages,scenes=scenes}));file:close()
            state.phase = "shots"
			log("READY")
		end)
	elseif state.phase == "shots" then
		local index = state.index
		local scene_id = math.floor((index - 1) / #pages) + 1
		if not scenes[scene_id] then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("fidelity capture complete", false, 0)
			return
		end
		local page = pages[(index - 1) % #pages + 1]
		local shot = scenes[scene_id] .. "_" .. page
		if not state.ran then
			if (index - 1) % #pages == 0 then scene(player, scenes[scene_id] == "bright") end
			shot_name = shot
            local ok, reason = pcall(show, player, page)
            if not ok then
                log("FAILED " .. shot .. " " .. tostring(reason))
                state.index = index + 1
                state.ran, state.logged = false, false
                return
            end
			state.ran, state.waited = true, 0
		end
		state.waited = state.waited + elapsed
		if not state.logged and state.waited >= settle then
			assert(last_fs and #last_fs > 0, "no form rendered for " .. shot)
            local file=assert(io.open(core.get_worldpath() .. "/ui_capture_" .. shot .. ".txt","w"))
            file:write(last_form .. "\n" .. last_fs);file:close()
            state.logged = true
            log("SHOT " .. shot)
		elseif state.logged then
			local file = io.open(core.get_worldpath() .. "/uifidelity_ack", "r")
			local ack = file and file:read("*l")
			if file then file:close() end
			if ack == shot then
				state.index = index + 1
				state.ran, state.logged = false, false
			end
		end
	end
end)
