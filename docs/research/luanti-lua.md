# The Lua environment inside Luanti

Deeper reference for the AGENTS.md section "Lua & Luanti environment".
All file references point into `reference_projects/luanti` (5.17.0-dev,
commit `df04879`) unless a URL is given.

**Planning note.** If you are briefing, scheduling or costing any task that
*executes* Lua — harness runs, gates, KATs, scans, reproductions — read
"Interpreter and test strategy" at the end of this file before writing the
plan. It fixes which interpreter owns which layer (LuaJIT for the
high-volume loop, PUC 5.1 for the static gates and targeted KATs) and
reserves comprehensive PUC rounds for the defined final gates; a plan that
gets this split wrong misprices the work by an order of magnitude.

## What the version pin means (read this first)

Two different version numbers are in play. Do not conflate them:

- **Luanti 5.17.0-dev** is the *engine* version of the reference checkout
  in `reference_projects/luanti`. It exists so every claim below can be
  quoted as `file:line` and re-checked. It is a **read-only source
  reference**, not an API floor we target.
- **Lua 5.1** is the *language* version we write. It is decoupled from the
  engine version and **never rises with it** — a newer Luanti still embeds
  Lua 5.1.5 (`lib/lua/src/lua.h:20`). Bumping the engine checkout does not
  unlock `goto`, `//`, `table.unpack` or any other 5.2+/5.3+ syntax.

So: "the engine is at 5.17" says nothing about which syntax is allowed.
The allowed syntax is fixed by the section "Language level & safe feature
set" below, and it is Lua 5.1 — *plain* 5.1, not LuaJIT's superset,
because the fallback build ships plain PUC 5.1.5 (see "Which Lua exactly").

## Where the real code lives

The engine's own Lua **is checked out in this repo** — never guess at
engine behaviour, read it. All paths are relative to
`reference_projects/luanti`:

| What | Path |
| --- | --- |
| **The Lua the engine ships and runs before any mod** | `builtin/init.lua` (bootstrap + load order) |
| Stdlib extensions & helpers | `builtin/common/` — `math.lua`, `vector.lua`, `vector2.lua`, `strict.lua`, `serialize.lua`, `misc_helpers.lua`, `after.lua`, `metatable.lua`, `register.lua`, `mod_storage.lua`, `item_s.lua`, `chatcommands.lua` |
| Server-side game layer (the `core.*` behaviour mods sit on) | `builtin/game/` — `item.lua`, `falling.lua`, `register.lua`, `hud.lua`, `knockback.lua`, `features.lua`, `deprecated.lua`, `privileges.lua`, `static_spawn.lua`, `voxelarea.lua`, … |
| Async / mapgen (emerge) environments | `builtin/async/game.lua`, `builtin/emerge/` |
| Engine-sanctioned usage examples | `builtin/common/tests/*_spec.lua`, `builtin/game/tests/` |
| Setting names, types and defaults | `builtin/settingtypes.txt` |
| **The interpreter itself** (fallback build) | `lib/lua/src/` — PUC Lua 5.1.5 |
| `bit` library when there is no LuaJIT | `lib/bitop/` |
| `string.pack`/`unpack`/`packsize` backport | `lib/lstrpack/` |
| **C++ binding layer** — the truth when the docs are silent | `src/script/lua_api/l_*.cpp` (one file per API area: `l_env`, `l_object`, `l_item`, `l_inventory`, `l_mapgen`, `l_noise`, `l_vmanip`, `l_util`, …) |
| Bootstrap, sandbox whitelist, callback dispatch | `src/script/cpp_api/` — `s_base.cpp`, `s_security.cpp`, `s_entity.cpp`, `s_player.cpp`, … |
| **The API spec** (~12,700 lines) | `doc/lua_api.md` |
| Other docs | `doc/breakages.md`, `doc/builtin_entities.md`, `doc/world_format.md`, `doc/client_lua_api.md`, `doc/menu_lua_api.md` |

Lookup order that works: `doc/lua_api.md` for the contract → `builtin/`
for what the engine actually does in Lua → `src/script/lua_api/l_*.cpp`
for anything the other two leave open (mapgen order, biome selection,
punch handling, nametag rendering). Quote `file:line` in findings so the
next agent can re-verify.

## Which Lua exactly

- The engine **prefers LuaJIT but does not require it**. `ENABLE_LUAJIT` is
  `TRUE` by default; if LuaJIT is not found the build silently falls back to
  the **bundled PUC Lua** — `cmake/Modules/FindLua.cmake:4-28`.
- The bundled interpreter is **Lua 5.1.5** (`lib/lua/src/lua.h:20`), patched
  with a custom `lua_atccall` hook so C++ exceptions can cross the Lua stack
  (`src/script/cpp_api/s_base.cpp:105-110`); system-wide PUC Lua is rejected
  at configure time for that reason (`src/CMakeLists.txt:908-921`).
- LuaJIT: anything older than ~March 2021 only warns
  (`src/CMakeLists.txt:890-906`). Luanti links a *system* LuaJIT, so
  compile-time LuaJIT flags are set by the distro, not by us.
- **Practical consequence: write code that runs on plain Lua 5.1.5.** Both
  configurations ship in the wild (aarch64/macOS builds regularly use the
  bundled Lua), and the engine's own builtin code stays 5.1-compatible —
  e.g. it feature-detects `table.move` instead of assuming it:
  `builtin/common/misc_helpers.lua:572-580` (`if table.move then -- LuaJIT`).

## Language level & safe feature set

Baseline is **Lua 5.1** syntax. LuaJIT adds 5.2/5.3 features on top, but
those are *not* available in the fallback build:

| Feature | plain 5.1 | LuaJIT 2.1 | verdict |
| --- | --- | --- | --- |
| `goto` / `::label::` | no | yes (unconditional) | **avoid** |
| `\u{XXXX}` string escape | no | yes (5.3 ext) | **avoid** |
| `\x41`, `\z` escapes | no | yes | **avoid** |
| `table.move`, `coroutine.isyieldable` | no | yes | avoid or guard |
| `table.unpack` / `table.pack` | no | only with `LUAJIT_ENABLE_LUA52COMPAT` | **never use** |
| `__len` on tables, `__pairs`, `rawlen` | no | only with `LUA52COMPAT` | never use |
| integer division `//` | no | no | never (use `math.floor(a/b)`) |
| bitwise operators `& \| ~ >> <<` | no | no | never (use `bit.*`) |
| `unpack`, `setfenv`, `getfenv`, `loadstring` | yes | yes | fine |

Sources for the LuaJIT columns: <https://luajit.org/extensions.html>
(sections "Extensions from Lua 5.2" / "from Lua 5.3" and the
`-DLUAJIT_ENABLE_LUA52COMPAT` list).

Always available regardless of interpreter, because the engine injects them:

- **`bit` (Lua BitOp)** — with LuaJIT it is built in; without it the engine
  compiles `lib/bitop` and opens it manually
  (`CMakeLists.txt:288-290`, `src/script/cpp_api/s_base.cpp:80-84`).
  API: `bit.tobit/tohex/bnot/band/bor/bxor/lshift/rshift/arshift/rol/ror/bswap`
  (`doc/lua_api.md:12705-12710`). Operates on **32-bit** values.
- **`string.pack` / `string.unpack` / `string.packsize`** — backported from
  PUC Lua 5.4 as a vendored C file (`lib/lstrpack/lstrpack.c:1-3`,
  registered in `src/script/cpp_api/s_base.cpp:87`, documented at
  `doc/lua_api.md:4597-4600`).

**Numbers**: no integer type; everything is a C double. The safe integer
range is `[slua] = ±(2^53−1)` and the API docs use that notation
(`doc/lua_api.md:86-104`). Note LuaJIT's 64-bit `bit` cdata semantics do not
exist in the fallback build — do not rely on them.

## Engine additions to the standard library

Loaded before any mod, in this order: `math.lua`, `vector.lua`,
`vector2.lua`, `strict.lua`, `serialize.lua`, `misc_helpers.lua`
(`builtin/init.lua:45-50`).

- `print` is redirected to the engine log/terminal; `core.debug(...)` logs
  (`builtin/init.lua:17-27`). `math.randomseed` is seeded at startup
  (`builtin/init.lua:29-35`) — do **not** reseed globally.
- `minetest = core` alias (`builtin/init.lua:38`) — we always write `core.*`.
- **string**: `string.split(str, sep, include_empty, max_splits, sep_is_pattern)`
  (`builtin/common/misc_helpers.lua:252`), `string:trim()` (`:300`).
- **table**: `table.indexof` (`:280`, returns `-1` when absent, not `nil`),
  `table.keyof` (`:290`), `table.copy` (`:564`, **strips metatables**),
  `table.copy_with_metatables` (`:568`), `table.insert_all` (`:572`),
  `table.key_value_swap` (`:583`), `table.shuffle` (`:592`). `table.copy`
  handles cycles but copies *keys* recursively too.
- **math**: `math.hypot`, `math.sign(x, tolerance)`, `math.factorial`,
  `math.round` (half away from zero), `math.isfinite`
  (`builtin/common/math.lua:8-50`).
- **dump / dump2**: value dump with cycle handling
  (`builtin/common/misc_helpers.lua:72,120`) — use this for logging, not
  `core.serialize`.
- **vector / vector2**: metatable-based (`builtin/common/vector.lua:12-30`).
  Operators `== - + - * /` work **only if all operands carry the metatable**
  (`doc/lua_api.md:4263`) — Lua 5.1 fires `__eq` only when both tables share
  one metatable. A literal `{x=1,y=2,z=3}` compared with `==` against an
  engine-returned position is therefore *silently false*; use
  `vector.equals()` (`builtin/common/vector.lua:73-78`). `#v` is **not**
  overloaded (5.1 has no `__len` for tables) — use `vector.length()`
  (`builtin/common/vector.lua:82-85`). `vector.metatable` must not be
  modified (`doc/lua_api.md:4252`).
- **`core.serialize` / `core.deserialize`** (`builtin/common/serialize.lua:216,234`):
  emits Lua source (`return {...}`), supports cycles and shared references.
  Only nil/boolean/number/string/table (+ deprecated functions) — **userdata
  and threads raise "unsupported type"** (`:31-33`). `deserialize` runs the
  chunk via `loadstring` in an env of `{inf, nan, loadstring}` — sandboxed but
  **not safe against untrusted input** (`doc/lua_api.md:8122-8135`).
- **`core.parse_json` / `core.write_json`** (`doc/lua_api.md:8092-8104`):
  `parse_json` returns `nil` + logs on failure unless `return_error` is set;
  JSON `null` maps to `nullvalue` (default `nil`).
- **`core.after(sec, func, ...)`** (`builtin/common/after.lua:156`): jobs run
  from a globalstep (`:117`), so `sec` is a **lower bound** measured in
  globalstep dtime, never a precise timer (`doc/lua_api.md:7596-7605`).
- **`core.global_exists(name)`** — the only way to test a global without
  tripping the strict warning (`builtin/common/strict.lua:3`).

## strict.lua and mod structure

`builtin/common/strict.lua:16-49` puts a metatable on `_G`. It **warns, never
errors**:

- Reading an undeclared global → `core.log("warning", "Undeclared global
  variable %q accessed at %s:%d")`.
- Assigning to an undeclared global **from inside a function** → warning.
  Assignment from a file's main chunk (`info.what == "main"`) is exempt and
  marks the name as declared (`:24-27`).
- Each source-line/name pair warns only once.

Consequences: **all mods share one global table** — there is no per-mod
environment, `loadScript` just `pcall`s the chunk in the shared state
(`src/script/cpp_api/s_base.cpp:257-280`). So: exactly one global per mod
(the mod table, assigned at file top level), everything else `local`.
Assigning your mod table lazily inside a function will warn.

## Async & mapgen (emerge) environments

Separate Lua states with **no access to map, entities, players, or your
globals** (`doc/lua_api.md:7617-7621`).

- Async: `core.handle_async(func, callback, ...)` and
  `core.register_async_dofile(path)` — `func` must be self-contained; its
  upvalues are *not* transferred. Available: `string/table/math/bit`,
  logging/filesystem/encoding/hashing/compression helpers, `core.settings`,
  read-only `core.registered_items/nodes/tools/craftitems/aliases` **with all
  functions and userdata replaced by `true`**, IPC, and the classes
  `ItemStack`, `VoxelManip`, `ValueNoise(Map)`, `PseudoRandom`, `PcgRandom`,
  `SecureRandom`, `AreaStore`, `VoxelArea`, `Settings`
  (`doc/lua_api.md:7640-7675`, impl. `builtin/async/game.lua`).
- Mapgen/emerge: `core.register_mapgen_script(path)`, callback
  `core.register_on_generated(vmanip, minp, maxp, blockseed)`. No globalstep,
  no timers, **no node metadata**; `core.get_node`/`set_node` only touch the
  current chunk (`doc/lua_api.md:7676-7757`).
- Tables crossing the boundary lose their metatables unless registered with
  `core.register_portable_metatable(name, mt)` **in both environments**
  (`doc/lua_api.md:8304-8313`, `builtin/common/metatable.lua:3-19`; `vector`
  is pre-registered as `__builtin:vector`).

## Sandbox (`secure.enable_security`, default true)

Default `true` (`builtin/settingtypes.txt:1936-1939`). The engine builds a
fresh global table and copies only whitelisted names into it
(`src/script/cpp_api/s_security.cpp:122-336`):

- Full copies: `coroutine`, `string`, `table`, `math`, `bit` (`:155-159`) —
  copies, so patching `string.format` cannot reach the insecure env; also the
  `""` string metatable is replaced (`:111-119`).
- `io` keeps only `close/flush/read/type/write`; `open/input/output/lines` are
  path-checked wrappers (`:166-172, 276-279`). **No `io.popen`.**
- `os` keeps only `clock/date/difftime/getenv/time`; `remove/rename/setlocale`
  are wrapped. **`os.execute`, `os.exit`, `os.tmpname` are gone** (`:173-179`).
- `debug` keeps `gethook/traceback/upvalueid/sethook/debug`, wrapped
  `getinfo`; `getlocal`, `getupvalue`, `setmetatable`, `getregistry` are gone
  (`:180-186`).
- `package` keeps only `config/cpath/path/searchpath`; **`require()` is
  disabled outright**, not path-restricted (`:1024-1028`).
- `jit` is trimmed to `arch/flush/off/on/opt/os/status/version/version_num`
  (`:193-203`) — no `jit.util`, no `jit.attach`.
- `load`/`loadstring`/`loadfile`/`dofile` are wrapped and **refuse Lua
  bytecode** (`:657-666`).
- Path rules (`:824-897`): **read** access to `builtin/`, the game dir and
  *all* mod dirs (not just your own); **read/write** in the world dir and the
  mod-data dir, except `worldmods/`, the world's `game/`, any `.git/` path and
  the settings file. So `dofile(core.get_modpath("grug_core").."/x.lua")` is
  fine; reading a sibling mod's file is technically allowed too.
- `core.request_insecure_environment()` needs `secure.trusted_mods` and only
  works from the mod's main scope at init time (`doc/lua_api.md:8292-8300`).
  **We never use it.**

## Do-not-write checklist

Every "write instead" below is plain 5.1 and runs on both builds.

1. No `goto` / `::labels::` — LuaJIT-only. Write instead: `break` out of an
   `if`, or restructure into a helper function with an early `return`.
2. No `\u{...}`, `\x..`, `\z` string escapes — LuaJIT-only. Write instead:
   the UTF-8 bytes literally in the source (`"§"`), or `string.char(0xC2, 0xA7)`;
   decimal escapes like `"\65"` are 5.1 and fine.
3. No `table.unpack` / `table.pack` / `rawlen` / `__len` on tables /
   `__pairs` — these need `LUAJIT_ENABLE_LUA52COMPAT`, which we cannot
   assume. Write instead: `unpack(t, 1, n)`, `#t` (arrays without holes),
   and track counts explicitly in a field (`t.n = n`).
4. No `table.move`, `coroutine.isyieldable`, `math.type`, `math.tointeger`,
   `utf8.*` — LuaJIT/5.3-only. Write instead: `table.insert_all` (engine
   helper) or an index loop; `x % 1 == 0` for the integer test.
5. No `//`, no `&`/`|`/`~`/`<<`/`>>` — write instead `math.floor(a / b)` and
   `bit.band/bor/bxor/bnot/lshift/rshift(a, b)` (32-bit). No integers above
   2^53−1.
6. No `require`, `io.popen`, `os.execute`, `os.exit`, no bytecode loading —
   blocked by the sandbox.
7. No `==` between vectors unless both sides came from `vector.*`; use
   `vector.equals`. No `#vec`; use `vector.length`.
8. No `core.serialize` on userdata/`ItemStack`/entities, and never
   `core.deserialize` on player-supplied strings.
9. No globals except the single mod table, assigned at file top level
   (strict.lua warns otherwise). Use `core.global_exists` for probing.
10. No reliance on `core.after` for precise timing; it is globalstep-bound.
11. No upvalue capture in `core.handle_async` functions; no `core.get_node`
    or player access in async/mapgen environments.
12. Always `core.*`, never `minetest.*`.

## Verifying a change

### The right interpreter: `tools/bin/luac51`, not `luajit`

**`luajit -e 'assert(loadfile(f))'` does NOT prove 5.1 compatibility.**
LuaJIT is a *superset*: it accepts exactly what the fallback build rejects.
Run `tools/build_lua51.sh` once per machine — it compiles the **engine's
own bundled PUC Lua 5.1.5** out of `reference_projects/luanti/lib/lua/src`
(no package, no network, only a C compiler) into `tools/bin/lua51` and
`tools/bin/luac51`. That parser *is* the fallback build's parser.

```sh
find mods/*/grug_* -name '*.lua' | xargs tools/bin/luac51 -p   # syntax gate
tools/bin/luac51 -l -p <file> | grep SETGLOBAL                 # global writes
tools/bin/lua51 tools/biomecheck/dump_biomes.lua > biomes.csv  # stub tools
```

`luac51 -p` parses without emitting bytecode; `-l -p` lists opcodes, so
`SETGLOBAL` is the plain-5.1 equivalent of `luajit -bl … | grep GSET` for
the strict.lua check — expect exactly one line, the mod table.

### Escapes are a *silent* divergence — only grep finds them

Neither parser errors on `\x`/`\u{}`/`\z`: Lua 5.1 keeps unknown escapes as
literal characters, so the same source means different things per build.
Measured, same file, both interpreters:

| source | LuaJIT | PUC 5.1.5 |
| --- | --- | --- |
| `"\x41"` | `A` (1 byte) | `x41` (3 bytes) |
| `"\u{41}"` | `A` | `u{41}` |
| `"a\z  b"` | `ab` (2) | `az  b` (5) |

An aarch64 player would see the literal text `u{41}` in the HUD, with no
error anywhere. `goto` at least fails loudly under `luac51`; these do not.

### The grep sweeps

Plain-5.1 conformance beyond syntax is checked by **grep**, against our own
mods only (`mods/*/grug_*`; `mods/BASE/*` and `mods/ENTITIES/mobs` are
vendored upstream code — see VENDOR.md — and legitimately use `minetest.*`):

```sh
# 1. goto / labels
grep -rnE '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' mods/*/grug_* --include=*.lua
# 2. LuaJIT-only string escapes
grep -rnE '\\u\{|\\x[0-9A-Fa-f]|\\z' mods/*/grug_* --include=*.lua
# 3. 5.2+/5.3 stdlib
grep -rnE 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' mods/*/grug_* --include=*.lua
# 4. integer division / bitwise operator syntax
grep -rnE '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' mods/*/grug_* --include=*.lua
# 5. sandbox-blocked calls and the wrong namespace
grep -rnE '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' mods/*/grug_* --include=*.lua
```

Sweeps 1 and 4 also match prose in comments (`|` in a design-doc table row,
C++ `Class::method` references) — read each hit, do not just count them.
Zero hits outside comments is the passing state.

### Interpreter and test strategy

LuaJIT is the preferred interpreter for as much development and exhaustive
iteration as a harness supports. It is substantially faster on the large
deterministic WP40 oracles, which makes complete search-space checks practical
while code and fixtures are still changing. That speed does **not** make
LuaJIT a compatibility gate: it remains a superset of the language accepted by
the fallback build.

The operating principle, decided 2026-08-16: **plain PUC 5.1 runs only where
it is the language contract — the static `luac51`/grep gates, defined
conformance and KAT gates, and the comprehensive final rounds — or where the
runtime is trivially short. LuaJIT owns everything else.** Consequently every
new harness with non-trivial runtime must support interpreter selection (the
`WP40_LUA_BIN` pattern) and must default to LuaJIT; an expensive runner
hardwired to PUC is a defect, not a conservative choice.
`run_t2_s1_authority.sh` was the live example — 111 s hardwired PUC against
21 s under LuaJIT, measured and fixed the day the principle was written down.

Use these layers together, in this order:

1. **Every Lua change:** run `tools/bin/luac51 -p`, inspect `SETGLOBAL` for
   changed mod files, and run all five grep sweeps above. These checks are
   mandatory even when every executable test uses LuaJIT.
2. **Development and exhaustive checks:** run the complete applicable search,
   seed corpus, geometry scan or other expensive suite under LuaJIT whenever
   the harness supports selecting it.
3. **Intermediate milestones:** run targeted representative KATs under the
   vendored PUC Lua 5.1 and compare their canonical artifacts or digests
   byte-for-byte with the LuaJIT results. Choose cases that exercise the
   changed arithmetic, control flow and boundary conditions; do not replace
   this with a second exhaustive serial run.
4. **Comprehensive WP40 PUC rounds:** reserve the full, expensive PUC suites
   for T2-final and T9-final. Split independent seed ranges or test groups into
   parallel processes, then verify exact coverage and canonical merged
   evidence fail-closed.
5. **Review:** a reviewer does not automatically duplicate an identical long
   PUC run. The reviewer checks the immutable input/output artifacts, logs,
   interpreter evidence and hashes, and runs focused independent PUC KATs.
   For WP40 outside T2-final and T9-final, missing evidence or a finding blocks
   the milestone and must be closed with targeted PUC KATs and newly bound
   immutable evidence; it never authorizes another comprehensive PUC round.
6. **Engine fallback:** a real fallback-engine runtime test remains a separate
   release/runtime gate. Neither standalone interpreter has Luanti's
   `builtin/`, sandbox or `core.*`, so offline equality cannot replace it.

The vendored `tools/bin/lua51` and `tools/bin/luac51` therefore remain the
plain-5.1 authority, but they are used deliberately: the parser and static
checks on every change, representative executable conformance at milestones,
and comprehensive executable rounds at the defined final gates. LuaJIT owns
the high-volume feedback loop, not the language contract.
