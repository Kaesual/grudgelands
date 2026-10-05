# CLAUDE.md

All project conventions, architecture decisions and Luanti/Lua details live
in **[AGENTS.md](AGENTS.md)** — read that first.

AI model routing defaults live in the project-wide
**[agent model policy](docs/process/agent-model-policy.md)**. Its roles are
defaults: the user decides per session which model coordinates, implements
and reviews (policy "Day-to-day routing rule", 2026-09-14). Independent
review of non-trivial changes remains mandatory regardless of model.

How a round runs: **[round workflow](docs/process/round-workflow.md)**.
Current status: **[docs/STATUS.md](docs/STATUS.md)**; goals:
**[ROADMAP.md](ROADMAP.md)**.
