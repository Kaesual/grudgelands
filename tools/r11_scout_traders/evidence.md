# Round 11 Scout trader implementation evidence

Base: `6bd8a6b8`

The bounded LuaJIT KAT loaded the production stock and trade modules and passed
all six brackets across 400 consecutive hourly rotations per bracket. It
also activated a synthetic roller at the production `roll_enchants` seam,
checked its full call contract, and drove the real formspec callback through a
successful filtered purchase and a rejected stale-hour purchase:

```text
r11 scout trader stock KAT: ok
```

Static validation passed for the three changed production modules and the KAT:

- plain Lua 5.1 parsing passed;
- production modules emitted zero `SETGLOBAL` opcodes;
- the fixture's nine intentional global substitutions are restored before it
  returns;
- all five source sweeps had no changed-code findings (the three changed-scope
  sweep-4 hits are comment prose);
- the tree-wide sweep output contains only pre-existing comments, string data
  and the two comments that explain forbidden escape syntax;
- `git diff --check` passed.

No PUC runtime was run, as required by the approved Round 11 lane plan.
