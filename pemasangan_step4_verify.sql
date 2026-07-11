-- ============================================================
-- STEP 4 — Verifikasi (wajib sebelum dianggap selesai)
-- ============================================================

-- 4a. Tiap anak terpasang punya tepat SATU baris aktif
-- Harus KOSONG
SELECT anak_tag, COUNT(*)
FROM pemasangan
WHERE tanggal_lepas IS NULL
GROUP BY anak_tag
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 4b. HM hasil view cocok dengan HM anak existing (toleransi 0)
-- Kolom hm_running harus = anak.running_hours
-- Selisih signifikan → backfill salah kalibrasi
SELECT
  v.anak_tag,
  v.hm_running                  AS hm_dari_view,
  e.running_hours               AS hm_dari_equipment,
  v.hm_running - COALESCE(e.running_hours, 0) AS selisih,
  v.punya_meter_sendiri
FROM v_hm_anak_aktif v
JOIN equipment e ON e.tag_number = v.anak_tag
ORDER BY ABS(v.hm_running - COALESCE(e.running_hours, 0)) DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 4c. Tidak ada hm_running negatif (harus KOSONG)
SELECT *
FROM v_hm_anak_aktif
WHERE hm_running < 0;

-- ------------------------------------------------------------
-- 4d. Anak yang punya parent tapi belum ter-backfill (harus KOSONG)
SELECT e.tag_number, e.parent_equipment_id, e.follow_parent_hm
FROM equipment e
WHERE e.parent_equipment_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM pemasangan p
    WHERE p.anak_tag = e.tag_number
      AND p.tanggal_lepas IS NULL
  );

-- ------------------------------------------------------------
-- 4e. Ringkasan final
SELECT
  'Total pemasangan aktif'    AS info, COUNT(*)::text AS nilai FROM pemasangan WHERE tanggal_lepas IS NULL
UNION ALL
SELECT 'Total anak di equipment', COUNT(*)::text FROM equipment WHERE parent_equipment_id IS NOT NULL
UNION ALL
SELECT 'HM negatif di view',      COUNT(*)::text FROM v_hm_anak_aktif WHERE hm_running < 0;
