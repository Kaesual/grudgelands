# Documentation guide

Start here to find the current rule, implementation status or evidence without
reading every development round.

| Question | Read |
|---|---|
| What is the current game delivery? | [Project status](STATUS.md) |
| What has been decided? | [Design topic index](design/README.md) |
| What is still to implement? | [BACKLOG](../BACKLOG.md) |
| What are the broader goals? | [ROADMAP](../ROADMAP.md) |
| What decisions remain open? | Root `TODO-*.md` files; unresolved audit findings below |
| How should work be performed? | [AGENTS](../AGENTS.md), then the relevant [workflow](process/wp-workflow.md) |
| Which implementation seam or pitfall matters? | [Module guide](technical/module-guide.md), [Lua rules](research/luanti-lua.md) |
| Why was something decided or how was it tested? | [Research and historical evidence](research/README.md) |
| What changed during documentation cleanup? | [Consolidation record](maintenance/documentation-round.md) |

## Reading and authority

Read the current topic, its open work and the relevant technical references.
Research is not a second mandatory specification. A completed round's plan may
explain a decision, but its old instructions must not silently override the
current consolidated rule. A historical test report certifies only its recorded
source and inputs.

An approved target may be unimplemented. Code tells us what runs, not what the
user intended. If current design, an approved later decision and code disagree,
record the discrepancy and resolve its authority before implementation. A newer
unapproved proposal does not win merely because it is newer.

The [maintenance rule](process/documentation.md) explains how to keep these
boundaries clear. Root README is a human-facing summary derived from these sources.
