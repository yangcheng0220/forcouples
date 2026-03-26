# ForCouples

Couples expense tracking powered by AI coding tools and Supabase. Natural language in, structured financial data out.

## What This Is

Couples expense tracking system — database schema, access rules, and a skill layer that teaches AI coding tools to manage shared and personal expenses. Users describe spending in natural language ("coffee at 7-11"), and the tool handles parsing, categorization, and storage via Supabase.

No custom backend. The system design is the product.

## Data Model

Each expense has:
- **type** — `personal` (visible only to the person who created it) or `shared` (visible to both partners)
- **description** — what was bought
- **amount** — how much (nullable)
- **category** — matched from history or the categories table (e.g. Food, Transport, Entertainment)
- **payer** — who paid out of pocket (can differ from who logged it)
- **date** — when it happened

**Visibility rule:** each partner sees their own personal expenses + all shared expenses. A partner's personal expenses are never exposed. This is enforced by RLS policies and skill query patterns.

## File Map

| File | Purpose |
|------|---------|
| `SETUP.md` | Interactive setup flow — read this to onboard a new user |
| `setup.sql` | Database schema (tables, RLS, functions, triggers) |
| `config.example.json` | Config template (user IDs, couple ID) |
| `skills/forcouples/SKILL.md` | The skill — log expenses, query spending |
| `examples/cost-analysis.sql` | SQL patterns for advanced analysis |

## First-Time Setup

If the user wants to set up ForCouples (says "set me up" or similar), read `SETUP.md` and follow its instructions to walk the user through the full onboarding flow.

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
Query food expenses for the current month grouped by week, display as a table.
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
- Test changes against a real Supabase project before submitting

If you encounter outdated instructions or setup issues, PRs to fix them are welcome.
