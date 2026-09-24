# Round 21 bounded evidence

This directory contains small fixtures for this round, not a new exhaustive
mapgen framework. Read [the execution ledger](../../docs/planning/round21-state.md)
before rerunning anything. User GUI acceptance is separate.

- `integration.lua REPO` uses the actual runtime/manifest constructor and
  planner/writer for three chosen 80³ owners. **LuaJIT only**, timeout120s.
  Its engine-shaped VM does not simulate native lighting/cave generation.
  It writes a small sparse settlement replay for diagnosis without another
  constructor or VM run. Existing logs record failed fixture assumptions as
  well as the final successful candidate; the final `integration.log` is the
  acceptance output.
- `final_micro.lua REPO` composes bounded resource/nature/settlement/feedback
  and actual planner checks. Run once per interpreter on final frozen bytes,
  comparing stdout byte-for-byte. No terrain constructor or VM owners.
- `nature_columns.lua` was the author's single real horizontal/height scalar
  investigation, with one corrected fixture assumption. Do not repeat it just
  to duplicate accepted evidence.
- `evidence/combined-pins.tsv` records semantic pin candidates subsequently
  confirmed by the actual constructor in `integration.log`. Deriving pins by
  itself is not a manifest integration test.

No full-world preparation, seed fleet, census or historical omnibus runner is
part of this evidence. Maximum parallel CPU workers authorized for the round:
six; the actual checks needed at most two concurrent interpreters.

Startup follow-up: `startup_micro.lua` covers the fixed fish disposition and
the engine's seven-slot arrow recipe representation. `startup_probe/` is a
disposable native registration probe for `PROBE=... tools/luanti_headless.sh`;
it checks actual fish and Basics/crafting registration and immediately requests
shutdown. It is never shipped. Evidence is under `evidence/startup-fix/`.
