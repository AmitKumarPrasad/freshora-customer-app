# FRESHORA agent coordination

Read the relevant project skill before working:
- Bug and regression work: .agents/skills/freshora-bugfix/SKILL.md
- Customer usability: .agents/skills/freshora-ui-review/SKILL.md
- Security and release verification: .agents/skills/freshora-release-security/SKILL.md

Use Flutter sources under mobile/. Inspect the actual backend repository when API behavior matters.

Use separate branches/worktrees for parallel work. Assign one owner per changed file; coordinate shared mobile/lib/main.dart edits before starting. The coordinator owns integration and latest-commit CI review.

Reproduce or document concrete evidence before fixing. Run available formatting, static checks and focused regressions before pushing; explicitly record missing tools. Batch related corrections. Never rerun unchanged failures or disable checks to get green.

Open scoped PRs with evidence and test results. Integrate only reviewed changes with required checks passing on the current commit. Continue available independent tasks while CI runs. Do not describe session subagents as persistent GitHub background workers.

Before recommending release, verify the signed AAB, increasing versionCode, production configuration and actual device flows. Keep failures and unverified checks visible. Do not claim Play Store approval or publish without release authorization.
