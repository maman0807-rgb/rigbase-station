-- ============================================================
-- FASE 7 — Kategori "Gejala" (early warning / investigasi)
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Tujuan:
--   Equipment menunjukkan gejala (suara aneh, getaran, asap, dll)
--   tapi BELUM rusak/berhenti operasi. Catat sebagai 'gejala' supaya:
--   - Tim ingat menyelidiki
--   - TIDAK menurunkan availability (alat masih jalan)
--   - TIDAK dihitung sebagai event kerusakan (MTBF tetap akurat)
--   - Eskalasi → ubah category ke 'breakdown'/'troubleshoot' kalau jadi rusak
-- ============================================================

ALTER TABLE downtime_events
  DROP CONSTRAINT IF EXISTS downtime_events_category_check;

ALTER TABLE downtime_events
  ADD CONSTRAINT downtime_events_category_check
  CHECK (category IN ('breakdown','troubleshoot','tunggu_spare','pm','mobilisasi','lainnya','gejala'));

-- Verifikasi:
-- SELECT con.conname, pg_get_constraintdef(con.oid)
-- FROM pg_constraint con
-- JOIN pg_class rel ON rel.oid = con.conrelid
-- WHERE rel.relname = 'downtime_events' AND con.conname LIKE '%category%';
