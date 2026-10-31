# Distinctness measurements

CIE76 ΔE: sRGB → linear RGB → CIE XYZ D65 → Lab; compute the Euclidean distance at each matching pixel and average only where BOTH alpha values are 255. No alignment, resizing, compositing, or background pixels enter the metric. N is the number of shared opaque pixels. Shape differences are deliberately not scored. These numbers are a guide, never a threshold; judge the 16 px strips first.

Three closest pairs per scope and version. The gem scope contains all 14 items,
including minerals and both gem states; blocks have their own scopes.
Every pair is in `measurements.json` and the expandable preview tables.

| Scope | Version | Pair | ΔE | N |
|---|---|---|---:|---:|
| Metal bars | OLD | Tin Bar / Steel Bar | 2.96 | 107 |
| Metal bars | OLD | Silver Bar / Silversteel Bar | 6.19 | 107 |
| Metal bars | OLD | Iron Bar / Silversteel Bar | 10.20 | 107 |
| Metal bars | A | Tin Bar / Steel Bar | 8.36 | 115 |
| Metal bars | A | Tin Bar / Silversteel Bar | 10.91 | 115 |
| Metal bars | A | Tin Bar / Silver Bar | 14.27 | 115 |
| Metal bars | B | Tin Bar / Steel Bar | 9.27 | 137 |
| Metal bars | B | Tin Bar / Silversteel Bar | 10.58 | 137 |
| Metal bars | B | Tin Bar / Silver Bar | 14.16 | 137 |
| Jewellery settings | OLD | Setting Iron / Setting Copper-inlaid Steel | 4.55 | 107 |
| Jewellery settings | OLD | Setting Tin / Setting Iron | 6.35 | 107 |
| Jewellery settings | OLD | Setting Copper-inlaid Steel / Setting Gold-filigreed Abyssal Steel | 10.26 | 107 |
| Jewellery settings | A | Setting Tin / Setting Copper-inlaid Steel | 12.83 | 95 |
| Jewellery settings | A | Setting Tin / Setting Iron | 16.01 | 95 |
| Jewellery settings | A | Setting Iron / Setting Copper-inlaid Steel | 18.25 | 104 |
| Jewellery settings | B | Setting Tin / Setting Copper-inlaid Steel | 11.50 | 105 |
| Jewellery settings | B | Setting Tin / Setting Iron | 18.61 | 97 |
| Jewellery settings | B | Setting Iron / Setting Copper-inlaid Steel | 21.44 | 97 |
| Gems and minerals | OLD | Cut Garnet / Cut Ruby | 3.85 | 88 |
| Gems and minerals | OLD | Cut Diamond / Quartz | 6.20 | 88 |
| Gems and minerals | OLD | Rough Garnet / Rough Ruby | 8.04 | 88 |
| Gems and minerals | A | Rough Garnet / Cut Garnet | 13.39 | 104 |
| Gems and minerals | A | Rough Jade / Cut Jade | 13.76 | 95 |
| Gems and minerals | A | Rough Sapphire / Cut Sapphire | 17.72 | 92 |
| Gems and minerals | B | Rough Jade / Cut Jade | 17.13 | 91 |
| Gems and minerals | B | Rough Garnet / Cut Garnet | 19.46 | 110 |
| Gems and minerals | B | Rough Garnet / Rough Ruby | 19.66 | 124 |
| Gems and minerals | C | Rough Jade / Cut Jade | 17.24 | 103 |
| Gems and minerals | C | Rough Ruby / Cut Ruby | 18.44 | 88 |
| Gems and minerals | C | Rough Garnet / Cut Garnet | 20.11 | 107 |
| Gems and minerals | D | Rough Jade / Cut Jade | 14.73 | 103 |
| Gems and minerals | D | Rough Ruby / Cut Ruby | 17.03 | 86 |
| Gems and minerals | D | Rough Garnet / Cut Garnet | 18.76 | 107 |
| Gems and minerals | FINAL | Rough Garnet / Cut Garnet | 9.47 | 147 |
| Gems and minerals | FINAL | Rough Jade / Cut Jade | 12.93 | 142 |
| Gems and minerals | FINAL | Rough Ruby / Cut Ruby | 16.06 | 116 |
| Metal storage blocks | OLD | Tin Block / Steel Block | 3.02 | 256 |
| Metal storage blocks | OLD | Iron Block / Silver Block | 5.12 | 256 |
| Metal storage blocks | OLD | Iron Block / Silversteel Block | 5.53 | 256 |
| Metal storage blocks | A | Tin Block / Steel Block | 10.91 | 256 |
| Metal storage blocks | A | Tin Block / Silversteel Block | 11.87 | 256 |
| Metal storage blocks | A | Silver Block / Silversteel Block | 17.13 | 256 |
| Metal storage blocks | B | Tin Block / Steel Block | 10.96 | 256 |
| Metal storage blocks | B | Tin Block / Silversteel Block | 11.61 | 256 |
| Metal storage blocks | B | Silver Block / Silversteel Block | 17.28 | 256 |
| Gem and crystal storage blocks | OLD | Garnet Block / Ruby Block | 8.04 | 88 |
| Gem and crystal storage blocks | OLD | Sapphire Block / Abyssal Crystal Block | 25.74 | 88 |
| Gem and crystal storage blocks | OLD | Jade Block / Diamond Block | 26.46 | 88 |
| Gem and crystal storage blocks | A | Sapphire Block / Abyssal Crystal Block | 27.11 | 256 |
| Gem and crystal storage blocks | A | Garnet Block / Ruby Block | 30.65 | 256 |
| Gem and crystal storage blocks | A | Jade Block / Diamond Block | 44.24 | 256 |
| Gem and crystal storage blocks | B | Sapphire Block / Abyssal Crystal Block | 26.99 | 256 |
| Gem and crystal storage blocks | B | Garnet Block / Ruby Block | 30.55 | 256 |
| Gem and crystal storage blocks | B | Jade Block / Diamond Block | 44.60 | 256 |
| Gem and crystal storage blocks | C | Sapphire Block / Abyssal Crystal Block | 27.59 | 256 |
| Gem and crystal storage blocks | C | Garnet Block / Ruby Block | 30.59 | 256 |
| Gem and crystal storage blocks | C | Jade Block / Diamond Block | 45.32 | 256 |
| Gem and crystal storage blocks | D | Sapphire Block / Abyssal Crystal Block | 27.35 | 256 |
| Gem and crystal storage blocks | D | Garnet Block / Ruby Block | 30.50 | 256 |
| Gem and crystal storage blocks | D | Jade Block / Diamond Block | 44.83 | 256 |
| Gem and crystal storage blocks | FINAL | Sapphire Block / Abyssal Crystal Block | 27.35 | 256 |
| Gem and crystal storage blocks | FINAL | Garnet Block / Ruby Block | 30.50 | 256 |
| Gem and crystal storage blocks | FINAL | Jade Block / Diamond Block | 44.83 | 256 |

## Rough versus cut

| Gem | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE | Final ΔE |
|---|---:|---:|---:|---:|---:|---:|
| Citrine | 31.73 | 20.46 | 34.10 | 27.40 | 20.39 | 17.39 |
| Jade | 28.85 | 13.76 | 17.13 | 17.24 | 14.73 | 12.93 |
| Garnet | 41.32 | 13.39 | 19.46 | 20.11 | 18.76 | 9.47 |
| Sapphire | 38.10 | 17.72 | 22.42 | 24.15 | 24.17 | 17.14 |
| Ruby | 38.96 | 17.79 | 31.28 | 18.44 | 17.03 | 16.06 |
| Diamond | 22.89 | 24.29 | 31.12 | 31.96 | 24.01 | 24.88 |

## Known weak pairs, before and after

| Pair | Old ΔE | A ΔE | B ΔE | C ΔE | D ΔE | Final ΔE |
|---|---:|---:|---:|---:|---:|---:|
| Tin Bar / Steel Bar | 2.96 | 8.36 | 9.27 | — | — | — |
| Silver Bar / Silversteel Bar | 6.19 | 17.76 | 16.98 | — | — | — |
| Iron Bar / Silversteel Bar | 10.20 | 31.55 | 32.33 | — | — | — |
| Copper Bar / Bronze Bar | 17.84 | 16.01 | 16.63 | — | — | — |
| Rough Garnet / Rough Ruby | 8.04 | 31.31 | 19.66 | 31.31 | 31.31 | 32.01 |
| Cut Garnet / Cut Ruby | 3.85 | 32.63 | 31.85 | 32.73 | 33.11 | 33.11 |
| Quartz / Cut Diamond | 6.20 | 31.76 | 28.12 | 29.66 | 34.77 | 33.77 |
