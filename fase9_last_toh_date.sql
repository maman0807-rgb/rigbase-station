-- ============================================================
-- FASE 9 (opsional) — Tambah kolom last_toh_date
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Konteks: equipment table sudah punya last_pm_date, last_goh_date.
-- Tapi last_toh_date belum ada. Tambah untuk konsistensi audit trail
-- (tanggal kapan TOH terakhir dilakukan, terpisah dari jam).
-- ============================================================

ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS last_toh_date DATE;

-- Verifikasi:
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name='equipment' AND column_name LIKE 'last_%';
