# Mail

Mailboxes, letters between players, letters from the admin and from the
people of the realm, messages to the admin and announcements to all
players. Decided by the user on 2026-10-14
([mail plan](../planning/mail-plan.md) §2, with the round's changes in
[Round 48](../planning/round48-plan.md) §2); built in Round 48 (0.48.0):
the mod `grug_mail` with the mailbox window (lane MAIL), the mailbox on the
waystone pads (lane WORLD), the mail icon beside the minimap (lane HUD), the
Admin Mail tab (lane ADMIN) and the starter quest with the welcome and level
letters (lane QUEST). Seams and storage: the
[module guide](../technical/module-guide.md#mail).

## 1. Mailboxes

- Every capital core and every starting village has one mailbox, placed by
  the world generator on the waystone's pad, a few nodes to the side of the
  stone ([settlements](settlements.md)). There is no other way to read or
  write mail: no chat command, no inventory tab (the admin's Admin Mail tab
  is the one exception, §6). The map shows no extra marker: the mailbox
  stands beside a waystone the map already shows.
- A mailbox is named after its settlement ("Mailbox in Dur Brannoc"): the
  settlement whose waystone stands within 16 nodes.
- Right-clicking it opens one window with four tabs: **Letters**,
  **Announcements**, **Write** and **To the admin**. The tab captions carry
  the unread count ("Letters (2)"). Every action checks again that the
  mailbox still stands and the player is alive within 6 nodes of it;
  otherwise the window closes. The window's header names the mailbox and
  the player's purse.
- Lists are paginated, 8 rows per page, newest first.

## 2. Letters

- **Kinds.** A player letter (from a character of the same faction), an
  admin letter (always shown from **"Server Admin"**, never the admin's own
  name; a shield badge in the list and the banner "Sent by the server
  administration" in the letter) and a letter from a character of the realm
  (an NPC such as the Riding Trainer, with a seal badge).
- **Read state** is automatic: clicking a letter opens and marks it read.
  There is no "mark read".
- **Limits.** A mailbox holds **50 player letters**; a full mailbox refuses
  player mail ("Brakka's mailbox is full."). Admin and NPC letters are always
  delivered, beyond the limit.
- **Expiry.** Every letter is deleted **30 days** after it arrived, its
  attachments too, with no return to the sender. The Letters tab says so
  ("Letters are deleted 30 days after they arrive, attachments too.").
- **Reply** on a player letter opens Write with the sender, "Re: <subject>"
  (never "Re: Re:") and the quoted text; it costs postage as usual. Reply on
  an admin letter or an announcement opens To the admin with "Re: <subject>".
  NPC letters have no Reply ("Letters from characters of the realm cannot be
  answered.") and no Report.
- **Take all** moves every attachment into the inventory, through the
  inventory's usual order, or none: without room the items stay in the
  letter.
- **Delete** removes a letter; a letter that still holds attachments asks
  first.
- **Report** (player letters only, once each): a reason (Spam, Insult or
  harassment, Scam, Other), an optional note (200 characters) and a
  confirmation ("Really report this letter from …?"). The report becomes a
  "Player report" message to the admin holding a frozen copy of the letter:
  sender, time, subject, text and the attachments' names.
- A letter for an online player raises the feed line "New letter from
  <sender>." No sound.

## 3. Writing letters

- Recipients are created characters of the **sender's own faction**, typed
  by name (any letter case); a character of the other faction and an
  unknown name get the same answer: "There is no player called X in your
  faction." Sending to oneself is refused. A character that has not joined
  since 0.48.0 is not known yet and cannot receive player mail until it
  joins (admin and NPC mail reach it).
- **Postage:** **5c** per letter plus **30c per attached stack**, up to **4**
  stacks ("one item" is one stack: twelve ingots cost as much as one axe).
  A Bag of Coins is an ordinary attachment; there is no cash on delivery and
  no money sent as a number.
- **Attachments** go into four attachment slots of the player's own
  inventory (the list `grug_mail_out`), dragged in on the Write tab like any
  slot. Soulbound items (the Claim Stone), skills and mount items do not
  fit. Item meta (quality, enchants, the crown, wear) travels with the item.
- **Send** takes the postage and the four slots in one transaction. The
  button shows the postage for the slots as last drawn ("Send (65c)"); when
  the slots changed since (a stack dragged in after the window was drawn),
  Send refuses without taking anything and shows the new postage, and the
  next Send pays it.
- Closing the window without sending gives the stacks back; what does not
  fit stays in the slots and shows at the next mailbox (and returns at the
  next join when there is room). **Discard** clears the letter and gives the
  stacks back.
- Text limits: subject 60 characters (required), message 1,500. Control
  characters (colour codes among them) are removed.
- Letters to other players vanish for the sender once sent: there is no
  sent folder.

## 4. Messages to the admin

- The To the admin tab sends a message with a **topic** (Feedback, Bug
  report, Question, Player report, Other), a subject and a text, free of
  charge and without items. The game version and the mailbox ("Sent from
  Mailbox in Dur Brannoc") are always attached, never optional; so are the
  sender's level, faction, race, class and position, which only the admin
  sees.
- The tab's hint: "Questions, problems or a player to report? Feedback on
  the game and bug reports are very welcome too. Mail to the admin is free."
- A player has at most **5 open** messages to the admin, reports included.
- Each message is a **ticket**: the player keeps seeing their own messages
  with their state, **Open**, **Answered** or **Closed** (closed without an
  answer), and can delete them. **Deleting removes the ticket for
  everyone**; the server log keeps every message, answer and closing.
- An admin's answer arrives as an ordinary admin letter "Re: <subject>" in
  Letters and closes the ticket. Tickets expire after 30 days like letters;
  the admin inbox has no limit.

## 5. Announcements

- A letter from the admin to **all players** is stored once and shown in
  every player's Announcements tab, with the shield badge, also to
  characters created after it was sent, until it expires after 30 days.
  Each player's read state is their own.

## 6. The admin side

- A privilege, **`mail_admin`**, opens the **Admin Mail** inventory tab. The
  server's admin has it (`give_to_admin`); in singleplayer it is not given
  on its own (`/grant <name> mail_admin`). The tab comes after Help and
  shows only with the privilege; granting or revoking it redraws the
  inventory window at once, and a revoke leaves the tab if it is open. The
  tab shows no player inventory. Every action checks the privilege again: a
  form sent without it does nothing.
- **The inbox** is shared by every admin and has no limit. Filters **Open**
  (with the number of open messages) and **All**, newest first, 8 rows a
  page; each row shows topic, sender, subject, state and date. The selected
  message shows its subject, date and time and its header: sender, level,
  faction, race and class, position, "Sent from Mailbox in …" and the game
  version, all as they were when it was sent. A **Player report** shows the
  reason, the note and the frozen copy of the reported letter (its sender,
  time, subject, text and attachments).
- **Send answer and close** sends the answer as an ordinary admin letter
  "Re: <subject>" from "Server Admin" into the player's Letters and closes
  the message as answered; the answer box starts with the message quoted.
  **Close without answer** closes it without a letter. A closed message
  shows "Answered and closed by <admin>" or "Closed without answer by
  <admin>" with the time, only in this tab; players see Answered or Closed
  (§4). **Delete** removes a message for everyone, the player's copy too.
- **New admin letter:** to one player (any character the server knows,
  either faction, also offline; always delivered) or, with **All players**
  ticked, an announcement (§5), stored once. A subject is required. Text
  only: admin letters carry no items (admins have `/give`). A preview shows
  how the letter appears in the player's mailbox (the row with the shield
  badge, "Server Admin", the subject, and the banner "Sent by the server
  administration"); it follows the typed text at **Update preview** and at
  every other click. Players can answer an admin letter or an announcement
  with Reply, which writes a new message to the admin (§2).
- **Announcements** (the third filter) lists the sent announcements with the
  admin who sent them; Delete removes one from every player's Announcements.
- **Logging (§4):** besides every message, report, answer and closing, the
  server log names the admin's real name for every answer, closing,
  deletion, admin letter and announcement. Players never see that name.
- A click on a sending button (Send answer, Close, Send) from a form older
  than the last successful send, a double click, does nothing; so does a
  click on Send answer, Close or Delete from a form drawn for another
  message than the one selected now. Send answer refuses an empty answer
  and one that is only the untouched quote.

## 7. The unread icon

- An icon beside the minimap counts unread letters (admin letters and
  answers included) and unread announcements, with a digit from 1 to 9 and
  "9+" above; it is gone when nothing is unread. With the minimap hidden it
  moves into the top-right corner with the daytime band and "Now playing"
  ([world map](world_map.md)). The count updates at every change and at
  join.

## 8. System letters

- The game itself sends admin-kind and NPC letters: the welcome letter and
  the two level letters below (lane QUEST, Round 48), and the "Lost and
  Found" letters of the 0.48.0 bag migration, which carry the items that no
  longer fit the smaller bags as attachments
  ([inventory](inventory_equipment.md)). Only that migration sends items in
  a system letter.
- Each of the three letters goes to a character **once**, and only to a
  created character (a player still creating one gets nothing yet). The
  texts are the user's picks (2026-10-14); the player's name and the
  capital of the player's race are filled in when the letter is sent, so no
  text names a fixed place.
  - The **welcome letter** ("Welcome to Grudgelands"), an admin letter, at
    the character's arrival, or at the first join after 0.48.0 for a
    character created before. It says that feedback and bug reports are very
    welcome and that writing to the admin is free.
  - The **Riding Trainer's letter** at level **15**, only while the
    character owns no riding tier (a boat is not one).
  - The **Housing Steward's letter** at level **20**, only while the
    character never had a Claim Stone.
  A jump over both levels (14 → 21) sends both. A character that is past
  the level when 0.48.0 arrives gets the letter at its next join, but only
  while it is still useful; a letter that is no longer useful is never sent
  later.
- **The starter quest** "Use a mailbox in one of the cities" (a system
  quest, [quests](quests.md) "System quests"): every character gets it once,
  at its arrival or at its next join; with a full quest log (20 quests) it
  is skipped for good, and an abandoned one does not come back. The tracker
  and the quest log read "Open a mailbox beside the waystone of a capital or
  a starting village". Opening any mailbox completes it before the window
  opens: 30 XP and 25c (the first letters' postage), and its completion line
  in the message feed. A full purse refuses the turn-in with the reason in
  the feed and keeps the quest.

## 9. Help

- Help → Mail sums the rules up: the mailboxes beside the waystones,
  postage, the 50-letter and 30-day rules and writing to the admin.

## 10. Persistence

- Mail is not bound to the map: a map reset keeps every letter, ticket and
  announcement. Expired entries are removed when a list is read and at join,
  never by a pass over every player.
