# Round 18 playtest

Status: technical checks and independent reviews PASS. Delivery is recorded in
[round18-completion.md](round18-completion.md); GUI acceptance is pending.
Use a fresh development world. Existing personal worlds are not rewritten.

## First pass: clarity and presentation

1. Complete preparation, create a character, and open Character. The Weapon slot
   and weapon tooltip explain equipping and attacking through a hotbar skill.
   Trying a raw weapon shows a short hint; it must not deal weapon damage.
2. Learn Cooking: expect an actual success message and Crafting guidance, with no
   Unlearn action. Reopen the trainer: expect known/progress information. Learn a
   primary profession and cancel its Unlearn confirmation; nothing is lost.
3. Check the highlighted Hotbar row, Crafting and Skills guidance, selected Bag,
   Talent and Map controls. Selection should be visible without a leading `>`.
4. Compare active skill icons across classes. Icons describe actions, while the
   held weapon still matches the equipped weapon and tier. Check bow draw, charge
   and cooldown readability. Skills recovery continues to work.
5. Stable display names use NPC lilac and appear/disappear with normal nearby
   nametags. They must not remain visible from far away or show combat HP bars.
6. Explore all six regional atlas views: capitals, fronts and dragon islands are
   covered. Party, quest, trainer and home markers retain their normal behavior.
   The native minimap initially shows terrain and your own arrow; V still toggles
   it. Other-player/entity dots are intentionally absent; use the atlas for them.

## Gameplay checks

7. In each starting culture, approach the warfront: local difficulty increases.
   In particular, the Troll town's easy surroundings must not naturally spawn
   level-10 Lynx. Boar identity must match local quests; Troll early Tapir quests
   should be achievable. Check both daytime and nighttime populations.
8. Pull an ordinary roaming mob far from its original location, damaging it at
   intervals shorter than 15 seconds. It should keep fighting. Stop damaging it:
   after roughly 15 seconds it should reset and return home. Taunt alone must not
   sustain the fight. Bosses, camp mobs, fixed guards and anchored rares retain
   their existing boundaries.
9. Level up with missing HP/mana: both fill to the new maxima, accompanied by one
   gold burst. Warrior rage stays unchanged. A multilevel `/xp give` emits only
   one burst; an excessive grant stops at 60. Death no longer removes XP.
10. Try Wood, Stone and Bronze pickaxes/shovels on dirt, gravel, sand, ash, stone
    and ore. Shovels handle loose material; picks are slower there and remain
    necessary for rock. Tier/depth restrictions and durability still apply.
11. The starter tool quests show short item names and still accept worn tools.

## Preparation / reconnect checks

12. On a fresh server with preparation active, waiting precedes character
    creation. Escape dismisses waiting; another Escape reaches the normal menu.
    Progress updates must not reopen the dismissed screen. Once ready, character
    creation resumes in faction/race/class order.
13. Disconnect/rejoin during waiting and after character creation. There must be
    no bypass, duplicate starter kit or unwanted teleport of a complete character.
    Preparation stop/resume keeps the saved mode and accepted progress.

Held-torch moving light and friendly-guard healing are deliberately deferred;
neither is an acceptance requirement for this round. Client-side GUI acceptance
and an actual fallback-engine run remain user tests, separate from automated
LuaJIT/PUC fixture parity.
