# Round 18 completion record

Date: 2026-09-23. Status: implementation, independent reviews and final technical
gates PASS; merged to main and locally synchronized. Remote push is blocked by
automatic approval review pending renewed confirmation. GUI acceptance remains user-run.
Contract: [round18-plan.md](round18-plan.md).
Execution: [round18-execution.md](round18-execution.md).
Next runtime pass: [round18-playtest.md](round18-playtest.md).

## Delivered scope

Equipment/trainer guidance, Cooking success feedback and protected unlearning,
clearer inventory/selection controls, 22 semantic action icons with equipped
weapon appearance retained, stable NPC-style nametags, full six-region atlas
coverage and terrain-only native minimap, level-appropriate ambient populations
and matching starter quests, ordinary mobs' 15-second incoming-damage pursuit,
level-up refill/burst and XP cap/death changes, correct shovel/pick material
semantics, and bounded preparation scheduling plus dismissible pre-creation
waiting. Whole-WP count remains 27/53.

Held-torch moving light is deliberately omitted after the approved complexity
preflight; friendly-guard healing is deferred. No client fork, migrations,
world geometry expansion, Nether content or additional balance campaign.

## Reviewed identities

Base: `7460c49d227a3f66673ad1bf4b7ed429e4b62321`.
Integration branch: `wp18-playtest-quality`.
Frozen production/test identity: `4d7adb555494e130feffdde2f83da3d6be4dd05a`.
Subsequent receipt changes contain documentation/evidence only.

| Lane | Root integration | Review |
|---|---|---|
| A UX | `0e67a78b` | Sol [UI/code](round18-review-ui.md) PASS |
| B atlas/minimap | `386f6216` | Sol code / Astra visual PASS |
| C populations | `c86621c4`, `3eb79a57` | Astra [world](round18-review-world.md) PASS |
| D pursuit | `fbca258a`, `85c162ab` | Astra world PASS |
| E XP | `486878ab` | Sol UI/code PASS |
| F waiting | `503948c6` | Sol UI/code PASS |
| G preparation | `d4b38594` | Astra world PASS |
| H1 artwork | `d20c1423` | Astra [visual/docs](round18-review-docs-art.md) PASS |
| H2 icons/tags | `8681af11`, `85c162ab` | Sol UI/code PASS |
| J tools | `27d8bae3`, `44a1a9a0` | Sol focused re-review PASS |

Independent review corrected return-deadline reset during Evade reacquisition,
Whitebridge's missing boar selection, the native probe's registration metadata
boundary, and cultural shovel-source capability groups. The drift review closed
old pursuit, icon and optional-torch descriptions. All findings are resolved.
No reviewer authored the reviewed implementation. Root retained a neutral
empty-slot wield placeholder instead of displaying an action-icon slab.

## Final technical evidence

Evidence: `tools/r18_final/evidence/`.

- Plain Lua 5.1 parser PASS on 55 changed/new Lua files, including tools.
  `static.txt` records SETGLOBAL inventory and all five compatibility sweeps.
  Production global writes are expected mod tables; test globals are explicit
  mocks. Sweep hits are comments/strings and the unchanged vendored
  `minetest.is_protected` call, not new incompatible code.
- Exactly one final compact process under each interpreter, 11 isolated
  fixtures: PUC 5.1 **0.067794 s**, LuaJIT **0.026646 s**, both exit 0.
  Byte-identical canonical SHA256:
  `d82a6c14aae29608178f351fc99822a417d0f414082809e34f40414785e8c2e8`.
  `puc51.txt`, `luajit.txt`, `parity.json` and `source.sha256` preserve evidence.
  No intermediate PUC runtime or exhaustive PUC campaign.
- Isolated native Luanti PASS, no ERROR or script-init clock warning. Eighteen
  real-authority population samples span six cultures at levels 3/6/10 using
  real role registration, host rows and species/day/night predicates. This is
  bounded eligibility evidence, not a generated-world density measurement.
  Actual engine dig parameters verify all eight tool materials, six loose
  hosts at pick/shovel time ratio 2, solid-host shovel refusal and cultural
  source access. Registry checks cover 22 action icons, quests, 12 homes and
  12 home atlas markers; disposition counts are 12 neutral/64 aggressive/11
  critter definitions (not simultaneous populations).
- `native.log` and compressed production/executed manifests record exact inputs.
  All **2083** production snapshot files match the frozen checkout. Scratch-only
  changes suppress generation scheduling and capture actual spawn-role inputs;
  no personal world/player data was modified. A prior init-phase clock probe
  was rejected and is not used as acceptance evidence.
- G's one existing bounded two-boot stop/resume check is retained in
  `tools/r18_preparation/evidence/`; independent review verified its hashes.
  Synthetic scheduling timing isolates avoidable wait, not a real FPS claim.
  No full-world run, repeated ETA estimate or new PERF campaign.
- Diff whitespace check and read-only reference pins PASS. No reference commit
  was moved.

## Visual delivery

[Local before/after gallery](../../tools/r18_art/gallery.html) and
[contact sheet](../../tools/r18_art/contact-sheet.png): 22 action icons with
recorded generation prompts and final hashes. Built-in image generation was
used; no provider CLI. An independent Astra inspected every icon at actual
32-pixel size and all six atlas views. Illustrated charge/wear overlays are
previews, not GUI evidence. Asset provenance is recorded in the manifest and
media license inventory.

## Calibration

| Scope | Implementer | Independent reviewer | Initial C/H/M/L | Fix rounds | Elapsed |
|---|---|---|---|---|---|
| A/B/E/F/H2 | native GPT-5.6 Sol; root Astra integration | native GPT-5.6 Sol | 0/0/0/0 | 0 | unknown |
| J | native GPT-5.6 Sol | native GPT-5.6 Sol | 0/1/0/0 | 1 | unknown |
| C/D/G and native boundary | C Sol, D/G Astra, root Astra | native GPT-6 Astra | 0/1/2/0 | 1 | unknown |
| H1 art and living docs | native GPT-6 Astra | independent native GPT-6 Astra | 0/0/1/2 | 1 | unknown |

Session routing explicitly authorizes native Sol/Astra. No Claude task or
same-provider CLI was used. Art had no visual findings; its row's findings
belong to living-document drift.

## Remaining runtime acceptance

Restart Luanti/server and use a fresh development world. Follow the linked
playtest checklist, especially trainer messages, hotbar/skill appearance,
atlas/minimap, long pulls and timeout, shovel use and waiting-screen Escape.
User GUI acceptance and actual fallback-engine runtime remain separate from
standalone interpreter parity and the headless native integration checks.

## Delivery receipt

- Reviewed evidence/receipt commit: `145cc77d`.
- Main merge: `92d63113982f2b7e03c814bf5d2a49cfdbe09584`.
- `tools/sync_to_luanti.sh` completed from main. Installed game:
  `/home/jan/.var/app/org.luanti.luanti/.minetest/games/grudgelands`.
  All 2083 production-manifest hashes match; complete mods/menu trees are
  byte-identical to checkout. No personal world/player data was modified.
- `git push origin main` was rejected by automatic approval review before
  execution. Root supplied the explicit earlier in-chat permission verbatim;
  the second review still rejected it because that earlier transcript was not
  verifiable in its context. Root did not bypass the block and requested renewed
  confirmation. Remote delivery is therefore **not complete**.
- Local playtest readiness is unaffected. Restart Luanti/server and use the
  linked fresh-world checklist. A later receipt-only commit may record the
  eventual push; it does not alter installed production bytes.
