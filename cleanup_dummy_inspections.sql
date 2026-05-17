-- ============================================================
-- CLEANUP: Hapus dummy siklus SIKLUS-2026-001 & SIKLUS-2026-002
-- ============================================================
-- Hapus dummy siklus yang aku bikin di awal testing.
-- Keep SIKLUS-2026-003 (data real dari PDF 15 Mei 2026).
-- Plus hapus maintenance_log auto-generated dari findings 001 & 002.
-- Aman dijalankan ulang (idempoten).
-- ============================================================

BEGIN;

-- 1. Hapus maintenance_log yang auto-generated dari findings 001 & 002
DELETE FROM maintenance_log
WHERE id IN (
  SELECT maintenance_log_id
  FROM inspection_findings
  WHERE inspection_id IN (
    SELECT id FROM inspections WHERE inspection_code IN ('SIKLUS-2026-001', 'SIKLUS-2026-002')
  )
  AND maintenance_log_id IS NOT NULL
);

-- 2. Hapus siklus (auto-cascade ke inspection_findings karena ON DELETE CASCADE)
DELETE FROM inspections WHERE inspection_code IN ('SIKLUS-2026-001', 'SIKLUS-2026-002');

-- 3. Verifikasi sisa data
SELECT 'Sisa Siklus' AS info, COUNT(*) AS count FROM inspections
UNION ALL
SELECT 'Sisa Findings', COUNT(*) FROM inspection_findings
UNION ALL
SELECT 'Maintenance Log dari Inspection', COUNT(*) FROM maintenance_log WHERE maintenance_type LIKE 'Inspection Closing -%';
-- Ekspektasi setelah cleanup:
--   Sisa Siklus: 1 (cuma SIKLUS-2026-003)
--   Sisa Findings: 8 (dari SIKLUS-2026-003 yang 8 temuan)
--   Maintenance Log dari Inspection: 0 (semua dari 001/002 udah keep di-delete; 003 semua status Open)

COMMIT;
