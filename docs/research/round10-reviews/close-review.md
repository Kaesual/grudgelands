# Independent CLOSE documentation review

**Verdict: FIX FIRST**

- Candidate: `93cc9ab28c7e8cadca51a224965dcc1711c61dea`
- Base: `6a6378d9`
- Reviewer: GPT-5.6 Sol, native independent context
- Independence: reviewer did not author the CLOSE candidate; review was read-only and did not certify the reviewer's separate GAME/ART implementation work
- Findings: 0 Critical, 0 High, 2 Medium, 0 Low
- Fix rounds reviewed: 0
- Runtime/interpreter work: none (documentation-only review)

## Medium findings

1. **`docs/design/character_visuals.md:69-78`, `docs/design/README.md:37`, `README.md:89-95` — the living visual contract and both tours still specify two armor lines and runtime tier tinting, contradicting the accepted three independent metal/cloth/leather families with baked tier media.** Trigger: a future implementer following the living design is instructed to make leather borrow cloth and to tint one overlay, while the accepted R10 visual outcome and staged ART candidate provide dedicated leather art and distinct per-tier source media. Update the living contract first, then derive both tour summaries from it; retain the already-decided four slots, six tiers, stature, animation and composition rules.

2. **`docs/design/character_visuals.md:60-63` — “every race ... takes the same damage from the same fall” contradicts the accepted Dwarf fall passive and the candidate's own playtest requirement.** Trigger: two characters with equal maximum HP falling through the same native damage must diverge because the accepted pipeline applies the Dwarf 20% reduction after max-HP scaling and before absorb (`docs/research/round10-next-playtest.md:31-34`). Narrow this sentence to say collision/eye/stature do not alter fall calculation, while race passives still apply through the combat contract.

## Confirmed clean areas

The candidate preserves honest whole-WP counts/status, keeps WP22/WP24/WP46/WP47/WP49/Scout/public-release work open, records the bandit-frontier 24-vs-16 discrepancy, archives resolved Round 7–10 TODOs without turning them into living authority, retains B22 and D18 as genuinely open, distinguishes 36 registered trinket identities from per-stack state, records Basics/profession exclusivity and seven primaries/two smiths/shared Forge, preserves native-provider routing, and supplies a conditional fresh-world GUI checklist with verified mount/Sweetroot item ids. `git diff --check` is clean.

## Focused re-review — `557f942e2627e30c8efc499e13a1e4c177622dfe`

**Verdict: CLEAN CONDITIONAL ON ART INTEGRATION**

- Finding 1: closed by the corrected README/design-tour summaries together with the explicit integration dependency on ART `6cfbea3c`, whose `character_visuals.md` §3 supplies the authoritative three-family/baked-tier text. The CLOSE branch deliberately does not duplicate that overlapping edit.
- Finding 2: closed at `character_visuals.md:60-64`; stature no longer asserts equal racial fall damage and the sentence points to the central formula plus the Dwarf 20% ordering.
- Remaining findings: 0 Critical, 0 High, 0 Medium, 0 Low.
- Review fix rounds: 1.
- `git diff --check` remains clean. Final dynamic status sweep remains a separate post-integration gate and is not certified here.
