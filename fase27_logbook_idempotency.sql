-- ============================================================
-- FASE 27 — Idempotency key untuk submission dari app Logbook
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
--
-- Latar belakang (audit 2026-08-14 app Logbook): submission (baik
-- lewat antrian offline maupun jalur online langsung) tidak punya
-- proteksi kalau retry terjadi -- misal: 2 tab offline sama-sama
-- sinkron antrian yang sama, atau insert sukses di server tapi
-- respons gak sampai ke HP (sinyal lemah) lalu user disuruh app-nya
-- sendiri buat "coba lagi". Kolom client_ref_id ini diisi UUID yang
-- di-generate SEKALI di browser per percobaan submit, dikirim bareng
-- data-nya. Kalau insert yang sama (client_ref_id sama) coba masuk
-- lagi, database otomatis skip -- gak perlu logic rumit di client.
-- ============================================================

ALTER TABLE logbook ADD COLUMN IF NOT EXISTS client_ref_id UUID;
CREATE UNIQUE INDEX IF NOT EXISTS logbook_client_ref_id_uniq
  ON logbook(client_ref_id) WHERE client_ref_id IS NOT NULL;

ALTER TABLE hm_photo_reports ADD COLUMN IF NOT EXISTS client_ref_id UUID;
CREATE UNIQUE INDEX IF NOT EXISTS hm_photo_reports_client_ref_id_uniq
  ON hm_photo_reports(client_ref_id) WHERE client_ref_id IS NOT NULL;

-- Verifikasi:
SELECT table_name, column_name FROM information_schema.columns
WHERE column_name = 'client_ref_id' AND table_name IN ('logbook', 'hm_photo_reports');
