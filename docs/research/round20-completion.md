# Round 20 integration receipt

Date: 2026-09-24. Coordinator: GPT-6 Astra. **Delivered locally: all technical gates passed, merged to main
as `8308229f` and synchronized to the local Luanti game on 2026-09-24.** [Execution ledger](../planning/round20-state.md).
Baseline: `e346ec482c34d1a494ebcdf32be61eb152653e83`.

## Scope

- Seventy additional authored POI compositions fill the art roster without
  replacing existing actors or expanding terrain reservations. The existing
  twelve civic and eighteen regional sites remain.
- 240 quests / 78 questgiver identities, including 36 conversation-only handoffs.
  Starter errands can be accepted together; cooks are distinct from trainers;
  capital introductions begin at level 10. Unfinished prerequisites hide later
  quests until turn-in. No Nether, Housing, player-kill quests or king finale.
- Class weapon permissions, family-specific enchant pools (588 operations),
  Scout Dexterity melee, exact durability text and persistent broken-item art.
- Contextual skill LMB combat/hand digging, ready-skill/Strike fallback, current
  ally-or-self support targeting, single-press loot and RMB bow/food holds.
- Full-cube suffocation, all-player native minimap markers, party level labels,
  inventory focus, accepted-stun particles and immediate ordinary crab removal.

Details: [quests](round20-quests.md), [content](round20-content.md),
[POIs](round20-pois.md), [equipment](round20-gear.md),
[input](round20-input.md), [combat audit](round20-combat.md).

## Independent reviews and calibration

Native thread limits prevented additional Sol workers, so three existing Astra
threads were reused with distinct authors and reviewers. No provider CLI ran.
All lanes are nontrivial; elapsed implementation time is not reliably measured.

| Lane | Implementer | Independent reviewer | Confirmed findings / fixes |
|---|---|---|---|
| F1/F2 UX | Astra worker | Astra root | 0 Critical/High; no confirmed production finding; final fixture passed |
| F3 equipment | Astra worker | Astra root | 0 Critical/High; no confirmed production finding; actual boundary fixture passed |
| F4 combat | Astra root | Astra worker `poi_quest_round_preflight` | 0 Critical/High; clean source review; 0 fixes; review about 5 min |
| Q1 framework | Astra root | Astra worker `r20_input_state_review` | 0 Critical/High; no confirmed source finding; final fixture passed |
| Q3 catalog | Astra worker | Astra worker `poi_quest_round_preflight` | 0 Critical/High production; Medium camp-palette fixture defect plus Low ineffective assertion corrected/re-reviewed; review about 8 min |
| P2/P3 art | Astra worker | Astra worker `r20_input_state_review` | 0 Critical / 2 High (missing slab, blocked root); Medium blocked doorway and visual path revision; three correction passes, independently re-reviewed |
| F5 input | Astra worker | Astra worker `r20_creative` | 0 Critical/High; two Medium: Loose cadence and stale food callback return; corrected in one pass and independently re-reviewed |
| Living docs | Astra root | Astra worker `r20_input_state_review` | Medium: two stale tool/fist PvP statements; corrected and re-reviewed |

Source review is separate from runtime evidence. Reviewers did not duplicate
portable interpreter or engine runs.

## Validation state

The compact PUC-5.1/LuaJIT pair passed byte-identically after the two input fixes, digest
`385d9d723000ab33375e38b3c038b0ace1fcec33ac4144849734ab36e168e371`.
The earlier pre-fix pair is retained as historical evidence, not the final gate.
It covers actual quest transactions, gear/catalog/application and equipment/
wear/repair boundaries, recovery/stun, UX and input dispatch fixtures.
It is not a GUI, real two-player or fallback-engine test.

POI construction uses actual runtime/strict manifest/MTS and planner consumers.
Early final attempts identified an obsolete empty-tool fixture (now uses actual
vendored tool definitions), the two art defects above and a harness-size error:
production P9G requires 80-by-80 columns, so the eighteen owners now have their
normal size. A later circulation assertion identified an inaccessible apex
camp interior; the rack was moved clear of the door and independently reviewed.
The corrected gate passed all 70 sites, 105 buildings, 18 full-size planner
owners, 12 cook sockets and 6 reused envoy sockets. Root visually inspected
15 generated schematic views; a bounded path revision removed uniform crosses.
The final geometry gate passed again after that revision. Manifest:
`b440dbd6110a047e402765b9ccaa54b1f09b9bb5c707ad566fcdfae1eed5c866`.
No full-world generation, seed fleet, exhaustive legacy suite or PERF campaign.

The isolated engine registration smoke reached listening and loaded all modules,
then exposed an overly narrow catalog fixture: it tested camp archers against
ambient spawn palettes only. Actual frontier camps supply those targets. The
fixture correction was independently reviewed. One bounded replacement smoke
passed with 240 quests / 78 NPC identities / 90 new regional quests / 36 talks /
6 guard objectives, and 22 skills / 63 foods. Catalog receipt digest:
`23b7a1b0c2fa7874427d0b1cc97811dff471d98d`. Both disposable worlds were removed.
Existing missing-vendor-price warnings for dropped apples/sticks remain economy
backlog items; no new load error or undeclared-global warning is accepted.
GUI acceptance belongs to the user: [playtest checklist](round20-playtest.md).

## Practical limitations and deliberately unchanged areas

Native GUI opening can behave like mouse release, and very short air clicks can
fall between control reports; both are user-accepted. Creative's accelerated
initial digging can be rejected before the 200 ms arbitration completes and
visually roll back once. Normal Survival timings take precedence.

The bandit premature-heal and mob-stacking reports were investigated without a
confirmed production defect. Existing camp-boundary reset remains; no speculative
AI rewrite is claimed. Native inventory-key handling while a text field actively
owns typing remains client behavior. The frontier bandit core-width discrepancy,
boat teaching, full story/PvP/front encounters and Housing remain in the backlog.
No remote push or deployment is authorized or claimed by this round.

## Frozen evidence

[Portable outputs](../../tools/r20/evidence/portable/puc.log),
[POI construction](../../tools/r20/evidence/pois/run.log),
[schematic gallery](../../tools/r20/evidence/pois/index.html),
[engine registration](../../tools/r20/evidence/engine.log),
[static gate output](../../tools/r20/evidence/static.log) and
[source hashes](../../tools/r20/evidence/inputs.sha256) are retained.
59 changed/new Lua files passed the plain-5.1 parser; SETGLOBAL writes are
expected mod declarations or isolated fixture doubles. Sweeps 1/2/3/5 had no
hits; every sweep-4 hit is a reviewed comment or literal pipe separator.
The grep script returns nonzero for those matches, not a clean automatic result.
Reference pins remain unchanged. No production Lua changed after final checks.

Final independent gate: Astra `r20_input_state_review` inspected the frozen
outputs and all 969 source hashes, confirmed unchanged reference pins and
removed temporary worlds, and returned PASS with no open High/Medium findings.
No duplicate runtime was run by the reviewer. A separate personal `luanti.bin`
GUI process was observed and deliberately left running; no probe server remains.
