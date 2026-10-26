# ForCouples

An experiment in agent-driven expense tracking using a schema, a skill file, and Supabase MCP.

## What This Is

Couples expense tracking system — database schema, access rules, and a skill layer that teaches AI coding tools to manage shared and personal expenses. Users describe spending in natural language ("coffee at 7-11"), and the tool handles parsing, categorization, and storage via Supabase.

No custom backend. The system design is the product.

## Data Model

Each expense has:
- **type** — `personal` or `shared` (intended visibility labels, not MCP access controls)
- **description** — what was bought
- **amount** — how much (nullable)
- **category** — matched from history or the categories table (e.g. Food, Transport, Entertainment)
- **payer** — who paid out of pocket (can differ from who logged it)
- **date** — when it happened

**Intended visibility:** own personal expenses and shared expenses from the configured pair. Developer MCP SQL can bypass RLS; skill filters and config are editable instructions, not authorization. Do not promise partner privacy or present this as a secure multi-user template. Categories are global: the authenticated policy permits all category rows to be managed, subject to grants.

## File Map

| File | Purpose |
|------|---------|
| `SETUP.md` | Interactive setup flow — read this to onboard a new user |
| `setup.sql` | Database schema (tables, RLS, functions, triggers) |
| `config.example.json` | Config template (user IDs, couple ID) |
| `skills/forcouples/SKILL.md` | The skill — log expenses, query spending |
| `examples/cost-analysis.sql` | SQL patterns for advanced analysis |

## First-Time Setup

If asked to set up ForCouples, read the limits in `README.md` and `SETUP.md` first. Explain that this is an experiment and developer MCP does not enforce partner privacy. Start with synthetic data in an isolated project. Do not invite partners as developers to provide private access.

## Daily Use

After setup, the skill handles two modes:

- **Log** — describe spending in natural language. Amount, category, date, and type are inferred. "lunch with partner $12" becomes a shared expense, auto-categorized. Missing fields are prompted for, not required upfront.
- **Query** — ask about spending. "how much did we spend on food this month?" returns a breakdown. Balance calculation shows who owes whom.

## Extending

The skill covers logging and basic queries. For recurring analysis or custom workflows, create a new skill rather than modifying this one.

A custom skill can be as simple as:

```yaml
---
name: monthly-food
description: Monthly food spending breakdown
allowed-tools: mcp__supabase__execute_sql
---
Query only the intended visible expenses for the configured pair, with the creator/type predicate in SKILL.md; group food expenses for the current month by week. These filters are not authorization.
```

See `examples/cost-analysis.sql` for SQL patterns to build on.

Examples of what's possible with additional skills:
- **Data ingestion** — scrape payment card transactions or e-invoices, reconcile against logged expenses
- **Analysis** — open-ended spending investigation via subagents
- **Reminders** — detect logging gaps, surface untracked days

## Contributing

When working on this repo:
- `SETUP.md` is the user-facing onboarding flow — changes here affect how new users get started
- `skills/forcouples/SKILL.md` is the daily-use skill — keep it under 500 lines
- `setup.sql` is the schema — changes require migration planning for existing users
- For schema or runtime changes, test in an isolated Supabase project with synthetic data. Documentation and query-example corrections can use static checks; report that live execution was not tested.

If you encounter outdated instructions or setup issues, PRs to fix them are welcome.
