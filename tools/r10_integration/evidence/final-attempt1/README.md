# First integrated Round 10 final-gate attempt

Frozen candidate: `2d3702d4627b215ea6782d10dc87e5d3b887c866`. This candidate
is **not accepted**. All six capital engines crashed in the ordinary socket
placement path: `patrol.face_yaw` calls the mobs_redo `self:set_yaw` method on
a plain `capital_display` entity. This is one shared High integration finding,
not six independent findings. Production correction and independent review
are required before repeating the relevant final gates.

The WP13 LuaJIT pre-step and complete integrated LuaJIT half passed. The PUC
half was intentionally terminated after the capital failure was diagnosed;
its retained partial output is **not interpreter parity evidence**. Candidate
inputs remained unchanged while those processes ran. A relevant production
change justifies a replacement frozen compact pair under the interpreter rule.

All 172 changed Lua inputs passed the parser and compatibility review, and
the fresh-server audit passed. `static/diff-check.log` reports only whitespace
in byte-preserved evidence artifacts; the independent static report records
that disposition without rewriting bound logs. These static results apply to
this candidate and do not close the engine finding.

The fleet used six isolated engine processes and the interpreter gate used
one, never exceeding the seven-process limit. Personal worlds were untouched.
`outputs.sha256` binds this retained attempt, including original failure logs.
