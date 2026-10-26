# ForCouples

An experiment in using an AI coding agent as an expense-tracking interface: natural language in, structured records in Postgres out. The repository contains the schema, skill, and setup flow for exploring this approach.

**Case study:** [ForCouples](https://yangchengchen.com/projects/forcouples)

## What It Demonstrates

- A skill file that guides parsing, category matching, confirmation, and SQL queries.
- A Supabase schema with expense types, payer attribution, and intended partner visibility rules.
- A move from form entry to conversation, with separate ingestion and reconciliation workflows.

There is no custom API between the agent and the database. This makes experiments easy, but also gives the agent developer database access. This is not a secure multi-user template or a ready-to-use couples finance service.

## Privacy Limits

The distinction between database access paths matters:

- **Authenticated application requests:** expense RLS policies use `auth.uid()` to select the caller's own expenses and shared expenses created by their linked partner. These policies apply only when the request runs as the intended restricted user role. This repository does not include a complete authorization test suite.
- **Developer MCP SQL:** the setup uses Supabase developer access. Privileged SQL can bypass ordinary RLS guarantees. Signing in to Supabase through OAuth is not signing in as one of the expense users in `auth.users`.
- **Skill instructions and config:** user IDs and SQL filters guide the agent. They do not enforce authorization. An agent or developer can omit or change them and read or modify other records. Partner privacy is not enforced through this path.
- **Categories:** `setup.sql` permits every `authenticated` user to read and manage every category, subject to table grants. Categories have no user or couple owner; they are not private per couple. `expenses.category` is free text, not a foreign key.
- **Project scoping:** `project_ref` limits the project reached by MCP. It does not limit rows within that project. OAuth still uses credentials managed by the MCP client; the absence of API keys in this repository does not mean no credentials exist.

Some original examples missed the intended scope: category matching searched all expenses, balance searched all shared expenses, editing matched only an expense ID, and total-paid analysis filtered only by payer. The retained examples now include user filters. These reduce accidental overreach; they do not make privileged MCP a privacy boundary. The schema has no `expenses.couple_id`; examples identify the intended pair through creator IDs from config, which is itself editable.

A service for independent users would need an authenticated, restricted access path, server-enforced user and couple membership checks, category ownership rules, and allow/deny tests for every operation. It must not expose developer MCP access to end users. See [Supabase MCP security guidance](https://supabase.com/docs/guides/ai-tools/mcp#security-risks) and [RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Data Model

Each expense records:

- `type`: `personal` or `shared`, the intended visibility classification.
- `description`, `amount` (nullable), `category`, and `date`.
- `created_by`: who logged the expense.
- `payer`: who paid, which can differ from the creator.

The intended view is one's own personal expenses plus the pair's shared expenses. That intent is not an MCP access guarantee.

## Repository Map

| File | Purpose |
|---|---|
| `SETUP.md` | Experimental setup flow and access-control limits |
| `AGENTS.md` | Context and limits for agents working on this reference |
| `setup.sql` | Tables, policies, functions, and triggers |
| `config.example.json` | Example identity fields, not credentials or authorization |
| `skills/forcouples/SKILL.md` | Expense workflow and scoped query examples |
| `examples/cost-analysis.sql` | Analysis examples with intended user filters |

## Study or Extend It

Read the privacy limits before the setup guide. Start with synthetic data in an isolated test project. Do not invite a partner as a Supabase developer as a way to provide private expense access.

The useful pattern is the combination of schema, conversational input, and reviewable workflow instructions. A skill can guide behavior; the database or a restricted application service must enforce access.
