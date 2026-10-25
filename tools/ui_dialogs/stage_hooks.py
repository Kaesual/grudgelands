#!/usr/bin/env python3
"""Expose private production renderers only in the disposable staged game."""
import difflib
import pathlib
import sys
repo = pathlib.Path(sys.argv[1])
hooks = {
 'mods/PLAYER/grug_classes/selection.lua': {'creation': 'create_formspec', 'preparing': 'loading_formspec'},
 'mods/PLAYER/grug_home/innkeeper.lua': {'innkeeper': 'form'},
 'mods/PLAYER/grug_home/waypoints.lua': {'waystone': 'function(player) return form(player, by_id.dawnmere) end'},
 'mods/PLAYER/grug_guild/lift.lua': {'lift': 'form'},
 'mods/PLAYER/grug_housing/manager.lua': {'housing': 'formspec'},
 'mods/ITEMS/grug_repair/providers.lua': {'repair': 'form'},
 'mods/PLAYER/grug_housing/stone_form.lua': {'stone': 'main_formspec', 'stone_inventory': 'ensure_inventory', 'stone_confirm': 'confirm_formspec'},
}
for path, exports in hooks.items():
    old = (repo / path).read_text()
    addition = '\n-- Disposable capture seam; not installed or committed as runtime code.\ngrug_core.capture = grug_core.capture or {}\n'
    for name, expr in exports.items():
        addition += f'grug_core.capture.{name} = {expr}\n'
    new = old.rstrip()[:-3] + addition + "\nend\n" if path.endswith(("stone_form.lua", "manager.lua")) else old + addition
    sys.stdout.writelines(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/'+path, tofile='b/'+path))
