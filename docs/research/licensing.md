# Licensing Research — Grudgelands

Researched 2026-08-06. Sources: gnu.org, creativecommons.org, ContentDB (content.luanti.org),
minetest_game / Mineclonia / VoxeLibre repositories.

## 1. Recommendation summary

- **Code license: GPL-3.0-or-later** ("GPLv3 or any later version"). This accepts MIT,
  Apache-2.0, LGPL-2.1 (any variant), LGPL-3.0, GPL-2.0-or-later, GPL-3.0-only/or-later,
  WTFPL, CC0 code — everything we plan to reuse **except GPL-2.0-only** code.
- **Media: keep every asset under its original license, per file** (CC0 / CC BY / CC BY-SA
  3.0 or 4.0), documented in per-mod `LICENSE-media.md`. Do **not** relicense media to GPL —
  this is standard Luanti practice (minetest_game, Mineclonia, VoxeLibre all do it this way).
- **File structure** (Mineclonia model):
  - `LICENSE.txt` — full GPLv3 text (repo root).
  - `README.md` — short "Licensing" section: "Code: GPL-3.0-or-later, media: see per-mod
    LICENSE-media.md; mods without their own license file inherit the game license."
  - `mods/<mod>/LICENSE-media.md` — per-file table (we already use this pattern).
  - `CREDITS.md` — all upstream projects and contributors (one line each).
- **ContentDB fields**: code license `GPL-3.0-or-later`, media license = the most
  restrictive media license in use (likely `CC-BY-SA-3.0` or `CC-BY-SA-4.0`).

## 2. Compatibility matrix (target: our GPL-3.0-or-later game)

| Source license | Code reuse? | Media reuse? | Conditions |
|---|---|---|---|
| MIT/Expat | Yes | Yes | Keep copyright + license notice |
| Apache-2.0 | Yes (GPLv3 only, **not** GPLv2) | Yes | Keep NOTICE/attribution |
| LGPL-2.1 (only *or* or-later) | Yes | — | §3 allows conversion to "GPLv2 or later" → GPLv3-compatible; GNU license list: "compatible with GPLv2 and GPLv3" |
| LGPL-3.0 | Yes | — | Convertible to GPLv3 (LGPLv3 §2) |
| GPL-2.0-or-later | Yes | Yes | Combination is conveyed under GPLv3 |
| **GPL-2.0-only** | **No** | No | GPLv2-only and GPLv3 are incompatible — avoid / ask author / replace |
| GPL-3.0-only | Yes | Yes | Combined work effectively GPLv3 (drops our "or later" for that combo) |
| "GPL" no version | Yes | Yes | GPL §9/§14: recipient may choose any published version → treat as any-version, but confirm with author |
| CC0-1.0 | Yes | Yes | None (credit anyway, good practice) |
| CC BY 3.0/4.0 | (avoid for code) | Yes | Attribution required |
| CC BY-SA 3.0 | No (not GPL-compatible) | Yes, **kept under CC BY-SA 3.0** | Attribution + ShareAlike; adaptations of the asset stay BY-SA 3.0 (or 4.0 via the "later version" clause) |
| CC BY-SA 4.0 | Rarely needed | Yes, kept under CC BY-SA 4.0 | Attribution + SA; *optionally* adaptations may be released under GPLv3 (one-way, see §3.2) |
| CC BY-NC / BY-ND (any version) | **No** | **No** | Non-free; ContentDB marks them non-FOSS; avoid or ask author to relicense |
| WTFPL | Yes | Yes | GPL-compatible per FSF; permitted but discouraged on ContentDB |
| No license stated | **No** | **No** | All rights reserved by default — ask author or replace |

## 3. Findings per question

### 3.1 Code

- **GPLv2-only vs GPLv2-or-later**: "or later" lets us take the code under GPLv3;
  GPLv2-only forbids adding GPLv3's extra conditions, so GPLv2-only code cannot be combined
  into a GPLv3 work (GNU FAQ, compatibility matrix:
  <https://www.gnu.org/licenses/gpl-faq.en.html#AllCompatibility> — the GPLv3 x GPLv2-only
  cell is "NO"; GPLv2-or-later is "OK: convey under GPLv3").
- **How common is GPLv2-only?** ContentDB API (2026-08): **35 packages declare code
  `GPL-2.0-only`**, 15 declare `GPL-2.0-or-later`. Real examples of GPL-2.0-only:
  `mt-mods/unifieddyes` (VanessaE lineage), `Wuzzy/tutorial`, `sofar/stamina`,
  `joe7575/towercrane`, `sofar/skybox`. So the trap is real but a small minority.
- **Checked authors**: Sokomine — `travelnet` GPL-3.0-only (code+media), `cottages`
  GPL-3.0-only + CC-BY-SA-3.0 media. VanessaE mods (now maintained by mt-mods) —
  `pipeworks` and `homedecor_modpack` are LGPL-3.0-only code + CC-BY-SA-4.0 media
  (fine for us), but `unifieddyes` is GPL-2.0-only (code and media!).
- **LGPL-2.1-only → GPLv3: yes.** LGPL-2.1 §3 explicitly permits relicensing any copy
  under "ordinary GNU GPL, version 2 … or later"; the GNU license list states LGPL-2.1 is
  "compatible with GPLv2 and GPLv3" (<https://www.gnu.org/licenses/license-list.en.html>).
- **minetest_game**: code **LGPL-2.1-or-later** ("version 2.1 of the License, or (at your
  option) any later version"), media **CC BY-SA 3.0**
  (<https://github.com/luanti-org/minetest_game/blob/master/LICENSE.txt>). → code usable.
- **mobs_redo** (`TenPlus1/mobs`): **MIT** for both code and media (ContentDB). → usable.
- **Apache-2.0**: compatible with GPLv3, *not* with GPLv2 (patent-termination and
  indemnification clauses) — another reason to be GPLv3+, not GPLv2+.

### 3.2 Media

- **CC BY-SA 4.0 → GPLv3, one-way** (declared by Creative Commons, Sept 2015:
  <https://wiki.creativecommons.org/wiki/ShareAlike_compatibility:_GPLv3>): you may release
  an *adaptation* of BY-SA 4.0 material under GPLv3. One-way only (GPL → BY-SA is not
  allowed); applies **only to 4.0, not 3.0**; BY-SA attribution duties still apply, and the
  "source in modifiable form" GPL duty extends to the adapted media.
- **Do we need it?** No — if we keep each asset under its original CC license with
  attribution (the community standard), no relicensing is required. Game = aggregation of
  GPL code + CC media; each part carries its own license. The one-way compatibility is only
  a fallback if we ever want a single-license (all-GPLv3) distribution.
- **CC BY-SA 3.0 constraint**: 3.0 assets stay under 3.0 (or, for *adaptations*, may be
  upgraded to 4.0 via 3.0 §4(b) "later version" clause — and from 4.0 an adaptation could
  then go GPLv3; a chain, only for modified assets). Much old Minetest media is BY-SA 3.0
  (minetest_game media, Sokomine's cottages media).
- **VoxeLibre / Mineclonia**: both list media `CC-BY-SA-4.0` on ContentDB. Mineclonia's
  `LEGAL.md` confirms: textures = **Pixel Perfection by XSSheep + "Legacy" update by Nova
  Wostra, CC BY-SA 4.0**; some CC BY 4.0 (armor trims), CC0 (menu), and unlabeled files
  default to CC BY-SA 3.0 (<https://codeberg.org/mineclonia/mineclonia>).
- **Attribution files must contain** (CC BY[-SA] 3.0/4.0 §3(a)): creator/attribution name,
  copyright notice if supplied, license name + URL, link to the original source, and an
  **indication whether we modified the file**. Per file: `file | author | source URL |
  license | modified? (what)`.

### 3.3 ContentDB

- Policy (<https://content.luanti.org/policy_and_guidance/>): packages **must** use an
  FSF- or OSI-approved FOSS license; a `LICENSE(.txt/.md)` file crediting **all** used
  resources is required; code and media licenses are declared separately per package;
  WTFPL is allowed but discouraged (no warranty disclaimer); non-free (NC/ND) packages are
  flagged non-FOSS and are being phased out. Publishing imposes nothing beyond honest
  license declaration and complete crediting — no relicensing to ContentDB.

### 3.4 Structure (see §1)

Mineclonia's proven layout: `LICENSE.txt` (GPLv3 text) + `LEGAL.md` (media overview) +
`CREDITS.md` + per-mod author/license documentation; "mods without an explicit license
inherit the game code license" stated once at top level. We keep our existing per-mod
`LICENSE-media.md` pattern and add `CREDITS.md`.

## 4. Risks and handling

| Trap | Handling |
|---|---|
| **GPL-2.0-only code** (e.g. unifieddyes) | Do not merge into our codebase. Ask author for "or later"/relicense; else replace or find an LGPL/MIT alternative |
| **NC / ND media** in mods or texture packs | Never ship. Ask author for CC BY(-SA); else replace (Pixel Perfection-style CC BY-SA 4.0 packs exist) |
| **No license stated** (old forum mods) | All rights reserved by default — unusable. Ask author; else rewrite/replace |
| **Skin databases** (e.g. Minecraft skin sites) | Licensing almost always unclear/proprietary. Only use skins with recorded author + free license (CC0/CC BY); build our own set otherwise |
| **WTFPL** | Legally fine (GPL-compatible), ContentDB-discouraged; treat as permissive, note it in credits, don't adopt it ourselves |
| **"GPL" without version** | GPL §9 lets us pick a version, but confirm intent with the author and record the answer |
| **CC BY-SA version mixing** | Never claim 3.0 assets as 4.0 or GPL; keep the exact version per file; only adaptations may move 3.0→4.0 |
| **Mislabeled media** (uploader ≠ author) | Verify provenance (source URL of the *original*) before importing; if untraceable, replace |
