# Round 13 combined native integration

Native Astra implementation/verification lane, 2026-09-21. This package owns
only the exact Basics catalog and disposable integration tools. Independent
review and the coordinator's joint commit remain separate. No user world,
push, sync or PUC runtime was used.

## Catalog reconciliation

The capture probe enumerates actual native craft registrations. Its disposable
`catalog-capture-only.patch` skips only presentation binding in the staged copy;
it is capture tooling, not validation evidence. Startup preload scheduling is
disabled to keep both native runs bounded. `rebuild_catalog.py` preserves every
unchanged route's original starter/main-material policy verbatim, allows only
the specified additions/removals and applies the three approved ownership changes.
The engine's empty-output hand/toolrepair sentinel is excluded exactly as the
production book excludes it.

The resulting catalog contains **656 exact routes**: 23 added (21 Alchemy
mixtures, two Stone Hoe patterns), 197 retired weapon/Imbue/Temper routes removed,
and Bread/Cooked Meat/Cooked Fish reassigned to general starter routes. Exact
changes are in `evidence/catalog-changes.json`. Rebuilding the already updated
catalog is idempotent; its reported delta is naturally empty on a second pass.

Capture command:

```sh
KEEP=1 PROBE=tools/r13_integration/catalog_probe \
GAME_PATCH=tools/r13_integration/evidence/catalog-capture-only.patch \
tools/luanti_headless.sh 45
python3 tools/r13_integration/rebuild_catalog.py <captured-server.log>
```

## Strict combined validation

The final run uses **no staged patch** and retains production startup catalog
binding. Native Flatpak Luanti, LuaJIT 2.1.1784272936:
**1,871 assertions passed**, including:

- all 656 strict catalog routes and all 456 individually identified book
  operations, including fixed values, family and minimum item tier;
- five actual station Apply transactions: suffix, prefix and replacement on a
  worn Bronze weapon, plus both channels on an authored-special trinket;
- exact preview/output equality, material debit and one profession credit;
  identical/duplicate-stat refusals preserve inputs and progression;
- level-one Bronze eligibility before initialization and after enchanting;
  exact wear, remainder and concrete item identity preservation;
- real ilvl-75 armor/shield scaling and equipment aggregation: 71 + 71 base,
  calibrated Protection rating 298.65, emergency rating 313.65;
- broken quiver cannot supply ammunition or accept refills, while its contents
  remain retrievable and usable from main inventory;
- personal furnace settlement during `allow_take`: a stale grain request at
  time 105 is refused after processing from time 100; a fresh bread request at
  the same time succeeds and transfers the exact finished stack.

```sh
KEEP=1 PROBE=tools/r13_integration/probe tools/luanti_headless.sh 45
```

Evidence: `strict-native.log`, `strict-launch.log`, `native-inputs.sha256`,
`static.log`. All 42 changed production files matched the staged native bytes
when the receipt was generated. The four owned Lua files pass the plain-5.1
parser, SETGLOBAL inspection (no global declarations) and all five sweeps.

The probe uses actual engine ItemStack, detached inventories, node metadata,
recipe catalogs and production station callbacks. Player objects, lookup, UI,
protection and talent/status inputs for the numerical calibration are controlled
adapters. Inventory moves/callback order are explicitly driven; this is not a
client/network, graphical interface or real-character equipment-notifier test.
The coordinator separately runs the wider station and restart fixture.

## User runtime plan

Use a fresh level-one character and Bronze weapon. At a shared Forge, apply a
suffix, add a prefix and replace it; compare preview, material consumption,
progression and wear. Repeat with crafted jewelry and verify its special.
Check all selectable named recipes in profession books. With two clients verify
shared input visibility, qualified previews and stale take refusal. Break a
filled quiver, retrieve its arrows, and verify broken refill/shoot restrictions.
