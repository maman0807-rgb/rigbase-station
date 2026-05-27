-- ============================================================
-- eRAMHoist Fase 6B — Tambah event_date di downtime_photos
-- Untuk record tanggal kejadian sebenarnya (beda dari uploaded_at)
-- Jalankan di Supabase SQL Editor.
-- ============================================================

ALTER TABLE downtime_photos
  ADD COLUMN IF NOT EXISTS event_date DATE DEFAULT CURRENT_DATE;

-- backfill record existing pakai tanggal upload (kalau ada)
UPDATE downtime_photos SET event_date = uploaded_at::date WHERE event_date IS NULL;

-- verify
SELECT 'downtime_photos' AS tabel, COUNT(*) AS jumlah, COUNT(event_date) AS ada_event_date FROM downtime_photos;
