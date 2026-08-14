-- ============================================================
-- eRAMHoist Fase 23 — Foto HM jadi bagian Revisi HM (via approval admin)
-- ============================================================
-- Sebelumnya Foto HM cuma laporan verifikasi terpisah (hm_photo_reports),
-- TIDAK pernah update equipment.running_hours -- mekanik jadi kerja 2x:
-- isi Foto HM + admin isi ulang manual "Revisi HM" di eRAMHoist.
--
-- Sekarang: Foto HM masuk antrian approval. Begitu ADMIN klik "Setujui"
-- di app Logbook, running_hours equipment ter-update OTOMATIS (setara
-- "Revisi HM" -- absolute set, bukan nambah, boleh turun kalau memang
-- itu bacaan fisik yang benar), + tercatat di activity_log + alert
-- Telegram, sama persis pola audit trail "Revisi HM" yang sudah ada.
-- Jalankan SEKALI di Supabase SQL Editor.
-- ============================================================

ALTER TABLE hm_photo_reports
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS review_note TEXT;

-- Data historis (sebelum fitur approval ini ada) dianggap sudah "selesai",
-- jangan tiba-tiba nongol di antrian pending admin.
UPDATE hm_photo_reports SET status = 'approved' WHERE status IS NULL;

-- RLS: admin boleh UPDATE (approve/reject). Read/insert sudah ada dari fase6.
DROP POLICY IF EXISTS hm_photo_reports_update ON hm_photo_reports;
CREATE POLICY hm_photo_reports_update ON hm_photo_reports FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT status, COUNT(*) FROM hm_photo_reports GROUP BY status;
