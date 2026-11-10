# Branding — the Grudgelands crest

The user-approved logo is a battle-worn iron shield with bronze half-heads:
The Accord's hart on slate blue and The Throng's boar on wine red, separated
by a fiery fissure. Concept 4 and its final polish were approved on 2026-11-10.
The [media record](../../menu/LICENSE-media.md) owns credit and licensing.

## Files and sizes

| File | Dimensions | Intended use |
|---|---|---|
| `grudgelands_icon.png` | 1254 × 1254 | Unmodified approved RGBA master; keep for future exports |
| `exports/plain_<N>.png` | 16, 32, 48, 64, 96, 128, 256, 512, 1024 square | Transparent icons, website branding and general reuse |
| `exports/avatar_512.png`, `exports/avatar_1024.png` | 512 / 1024 square | Opaque charcoal profile pictures with room for a circular crop |
| `exports/favicon.ico` | 16, 32, 48 frames | Website favicon |
| `../../menu/icon.png` | 96 × 96 | Same bytes as `exports/plain_96.png`; also used by the README |
| `generation.json` | — | Approval, generation prompt, input provenance and master checksum |
| `source/concept-4.png` | 1254 × 1254 | Retained input to the final polish; not a production logo |

Prefer 1024 for a large website logo or a profile-picture upload, 512 for
smaller branding, and the matching small PNG for a fixed-size UI icon.
These are general-purpose exports, not platform-specific upload requirements.
Use the transparent logo over a chosen background; use the avatar files when
the destination expects a filled square or crops pictures to a circle.

The master has real alpha. Plain exports trim transparent margins, preserve
aspect ratio and fit the shield inside 90% of a square. Avatars fit it inside
75% of a square over `#181b20`. There is no extra sharpening, saturation or
redrawing. At 32 px, the outline, faction colours and fiery split carry the
identity; fine facial details are clearer at 64 px and above.

No upscaled 2048/4096 master or traced SVG is supplied: the approved source is
raster art at 1254 px. Preserve it rather than treating interpolation as new detail.

## Reproduce

Requires ImageMagick 7; run from the repository root:

```sh
bash tools/branding/make_icons.sh tools/branding/grudgelands_icon.png /tmp/grudgelands-icons
cmp /tmp/grudgelands-icons/plain_96.png menu/icon.png
diff -qr tools/branding/exports /tmp/grudgelands-icons
```

To refresh the tracked exports intentionally:

```sh
bash tools/branding/make_icons.sh tools/branding/grudgelands_icon.png tools/branding/exports
cp tools/branding/exports/plain_96.png menu/icon.png
```

Export PNGs omit timestamps and metadata; the approved master is copied
byte-for-byte. Reproduction is checked with ImageMagick 7 on this workstation;
different ImageMagick versions may produce different encodings or resampling.
The old black-background source, hand mask and automatic mask helper are
retired; their provenance remains in Git history (before the logo refresh).

## Acceptance

The user accepted the final full-size logo and the light/dark, 32/64/128 px
previews before integration on 2026-11-10. This is a compatible artwork-only
change; no game version, world state or gameplay code changes.
