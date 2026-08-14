-- Siapa yang submit/update Laporan Harian PM tanggal 5 Agustus 2026
-- untuk TL-KB150A (yang keliru catat RH 1.415,2)

SELECT lh.tanggal, lh.status AS status_laporan, lh.tim,
       lh.created_by, p.full_name AS dibuat_oleh, p.email,
       e.status_kerja, e.rh, e.job_desc, e.notes
FROM laporan_harian_entries e
JOIN laporan_harian lh ON lh.id = e.laporan_id
LEFT JOIN profiles p ON p.id = lh.created_by
WHERE e.equipment_id = (SELECT id FROM equipment WHERE tag_number = 'TL-KB150A')
  AND lh.tanggal = '2026-08-05';
