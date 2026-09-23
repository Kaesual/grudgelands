# Round 18 preparation waiting report

Package F moves the shared world-preparation gate ahead of faction, race and
class selection. Both form display and submitted faction/race/class fields
check current preparation readiness. A per-connection creation session keeps
movement and immortality stasis active while allowing the waiting form to be
dismissed with Escape; ordinary progress notifications do not reopen it.

A transition into scheduler failure clears that dismissal once and exposes the
retry action. Repeated failed notifications do not steal focus. Readiness
continues at the first missing selection step, while a complete character is
released in place without another class commit, starter grant or teleport.
Deferred arrival callbacks retain their existing session and generation checks.
The separate arrival-load failure has its own one-shot transition, so it can
reveal Retry after its in-progress form was dismissed without reopening on
later ready notifications.

The bounded real-module fixture in `tools/r18_waiting/fixture.lua` loads the
production faction and selection modules with deterministic engine seams. It
covers pending, forged fields, dismissal, failure/retry, readiness, new,
partial and complete characters, plus a stale callback after reconnect. The
fixture returns a canonical string for the coordinator's final interpreter
pair. It does not emulate the native Escape-to-menu transition; that remains a
GUI acceptance check.
