-- ============================================================
-- FASE 26 — Fungsi atomic buat nambah running_hours (KM carrier)
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
--
-- Latar belakang: saveMobilization() di index.html nambah KM carrier
-- dengan baca-dulu-tulis (`current + jarak`) di sisi client — kalau
-- 2 mobilisasi submit berdekatan waktu, salah satu jarak bisa ke-timpa
-- diam-diam (race condition baca-stale). Fungsi ini pindahin
-- penambahan ke DALAM 1 statement UPDATE di database (atomic), gak
-- peduli berapa banyak client yang baca nilai lama bersamaan.
-- Bukan SECURITY DEFINER — RLS equipment tetap berlaku normal,
-- cuma bikin cara nambahnya aman dari race.
-- ============================================================

CREATE OR REPLACE FUNCTION increment_running_hours(p_equipment_id UUID, p_delta NUMERIC)
RETURNS NUMERIC AS $$
  UPDATE equipment
  SET running_hours = COALESCE(running_hours, 0) + p_delta
  WHERE id = p_equipment_id
  RETURNING running_hours;
$$ LANGUAGE SQL;
