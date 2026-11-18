# Round 83 — Character deletion on the website's request (0.83.0)

Planned with the user on 2026-11-18. Source: the kaesual coordinator's task of 2026-11-18
(`~/projects/kaesual-stack/.local/grudgelands-character-delete-task.md`, copied to
`~/projects/grudgelands-orchestration/r83/website-task.md`). grudgelands.com gets a privacy
policy that promises erasure (GDPR Art. 17); a character's data lives in the game, so the game
gets a bridge command `character.delete` that erases it, online or offline. Version **0.83.0**,
expected **compatible** over 0.81.0 and 0.82.0: every clear works on today's stores, nothing is
migrated.

Two read-only studies came first (2026-11-18, private:
`~/projects/grudgelands-orchestration/r83/reports/study-a-stores.md`, the inventory of every
per-character store; `study-b-mechanics.md`, the bridge, engine and timing facts). The
coordinator checked their load-bearing claims against the code. The lane reads both reports;
this plan names only what it builds on.

Routing (the user, 2026-11-18): this session coordinates; one Opus lane implements; an
independent Opus review.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling until
  the user says so; a coordinator default is marked as such.

## 1. Lanes and order

Start state: main at the commit of this plan (0.82.0). Integration branch `round83` in
`.claude/worktrees/round83`; a one-lane round works on it directly. Orchestration folder
`~/projects/grudgelands-orchestration/r83/`.

| Lane | Goal (§4) | Who | Review |
|---|---|---|---|
| DEL | `character.delete`: the bridge command, the deferred answer, the per-mod clears, the login guards, the tests, the contract docs | Opus | independent Opus review |
| D | Release 0.83.0, the round's end records, the answer to the website | coordinator | coordinator |

## 2. User rulings

From the conversation of 2026-11-18:

1. **Letters the deleted character wrote** that sit in other players' mailboxes **stay**, the
   name as bare text; they expire by the 30-day rule. The same holds for other players' sent
   copies addressed to it and for report tickets about its letters (coordinator default, by the
   same reason).
2. **A deleted clan leader hands the lead on** to another member (by the clan's existing rule).
3. **The housing claim is released and its Claim Stone removed**; containers and blocks inside
   stay as they are. No extra clean-up work. Removing the stone at once is fine (it is possible:
   the existing `grug_housing.remove_stone_node` loads the block).
4. **Traces in the world outside the claim stay** (owner meta, sign texts, written books, crop
   marks); they go into the answer for the privacy policy.
5. **Online deletion:** disconnect, wait until the engine is done with the player, delete,
   answer.
6. **A hard end-to-end test:** seed a character in every store, delete it, search the world for
   its name and id.
7. **Server backups** are the website's (deleted after 30 days); not this round's task.
8. **Flow:** read-only studies, this plan, one Opus lane, an independent Opus review, one squash
   commit, tag `round-83`, the answer to the website.
9. **Locked chests, steel doors and trapdoors, and the personal furnace slots in public
   furnaces** keep their owner by name in the node meta. A new character that later registers
   the same name gets access to them. **Accepted and documented**, no new mechanism.
10. **Mail is pruned at every server start:** every mailbox, sent list and the ticket list lose
    their entries older than 30 days, so "removed after 30 days" is true within one restart
    (today the pruning happens only when a list is read).
11. **The server administrator's character** (the name in the server setting `name`, which the
    engine gives every privilege) cannot be deleted: `refused`. Other characters with
    privileges are deleted like any other.

Coordinator defaults the user accepted on 2026-11-18 (unchanged unless the user says
otherwise):

12. The wait for one mod-storage commit per deletion (about 5.5 s) stays (§3.3 step 3).
13. A login is refused while a name's id index holds the tombstone **and** an auth entry still
    exists (only reachable after a half-finished deletion); `web-accounts.md` §2 "the meta wins"
    gets this exception.
14. The login race is guarded by letting the engine's `record_login` tolerate a missing auth
    entry and disconnecting such a join (an entry in the engine-workaround list).
15. A second `character.delete` for a name whose deletion is running answers `refused`.
16. An online character that is not gone before the deadline (§3.3) answers `expired`: it was
    disconnected, nothing was deleted.
17. The game's stored copy of the website's binding list drops the deleted character's row at
    once (the version stays; the website's next list replaces it anyway).
18. Engine IP bans (`ipban.txt`, the builtin `/ban`), other characters' party favourites and
    the bridge's ban list keep the name.
19. Clan and party line for a deleted member: "<name> is no longer a member." The clan's and
    party's existing successor and dissolve rules apply (a two-member clan dissolves, as at a
    leave).

## 3. Shared conventions

### 3.1 The wire form (as the website proposed; the lane changes it only with a reason in its report)

- **Capability** `characters.delete` in `C.CAPABILITIES` (`grug_bridge/commands.lua`).
- **Type** `character.delete`, args `name` (the character's name, exact spelling; another case
  is `unknown_target`), optional `character_id` (32 lower-case hex digits), `admin` (the
  website account's name, as in the other commands).
- **Codes:** `ok`; `unknown_target` (no such character, or `character_id` does not match);
  `refused` with a message (the server admin's character; a deletion of the name already
  running); `invalid_args`, `expired`, `error` in their general meanings.
- **Disconnect text:** "This character was deleted on the website." (through
  `core.disconnect_player`, so the player reads it without "Kicked: ").
- **At most once**, as every command. A later `character.delete` for a deleted name answers
  `unknown_target`.
- **The log line:** exactly one `action` line per deletion with the name, the character id and
  the acting admin, nothing else personal (no position, no account id). The bridge's generic
  command line may be that line if the result message carries exactly this; then nothing else
  in the deletion logs the name with more detail. A character in creation counts like any other
  (the bridge's `character()` helper, which refuses those, is not reused).

### 3.2 What is erased (study A, stores S1–S25 and R1–R10; the lane re-checks each)

- **Engine:** the auth entry (name, verifier, privileges, last login) and the player record with
  its meta and inventories, through `core.remove_player` and `core.remove_player_auth` (both
  remove by cascade under sqlite3 and PostgreSQL; production keeps players and auth in
  PostgreSQL, mod storage in sqlite3).
- **grug_accounts:** the id index entry becomes `M.TOMBSTONE`, **always**, also when there is no
  entry; the cached binding row is dropped (ruling 17).
- **grug_mail:** own mailbox (attachments go with it), own sent list, own tickets, the row in the
  recipient index.
- **grug_clans, grug_parties:** the member row, with the existing successor and dissolve rules
  (ruling 19).
- **grug_housing:** every claim owned by the name is released and its stone removed (ruling 3);
  the name's rights in every other claim are removed; the owner's player record is dropped (not
  left as "removed"); packed and recovered map-reset belongings of the name are cleared.
- **grug_home:** the pending "claim lost" notice, cleared **last** (a claim removal with a loss
  event writes it, so the deletion uses an event grug_home does not count as a loss).
- **grug_achievements:** the queue of waiting grants.
- **grug_expeditions:** a run the character owns ends.
- In-memory state that would carry over to a same-name character in the same boot is dropped
  (study A §4).

**Stays, and goes into the answer:** other players' letters, sent copies and report tickets that
name the character (rulings 1, 10); admin fields naming it if it was an admin (closed tickets,
announcements); other characters' party favourites; the bridge's ban list; an engine IP ban;
node meta in the world (locked chests, steel doors and trapdoors, personal furnace slots, crop
marks, written books, sign texts; rulings 4, 9); the server log. Physically deleted bytes may
survive in database free pages until a vacuum (informational).

**Every future per-character store must take part.** The deletion runs through one registry
(each mod registers its own clear function; the lane picks the home, for example beside
`grug_core.map_reset`, and says why), and the module guide gets a rule: a new store keyed by a
character registers its clear, or the reviewer rejects it.

### 3.3 The sequence (study B §10; the lane may refine it and documents what it built)

0. **At arrival, synchronous:** argument checks; existence (an auth entry, or an index entry that
   is a character id, so a retry after a crash still finds a half-deleted character);
   `character_id` against the online meta id or else the index entry; the refusals (ruling 11,
   ruling 15). Then the name is blocked at prejoin (case-insensitive) and the command answers
   later (§3.4).
1. **Online only:** disconnect, then wait until the player is gone from the engine:
   `core.get_player_by_name(name) == nil` **and** `core.objects_by_guid[name] == nil` (the
   engine's own save of the leaving player happens before the second; deleting earlier lets that
   save re-create the record). The same wait applies to a player who has only just left.
2. **Clear, one synchronous call:** the tombstone and every registered clear (§3.2).
3. **Wait one mod-storage commit** (`server_map_save_interval` plus a step, read from the
   settings), so the tombstone and the clears are on disk before the login disappears (ruling
   12).
4. **Engine removal, one synchronous call:** the clears again (catches mail or a queued grant
   that arrived during step 3), `core.remove_player`, `core.remove_player_auth`, prejoin block
   off, the answer and its log line.

**Deadline (coordinator default):** step 2 starts only while at least 10 s remain before the
command's `expires_at`; otherwise the answer is `expired` and nothing was deleted (ruling 16).
So the whole deletion ends before the expiry and the website's promise "no game acts on a command
after its expiry" holds. Every deferred step runs under `pcall` and ends in an `error` answer on
failure (an error in a `core.after` job ends the server).

**Login guards:** the prejoin block during the deletion; the tombstone-plus-auth refusal
(ruling 13); the `record_login` guard for a client that passed prejoin before the deletion and
joins after it (ruling 14), with its entry in `docs/technical/upstream-workarounds.md`.

### 3.4 The deferred answer

Today a command answers synchronously. The bridge's ledger already treats an entry without a
result as running and sends nothing for it, and the website re-delivers until `expires_at` and
takes a late result from the same boot. The lane adds the smallest change that lets one command
type answer later, exactly once, without changing the other types; a deferred command lost in a
crash or shutdown stays unanswered (the website marks it `unknown` at the next boot, the player
may retry; the deletion is idempotent).

### 3.5 Shared files

One lane; it owns every file it needs under `mods/`, `tools/r83_*`, the bridge and accounts
fixtures it extends, and these documents: `docs/technical/web-bridge.md`,
`docs/technical/web-accounts.md` (§1, §2 tombstone row and the ruling-13 exception, §10 outlook),
`docs/technical/modules/platform.md`, `docs/technical/module-guide.md` (the store rule),
`docs/technical/upstream-workarounds.md`, the comment at `grug_accounts/model.lua` "written only
by a future deletion". Lane D owns `CHANGELOG.md`, `game.conf`, `tools/web_data/upgrade.json`,
`docs/STATUS.md` and this plan's Completion.

## 4. Lane goals

### DEL (Opus)

1. **The command** (§3.1, §3.3) with the deferred answer (§3.4), the capability, the refusals,
   the deadline and the log line.
2. **The clears** (§3.2) as one function per mod, registered in one registry, with the order
   traps of study A respected (the claim removal re-saves the owner's record; the claim event
   must not make grug_home write its notice; clan and party leave hooks persist rows). Functions
   that are local today get a narrow export.
3. **Mail pruning at start** (ruling 10), all lists in one pass.
4. **The login guards** (§3.3).
5. **The contract docs and the store rule** (§3.5), so the website can amend its
   `game-bridge-protocol.md` from them.
6. **Tests:**
   - a portable fixture (`tools/r83_del/portable_test.lua`, or extensions of
     `tools/r691_bridge/portable_test.lua` and `tools/r79_acc/portable_test.lua` where they fit
     better): the deferred ledger (silent while running, one result, `done` twice, expiry, an
     error in the continuation), the argument checks and codes, every clear, the refusals, the
     prejoin rules, the `record_login` guard, the mail start pruning;
   - **the end-to-end scenario** (ruling 6), built on `tools/r691_bridge/scenario.py` (real
     server, real client, fake bridge, probe mod): seed one character in every store of §3.2 and
     a second character whose data refers to it; delete one character online and one offline;
     a repeated delivery stays silent; a second deletion answers `unknown_target`; a wrong
     `character_id` changes nothing; then a clean shutdown and a search of every world database
     (auth, players, mod storage, the map blocks decompressed, every other file) for the name
     in any case and the id, against an explicit allow-list built from §3.2 "Stays"; finally a
     join with the same name gets a new id and adopts nothing. The scenario's log also confirms
     the timing study B inferred (leave and removal after the disconnect).

## 5. Rules

- The launch sentence of the [round workflow](../process/round-workflow.md#6-writing-briefs) in
  every brief.
- The lane never pushes, merges, syncs, touches the main checkout, or launches agents. Engine
  runs only through the scenario's isolation (as `tools/luanti_headless.sh`: a temporary user
  path, never the user's Luanti folder, `LC_ALL=C`), through the shared queue, and with
  `pgrep -f '^luanti.bin'` empty at the end.
- Nothing is deleted by a clear that study A or the rulings keep (§3.2 "Stays"); a store the
  lane finds that neither lists goes to `## Blockers / questions`, with the action it would
  pick, unless it is plainly keyed by the character (then it is cleared and reported).
- A decision the plan reserves, or a blocker outside the lane, ends in
  `## Blockers / questions`.

## 6. Verification

- **DEL:** `bash tools/check_lua.sh` on the changed Lua; its own fixture plus the fixtures that
  test the changed behaviour (the bridge and accounts fixtures, and those of the clans, parties,
  housing registry and mail store where their behaviour changes); the end-to-end scenario
  (§4.6), a few runs at most; `python3 tools/check_fresh_server.py`; the upgrade
  classification in the report.
- **Review:** the review brief's checklist, plus: every store of study A is cleared or listed as
  staying; no destructive step can run after `expires_at` or before the engine has saved the
  leaving player; the at-most-once guarantee holds for the deferred type; no log line carries
  more than name, id and admin; the scenario's allow-list is no wider than §3.2.
- **Round end** (a real round): the full `tools/run_fixtures.sh` once, `check_fresh_server.py`,
  `check_upgrade.py`, one smoke boot of the round branch.
- **Human test:** none needed in the game: the scenario kicks a real client. The real acceptance
  is the website's first deletion on the rehearsal realm, on its side.

## 7. Orchestration notes

- Process budget: one lane, LuaJIT through the shared queue
  (`~/projects/grudgelands-orchestration/r45/lua_run.sh`); the scenario takes one queue slot and
  a private Xvfb.
- **Compaction checkpoint:** after the review verdict, before the fix round or lane D.
- Decided during the round: anything the lane reports under `## Blockers / questions`.

## Completion (2026-11-18)

Lane DEL (Opus) built the command on `round83`, an independent Opus review returned MERGE AFTER
FIXES, a fix round closed its findings 1–3 and an independent delta review returned MERGE; lane
D (this section) runs on the same branch. Release **0.83.0**, **compatible**: no new saved key
and no format change (the index entry `id:<name>` takes the existing tombstone value; the other
stores lose rows or entries).

**What shipped (DEL):**

- The bridge command `character.delete` (capability 13), answered deferred: the ledger's
  `defer()` returns a `done(code, message)` that answers once; a repeated delivery while the
  deletion runs stays silent, a second deletion of the name answers `refused`.
- The sequence of §3.3: refuse or expire at arrival, disconnect an online character (the text
  of §3.1), wait until it is gone from `core.objects_by_guid`, run the clears, wait for one
  mod-storage commit, remove the player record and the auth entry, answer `ok` with the one
  log line. Measured in the end-to-end scenario: disconnect → leave 1 ms → gone from the
  engine 272 ms → clears at 272 ms → removal at 6.1 s; the website's fake had the answer after
  about 7.8 s (online) and 8.0 s (offline).
- The clears: `grug_core.character_delete.MODS`, an explicit ordered list of the mods with
  per-character stores, each defining `forget_character(name)` (a listed mod without it stops
  the start); accounts (the tombstone, always), mail, clans, parties, classes, Expeditions,
  housing, home, achievements. Mail is pruned to 30 days at every server start (ruling 10).
- Login guards: the name is refused at login while its deletion runs (any letter case) and
  while a tombstone stands beside a used login; the engine's `record_login` tolerates a
  missing auth entry (`docs/technical/upstream-workarounds.md` §10).
- The rule in the module guide: a new per-character store defines its clear and is listed.
- Tests: the new end-to-end scenario `tools/r83_del` (a real server and client: a character
  seeded in every store, deleted online and offline, the world, auth, players, mod storage and
  decompressed map blocks searched for its name and id; 54/54 checks, the allow-list no wider
  than §3.2), its portable fixture, new cases in `r691_bridge` and `r79_acc`, stubs in three
  mail fixtures. 45 files, about +2,560/−60 lines.
- Docs: `web-bridge.md` (the command, codes, what goes and what stays), `web-accounts.md`
  §1/§2/§10, the module docs of platform, mail, clans, parties, accounts, player systems.

**Review:** the first review confirmed the deferred ledger, the engine claims, every clear
against study A and the allow-list, and found one HIGH: a retry carrying `character_id` could
not finish a deletion that stopped after its clears (it answered `unknown_target`, the website
would drop its row and the login would stay). Fixed: a tombstone beside a login of an offline
character resumes the deletion with the id the website sends; two fixture cases (an error, an
expiry) retry with the id and end `ok`. Also fixed: a stale result in the scenario's later-boot
check, and every deadline comparison is `>=` (no destructive step at `expires_at`). The delta
review's one LOW (the doc said "less than" where the code expires at exactly the margin) is a
doc fix ("at most").

**Deviations from the plan:**

- Wire form (§3.1): `expires_at` is required (`invalid_args`); `expired` also at arrival when
  at most `max(10, server_map_save_interval + 4.5)` s remain; `expired` "not deleted
  completely … Send it again." when the clears ran but the removal could not finish in time
  (the login stays refused until the retry). §3.3's "at least 10 s remain" reads "more than
  the margin" in the code.
- Ruling 13 is narrowed to a **used** login (`last_login ≠ -1`) beside the tombstone, so a new
  player whose first connection aborted after registration is not locked out.
- The registry is an explicit list instead of each mod registering itself (a load-time call
  broke 45 fixtures that load these files with partial stubs; the list also shows the order
  traps in one place).
- A store study A missed, `clans_unreadable` (a copy of a corrupt clan store kept for an
  admin), **stays** (the user, 2026-11-18) and is listed under "What stays".

**Gates** (round end, on `round83`): the full fixture run 375 passed and 1 failed:
`r81_safe` loads `grug_bridge/commands.lua` without a `core` stub, and the command file now
loads `delete.lua` through the mod path (the lane's selection missed it); the coordinator gave
the fixture a `core.get_modpath` stub (tool-only), and `r81_safe` passes. `check_upgrade.py`
PASS (0.83.0, compatible), `check_fresh_server.py` PASS, one smoke boot of the round branch
PASS (listening, no error), besides the scenario's own boots.

**Human test:** none in the game (the scenario kicks a real client); the acceptance is the
website's first deletion on the rehearsal realm. The answer to the website went through the
user (private: `~/projects/grudgelands-orchestration/r83/website-answer.md`).

## Carry-overs

Each line names where it came from; none is wanted work yet, so none has a BACKLOG line.

- **Review note 4:** a client that joins while the deletion waits for the player to be gone is
  not disconnected again; the command ends `expired` with nothing deleted (safe).
- **Review note 5:** the login guards are installed only while the bridge is active; with the
  bridge off, a half-deleted character could log in.
- **Delta review note:** a never-joined login (`last_login = -1`) beside the tombstone also
  takes the resume path (only after a full deletion whose answer was lost and a new
  registration of the name that never joined); it removes that empty login and answers `ok`.
  Using `grug_accounts.half_deleted(name)` for the resume would match the login guard.
- **Delta review note:** a command with a wrong id during a running deletion answers `refused`
  ("already being deleted") instead of `unknown_target` (harmless).
