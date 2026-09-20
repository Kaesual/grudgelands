# WP11 X3 validation evidence

This directory records the focused validation of the original-class X3
talent consumers on 2026-09-20.

- `kats.log` records LuaJIT execution of the real ability closures, the X3
  source/integration contract, and the existing full talent-model fixture.
  The behavior fixture exercises each of the four granted abilities and every
  replacement or settlement effect. It checks hostile current-ray refusal,
  friendly self fallback, shared action identity for multi-target settlement,
  the trigger windows, and the existing model fixture's death, leave, respec,
  and cap-restoration cases.
- `engine-server.log` is the isolated native Luanti server log from the
  disposable `tools/luanti_headless.sh` world. `WP11X3 RESULT PASS` confirms
  that all four granted definitions and their production registrations loaded;
  the server then reached its listening state without `ERROR` or `ModError`.
- `static.log` records the plain Lua 5.1 parser gate for every changed file,
  the inspected `SETGLOBAL` output for changed mod files, and complete mod and
  tools parser passes.
- `sweeps.log` records all five required repository sweeps. Its matches are
  existing comments, literal separators, offline tooling, and frozen manifest
  data; none is a new runtime-language violation in this package.
- `files.sha256` pins the production and focused-fixture bytes tested.

The native command used port 31248, a temporary world, `timeout`, and the local
Flatpak server. No GUI world, map-generation population, broad performance
suite, or PUC runtime was used. The remaining gates are independent review and
the user's eventual GUI runtime playtest.
