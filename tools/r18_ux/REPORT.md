# Round 18 lane A implementation report

## Result

The equipment, trainer, inventory, Skills, Talents and quest clarity package is
implemented on `wp18-ux`.

- Weapon descriptions and the Character weapon-slot tooltip direct players to
  equip the weapon and use a hotbar combat skill. A rising-edge, three-second
  throttled control watcher explains attempts to use a raw hotbar weapon. It
  observes input only: item callbacks, pickup, NPC right-click behavior, equip
  state and all damage paths are unchanged.
- Trainer learning now reports a distinct successful event with Crafting/book
  guidance. Revisits show the known profession, tier and current-tier craft
  count. Cooking cannot be unlearned through the page, forged Unlearn, forged
  Confirm or the public state API. Primary professions require the displayed
  destructive confirmation; Cancel retains the profession and progression.
- Crafting starts with a Basics/book prompt. Skills explains icon deletion,
  entitlement recovery and the one-copy rule across main inventory, crafting
  and bags.
- The main-inventory top row is labeled and tinted as the Hotbar. Bags and
  Talents use `grug_inventory.selected_button_style(fieldname, selected)`, with
  tint plus a border/non-border cue, and no selection `>` prefix. The helper is
  independent of coordinate mode and is ready for the atlas consumer.
- Quest page, HUD objectives and reward labels use only the first description
  line. Turn-in settlement still compares item identity and therefore accepts
  qualifying worn tools unchanged.

## Verification

Development fixture:

```sh
tools/r18_ux/run.sh /tmp/grug-r18-ux
```

Expected digest:

```text
r18_ux_v1|trainer=success+known+confirm|cooking=protected|players=isolated|style=tint+border|quest=concise+wear_identity|raw_weapon=observed_only
```

The fixture executes real `grug_jobs/state.lua` and `trainers.lua` callbacks for
successful/rejected/forged operations, confirmation and cancellation, and two
player-local records. It also checks the shared style contract, concise quest
formatting, wear-independent turn-in identity, and that the raw-weapon hint does
not install or override item-use callbacks.

Additional checks: all changed Lua parses with the repository's plain-5.1
compiler; changed production files have no unexpected `SETGLOBAL`; all five
repository Lua source sweeps were inspected (hits are existing comments/data);
the Round 14 quest core fixture passes, including bag hand-in and player
isolation. Per the Round 18 contract, this lane ran no PUC runtime fixture; root
owns the single final PUC/LuaJIT digest pair after integration.

## Native GUI checks

Check all four class Character/Talents pages, each Bag selection, Crafting and
Skills text, Cooking and a primary trainer, a worn-tool quest objective, and a
raw weapon on the hotbar. Verify Hotbar labeling on the shared inventory pages
and confirm that ordinary dropped-item pickup and NPC right-click remain
unchanged while the raw-weapon hint is throttled.
