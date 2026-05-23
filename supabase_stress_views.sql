-- ============================================================
-- STRESS SCORE — VIEW AGREGASI (server-side)
-- Tujuan: dashboard tidak lagi menarik semua baris ke browser
-- (kebal batas 1000 baris PostgREST + selalu akurat & cepat).
-- security_invoker=true → RLS tabel dasar (Sr Mekanik+) tetap berlaku.
-- Jalankan di Supabase SQL Editor. Idempoten.
-- ============================================================

-- Akumulasi stress per EQUIPMENT (≤ jumlah equipment, jauh di bawah 1000)
CREATE OR REPLACE VIEW v_stress_per_equipment
WITH (security_invoker = true) AS
SELECT
  me.equipment_id,
  MAX(me.equipment_tag)              AS equipment_tag,
  MAX(me.equipment_name)            AS equipment_name,
  COUNT(*)                          AS mob_count,
  COALESCE(SUM(me.applied_score),0) AS total_stress,
  MAX(mr.mob_date)                  AS last_mob_date
FROM mobilization_equipment me
JOIN mobilization_records mr ON mr.id = me.mobilization_id
WHERE me.equipment_id IS NOT NULL
GROUP BY me.equipment_id;

-- Akumulasi stress per RIG (unit)
CREATE OR REPLACE VIEW v_stress_per_unit
WITH (security_invoker = true) AS
SELECT
  mr.unit_id,
  MAX(mr.unit_name)                 AS unit_name,
  COUNT(*)                          AS mob_count,
  COALESCE(SUM(mr.total_score),0)   AS total_stress,
  COUNT(*) FILTER (WHERE mr.category = 'low')      AS low_count,
  COUNT(*) FILTER (WHERE mr.category = 'medium')   AS medium_count,
  COUNT(*) FILTER (WHERE mr.category = 'high')     AS high_count,
  COUNT(*) FILTER (WHERE mr.category = 'critical') AS critical_count,
  MAX(mr.mob_date)                  AS last_mob_date
FROM mobilization_records mr
GROUP BY mr.unit_id;

GRANT SELECT ON v_stress_per_equipment TO authenticated;
GRANT SELECT ON v_stress_per_unit       TO authenticated;

-- ============================================================
-- SELESAI. Dashboard membaca kedua view ini (hasil ringkas).
-- Riwayat per-equipment = query mobilization_equipment difilter
-- equipment_id (sudah terindeks) — kecil & cepat.
-- ============================================================
