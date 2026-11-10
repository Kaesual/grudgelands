# Media Origin & Licenses (menu)

The game's menu icon and menu music. Luanti reads `<game>/menu/icon.png` for
the game bar of the main menu and plays `<game>/menu/theme.ogg` there
(`doc/lua_api.md` "Menu music"); header, background and footer images are not
part of this directory yet.

## `icon.png` — CC0 1.0

The Grudgelands crest is a battle-worn iron shield split by a fiery fissure.
Bronze half-heads show The Accord's hart on slate blue and The Throng's boar
on wine red. The user approved concept 4 and its final polish on 2026-11-10.

* Art direction, selection and rights holder: Jan Hangebrauck.
* Generated and polished with OpenAI's built-in image generation tool, with
  prompts prepared by Codex from the user's direction and repository heraldry.
  The tool did not expose an underlying image-model identifier.
* Licence: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  (public-domain dedication), continuing the project's branding licence for
  the source, retained concept and derivatives.
* Source: [the approved 1254×1254 transparent PNG](../tools/branding/grudgelands_icon.png),
  preserved byte-for-byte. The final edit's input is retained as
  [concept 4](../tools/branding/source/concept-4.png); the
  [generation record](../tools/branding/generation.json) contains its prompt,
  lineage, original references and the master checksum.
* Derivation: ImageMagick trims transparent margins, scales with Lanczos and
  centres the shield within 90% of a transparent square. `menu/icon.png` is
  byte-identical to the 96×96 `exports/plain_96.png`. No contrast or colour
  adjustment is applied. The profile-picture variants use 75% over charcoal.
* Reproduction and all export sizes: [branding kit](../tools/branding/README.md).
  The old Z-Image source and its GIMP cutout mask are retired; their original
  credit and licence record remain in Git history before the logo refresh.

## `theme.ogg` — CC0 1.0

"Fantasy Orchestral Theme" by joth
([OpenGameArt](https://opengameart.org/content/fantasy-orchestral-theme),
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), licence checked
on the page 2026-10-04), the user's pick for the main menu (Round 34, R32 M6).
The same file as `mods/CORE/grug_ambience/music/grug_music_fantasy_orchestral_theme.ogg`:
converted to Ogg Vorbis (stereo, q1) and levelled to -18 LUFS; no cut.

## AI disclosure

This image is AI-generated. ContentDB's content policy (§4.3 as of 2026-09-16)
requires packages with AI-generated media to set the AI-generated flag on the
package page and to credit the tool in the licence file; this file is that
credit, and the flag is listed under the first-public-release gates in
`BACKLOG.md`.
