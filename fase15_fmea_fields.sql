-- ============================================================
-- FASE 15 — Field tambahan FMEA (kontrol, action priority, regulasi)
-- ============================================================
-- Jalankan di Supabase SQL Editor. Idempoten.
--
-- 3 kolom baru di fmea_entries:
--  - kontrol_saat_ini : kontrol/deteksi yg sedang berjalan (dasar nilai Detection)
--  - action_priority  : prioritas tindakan (Tinggi/Sedang/Rendah) — gaya AIAG-VDA AP
--  - catatan_regulasi : dasar/justifikasi regulasi untuk nilai Severity saat audit
-- ============================================================

ALTER TABLE fmea_entries
  ADD COLUMN IF NOT EXISTS kontrol_saat_ini TEXT,
  ADD COLUMN IF NOT EXISTS action_priority  TEXT,   -- 'Tinggi' | 'Sedang' | 'Rendah'
  ADD COLUMN IF NOT EXISTS catatan_regulasi TEXT;

COMMENT ON COLUMN fmea_entries.kontrol_saat_ini IS
  'Kontrol/deteksi yg saat ini berjalan (mis. gauge kontinu, function test berkala). Dasar penilaian Detection.';
COMMENT ON COLUMN fmea_entries.action_priority IS
  'Prioritas tindakan: Tinggi/Sedang/Rendah. Saran auto dari Severity/RPN/regulasi, bisa override manual.';
COMMENT ON COLUMN fmea_entries.catatan_regulasi IS
  'Dasar/justifikasi regulasi untuk nilai Severity (mis. kewajiban Migas). Penting saat audit.';

-- Verifikasi:
-- SELECT failure_mode, severity, action_priority, kontrol_saat_ini, catatan_regulasi
-- FROM fmea_entries LIMIT 5;
