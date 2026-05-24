-- ============================================================
-- CLEANUP: hapus data logbook yang ter-import berulang (3x).
-- Setelah run ini, jalankan supabase_data_import.sql HANYA SEKALI.
-- ============================================================
-- Aman: hanya kosongkan tabel modul logbook. TIDAK menyentuh
-- equipment / parent_units / categories / inspection RigBase.
-- ============================================================

TRUNCATE materials, stock_transactions, daily_logs, pm_schedules;
DELETE FROM manpower_rates;

-- Verifikasi semua sudah 0:
SELECT 'materials' AS tabel, count(*) FROM materials
UNION ALL SELECT 'daily_logs', count(*) FROM daily_logs
UNION ALL SELECT 'stock_transactions', count(*) FROM stock_transactions
UNION ALL SELECT 'pm_schedules', count(*) FROM pm_schedules
UNION ALL SELECT 'manpower_rates', count(*) FROM manpower_rates;
