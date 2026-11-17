-- The retired mount items (Round 44, ui-crafting-rework-plan.md ruling 9):
-- mounts and boats live in the quickbar (E, grug_quickbar), which works from
-- the purchase record (state.lua). The 0.44.0 migration step removed the
-- items from every player inventory; a crafting station's grid in node meta
-- may still hold one. Round 81 (ruling 10): each name is an alias of "", so
-- such a stack is cleared when it loads (the engine resolves aliases while
-- deserializing and empties a stack whose name becomes "",
-- src/inventory.cpp ItemStack::deSerialize) instead of showing as an unknown
-- item. Nothing is lost: the purchase lives in player meta. The names are
-- frozen as in tools/migration/steps/v0_44_0.py.
for _, name in ipairs({
	"grug_mounts:apprentice_mount", "grug_mounts:journeyman_mount",
	"grug_mounts:expert_mount", "grug_mounts:master_mount",
	"grug_mounts:boat", "grug_mounts:improved_boat",
}) do
	core.register_alias(name, "")
end
