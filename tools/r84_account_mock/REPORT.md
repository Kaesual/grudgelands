# Round 84 · Account page

**Pick The Charter.** The crest frames the reward a new player will get. Beside it, one column leads from the readable web address through code creation to the highlighted field. After linking, the crest identifies the account and the wider column shows its rewards with a hint for using each one. **Village Road** uses the village panorama, a horizontal reward shelf and a left-to-right path from website to game. It gives the world more space and the code field less. [Open the offline pick page](index.html)

Both layouts use existing art. The Charter uses the opening crest. Village Road crops the human character-creation scene. Both use the inventory’s nine-slice plates, Arimo text and catalogue icons. A slate box supplies the fill that a native borderless field cannot draw. A visible address accompanies the client’s URL button. The builder can inspect every element’s position and size in the page’s **Builder’s coordinates & art** panel.

Each layout has ten PNGs covering unlinked, linked, confirmation, wrong and expired codes, three and four advertised rewards, an empty offer, a missing website field and an empty linked account. The default offer shows Cheer. The larger offers are hypothetical website selections. The linked example owns Cheer and Emberwake. Try the sample code `V7KMP-4TR9A` to check the account name before confirming. [PNG renders](renders/)

**Verification.** A Pillow comparison matched all 20 embedded views to their PNGs pixel for pixel. The frame and action rectangles fit 1366 × 768 and 1920 × 1080. An isolated DOM check exercised selection, code entry, retries, cancellation, confirmation and the website prompt. Chromium and Firefox could not start inside the sandbox, so a visual browser check remains open. No project fixture reads the changed documents, as checked with `rg`; zero fixtures, Lua runs or engine runs. Upgrade classification is **compatible** (tools only).

**Open pick.** Which layout should the game adopt? If the website has a dedicated support destination, what address should the linked page use? Both proposals currently direct players to ask a website administrator via grudgelands.com/play.

Rebuild with `python3 -B tools/r84_account_mock/build.py`. Pass `--fonts DIR` for another installation’s Luanti Arimo fonts.

Pick-page commit `2d378ffbfedd755182aeb610e6614f6753b2c6a8`. The final lane commit includes this report. Its full hash is available with `git log -1 --format=%H -- tools/r84_account_mock/REPORT.md`. `git status --porcelain` returned no entries.
