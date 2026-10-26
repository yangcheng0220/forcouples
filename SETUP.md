# ForCouples — Setup

Setup flow for an experimental agent-driven expense tool. Developer MCP does not enforce partner privacy; this is not a secure multi-user setup guide.

## Read Before Setup

Read the [privacy limits](README.md#privacy-limits) first. Start with synthetic data in an isolated test project before deciding whether the access model fits your use.

Supabase MCP uses developer permissions, not the identity in `config.json`. Privileged SQL bypasses ordinary RLS guarantees. Creating Auth users and changing config does not restrict that SQL to either partner. Skill filters are workflow instructions, not enforceable partner privacy. Project scoping limits projects, not rows. Categories are global and all authenticated users can manage them, subject to grants.

The steps below let you explore the workflow. They do not establish a safe production deployment.

**Action markers:**
- **[USER]** — user acts in a browser or UI. Agent explains what to do and waits.
- **[AGENT]** — agent executes directly (SQL, file writes). Confirm with user before running.
- **[AGENT+USER]** — agent needs information from the user before executing.

---

## Step 1: Create Supabase Project [USER]

ForCouples needs its own Supabase project. Even if the user has existing Supabase projects, create a new one for ForCouples to keep data isolated.

**New to Supabase:**
1. Go to https://supabase.com/dashboard and sign up (email verification may be required)
2. Create an organization — free plan is sufficient
3. Create a new project inside that organization — name it "ForCouples" or similar
4. Set a database password and save it (not needed for this setup — MCP uses OAuth — but useful for direct database access later)
5. Select the closest region
6. Wait for provisioning to complete (1-2 minutes)

**Existing Supabase user:**
1. Go to the dashboard and click "New Project"
2. Create it under an existing organization or create a new one
3. Same as above — name it, set password, pick region, wait

---

## Step 2: Configure Supabase MCP [AGENT+USER]

The agent needs database access via Supabase MCP.

If the user already has Supabase MCP configured, verify it's connected to the ForCouples project (not a different one). If connected to a different project, a new MCP configuration is needed for this project.

**Setting up MCP:**

Direct the user to the Supabase MCP setup page:

https://supabase.com/docs/guides/getting-started/mcp

On that page, the user should:
1. Select their ForCouples project
2. Leave read-only OFF (the skill needs write access to log expenses)
3. Leave feature groups at the default (all features except Storage)
4. Select their AI coding tool
5. Follow the generated install instructions for their specific tool

The page generates the exact MCP server URL and shows tool-specific setup steps — no need to manually construct URLs or edit config files.

After install, the tool will prompt a browser window for OAuth login to Supabase. This authenticates developer access. It does not establish an expense-user session. The MCP client manages OAuth credentials; do not commit them.

**Note:** Some tools require a session restart after MCP install for the connection to become available. If the verification query below fails, ask the user to restart their session and resume setup.

**Verification:**

```sql
SELECT current_database();
```

If this fails, do not continue. Direct the user back to: https://supabase.com/docs/guides/getting-started/mcp

---

## Step 3: Create Tables [AGENT]

Check if tables already exist:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN ('profiles', 'couples', 'categories', 'expenses')
ORDER BY table_name;
```

If all four tables exist, skip to Step 4. Otherwise, read `setup.sql` from this repo and execute it via the Supabase MCP `execute_sql` tool. The script uses conditional creation and replaces named policies, but is not a migration or a guarantee of compatibility with an existing database. Use a fresh isolated test project; do not run it against an existing deployment.

Verify all tables were created:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN ('profiles', 'couples', 'categories', 'expenses')
ORDER BY table_name;
```

All four tables must be present. If any are missing, re-run `setup.sql`.

---

## Step 4: Create User Accounts [AGENT+USER]

The schema uses two Supabase Auth accounts to attribute sample records and express intended visibility for authenticated application requests. They do not restrict developer MCP access.

Use test accounts and synthetic identities only. Explain that developer MCP can read either account's records regardless of their personal/shared label.

For known test account IDs, check only those accounts. If the IDs are not known, have the user identify their synthetic accounts in the dashboard first:

```sql
SELECT id FROM auth.users WHERE id IN ('<TEST_USER_A_ID>', '<TEST_USER_B_ID>');
```

**If test users exist:** Ask which two test accounts form the sample couple. Do not display unrelated account details.

**If fewer than two:** The user must create accounts in the Supabase dashboard:
1. Go to Authentication > Users > Add user
2. Create an account for each partner with email and password

Wait for the user to confirm, then re-query.

---

## Step 5: Create Profiles [AGENT+USER]

Ask for each person's display name, then execute:

```sql
INSERT INTO profiles (id, name, email)
VALUES ('<USER_A_ID>', '<Name A>', '<email_a>'), ('<USER_B_ID>', '<Name B>', '<email_b>')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
```

---

## Step 6: Link as Couple [AGENT]

```sql
INSERT INTO couples (user_a, user_b) VALUES ('<USER_A_ID>', '<USER_B_ID>')
RETURNING id;
```

Save the returned couple ID for Step 9.

---

## Step 7: Add Categories [AGENT+USER]

Ask what expense categories the user wants. If unsure, suggest defaults:

```sql
INSERT INTO categories (name) VALUES
  ('Food'), ('Transport'), ('Entertainment'), ('Shopping'),
  ('Utilities'), ('Rent'), ('Medical'), ('Miscellaneous');
```

Categories can always be added or removed later.

---

## Step 8: Install Skill [AGENT+USER]

Install `skills/forcouples/SKILL.md` from this repo into the user's AI coding tool environment.

Ask the user whether they want it available in all projects (personal scope) or just one specific project (project scope). If project scope, ask which project — install into that project's directory, not into this cloned repo.

Use the tool's native skill directory structure — the agent knows where skills are stored for its own tool. Create the directory if it doesn't exist, then copy the file. Place `config.json` (generated in Step 9) in the same directory as SKILL.md.

---

## Step 9: Generate Config [AGENT+USER]

Ask which of the two users is "me" (the one setting this up now).

Explain: "Config selects the identities used in example filters. It does not authenticate an expense user or restrict developer MCP access. Changing or ignoring it can expose other records."

Write `config.json` next to the installed SKILL.md:

```json
{
  "current_user_id": "<chosen user's UUID>",
  "current_user_name": "<chosen user's name>",
  "partner_user_id": "<other user's UUID>",
  "partner_user_name": "<other user's name>",
  "couple_id": "<couple UUID from Step 6>"
}
```

`config.json` contains real user IDs. If the skill directory is inside a git repo, check if a `.gitignore` exists in the repo root. If it does, append `config.json` to it. If not, create one with `config.json` as the only entry.

---

## Step 10: Verify [AGENT]

Test the installed skill with a fictional purchase and synthetic identities only. This verifies the workflow, not authorization or partner privacy.

If it works, setup is complete. The cloned repo is no longer needed — the skill and config are installed in the user's environment. The user can delete the cloned folder.

---

## Partner Access — Developer Permissions

Inviting a partner to the Supabase organization as a Developer grants developer access. A separate MCP connection and config do not isolate personal expenses. Separate OAuth logins do not turn developer SQL into requests governed by each expense user's RLS policies.

Do not use a developer invitation as private partner access. A multi-user replacement needs a restricted authenticated interface and tested authorization rules before any real data is added. See [Supabase access control](https://supabase.com/docs/guides/platform/access-control) and [MCP security guidance](https://supabase.com/docs/guides/ai-tools/mcp#security-risks).
