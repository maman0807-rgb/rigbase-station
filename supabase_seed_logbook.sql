-- ============================================================
-- SEED DATA LOGBOOK MODULES (rate manpower default)
-- Langsung run di Supabase SQL Editor. Idempoten (skip kalau sudah ada).
-- ============================================================

INSERT INTO manpower_rates (position, rate_per_hour, rate_per_day)
SELECT * FROM (VALUES
  ('Supervisor',        187500, 1500000),
  ('Senior Mekanik',    125000, 1000000),
  ('Mekanik',            93750,  750000),
  ('Welder',            100000,  800000),
  ('Electrician',       106250,  850000),
  ('Helper',             56250,  450000),
  ('Vendor Specialist', 375000, 3000000)
) AS v(position, rate_per_hour, rate_per_day)
WHERE NOT EXISTS (SELECT 1 FROM manpower_rates LIMIT 1);

-- Cek hasil:
-- SELECT * FROM manpower_rates ORDER BY position;
