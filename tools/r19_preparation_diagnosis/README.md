# Isolated full-world preparation diagnosis

This directory retains evidence from the single native diagnosis run on
2026-09-23. It is not a production test suite or authorization to rerun a
long benchmark. Interpretation and scope:
[CPU diagnosis](../../docs/research/pregen-cpu-diagnosis.md).

`evidence/engine-os.jsonl` and `engine-minutes.jsonl` contain corrected
five-second host samples and minute summaries from the verified Luanti engine.
`engine.log` contains disposable-snapshot phase instrumentation from startup.
`instrumentation.diff` changes observation only; production files were untouched.
`snapshot.json` hashes the instrumented copied game. `run.conf`, `command.json`,
`engine-identity.json`, `system.txt`, and `static-checks.txt` establish the
settings, engine, source revision, process identity, host and Lua static checks.
Run `python3 tools/r19_preparation_diagnosis/evidence/analyze.py` from the
repository root to reproduce `phase-summary.txt`; it reads logs only and does
not start an engine.

A first sandbox launch failed before the engine booted. The initial host
sampler then selected a Flatpak wrapper, whose raw `os.jsonl` and
`minutes.jsonl` are excluded as invalid engine measurements. The corrected
sampler attached to the real engine without restarting it, beginning 43 seconds
after engine launch. That missing interval has cumulative startup CPU evidence
only. Phase instrumentation was active from startup.

The retained world and copied game are disposable local scratch paths recorded
in the report; no personal world or installed game was modified. Full process
command lines and paths refer only to this isolated diagnostic instance.
