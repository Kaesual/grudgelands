-- The Crafting tab. Round 45 lane RG removed the crafting grid and the recipe
-- books; until lane UI builds the recipe lists (round45-plan.md §4.4, ruling
-- 5) the tab is the "Crafting is being rebuilt" stub: a notice above the
-- short inventory, no lists of its own and no fields.
local STUB_TEXT = "Crafting is being rebuilt.\n\n" ..
	"The crafting grid and the recipe books are gone: recipes become lists " ..
	"with timed crafting jobs. This tab returns with the next update."

function grug_jobs.crafting_page_content(player)
	return ("textarea[0.3,0.3;9.8,3;;;%s]"):format(core.formspec_escape(STUB_TEXT))
end

sfinv.override_page("sfinv:crafting", {
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			grug_jobs.crafting_page_content(player), true)
	end,
})
