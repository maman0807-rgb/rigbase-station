-- ============================================================
-- Cek unit yang breakdown/troubleshoot berulang dalam 30 hari terakhir
-- (kasus DAMKAR-04: rusak → diperbaiki → 5 jam kemudian rusak lagi)
-- Jalankan di Supabase SQL Editor, copy-paste HASIL keduanya balik ke Claude.
-- ============================================================

-- 1) RINGKASAN — unit dengan >=2 kejadian breakdown/troubleshoot dalam 30 hari terakhir
SELECT
  e.tag_number,
  e.nama_equipment,
  COUNT(*) AS jumlah_kejadian_30hari
FROM downtime_events de
JOIN equipment e ON e.id = de.equipment_id
WHERE de.category IN ('breakdown', 'troubleshoot')
  AND de.start_at >= now() - interval '30 days'
GROUP BY e.tag_number, e.nama_equipment
HAVING COUNT(*) >= 2
ORDER BY jumlah_kejadian_30hari DESC;

-- 2) DETAIL — semua kejadian breakdown/troubleshoot 30 hari terakhir per unit,
--    plus jarak jam dari selesai perbaikan sebelumnya ke mulai rusak berikutnya
--    (kolom "jam_sejak_perbaikan_sebelumnya" kecil = tanda repair kemarin kemungkinan gak tuntas)
SELECT
  e.tag_number,
  e.nama_equipment,
  de.category,
  de.start_at,
  de.end_at,
  de.notes,
  ROUND(EXTRACT(EPOCH FROM (
    de.start_at - LAG(de.end_at) OVER (PARTITION BY de.equipment_id ORDER BY de.start_at)
  )) / 3600, 1) AS jam_sejak_perbaikan_sebelumnya
FROM downtime_events de
JOIN equipment e ON e.id = de.equipment_id
WHERE de.category IN ('breakdown', 'troubleshoot')
  AND de.equipment_id IN (
    SELECT de2.equipment_id
    FROM downtime_events de2
    WHERE de2.category IN ('breakdown', 'troubleshoot')
      AND de2.start_at >= now() - interval '30 days'
    GROUP BY de2.equipment_id
    HAVING COUNT(*) >= 2
  )
ORDER BY e.tag_number, de.start_at;
