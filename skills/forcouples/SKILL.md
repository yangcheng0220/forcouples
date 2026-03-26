---
name: forcouples
description: "Couples expense tracking via Supabase. Log expenses, query spending, and manage shared finances. Use when the user mentions expenses, spending, logging purchases, checking balances, or asks how much was spent."
allowed-tools: mcp__supabase__execute_sql mcp__supabase__list_tables Read Bash(date:*)
argument-hint: "[log|query] or natural language"
---

# ForCouples — Couples Expense Tracking

Track shared and personal expenses between partners using Supabase.

Each expense has:
- **type** — `personal` (only visible to the person who logged it) or `shared` (visible to both partners)
- **description** — what was bought
- **amount** — how much (can be null if unknown)
- **category** — matched from history or the categories table
- **payer** — who paid out of pocket (can differ from who logged it)
- **date** — when it happened

## Getting Started

Read `config.json` from the same directory as this skill file. If it does not exist, tell the user to run the setup flow first (see SETUP.md in the forcouples repo).

Config fields:
- `current_user_id`, `current_user_name` — the user in this session
- `partner_user_id`, `partner_user_name` — their partner
- `couple_id` — the couple record ID

## Data Visibility

Every query and log operation MUST follow this rule:
- **Personal expenses:** only visible to the person who created them (`created_by = current_user_id`)
- **Shared expenses:** visible to both partners (`type = 'shared'`)

Never expose a partner's personal expenses. All WHERE clauses for listing or aggregating expenses must filter to:
```sql
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
```

---

## Log

Add or edit expenses. Triggered by descriptions of spending or `/forcouples log`.

Users only need to describe what happened — "coffee at 7-11" is enough. Amount, category, date, and type are all inferred from context or prompted for if needed. Never require structured input.

### Parsing

Extract from natural language:
- **description** (required) — what was bought/paid for
- **amount** — number if mentioned, null if not (null is acceptable)
- **type** — `shared` if the partner's name or relationship words (partner, girlfriend, boyfriend, etc.) appear, otherwise `personal`
- **payer** — `partner_user_id` if input indicates partner paid, otherwise `current_user_id`
- **date** — run `date +"%Y-%m-%d"` via Bash. Use a mentioned date if one is provided.
- **category** — match against history (see below)
- **created_by** — always `current_user_id`

### Category matching

Query past expenses for similar descriptions:

```sql
SELECT description, category, COUNT(*) AS freq
FROM expenses
WHERE similarity(description, 'USER_INPUT') > 0.4
GROUP BY description, category
ORDER BY freq DESC
LIMIT 5;
```

If a strong match exists, use it. If no match, fall back to the categories table:

```sql
SELECT name FROM categories ORDER BY name;
```

Pick the closest fit or ask the user to choose.

### Confirmation

Display all fields before inserting. Flag missing values inline but do not block on them:

```
Logging: "lunch at 7-11" → Food (matched 12 similar)
Amount: $85 | Date: 2026-03-25 | Type: personal
Confirm? [y/n]
```

After confirmation:

```sql
INSERT INTO expenses (type, date, payer, description, amount, category, created_by)
VALUES ('personal', '2026-03-25', 'USER_ID', 'lunch at 7-11', 85, 'Food', 'USER_ID')
RETURNING id, type, date, description, amount, category;
```

### Editing

For updates ("change the last one", "update amount to 120"), find the expense and update:

```sql
UPDATE expenses SET amount = 120, updated_at = NOW()
WHERE id = 'EXPENSE_ID' RETURNING *;
```

---

## Query

Fetch and display expense data. Triggered by questions about spending or `/forcouples query`.

### Defaults

- Timeframe: last 7 days unless specified
- Order: date DESC
- Limit: 20 rows

### Listing expenses

```sql
SELECT date, type, description, amount, category
FROM expenses
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC
LIMIT 20;
```

Display as a markdown table.

### Balance

Who owes who — positive means the partner owes the current user:

```sql
SELECT COALESCE(SUM(CASE
  WHEN payer = '{current_user_id}' THEN amount
  ELSE -amount
END) * 0.5, 0) AS balance
FROM expenses
WHERE type = 'shared'
AND date >= CURRENT_DATE - INTERVAL '30 days';
```

Default is last 30 days. For all-time balance, drop the date filter. Assumes 50/50 split — adapt the multiplier if the couple splits differently.

### Category breakdown

```sql
SELECT category, COUNT(*) AS count, SUM(amount) AS total
FROM expenses
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY category
ORDER BY total DESC;
```

### Display rules

- Monetary values: always 2 decimal places (`$1,234.50`)
- All aggregation must come from SQL — never manually sum rows

