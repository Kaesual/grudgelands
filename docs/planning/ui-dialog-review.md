# Atlas 03 dialog review

2026-10-25. Design evaluation only; no runtime implementation is authorized by
this artifact. The user wants to revisit Atlas 03 views **18–34**, especially
vendors and quest givers, while preserving the existing mechanisms. They also
reported oversized purchase icons in 0.60.1. Keep the `ui-tab-hover` worktree;
its separate hover correction is commit `0727925c`.

## Review artifact

Private, offline browser bundle:
`~/projects/grudgelands-orchestration/ui-atlas03-dialogreview-2026-10-25/Grudgelands-UI-Atlas-03-Dialogreview.html`.
Editable sources, asset provenance, source notes and screenshots are alongside
it. The original Atlas 03 remains unchanged in `ui-mockup-2026-10-24-v3`.
The new comparison covers main `c3861491` / 0.60.1. Views outside 18–34 are
explicitly archived, not refreshed representations of the current client.

Every reviewed view has a collapsible comparison outside the game mockup:
proposed presentation, retained mechanics, implementation cautions and source
owners. The scenario controls are review tools, not new player settings.

## Proposals to evaluate

- **Vendor:** compact two-column cards with small icons, readable item names
  and prices, and an explicit direct Buy button. Long catalogues scroll within
  the offer pane. Keep one existing purchase operation per click, every offer,
  the vendor-specific shelf, race discount, exact stack tooltips, and the
  existing sell/lot/remainder rules. No cart, quantity selector or confirmation
  step. Ordinary money shops and reputation-only camp shops remain distinct.
- **Quest giver:** narrower categorized list beside prose, objectives and
  rewards; actions stay below, chosen reward details remain readable. Use
  actual quest text and the current giver/turn-in logic. Completion text is
  shown before turn-in; there is no added completion screen. A styled list
  needs an adapter to the existing selection route and Close focus behavior.
- **Other dialogs:** retain the stronger Atlas layouts while correcting
  mismatches: repair durability and total cost; primary-profession versus
  additional Alchemy rules; mount predecessor/level/owned states; complete
  Claim Stone instructions; mail deletion with attachments; quickbar item use
  and closure; Welcome dismissal. Creation stays one page, and withdrawal
  keeps three coin fields in one row.

The General shelf uses all 14 current base offers; the T1 mockup explicitly
shows a four-offer excerpt, not a capacity change. Highcourt quest text and
reward formulas use repository data. Player inventories/progress, mail,
repair/sale prices and lift floors are examples. Some icons/tints approximate
runtime composition. These limits are documented in the artifact's README
and review notes; the browser is not an economy or persistence simulator.

## Constraints and acceptance

No change to native slots, drag/shift-click, saved state, ids, capacities,
validation, travel ownership, mail attachment handling or profession rules.
Keep current animation strips and send cadence; no new progress timers.
Preparation retains its existing percentage and static bar. Repair percentages
are existing durability snapshots, not countdowns.

Browser checks: **52 states across 17 views**, no script errors, broken images
or detected horizontal content overflow; **9 interaction assertions pass**.
Screenshots cover each view, vendor/quest variants, and key windows at
1035×696 and 1920×1080. Images were inspected, including compact vendor offers,
reputation stock, quest choices, multiple quests, trainers and Housing Steward.
Browser fit scales text with the canvas; use 100% to assess typography. Native
Luanti small-window font behavior, input/focus and desktop/web acceptance still
need implementation-time checks. No Luanti changes or personal installation
were made for this review.

Next is the user's visual feedback on these proposals, before a runtime lane.
The existing shared UI helpers should remain the rendering foundation; the
service mods keep their current mechanics and authoritative data.
