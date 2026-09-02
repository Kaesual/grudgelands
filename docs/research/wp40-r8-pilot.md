# WP40 R8 real-engine pilot record

**Status:** the first diagnostic attempt stopped before generation; a fresh
pilot on the corrected and reviewed candidate is pending.

## Attempt 1 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `a1dc04b89d6e54945fb3507bf92967c4d6c0a86c`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `981cf1169e5565128cb1bf50613182e016787835b9da779d8e89c7dd6ad83883`
- Result: stopped before mapchunk generation; reverse order not started
- Process result: exit 1 after 0.58 seconds; launcher peak RSS 19,248 KiB;
  these startup-only numbers are not a G2 projection
- Failure: `get_mapgen_setting_noiseparams("mgv7_np_terrain_base").spread`
  carried the engine's builtin vector metatable, which the R7 validator
  incorrectly rejected as non-plain
- Forward console-log SHA-256:
  `14938afdb49a6a669c8d3107106802ea565c6e17358a58e06ee7ca7873c1f222`
- Forward server-log SHA-256:
  `c785edab6bdf4247b7729b5803bfd9f128ddee95c08609d3f480bab954a8b2bb`

The disposable world was removed by the runner trap. The diagnostic logs and
exact input copies remain under the ignored but permanent
`tools/wp40/results/r8/<capture-id>/` tree; the hashes and conclusion above are
the durable repository record. No mapchunk, native-event, order-equality,
timing, RSS, shutdown or release claim is accepted from this attempt.

## Correction and rerun rule

The correction is deliberately narrow: accept a readback `spread` table only
when its metatable is exactly `vector.metatable`, while continuing to accept
the legacy/plain fixture shape and reject unrelated metatables. It changes no
noise value, seed, native registration or writer behavior. Because production
Lua changed, final frozen bytes require a replacement compact PUC 5.1/LuaJIT
micro-KAT pair. The complete sequential pilot must then run from a new exact
reviewed commit and will receive its own immutable capture ID.

The runner correction also writes probe events through the test-only trusted
environment into the exact durable capture directory. Its interrupt trap
stops and waits for parallel wrappers, then repeats the process-group sweep so
a late-published engine group cannot survive scratch-world cleanup.

## Attempt 2 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `2cbe52748eaaa8bba1efbae83b2700bc1231c480`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `7171368d88152980ec26399c05f6abea51bb1577969852744a2644b679cc01f9`
- Result: stopped before mapchunk generation; reverse order not started
- Process result: exit 1 after 0.56 seconds; launcher peak RSS 19,004 KiB;
  these startup-only numbers are not a G2 projection
- Failure: the effective global and mapgen settings both returned the exact
  string `1`, but the R7 validator required the real `core.settings` object to
  have Lua type `table`; Luanti exposes its Settings object as `userdata`
- Forward console-log SHA-256:
  `9d145f2feef3e2cf79095642a9d33b6f4e626bc94d88e36ee71f0627d5bec47e`
- Forward server-log SHA-256:
  `8ce021e9c289037aa7ab42482dde60a5010e3e3296e4c4bf8de10999015319ed`

An isolated pre-loader diagnostic confirmed
`core.settings:get("num_emerge_threads") == "1"` and
`core.get_mapgen_setting("num_emerge_threads") == "1"`. The correction admits
the engine's userdata Settings object as well as the test seam's table, while
still requiring a callable `get` method and the exact string value `1`. The
final micro-KAT now models this boundary with a userdata proxy.
