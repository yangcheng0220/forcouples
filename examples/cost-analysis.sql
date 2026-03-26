-- Example: True Cost Analysis
--
-- "True Cost" = personal expenses at 100% + shared expenses at 50%.
-- This gives each partner's actual spending, accounting for the split.
-- Adjust the 0.5 multiplier if the couple splits differently.

-- True cost for a given period
SELECT SUM(CASE
  WHEN type = 'personal' THEN amount
  WHEN type = 'shared' THEN amount * 0.5
END) AS true_cost
FROM expenses
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
AND date >= CURRENT_DATE - INTERVAL '30 days';

-- Total paid (cash out of pocket, regardless of split)
SELECT SUM(amount) AS total_paid
FROM expenses
WHERE payer = '{current_user_id}'
AND date >= CURRENT_DATE - INTERVAL '30 days';

-- Category breakdown by true cost
SELECT category, COUNT(*) AS count,
  SUM(CASE
    WHEN type = 'personal' THEN amount
    WHEN type = 'shared' THEN amount * 0.5
  END) AS true_cost
FROM expenses
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
AND date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY category
ORDER BY true_cost DESC;

-- Monthly summary with true cost and total paid
SELECT
  DATE_TRUNC('month', date) AS month,
  SUM(CASE
    WHEN type = 'personal' THEN amount
    WHEN type = 'shared' THEN amount * 0.5
  END) AS true_cost,
  SUM(CASE WHEN payer = '{current_user_id}' THEN amount ELSE 0 END) AS total_paid
FROM expenses
WHERE (created_by = '{current_user_id}'
  OR (type = 'shared' AND created_by = '{partner_user_id}'))
GROUP BY DATE_TRUNC('month', date)
ORDER BY month DESC;
