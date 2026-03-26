-- ForCouples — Database Setup
-- Run this in your Supabase project's SQL Editor

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tables
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_initials TEXT NOT NULL DEFAULT 'U',
  color TEXT NOT NULL DEFAULT 'bg-gray-600',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS couples (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_a UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_a, user_b)
);

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- payer = who paid out of pocket. created_by = who logged it. These can differ.
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL CHECK (type IN ('personal', 'shared')),
  date DATE NOT NULL,
  payer UUID NOT NULL REFERENCES auth.users(id),
  description TEXT NOT NULL,
  amount NUMERIC(10, 2),
  category TEXT,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_couples_user_b ON couples(user_b);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);
CREATE INDEX IF NOT EXISTS idx_expenses_payer ON expenses(payer);

-- Helper functions
CREATE OR REPLACE FUNCTION get_partner_id(my_user_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT CASE
    WHEN user_a = my_user_id THEN user_b
    WHEN user_b = my_user_id THEN user_a
    ELSE NULL
  END
  FROM public.couples
  WHERE user_a = my_user_id OR user_b = my_user_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Triggers
DROP TRIGGER IF EXISTS expenses_updated_at ON expenses;
CREATE TRIGGER expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Row Level Security
-- RLS protects the app (authenticated client). The Supabase MCP uses
-- a service role that bypasses RLS — privacy there is enforced by the
-- skill's WHERE clauses (see SKILL.md Data Visibility section).
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View own and partner profile" ON profiles;
CREATE POLICY "View own and partner profile" ON profiles
  FOR SELECT TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR id = (SELECT get_partner_id((SELECT auth.uid())))
  );

DROP POLICY IF EXISTS "Update own profile" ON profiles;
CREATE POLICY "Update own profile" ON profiles
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "View own couple" ON couples;
CREATE POLICY "View own couple" ON couples
  FOR SELECT TO authenticated
  USING (
    user_a = (SELECT auth.uid())
    OR user_b = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "View categories" ON categories;
CREATE POLICY "View categories" ON categories
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Manage categories" ON categories;
CREATE POLICY "Manage categories" ON categories
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "View relevant expenses" ON expenses;
CREATE POLICY "View relevant expenses" ON expenses
  FOR SELECT TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR (type = 'shared' AND created_by = (SELECT get_partner_id((SELECT auth.uid()))))
  );

DROP POLICY IF EXISTS "Create expenses" ON expenses;
CREATE POLICY "Create expenses" ON expenses
  FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Update relevant expenses" ON expenses;
CREATE POLICY "Update relevant expenses" ON expenses
  FOR UPDATE TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR (type = 'shared' AND created_by = (SELECT get_partner_id((SELECT auth.uid()))))
  );

DROP POLICY IF EXISTS "Delete relevant expenses" ON expenses;
CREATE POLICY "Delete relevant expenses" ON expenses
  FOR DELETE TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR (type = 'shared' AND created_by = (SELECT get_partner_id((SELECT auth.uid()))))
  );

-- Realtime (optional — for the PWA frontend)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'expenses'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE expenses;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'categories'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE categories;
  END IF;
END $$;

SELECT 'Setup complete!' AS status;
