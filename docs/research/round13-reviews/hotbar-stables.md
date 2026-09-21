# Independent hotbar and stable-floor review

2026-09-21. Reviewer: native GPT-5.6 Sol, independent of the two native
GPT-5.6 Sol implementation agents. Review was read-only apart from this report.

## Result

**Clean.** No Critical, High, Medium or Low finding remains in the reviewed
playtest fixes. Fix rounds: 0. Elapsed wall time: unknown.

Candidate branch: `wp47-playtest-hotbar-stables`, based on
`1d27b60cb6e648031fa273e7d842a403bba4eac1`. Production-code diff SHA-256
(`grug_abilities/init.lua` and `wp13/capitals.lua`):
`214577cbf0d731092918d73e43bc328c34146c2cefa8588f8e8df43bff91652c`.

## Review

- `grug_abilities` now distinguishes the one initial character-kit operation
  with persistent player metadata. It inserts the ordered base abilities at
  the front of `main`, shifting complete `ItemStack` values into the first
  available space. Strike therefore occupies key 1, the remaining base kit
  follows, and faction supplies retain their counts and metadata afterwards.
  The completion marker is written only after every missing base ability was
  inserted, so a capacity failure cannot falsely certify a partial kit.
- The existing later/admin class-change path retains its prior preferred-slot,
  then first-free-slot behavior. Join and talent callbacks still call only
  normalization; they neither grant deleted representations nor rearrange the
  inventory. The Skills catalogue remains the manual recovery authority.
- The stable change is confined to the shared open-shelter branch of
  `capitals.stable`. Each of the six capital plot adapters marks its configured
  Riding service with `open_shelter = true`, so the single substitution covers
  Highcourt, Dur Brannoc, Lethariel, Nhal Veyr, Gor Drazhak and Kezamba while
  leaving unrelated stable buildings unchanged.
- `grug_farming:soil` is the already registered Human-field soil. It is outside
  default grass spread and the authored wild-soil roster. The existing current-
  world activation may hydrate it near water, but it does not turn it into
  grass; no new node, compatibility path or saved-world rewrite was introduced.
- The living class and mount design sections describe the implemented scope,
  and the follow-up record preserves the runtime boundary: fresh character and
  fresh generated stable, with no retrofit claim for existing mapblocks.

## Evidence and limits

- Reviewer rerun: `luajit tools/r12_skills/behavior.lua .` passed. It exercises
  the real class callback, verifies Strike at slot 1, all four Warrior base
  abilities ahead of both supplied stacks, the completion marker, deleted-skill
  non-regrant, catalogue recovery and the pre-existing bound-item rules.
- Plain-Lua-5.1 parsing passed for both changed production files and the focused
  fixture. `SETGLOBAL` inspection found only the expected `grug_abilities`
  production global; the pure mapgen module has none. `git diff --check` passed.
  Root's integrated static pass over all three changed Lua files is recorded at
  `/tmp/grug-hotbar-stable-static.log`; the five mandatory sweeps are clean
  apart from their explicitly filtered pre-existing prose matches.
- Stable routing, node registration and grass/hydration lifecycle were checked
  by source inspection. No broad mapgen population, PUC runtime, GUI or user
  world was run. Runtime acceptance remains the user's fresh-character and
  fresh-world visual check.
- The separately raised recipe redesign is discussion-only, has no code in this
  candidate and is outside this review.

Calibration: implementing models native GPT-5.6 Sol; reviewing model native
GPT-5.6 Sol, independent agent; 0 Critical / 0 High / 0 Medium / 0 Low; fix
rounds 0; elapsed wall time unknown.
