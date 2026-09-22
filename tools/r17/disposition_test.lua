local repo = assert(arg[1], "repository path required")

grug_mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/disposition.lua")

local checks = 0
local function check(value, message)
	checks = checks + 1
	if not value then error(message, 0) end
end

local boar = {attack_players = true, runaway = true, attack_type = "dogfight"}
check(grug_mobs.apply_disposition("grug_mobs:boar", boar) == "neutral",
	"boar is not neutral")
check(boar._grug_disposition == "neutral" and boar.passive == false
	and boar.attack_players == false and boar.attack_npcs == false
	and boar.runaway == false and boar.group_attack == false,
	"neutral retaliation fields differ")

local rat = {_grug_tier = "normal", attack_players = true}
check(grug_mobs.apply_disposition("grug_mobs:giant_rat", rat) == "aggressive"
	and rat._grug_disposition == "aggressive" and rat.attack_players == true
	and rat.passive == false and rat.runaway == false,
	"rat aggression differs")

local rabbit = {_grug_tier = "critter", attack_players = true}
check(grug_mobs.apply_disposition("grug_mobs:rabbit", rabbit) == "critter"
	and rabbit._grug_disposition == "critter" and rabbit.passive == true
	and rabbit.attack_players == false, "critter behavior differs")

check(grug_mobs.disposition("grug_mobs:king_human") == "aggressive",
	"king family disposition differs")
check(grug_mobs.disposition(boar) == "neutral",
	"live entity disposition lookup differs")
check(grug_mobs.disposition("grug_mobs:guard_accord") == nil,
	"guard must remain an independent role")

local ok = pcall(grug_mobs.apply_disposition, "grug_mobs:unknown", {})
check(not ok, "unclassified wrapped mob was accepted")

io.write("round17-disposition\t", checks, "\n")
