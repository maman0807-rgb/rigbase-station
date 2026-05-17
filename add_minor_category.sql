-- ============================================================
-- ALTER inspection_findings.category — tambah opsi 'Minor'
-- ============================================================
-- Sebelumnya: CHECK (category IN ('N/A', 'Major', 'Critical'))
-- Sekarang:   CHECK (category IN ('N/A', 'Minor', 'Major', 'Critical'))
-- ============================================================

BEGIN;

-- Drop constraint lama
ALTER TABLE inspection_findings
  DROP CONSTRAINT IF EXISTS inspection_findings_category_check;

-- Add constraint baru dengan Minor
ALTER TABLE inspection_findings
  ADD CONSTRAINT inspection_findings_category_check
  CHECK (category IN ('N/A', 'Minor', 'Major', 'Critical'));

-- Verifikasi
SELECT pg_get_constraintdef(oid) AS constraint_def
FROM pg_constraint
WHERE conname = 'inspection_findings_category_check';
-- Ekspektasi: CHECK ((category = ANY (ARRAY['N/A'::text, 'Minor'::text, 'Major'::text, 'Critical'::text])))

COMMIT;
