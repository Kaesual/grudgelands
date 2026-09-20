# Capital avenue cadence correction

The accepted inner avenue endpoint moved from 48 to 50, but the settlement
adapter also used that endpoint as the lamp and support-pier phase. This moved
outer gate and curtain cells unintentionally. Eleven moved north/east runs now
explicitly retain phase 48. Lethariel's north entrance remains at 22; negative
runs retain their unchanged starts. The adapter validates, carries and hashes
the phase independently of the endpoint. No outer wall, route or start geometry
changes.

`tools/wp13/integration_fixture.lua` exercises the actual prepare/config/writer
path, requires the authored phases/endpoints, rejects a false phase and proves
that changing the phase changes its published identity. Existing whole/clipped
road oracles now pass the authored phase. `project.lua` additionally runs actual
zone height, blueprints and settlement tails on the engine owner grid for the
exact four probe regions. It intentionally supplies no native terrain nodes.
Run it under LuaJIT only, with repository, capital key and absent-file output
directory arguments. `verify_outer.py REPO OLD_OUTPUT FIXED_OUTPUT` requires
byte-identical old/fixed authored outer cells and exact frozen gate SHA/counts.

The pre-CAP source is 7e2bc1f0; the unfixed integrated source is 2fcda608.
All four corrected gates reproduce the unchanged historical frozen hashes.
All twelve authored outer regions return exactly to the pre-CAP source.
Some pre-CAP source projections differ from historical engine expectations;
these remain separate attribution work, not accepted expectation updates.
The historical source 6cd971b0 matches every retained streets-r4 WP13 and
settlement source hash, unlike the dfb32cd5 provenance label. Its Highcourt
projection reproduces all four historical hashes exactly.

Full WP13 LuaJIT development suite passed before adding the focused phase
identity/validation assertions; that integration fixture is checked separately
on final source. Parser, SETGLOBAL and five sweeps cover changed Lua. No PUC
runtime was run in this lane. Engine acceptance and complete historical delta
attribution remain pending at this source checkpoint. Root owns the replacement
final engine fleet, final compact interpreter pair and independent review.
