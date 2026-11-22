-- The account Claim Stone, engine side (Round 86 lane STONE;
-- docs/planning/housing-rework-concept.md §3.1 rulings 1-10,
-- docs/planning/round86-plan.md rulings 10, 13, 14, 16 and §2.3). The model
-- (registry.lua) keeps the memberships in the characters' own records; this
-- file connects them to grug_accounts (an optional dependency; without it
-- nobody can choose the account stone) and to the Housing Steward:
--
--   * the owner text of a character's binding: `account:<id>:<faction>`;
--   * the Steward's choice (account_offer, choose_account, leave_account):
--     joining a standing claim gives no item, before it stands a member
--     gets an Account Claim Stone; a carried personal stone vanishes at the
--     choice; joining moves the character's belongings to the account's
--     (lane PACK's recovered.move_to_account);
--   * the reconcile: a membership whose binding no longer counts (an
--     unlink, the account gone from the list, a binding for another
--     character id) or whose faction changed ends, at load, on every list
--     change, at a join and before every action of the member; housing
--     hears no event naming the old account, so the record holds it;
--   * the end of a membership: the member's own draft goes, carried account
--     stones vanish (an offline character's at its next join); an account
--     claim with no member left ends as /claim_remove does (ruling 8) when
--     the game was told directly (deletion, a faction change), and stands
--     ownerless when the list took its last member (ruling 18, below); its
--     belongings stay the account's either way (ruling 13);
--   * ruling 16: an activation removes the account's other drafts at once,
--     their blocks loaded for it, and tells their placers.

local model = grug_housing.model
local ACCOUNT = model.ACCOUNT
local ACCOUNT_ITEM = grug_housing.ACCOUNT_ITEM

local function accounts()
	local mod = rawget(_G, "grug_accounts")
	return type(mod) == "table" and type(mod.account_of) == "function" and mod or nil
end

local function player_level(player)
	local xp = rawget(_G, "grug_xp")
	return xp and xp.get_level(player) or 0
end

local function faction_of(player)
	local factions = rawget(_G, "grug_factions")
	return factions and factions.get_faction(player) or nil
end

local function tell(name, text)
	local player = core.get_player_by_name(name)
	if not player then return end
	if grug_core.flash then grug_core.flash(player, text) end
	core.chat_send_player(name, text)
end

grug_housing.NO_ACCOUNT_LINE = "Link this character to your account on " ..
	"grudgelands.com/play first (the Account tab)."

-- The owner text the character's binding gives in `faction`, or nil (no
-- grug_accounts, no counting binding, no faction).
function grug_housing.binding_owner(name, faction)
	local mod = accounts()
	local account = mod and mod.account_of(name)
	if not account or (faction ~= "accord" and faction ~= "throng") then return nil end
	return model.owner_text(account.id, faction)
end

-- Removes every stone of `item` from the player's lists; returns how many.
local function take_stones(player, item)
	local inv = player:get_inventory()
	local taken = 0
	for listname, list in pairs(inv and inv:get_lists() or {}) do
		for index, stack in ipairs(list) do
			if stack:get_name() == item then
				taken = taken + stack:get_count()
				inv:set_stack(listname, index, ItemStack(""))
			end
		end
	end
	return taken
end

local function holds(player, item)
	local inv = player:get_inventory()
	for listname in pairs(inv and inv:get_lists() or {}) do
		if inv:contains_item(listname, item) then return true end
	end
	return false
end

-- Removes a claim's stone and record with the event, as an admin removal
-- does (nothing refunded).
local function end_claim(claim, event, why)
	grug_housing.remove_stone_node(claim)
	model.remove(claim, event == "deleted" and "deleted" or "removed")
	grug_housing.notify_claim_changed(claim, event)
	core.log("action", ("[grug_housing] Claim Stone %d of %s ended: %s"):format(
		claim.id, claim.owner, why))
end

-- The end of `name`'s membership (`reason`: "left", "unlinked", "faction",
-- "deleted"); false when it was no member.
-- Ruling 18 (the user, 2026-11-22): an account claim whose last member
-- went through a list change (reason "unlinked": the change callback or a
-- reconcile reading the list) is not removed at once: the list may be
-- faulty. It stands ownerless (an account claim with no member record:
-- derived from the records, nothing stored), fuelled or empty, as any
-- claim whose owner stopped fuelling it (the coordinator's decision of
-- 2026-11-22): it protects while its fuel lasts, nobody can refuel it (only
-- owners open its form), and then it is the empty stone, which any pick
-- digs, ending it. A character of that account and faction that joins owns
-- it again. The paths the game is told directly end it at once (deletion,
-- pick-up, /claim_remove, an admin's faction change).
local function ownerless(claim)
	return claim ~= nil and claim.kind == ACCOUNT and model.parse_owner_text(claim.owner) ~= nil and
		model.claim_by_id(claim.id) == claim and #model.members(claim.owner) == 0
end
grug_housing.is_ownerless = ownerless

-- Returns whether `name` was a member, and whether its account's claim now
-- stands ownerless (ruling 18).
local function end_membership(name, reason)
	local owner, draft, orphan = model.end_membership(name)
	if not owner then return false end
	local standing = orphan or model.account_claim(owner)
	if draft then
		grug_housing.remove_stone_node(draft)
		model.remove(draft, "draft_expired")
		grug_housing.notify_claim_changed(draft, "draft_expired")
	end
	local player = core.get_player_by_name(name)
	if player then take_stones(player, ACCOUNT_ITEM) end
	-- A home on the account claim is no longer this character's (grug_home).
	local home = rawget(_G, "grug_home")
	if standing and reason ~= "deleted" and home and type(home.claim_lost) == "function" then
		home.claim_lost(name, standing, (reason == "unlinked" or reason == "faction") and reason or "left")
	end
	core.log("action", ("[grug_housing] %s is no longer in the account home %s (%s)"):format(
		name, owner, reason))
	if orphan and reason == "unlinked" then
		core.log("action", ("[grug_housing] Claim Stone %d of %s stands ownerless (ruling 18)"):format(
			orphan.id, orphan.owner))
		return true, true
	elseif orphan then
		end_claim(orphan, reason == "deleted" and "deleted" or "removed", "no member left")
	end
	return true, false
end
grug_housing.end_account_membership = end_membership

-- The reconcile of one character: its membership ends when its binding no
-- longer counts for that account, or (when known: an online character) its
-- faction differs. Returns whether it is still a member.
function grug_housing.reconcile_member(name, faction)
	local owner = model.account_owner_of(name)
	if not owner then return false end
	local mod = accounts()
	if not mod then return true end -- no account mod: nothing to check against
	local id, owner_faction = model.parse_owner_text(owner)
	-- No list held at all (a new realm, or a stored list that did not
	-- decode at boot): nothing to check the binding against.
	local held = type(mod.held_version) == "function" and mod.held_version() or 0
	local account = mod.account_of(name)
	if held > 0 and (not account or account.id ~= id) then
		local _, stays = end_membership(name, "unlinked")
		tell(name, "Your character is no longer linked to the account of its home: " ..
			"you left your account's home." .. (stays and " It stands on; a character of " ..
			"that account and faction can join it again at a Housing Steward." or ""))
		return false
	end
	if faction and faction ~= owner_faction then
		end_membership(name, "faction")
		tell(name, "Your faction changed: you left your account's home.")
		return false
	end
	return true
end

local function reconcile_player(player)
	return grug_housing.reconcile_member(player:get_player_name(), faction_of(player))
end
grug_housing.reconcile_player = reconcile_player

-- The Steward's account column (rulings 1-5): {owner, member, stands,
-- members, text, button, action, reason, confirm}. `text` says where the
-- character stands; either `button` (with `action` "join" or "stone") or
-- `reason` in its place; `confirm` when the action takes a carried
-- personal stone.
function grug_housing.account_offer(player)
	local name = player:get_player_name()
	if accounts() then reconcile_player(player) end
	local own = model.account_owner_of(name)
	local owner = own or grug_housing.binding_owner(name, faction_of(player))
	local offer = {owner = owner, member = own ~= nil}
	if not owner then
		offer.text = "One home for all your account's characters in this faction."
		offer.reason = grug_housing.NO_ACCOUNT_LINE
		return offer
	end
	local claim = model.account_claim(owner)
	offer.stands = claim ~= nil
	offer.members = #model.members(owner)
	local level = player_level(player)
	if own then
		if claim then
			offer.text = ("You share your account's home with %d other character(s)."):format(
				offer.members - 1)
			offer.reason = "Its stone stands: you need none."
			return offer
		end
		offer.text = "You chose it; your account's home stands nowhere yet."
		local ok, why = model.can_issue_account(name, level, grug_housing.holds_stone(player))
		if ok then
			offer.button, offer.action = "Receive Account Claim Stone", "stone"
		else
			offer.reason = why
		end
		return offer
	end
	if claim then
		offer.text = offer.members > 0 and
			("Your account's home stands: %d of its characters share it."):format(offer.members) or
			"Your account's home stands without an owner: join it to own it again."
	else
		offer.text = "One home for all your account's characters in this faction."
	end
	local ok, why = model.can_join(name, level, owner)
	if not ok then
		offer.reason = why
		return offer
	end
	offer.button = claim and "Join your account's home" or "Choose the Account Claim Stone"
	offer.action = claim and "join" or "stone"
	if holds(player, grug_housing.STONE_ITEM) then
		offer.confirm = "The Claim Stone you carry vanishes."
	end
	return offer
end

-- The Steward's account button: joins (ruling 3; a carried personal stone
-- vanishes; the belongings move to the account's, ruling 7) and hands out
-- an Account Claim Stone while the account's claim does not stand (ruling
-- 5). Returns ok, message.
function grug_housing.choose_account(player)
	if not player or not player:is_player() then return false, "No player." end
	local name = player:get_player_name()
	if not accounts() then return false, grug_housing.NO_ACCOUNT_LINE end
	reconcile_player(player)
	local level = player_level(player)
	local owner = model.account_owner_of(name)
	local joined = false
	if not owner then
		owner = grug_housing.binding_owner(name, faction_of(player))
		if not owner then return false, grug_housing.NO_ACCOUNT_LINE end
		local ok, why = model.can_join(name, level, owner)
		if not ok then return false, why end
		local standing = model.account_claim(owner)
		local personal = holds(player, grug_housing.STONE_ITEM)
		-- The account stone takes the personal stone's slot, else needs room.
		if not standing and not personal and not holds(player, ACCOUNT_ITEM) and
				not grug_inventory.fits(player, {ItemStack(ACCOUNT_ITEM)}) then
			return false, "Make room in your inventory for the Account Claim Stone."
		end
		if personal then take_stones(player, grug_housing.STONE_ITEM) end
		model.join(name, owner)
		joined = true
		local recovered = grug_housing.recovered
		if recovered and type(recovered.move_to_account) == "function" then
			recovered.move_to_account(name, owner)
		end
		core.log("action", ("[grug_housing] %s joined the account home %s"):format(name, owner))
		if standing then
			return true, "You joined your account's home: it is yours as well now. To " ..
				"travel and respawn there, choose \"Set as home\" on its stone."
		end
	end
	local ok, why = model.can_issue_account(name, level, grug_housing.holds_stone(player))
	if not ok then
		if joined then return true, "You chose the Account Claim Stone." end
		return false, why
	end
	local stone = ItemStack(ACCOUNT_ITEM)
	if not grug_inventory.fits(player, {stone}) then
		return false, "Make room in your inventory for the Account Claim Stone."
	end
	grug_inventory.give(player, stone)
	return true, "Here is your Account Claim Stone. Only one of your account's stones " ..
		"can be activated."
end

-- Whether `name` may leave (ruling 6): ok, or false and the reason.
function grug_housing.can_leave_account(name)
	return model.can_leave(name)
end

-- The Steward's leave button (ruling 6). Returns ok, message.
function grug_housing.leave_account(player)
	if not player or not player:is_player() then return false, "No player." end
	local name = player:get_player_name()
	if accounts() and not reconcile_player(player) then
		return false, "You are in no account's home."
	end
	local ok, why = model.can_leave(name)
	if not ok then return false, why end
	end_membership(name, "left")
	return true, "You left your account's home. A personal Claim Stone is yours to choose."
end

-- Ruling 16: the account's other drafts go when one is activated.
function grug_housing.account_activated(claim)
	for _, draft in ipairs(model.member_drafts(claim.owner, claim)) do
		local placer = draft.owner
		grug_housing.remove_stone_node(draft)
		model.remove(draft, "draft_expired")
		grug_housing.notify_claim_changed(draft, "draft_expired")
		tell(placer, "Another character of your account activated its Claim Stone: " ..
			"your draft is gone. Your account's home stands, and you share it.")
		core.log("action", ("[grug_housing] draft Claim Stone %d of %s removed: %s activated %d"):format(
			draft.id, placer, claim.owner, claim.id))
	end
end

-- Every member against its binding (the reconcile at load).
function grug_housing.reconcile_all()
	for _, row in ipairs(model.all_members()) do
		grug_housing.reconcile_member(row.name, nil)
	end
end

-- The hooks ---------------------------------------------------------------

-- A join: the membership checked against the binding and faction; account
-- stones of a character that is no member vanish.
-- Ruling 18: a character of an account and faction whose claim stands
-- ownerless hears of it once per login (derived: no member record, the
-- binding names that claim), when it could join it.
local function feed_later(name, text, key)
	core.after(0, function()
		local online = core.get_player_by_name(name)
		if online then grug_core.feed(online, "notice", text, key) end
	end)
end

core.register_on_joinplayer(function(player)
	if not accounts() then return end
	local name = player:get_player_name()
	reconcile_player(player)
	if model.account_owner_of(name) then return end
	if take_stones(player, ACCOUNT_ITEM) > 0 then
		feed_later(name, "Your Account Claim Stone crumbled: you are " ..
			"in no account's home.", "grug_housing_account_stone")
	end
	local owner = grug_housing.binding_owner(name, faction_of(player))
	-- Only a character the Steward would let join (level, no placed stone).
	if owner and ownerless(model.account_claim(owner)) and
			model.can_join(name, player_level(player), owner) then
		feed_later(name, "Your account's home stands without an owner. A Housing Steward " ..
			"lets you join it.", "grug_housing_ownerless")
	end
end)

core.register_on_mods_loaded(function()
	local mod = accounts()
	if mod and type(mod.register_on_change) == "function" then
		-- The list changed: every changed name is checked (its faction when
		-- online).
		mod.register_on_change(function(names)
			for _, name in ipairs(names) do
				if model.account_owner_of(name) then
					local player = core.get_player_by_name(name)
					grug_housing.reconcile_member(name, player and faction_of(player) or nil)
				end
			end
		end)
	end
	-- An admin's faction change counts as leaving (plan §2.3).
	local factions = rawget(_G, "grug_factions")
	if factions and type(factions.register_on_faction_chosen) == "function" then
		factions.register_on_faction_chosen(function(player, faction)
			grug_housing.reconcile_member(player:get_player_name(), faction)
		end)
	end
	-- The reconcile at load (a crash between the list's store and its
	-- callbacks, a binding that stopped counting meanwhile), on the first
	-- server step, when stone nodes can be loaded.
	if mod then core.after(0, grug_housing.reconcile_all) end
end)
