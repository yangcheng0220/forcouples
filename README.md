# forcouples

A couples expense tracker where the AI coding tool is the interface. No app needed — just describe your spending in natural language and the tool handles parsing, categorization, and storage.

Built on Supabase (Postgres) with zero backend code. The system design is the product — schema, access rules, and a skill layer that teaches any AI coding tool how to use it.

## Getting Started

```
git clone https://github.com/yangcheng0220/forcouples
cd forcouples
<your agent>             # claude, codex, droid, etc.
> set me up
```

The tool walks you through everything — Supabase project, database schema, MCP connection, skill install. No API keys to manage. OAuth handles authentication. Takes about 15 minutes.

Your partner? Invite them to the Supabase org, have them clone the same repo, and say "set me up." Same flow, shared database, separate configs.

## The Story

I built a couples expense app — React, TypeScript, Tailwind, Supabase backend. It worked. Then I realized the app was the wrong interface.

Logging an expense through a UI means opening the app, tapping through forms, picking categories. With an AI coding tool, I just say "coffee at 7-11" and it figures out the rest — amount, category, date, who paid, shared or personal. The tool became the primary interface. The app became optional.

Then I automated data ingestion — separate skills that scrape payment card transactions and e-invoices, then reconcile them with logged expenses. At that point, the app was just a read-only dashboard.

This repo is the open-source version of that system. It demonstrates a pattern: **the intelligence lives in the system design — schema, access rules, and a skill layer — not in custom application code.**

## What This Demonstrates

- **Skill-based tooling** — a structured prompt file that teaches an AI coding tool to interact with a database intelligently
- **Natural language as interface** — "lunch with partner $12" becomes a typed, categorized, attributed expense record
- **Zero backend architecture** — Supabase provides the database and API. The skill file provides the intelligence. Nothing in between.
- **The "app to skill" pivot** — why building a traditional UI was the wrong approach for this problem

## Data Model

Each expense tracks:
- **type** — `personal` (only you see it) or `shared` (both partners see it)
- **description** — what was bought
- **amount** — how much (can be logged later if unknown)
- **category** — auto-matched from history (e.g. Food, Transport, Entertainment)
- **payer** — who paid out of pocket (can differ from who logged it)
- **date** — when it happened

Each partner only sees their own personal expenses plus all shared expenses. Your partner's personal spending stays private.

## How It Works

```
User: "grabbed lunch, $12"
  → Tool parses: description, infers category (Food), date (today), type (personal), payer (me)
  → Tool: "Logging: grabbed lunch → Food | $12.00 | personal | 2026-03-25. Confirm?"
  → User: "y"
  → Tool: INSERT INTO expenses → done

User: "how much did we spend on food this month?"
  → Tool queries expenses table with date + category filter
  → Returns markdown table with breakdown
```

The tool reads a skill file (SKILL.md) that contains parsing rules, SQL patterns, and category matching logic. It uses Supabase MCP for database access — no custom API, no middleware.

## Architecture

```
┌─────────────────────────────────────────────┐
│  AI Coding Tool (Claude Code, Cursor, etc)   │
│  ┌────────────────────────────────────────┐  │
│  │  SKILL.md — log, query, categorize     │  │
│  │  config.json — user identity           │  │
│  └──────────────┬─────────────────────────┘  │
│                 │ SQL via MCP                 │
└─────────────────┼───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Supabase                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ expenses │ │ profiles │ │  categories  │ │
│  └──────────┘ └──────────┘ └──────────────┘ │
│  ┌──────────┐                                │
│  │ couples  │  + RLS policies + functions    │
│  └──────────┘                                │
└──────────────────────────────────────────────┘
```

## Repository Structure

```
forcouples/
├── README.md              ← you are here
├── SETUP.md               ← AI-readable setup flow (your tool walks you through it)
├── AGENTS.md              ← context for AI coding tools working with this repo
├── CLAUDE.md              ← symlink to AGENTS.md (Claude Code entry point)
├── setup.sql              ← database schema
├── config.example.json    ← config template
├── .gitignore             ← keeps config.json out of version control
├── examples/
│   └── cost-analysis.sql  ← advanced SQL patterns (True Cost, monthly summaries)
└── skills/
    └── forcouples/
        └── SKILL.md       ← the skill (log + query)
```

## Extending

The skill covers logging and basic queries. For recurring analysis or custom workflows, create your own skill. A custom skill can be as simple as:

```yaml
---
name: monthly-food
description: Monthly food spending breakdown
allowed-tools: mcp__supabase__execute_sql
---
Query food expenses for the current month grouped by week, display as a table.
```

See `examples/cost-analysis.sql` for SQL patterns you can build on.

## Privacy & Security

- **Personal expenses stay private** — each partner only sees their own personal expenses plus shared expenses. Enforced by RLS policies and skill query patterns.
- **No credentials in files** — OAuth handles authentication, no API keys or tokens stored
- **config.json contains user IDs** — the setup flow places it next to the skill file. If your skill directory is inside a git repo, add `config.json` to `.gitignore`.
- **Scoped MCP access** — locked to a single Supabase project via `project_ref`
