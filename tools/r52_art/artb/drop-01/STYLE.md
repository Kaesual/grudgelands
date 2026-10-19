# ARTB pass 1: style rules

These are three alternatives for the same eventual 118-icon set (44 skills
and 74 talents), not styles to mix within a set. The user's style selection
is pending. Motifs and tree membership follow the
[node list](../../../../docs/planning/class-redesign/node-list.md); the
[manifest](manifest.json) preserves every exact image prompt.

## A — Painted embers

Use broad, faceted painted masses with a luminous core, restrained bloom
and deep matte shadows, applying the tree palettes below to the motif and
background while keeping the common bronze rim.
Light every object from the upper left; keep meaningful edges and gaps
about 2 final pixels wide, with detail subordinate to three main value masses.
Skills fill the square without a border; talents sit in a simple circular
bronze medallion about 91% of the canvas wide with a roughly 3 px rim.

## B — Cut enamel

Use crisp angular silhouettes, large flat color steps, roughly 2 px dark
outlines and the tree palettes below, reserving the lightest tone for the
main identifying shape.
Light-facing facets point upper left; suppress surface grain and keep
negative spaces broad enough to survive the reduction to 32 px.
Skills remain unframed; talents use a square enamel frame with clipped
corners and roughly 3 px edge bands in a muted tree color.

## C — Forged sigils

Build the motif as a shallow relief of broad metal planes and colored
inlays using the tree palettes below, with blackened recesses and restrained
wear that never carries essential information.
Use upper-left raking light, lower-right cast shadows and carved divisions
about 2 final pixels wide so the form reads before the surface texture.
Skills remain unframed relief scenes; talents use an octagonal forged
bezel with broad roughly 3 px bevels and a dark inset plate.

## Palette anchors for pass 2

The named colors are the tree language from the node list; the hex values
are working art anchors for extending this sample, not gameplay constants.
Use the same anchors for all three style proposals; change the surface
treatment, not the identity of the tree.

| Tree | Main colors | Dark field | Shape vocabulary |
|---|---|---|---|
| Ember | Orange `#F68B28`, red `#BC321E`, warm ivory glint | Charcoal `#171619` | Flames, sparks, burning rings |
| Rime | Pale blue `#A5D9F2`, cold white `#F1FBFF` | Navy `#0A1930` | Crystals, frost, ice plates |
| Bulwark | Steel `#99A3AE`, bronze `#B08A4D` | Slate `#171D26` | Plates, shields, planted stances |
| Ruin | Crimson `#B52F3B`, pale hot edges | Black `#140E15` | Heavy blows, broken metal, rage |
| Mercy | Warm gold `#E8BC5C`, ivory `#FFF0CE` | Warm brown `#251B17` | Open hands, gentle light, vessels |
| Reckoning | Hard gold `#D5AD52`, white `#FFF6DD`, crimson `#A32A32` | Umber-black `#1E1615` | Quills, seals, scales, severe sun |
| Quarry | Green `#91AA55`, earth brown `#94603A` | Forest `#10251D` | Arrows, feathers, bows, eyes |
| Veil | Indigo `#343568`, violet `#8162B1`, silver `#DFE4ED` | Indigo-black `#100F22` | Short blades, smoke, crescents |

Skill families use their node-list language: fire follows Ember, frost
follows Rime, holy uses gold-white, wild uses green-teal and earth, shadow
uses indigo/violet and silver, and rage uses crimson/black.
Bulwark talents retain their steel/bronze language even when a related
skill belongs to the rage family.

## Shared continuation rules

- Draw the motif, never a name, numeral or letter; names remain provisional.
- Use one main silhouette with one semantic accent at most, as in the
  crown, crack, rivets, drops, sharpened nib and returning arrow here.
- Preserve the base skill's placement, angle and outer contour for its
  transform. Each Cold Spark in this drop edits only this project's own
  matching Fiery Spark source; it changes flame to crystal and the palette
  to frost. Apply the same approach to later transform pairs.
- Judge every new icon at 32 px before accepting its 64 px master; the
  preview's 48 px hotbars provide the intermediate-size comparison.
- Keep the frame treatment constant throughout the chosen talent set,
  including window nodes such as R10. Runtime readiness is a separate
  integration concern; no state overlay is baked into this sample.
- Deliver opaque 64 × 64 RGB PNGs with Lanczos reduction, retaining the
  individual prompt, tool output path, processing and SHA-256 receipt.
