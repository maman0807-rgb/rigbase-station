-- ============================================================
-- FASE 14 — SOS Baseline Reset (GOH / TOH)
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- Problem: Setelah GOH/TOH, komponen aus (ring, liner, bearing) diganti
-- baru → wear metal (Fe, Cu, Pb...) reset ke baseline rendah. Kalau SOS
-- pra-overhaul dicampur dgn pasca-overhaul, trend salah baca:
--   - grafik nampak "turun drastis" (efek overhaul, BUKAN kondisi membaik)
--   - 1-3 sample pertama pasca-GOH masih kehitung data lama → arah salah
--
-- Solusi: tandai tanggal reset baseline per component. Decision Engine
-- HANYA pakai sample dgn sampled_date >= baseline_reset_date. Sample lama
-- tetap disimpan (arsip) tapi dipisah di grafik (garis putus-putus).
-- ============================================================

ALTER TABLE equipment_components
  ADD COLUMN IF NOT EXISTS baseline_reset_date DATE,
  ADD COLUMN IF NOT EXISTS baseline_reset_type TEXT,   -- GOH | TOH | OTHER
  ADD COLUMN IF NOT EXISTS baseline_reset_note TEXT;

COMMENT ON COLUMN equipment_components.baseline_reset_date IS
  'Tanggal overhaul/reset baseline. Decision Engine hanya analisa sample >= tanggal ini. Sample lama diarsipkan & ditampilkan putus-putus di grafik.';
COMMENT ON COLUMN equipment_components.baseline_reset_type IS
  'Jenis reset: GOH (general overhaul), TOH (top overhaul), atau OTHER (ganti komponen mayor).';

-- Verifikasi:
-- SELECT name, baseline_reset_date, baseline_reset_type, baseline_reset_note
-- FROM equipment_components WHERE baseline_reset_date IS NOT NULL;
