# Full-preparation scan-budget comparison

A bounded comparison of the 40 ms full-preparation column-selection budget
against the recorded 4 ms baseline. Scope, results and cave-generation limits:
[experiment report](../../docs/research/pregen-scan-budget.md).

- `micro.lua` invokes the actual portable scheduler fixture for the final
  PUC-5.1/LuaJIT parity pair.
- `run_native.py --execute` requires separate authorization for one native
  engine run. It copies the game, uses fresh isolated user/XDG/world paths,
  samples the exact engine PID, and stops at the matched 561-tile prefix or a
  seven-minute safety limit. It never uses a personal engine directory.
- `instrument.py` adds observation and a Server-step stop flag to the copy only.
- `compare.py` reads retained evidence and checks prefix/action/settings/source
  equality against `tools/r19_preparation_diagnosis/evidence`. It never runs an
  engine. Run `python3 tools/r19_preparation_budget/compare.py` from the repo.
- `evidence/` retains raw measurements, static checks, final interpreter parity,
  input hashes and the offline comparison result.

The first diagnostic run and this candidate run have separate authorizations.
These scripts are not a standing authorization to repeat long measurements.
