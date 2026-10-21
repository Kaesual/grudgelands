-- Round 55 lane FINISH's scene for the GAME capture probe
-- (SCENE=tools/r55_art/scene.lua ART=tools/r55_art/art OFFHAND=true|false
-- tools/r55_game/capture.sh OUT_DIR; the format is in the probe's init.lua):
-- the picked offhand art as the game composes it.
--
-- With the look on: Warriors with shields T1, T3 and T6 (front, three
-- quarters, the left side, Block), Mages and Priests with books T1, T3 and
-- T6 (standing and casting), a Scout with the bow and with the sword in the
-- hand (the other weapon on the back, with and without a cloak), the capture
-- player granted Supporter through the real /achievement command and wearing
-- the Supporter Cloak with its wings (back, three quarters, walking), the
-- Character tab. With the look off: Warrior, caster and Supporter figures,
-- the Character tab, and the inventory icons of the twelve items (plain,
-- enchanted, broken, and the Character page's two offhand ghosts; icons do
-- not depend on the setting). Real cloaks: grug_achievements' own cloak source.
return function(api)
	local PI = math.pi
	local F, C = api.frames, api.cams
	local scene = {real_cloaks = true}

	local function row(looks, yaw, frame)
		local out = {}
		for i, look in ipairs(looks) do
			out[i] = {x = (i - (#looks + 1) / 2) * 1.4, yaw = yaw, frame = frame, look = look}
		end
		return out
	end
	local function caster(class, b)
		return {class = class, line = "cloth", tier = b, offhand = api.book(b),
			weapon = grug_gear.weapon_item("staff", b)}
	end
	local function warriors() return {api.warrior(1), api.warrior(3), api.warrior(6)} end
	local function mages() return {caster("mage", 1), caster("mage", 3), caster("mage", 6)} end
	local function priests() return {caster("priest", 1), caster("priest", 3), caster("priest", 6)} end
	local function supporter()
		return {class = "priest", line = "cloth", tier = 3, cloak_id = "supporter"}
	end
	local function scout(held, cloak)
		local look = api.scout(held)
		look.cloak_id = cloak and "plain_grey" or "none"
		return look
	end

	-- The real command, as a chat line through the engine's chat handlers,
	-- with the privilege it asks for.
	local function grant(player)
		local privs = core.get_player_privs(api.name)
		privs.server = true
		core.set_player_privs(api.name, privs)
		for _, fn in ipairs(core.registered_on_chat_messages) do
			if fn(api.name, "/achievement grant " .. api.name .. " supporter") then break end
		end
		local owned = grug_achievements.select_cloak(player, "supporter")
		api.log(("supporter granted: the cloak is %s"):format(owned and "owned and worn" or "NOT owned"))
	end

	-- The twelve items' icons: a column per tier; rows plain shields, plain
	-- books (item_image: the registered image), then each enchanted
	-- (Strength prefix red, Dexterity suffix mint) and broken, as
	-- grug_gear composes a stack's image; last the Character page's empty
	-- Shield and Caster-offhand ghosts.
	local function icons()
		local fs = {"formspec_version[6]size[13.6,13.4]bgcolor[#202024;true]",
			"style_type[label;font_size=*1.1]"}
		local x0, y0, step = 3.2, 1.0, 1.6
		local rows = {
			{"shield", function(b) return api.shield(b) end, "plain"},
			{"book", function(b) return api.book(b) end, "plain"},
			{"shield", function(b) return api.shield(b) end, "enchanted"},
			{"book", function(b) return api.book(b) end, "enchanted"},
			{"shield", function(b) return api.shield(b) end, "broken"},
			{"book", function(b) return api.book(b) end, "broken"},
		}
		for b = 1, 6 do
			fs[#fs + 1] = ("label[%.2f,0.5;T%d]"):format(x0 + (b - 1) * step + 0.4, b)
		end
		for r, entry in ipairs(rows) do
			local y = y0 + (r - 1) * step
			fs[#fs + 1] = ("label[0.3,%.2f;%s %s]"):format(y + 0.6, entry[1], entry[3])
			for b = 1, 6 do
				local item = entry[2](b)
				local x = x0 + (b - 1) * step
				local image = core.registered_items[item].inventory_image
				if entry[3] == "plain" then
					fs[#fs + 1] = ("item_image[%.2f,%.2f;1.4,1.4;%s]"):format(x, y, item)
				elseif entry[3] == "enchanted" then
					fs[#fs + 1] = ("image[%.2f,%.2f;1.4,1.4;%s]"):format(x, y,
						core.formspec_escape(grug_gear.enchant_image(image, "str", "dex")))
				else
					fs[#fs + 1] = ("image[%.2f,%.2f;1.4,1.4;%s]"):format(x, y,
						core.formspec_escape("(" .. image .. ")" .. grug_gear.BROKEN_MODIFIER))
				end
			end
		end
		local y = y0 + #rows * step
		fs[#fs + 1] = ("label[0.3,%.2f;slot ghosts]"):format(y + 0.6)
		local rules = grug_inventory.HAND_RULES
		fs[#fs + 1] = ("image[%.2f,%.2f;1.4,1.4;%s]"):format(x0, y,
			core.formspec_escape(rules.warrior.offhand.ghost))
		fs[#fs + 1] = ("image[%.2f,%.2f;1.4,1.4;%s]"):format(x0 + step, y,
			core.formspec_escape(rules.mage.offhand.ghost))
		api.log("icon grid shown")
		return table.concat(fs)
	end

	function scene.on()
		local bow, sword = "bow_skill", "melee_skill"
		return {
			{name = "W1_shields_T1_T3_T6_front", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI, F.stand)},
			{name = "W2_shields_T1_T3_T6_3q", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI * 0.7, F.stand)},
			{name = "W3_shields_T1_T3_T6_left", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI / 2, F.stand)},
			{name = "W4_shields_T1_T3_T6_block_front", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI, F.block)},
			{name = "W5_shields_T1_T3_T6_block_3q", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI * 0.7, F.block)},
			{name = "B1_mages_T1_T3_T6_3q", cam = C.far, pitch = 0.2,
				figures = row(mages(), PI * 0.7, F.stand)},
			{name = "B2_priests_T1_T3_T6_cast_3q", cam = C.far, pitch = 0.2,
				figures = row(priests(), PI * 0.7, F.cast)},
			{name = "B3_mages_T1_T3_T6_left", cam = C.far, pitch = 0.2,
				figures = row(mages(), PI / 2, F.stand)},
			{name = "B4_priests_T1_T3_T6_front", cam = C.far, pitch = 0.2,
				figures = row(priests(), PI, F.stand)},
			{name = "S1_scout_bow_sword_hand_front_3q", cam = C.far, pitch = 0.2,
				figures = row({scout(bow), scout(sword)}, PI * 0.8, F.stand)},
			{name = "S2_scout_bow_sword_hand_back", cam = C.far, pitch = 0.2,
				figures = row({scout(bow), scout(sword)}, PI * 0.1, F.stand)},
			{name = "S3_scout_bow_sword_hand_back_cloak", cam = C.far, pitch = 0.2,
				figures = row({scout(bow, true), scout(sword, true)}, PI * 0.1, F.stand)},
			{name = "C1_supporter_back_3q_walk", cam = C.far, pitch = 0.2, before = grant, figures = {
				{x = -1.4, yaw = 0, frame = F.stand, look = supporter()},
				{x = 0, yaw = PI * 0.25, frame = F.stand, look = supporter()},
				{x = 1.4, yaw = PI * 0.25, frame = F.walk, look = supporter()}}},
			{name = "C2_supporter_front_side", cam = C.far, pitch = 0.2, figures = {
				{x = -0.8, yaw = PI * 0.75, frame = F.stand, look = supporter()},
				{x = 0.8, yaw = PI / 2, frame = F.walk, look = supporter()}}},
			{name = "C3_supporter_close_back_walk", cam = C.near, pitch = 0.25, figures = {
				{x = 0, yaw = PI * 0.15, frame = F.walk, look = supporter()}}},
			{name = "T1_tab_warrior_shield_T6", tab = api.warrior(6)},
			{name = "T2_tab_mage_book_T3", tab = caster("mage", 3)},
			{name = "T3_tab_supporter_back", tab = supporter(), rotation = api.back_view},
		}
	end

	function scene.off()
		return {
			{name = "X1_off_shields_T1_T3_T6_3q", cam = C.far, pitch = 0.2,
				figures = row(warriors(), PI * 0.7, F.stand)},
			{name = "X2_off_casters_supporter_back", cam = C.far, pitch = 0.2, before = grant, figures = {
				{x = -1.4, yaw = PI * 0.7, frame = F.stand, look = caster("mage", 6)},
				{x = 0, yaw = PI * 0.7, frame = F.cast, look = caster("priest", 3)},
				{x = 1.4, yaw = PI * 0.25, frame = F.stand, look = supporter()}}},
			{name = "T1_off_tab_warrior_shield_T6", tab = api.warrior(6)},
			{name = "T2_off_tab_mage_book_T3", tab = caster("mage", 3)},
			{name = "T3_off_tab_supporter_back", tab = supporter(), rotation = api.back_view},
			{name = "I1_off_icons", formspec = icons},
		}
	end

	return scene
end
