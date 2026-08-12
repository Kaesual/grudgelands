-- Wrapper normalization for vendored default/stairs registrations (WP43).
-- core.override_item replaces whole fields, so every group edit starts from a
-- copy of the live definition and preserves unrelated upstream groups.

local function edit_groups(item_name, edit)
	local def = core.registered_items[item_name]
	if not def then
		error("grug_materials: cannot normalize missing item " .. item_name)
	end
	local groups = table.copy(def.groups or {})
	edit(groups)
	core.override_item(item_name, {groups = groups})
end

local function natural_resource(item_name, tier)
	edit_groups(item_name, function(groups)
		groups.level = nil
		groups.grug_natural = 1
		groups.grug_resource = tier
	end)
end

natural_resource("default:stone_with_coal", 1)
natural_resource("default:stone_with_copper", 1)
natural_resource("default:stone_with_tin", 1)
natural_resource("default:stone_with_iron", 1)
natural_resource("default:stone_with_gold", 2)

edit_groups("default:stone", function(groups)
	groups.level = nil
	groups.grug_natural = 1
	groups.grug_stratum = 1
end)

local normalized_blocks = {
	"default:obsidian", "default:obsidianbrick", "default:obsidian_block",
	"default:steelblock", "default:copperblock", "default:tinblock",
	"default:bronzeblock",
}
for _, item_name in ipairs(normalized_blocks) do
	edit_groups(item_name, function(groups)
		groups.level = nil
	end)
end

-- Preserve WP25's effective ordinary-rock values while retiring maxlevel as
-- an authority. Package B supplies the full six-pick capability builder.
core.override_item("default:pick_wood", {
	tool_capabilities = {
		full_punch_interval = 1.2,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[3] = 1.60}, uses = 30, maxlevel = 0},
		},
		damage_groups = {fleshy = 2},
	},
})

core.override_item("default:pick_stone", {
	tool_capabilities = {
		full_punch_interval = 1.3,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[2] = 2.0, [3] = 1.00}, uses = 60, maxlevel = 0},
		},
		damage_groups = {fleshy = 3},
	},
})

core.override_item("default:pick_bronze", {
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 1,
		groupcaps = {
			cracky = {times = {[1] = 2.25, [2] = 0.90, [3] = 0.45},
				uses = 180, maxlevel = 0},
		},
		damage_groups = {fleshy = 4},
	},
})

-- stairs is optional for a standalone grug_materials load, but ordered before
-- us when present through mod.conf. Normalize all four generated shapes.
if core.get_modpath("stairs") then
	local bases = {"obsidian", "obsidianbrick", "obsidian_block", "steelblock",
		"tinblock", "copperblock", "bronzeblock"}
	local shapes = {"stair_", "stair_inner_", "stair_outer_", "slab_"}
	for _, base in ipairs(bases) do
		for _, shape in ipairs(shapes) do
			edit_groups("stairs:" .. shape .. base, function(groups)
				groups.level = nil
			end)
		end
	end
end
