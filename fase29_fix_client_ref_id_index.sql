-- ============================================================
-- FASE 29 — Fix bug fase27: index client_ref_id parsial gak bisa
-- dipakai ON CONFLICT-nya Supabase upsert().
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
--
-- Error yang muncul di app: "there is no unique or exclusion
-- constraint matching the ON CONFLICT specification"
--
-- Penyebab: index unique yang dibuat fase27 pakai syarat
-- "WHERE client_ref_id IS NOT NULL" (index parsial). Supabase JS
-- client (`upsert(row, {onConflict:'client_ref_id'})`) menghasilkan
-- SQL "ON CONFLICT (client_ref_id) DO NOTHING" TANPA klausa WHERE
-- yang sama persis — Postgres gak bisa mencocokkan itu ke index
-- parsial, jadi ditolak. Fix: ganti jadi index unique BIASA (tanpa
-- syarat WHERE). Ini tetap aman dipakai di kolom yang boleh kosong,
-- karena Postgres menganggap setiap NULL berbeda satu sama lain
-- (banyak baris client_ref_id=NULL tetap gak dianggap bentrok).
-- ============================================================

DROP INDEX IF EXISTS logbook_client_ref_id_uniq;
CREATE UNIQUE INDEX IF NOT EXISTS logbook_client_ref_id_uniq
  ON logbook(client_ref_id);

DROP INDEX IF EXISTS hm_photo_reports_client_ref_id_uniq;
CREATE UNIQUE INDEX IF NOT EXISTS hm_photo_reports_client_ref_id_uniq
  ON hm_photo_reports(client_ref_id);

-- Verifikasi:
SELECT indexname, indexdef FROM pg_indexes
WHERE indexname IN ('logbook_client_ref_id_uniq', 'hm_photo_reports_client_ref_id_uniq');
