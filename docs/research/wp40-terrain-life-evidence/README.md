# Integrated terrain-life validation

Final frozen production and fixture bytes passed one compact PUC 5.1 runtime
process and the same fixture once under LuaJIT. `parity/inputs.sha256` binds
all inputs; `inputs-check.txt` verifies they stayed unchanged during the pair.
The two 219-line canonical outputs are byte-identical, SHA-256:

`7e3b294bc4f7dc9b46768126e71d352a00c15ce9a61326d888fa9580e69627c5`

`parity/output.sha256` retains the original `/tmp/grug-life-final-parity` run
paths. The copied output files have the same bytes. Interpreter stderr records
only interpreter identity. The R7 seam reports all 74 required production
modules executed. Actual engine/GUI testing remains the user's gate.

`axes/` records eight independent final composed-route-axis LuaJIT runs,
maximum seven concurrent processes with idle scheduling. Each run used:

```sh
chrt --idle 0 ionice -c3 luajit tools/wp40/quality_geometry_fixture.lua   /home/jan/projects/grudgelands /tmp/grudgelands-wp40-quality.rootN SEED
```

`axes.sha256` binds all logs and results. `static.txt` records the parser,
SETGLOBAL and five inspected sweeps; its exact offline driver is retained as
`static_check.py`. Offline shell hashing and comment/string matches are benign.

`gravewood/` preserves the final real-MTS versus portable writer comparison;
`flight/` preserves the accepted controller fixture and static checks;
`graph-oracle/` preserves the independent Floyd-Warshall comparison. These
focused development runs used LuaJIT only; their hashes retain original paths.
The final pair re-executes their portable fixtures on integrated frozen bytes.
