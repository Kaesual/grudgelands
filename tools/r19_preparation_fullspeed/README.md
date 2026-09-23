# Full-speed preparation pipeline measurement

Python harnesses and retained native evidence for the separately authorized
bounded lookahead preparation experiment. Production scheduler and Lua fixture
ownership are separate from this measurement package. Results and scope:
[full-speed report](../../docs/research/pregen-fullspeed.md).

`run_native.py --execute --production-sha256 <approved hash>` performs exactly
one fresh native comparison, using isolated Luanti user/XDG directories and a
fresh disposable world on the workspace's disk filesystem. It requires the
preflight-approved frozen scheduler hash and the new pipeline's exact source
anchors; it cannot silently run the former serial scheduler. No personal
engine installation or world is used. One emerge worker and all normal engine
settings are preserved.

The copied scheduler's fill condition additionally requires
`planner.cursor < 561`. This observation-only boundary prevents tile 562 from
even entering selection while the last requests settle. Neither `state.total`
nor the world's persisted plan is rewritten. Shutdown is requested from a
Server step only after the committed prefix is 561, the scheduler queue is
empty, and observed native inflight count is zero. A seven-minute external
safety cap bounds failure. Request IDs, start times, selection descriptors and
action counts are local to each request, so callbacks cannot accidentally use
the most recent dispatch's identity.

After that comparison is frozen, the separately authorized command
`run_native.py --execute --production-sha256 <approved hash> --stop-resume-root <measurement root>`
performs exactly two bounded boots on that disposable world. Boot A stops from
a Server step with two outstanding requests, lets shutdown callbacks settle,
and records the committed prefix. Boot B must reload that prefix and completes
two more units before a drained normal stop. Each boot has a 60-second safety
cap. Separate copied game/user/XDG paths and logs preserve the original
measurement snapshot. The two-boot directory must not already exist, preventing
accidental repeated execution.

`compare.py` is an offline reader; it starts no engine. It compares the same
561 dispatch descriptors and per-request action counts against both retained
4 ms and 40 ms serial baselines. The canonical descriptor contains request ID,
low/high coordinates and selection; it excludes the observed committed cursor,
which legitimately trails speculative lookahead. Therefore its digest differs
from the earlier serial report that included cursor. All three runs are
rehashed with this same descriptor, and every recorded committed cursor is
independently checked against the completed contiguous request prefix. CPU samples are restricted to wholly enclosed
five-second intervals within matched geographic ranges. With pipelining,
request duration includes queue residence; it is not native service time.
Queue-empty time is derived from dispatch/completion events and means no
observed outstanding request, not every possible native engine wait. Raw
completion order and maximum inflight count remain part of the result.

`instrument.py` modifies only disposable source copies. Its strict source
anchors must be reviewed again if the scheduler changes. The retained evidence
contains exact inputs, launch settings, process identity, raw phase/thread
measurements, normal shutdown receipts and offline comparison. These scripts
are not standing authorization for repeated native runs.

The frozen run completed 561 tiles in 135.07 seconds after the mods-loaded
marker, versus 177.76 seconds for the 40 ms serial baseline. In matched tiles
101–561, Emerge-0 used 99.43% of one logical CPU and Server 12.15%; the process
sum exceeds 100% because both threads do useful work. There was exactly one
emerge worker, maximum two requests, no observed queue-empty interval between
first dispatch and final completion, and matching work/action prefixes.

The targeted stop/resume evidence is under `evidence/stop-resume/`. Boot A
cancelled 250 mapblock callbacks and retained committed prefix 561; boot B
reloaded that prefix and completed units 562–563. Both engine exits were normal,
with no surviving diagnostic engine. The initial Python receipt reader failed
after Boot B because Lua's empty queue table encoded as JSON null. The narrow
reader correction accepts null only with queue depth zero; no engine was
rerun. `receipt-reader-fix.diff`, `receipt-reader-finding.json`, and the executed
harness copy retain that distinction. Run
`python3 tools/r19_preparation_fullspeed/evidence/audit_stop_resume.py` for a
read-only replay of the final two-boot receipt. The primary prefix artifacts
remain byte-identical to `prefix-measurement-freeze.json`.
