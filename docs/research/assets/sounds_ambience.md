# Research: Sounds & Ambience

Status: 2026-08-06 (three parallel scans: Luanti sound mods, external SFX
sources, music sources). Constraints: media reused per-file with
attribution; CC0/CC BY strongly preferred, CC BY-SA ok, **no NC/ND**.
Luanti ships media as loose files — "royalty-free" EULAs that forbid raw
file redistribution are unusable.

## Summary / top recommendations

1. **Ambience mod (TenPlus1)** — MIT code + ~35 per-file-licensed sounds
   (CC0/CC BY) covering nearly all six regions (day birds, wind
   variants, night crickets/owl/wolves, coyote, jungle frogs, cave
   drips). ⚠ Exactly one file must be excluded: `seagull 2` (CC BY-NC
   4.0). Harvest sounds + use its trigger logic as reference.
2. **minetest_game default sounds** — footsteps/dig/place set, 100%
   CC BY 3.0 + CC0, cleanest filler source (we ship it in BASE already).
3. **CC0 SFX packs** cover ~90% of combat/mob/UI needs: Kenney (RPG
   Audio, Impact Sounds, Interface/UI Audio), OGA "RPG Sound Pack"
   (artisticdude, 95 files incl. spell FX + growls), OGA "Monster Sound
   Effects Pack" (Ogrebane).
4. **Music**: Kevin MacLeod/incompetech and Scott Buckley (both CC BY
   4.0, mood-searchable orchestral catalogs) + OGA artists Matthew
   Pablo / Alexandr Zhelanov (CC BY 3.0/4.0, verify per track).
5. Rain/thunder is NOT in the ambience mod — source storm sounds from
   Freesound (CC0 filter).

## Luanti sound mods

| Name | Author | Code | Media | Harvestable | ⚠ |
|------|--------|------|-------|-------------|---|
| Ambience ([ContentDB](https://content.luanti.org/packages/TenPlus1/ambience/), [Codeberg](https://codeberg.org/tenplus1/ambience)) | TenPlus1 | MIT | per-file CC0/CC BY 3.0/4.0 | region ambience for all 6 regions | `seagull 2` is CC BY-NC — exclude |
| minetest_game `default` ([license.txt](https://github.com/luanti-org/minetest_game/blob/master/mods/default/license.txt)) | core devs | LGPL 2.1+ | CC BY 3.0 + CC0 | footsteps/dig/place full set | none |
| VoxeLibre sounds | VL team | GPLv3+ | mixed, per-mod | mob/env sounds | per-file audit needed — deprioritize |
| Scary Ambience / Cave Ambience | StarNinjas / Thresher | unverified | unverified | dark-forest/cave mood | ⚠ verify licenses before use |

## External SFX sources

| Source / Pack | License | Covers | ⚠ |
|---------------|---------|--------|---|
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 | melee hits, thuds, UI clicks/chimes | — |
| [OGA RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) (artisticdude) | CC0 | 95 WAVs: spells, sword clashes, NPC growls, UI | — |
| [OGA Monster Sound Effects Pack](https://opengameart.org/content/monster-sound-effects-pack) (Ogrebane) | CC0 | monster grunts/pain/death | — |
| [OGA 37 hits/punches](https://opengameart.org/content/37-hitspunches) | CC0 | melee impacts | 7z archive |
| [OGA Fantasy Sound Effects Library](https://opengameart.org/content/fantasy-sound-effects-library) (Little Robot Sound Factory) | CC BY 3.0 | dragon/goblin voices, spells, jingles | attribution + link |
| [OGA Spell Sounds Starter Pack](https://opengameart.org/content/spell-sounds-starter-pack) (p0ss) | CC BY-SA 3.0 | ~70 spell sounds | SA bookkeeping — consider skipping |
| [freesound.org](https://freesound.org) | per-file | anything (animal calls, storms, town ambience) | use license filter "Free Cultural Works" (CC0+CC BY only) |

## Music sources

| Source / Artist | License | Fits | ⚠ |
|-----------------|---------|------|---|
| [Kevin MacLeod / incompetech](https://incompetech.com/music/royalty-free/) | CC BY 4.0 | exploration, dark, city themes | MP3 → transcode .ogg |
| [Scott Buckley](https://www.scottbuckley.com.au/library/) | CC BY 4.0 (site-wide) | cinematic orchestral, long ambient | transcode .ogg |
| [Matthew Pablo (OGA)](https://opengameart.org/users/matthew-pablo) | CC BY 3.0 | orchestral fantasy ("Soliloquy", "Blackmoor Tides") | credit link requested; check per entry |
| [Alexandr Zhelanov (OGA)](https://opengameart.org/users/alexandr-zhelanov) | mostly CC BY 3.0/4.0 | epic/adventure, dark ambient | some tracks CC BY-SA — per-file |
| [Yubatake (OGA)](https://opengameart.org/users/yubatake) | mostly CC BY 3.0 | medieval/tavern | confirm per file |
| [OGA "CC0 Fantasy Music & Sounds"](https://opengameart.org/content/cc0-fantasy-music-sounds) | CC0 | filler stems | quality varies |
| ~~FreePD.com~~ | — | — | ⚠ shut down 2025 — do not plan around it |

Note: **OGA-BY 3.0** (seen on some OGA entries) = CC BY 3.0 minus the
anti-DRM clause — strictly more permissive; treat like CC BY in credits.
Traps: FMA, Pixabay Music and most itch.io "royalty-free" packs have NC
clauses or custom EULAs — unusable for loose-file distribution.

## Attribution & conversion workflow

- Per-file credits table (per mod `LICENSE-media.md`, see licensing.md):
  `filename | title | author | source URL | exact license+version |
  modifications ("converted to ogg", "trimmed")`.
- CC BY 3.0 vs 4.0 have different attribution wording — copy the version
  from each source page. MacLeod has a required credit format + generator
  on his licenses page.
- Freesound: account page `freesound.org/home/attribution/` auto-lists
  all downloads — direct input for the credits table.
- Conversion: `ffmpeg -i in.wav -c:a libvorbis -q:a 4 out.ogg`; prefer
  WAV sources over MP3; **mono** files for positional sounds in Luanti.
