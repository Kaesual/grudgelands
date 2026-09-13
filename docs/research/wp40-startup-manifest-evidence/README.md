# Startup manifest evidence

See [repair report](../wp40-startup-manifest-fix.md) for scope and review.
`engine-game.sha256` binds all production mod files in the two real-engine
smoke runs. `engine-invocation.txt` records the Flatpak command and version;
each seed folder contains its log, config and temporary worldmod. The worldmod
is test-only and was never copied into the shipped game.

`diagnostic-projection.txt` is from a separately instrumented disposable copy;
passing smoke runs use the unmodified game. `parity/` contains the real
constructor preflight, one PUC/LuaJIT compact pair and input stability proof.
Its output hash is `b08345fde4c238e1d497fb7d9d2034dc0d36be02cfe169be10ae421239bd0f23` (both files, 219 lines each).
Archived hash files retain original `/tmp` paths; copied bytes are unchanged.

To reproduce the constructor regression under LuaJIT:

```sh
chrt --idle 0 ionice -c3 luajit tools/wp40/r7/manifest_constructor_kat.lua "$PWD"
```

The normal `tools/wp40/quality/final_micro.sh` runner includes it before parity.
