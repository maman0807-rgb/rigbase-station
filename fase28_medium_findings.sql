-- ============================================================
-- FASE 28 — Sisa temuan Medium dari audit 2026-08-14
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
-- ============================================================

-- ------------------------------------------------------------
-- 1) stock_transactions INSERT WITH CHECK(true) — siapa pun yang login
--    bisa nulis baris pergerakan stok palsu (gak bisa ubah stok fisik,
--    tapi bisa ngotorin jejak audit). Kunci ke is_gudang() juga,
--    konsisten dengan tabel audit_gudang/audit_temuan.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "stocktx_insert" ON stock_transactions;
CREATE POLICY "stocktx_insert" ON stock_transactions
  FOR INSERT TO authenticated WITH CHECK (is_gudang());

-- ------------------------------------------------------------
-- 2) payroll_employees — field gaji gak ada batas non-negatif (beda
--    dari payroll_kasbon yang sudah CHECK(jumlah > 0)). Salah ketik
--    minus lolos bersih, ngacauin PPh21/BPJS sebulan penuh.
-- ------------------------------------------------------------
ALTER TABLE payroll_employees
  ADD CONSTRAINT chk_gaji_pokok_nonneg     CHECK (gaji_pokok >= 0),
  ADD CONSTRAINT chk_tunj_jabatan_nonneg   CHECK (tunj_jabatan >= 0),
  ADD CONSTRAINT chk_tunj_transport_nonneg CHECK (tunj_transport >= 0),
  ADD CONSTRAINT chk_tunj_makan_nonneg     CHECK (tunj_makan >= 0),
  ADD CONSTRAINT chk_tunj_lainnya_nonneg   CHECK (tunj_lainnya >= 0);
-- Catatan: kalau ada baris existing yang somehow sudah minus, ALTER TABLE
-- ini bakal GAGAL dan kasih tau baris mana. Kalau itu terjadi, betulkan
-- dulu datanya manual baru jalankan ulang bagian ini.

-- ------------------------------------------------------------
-- Verifikasi:
-- ------------------------------------------------------------
SELECT policyname, cmd, with_check FROM pg_policies
WHERE tablename = 'stock_transactions' AND policyname = 'stocktx_insert';

SELECT conname FROM pg_constraint
WHERE conrelid = 'payroll_employees'::regclass AND conname LIKE 'chk_%nonneg';
