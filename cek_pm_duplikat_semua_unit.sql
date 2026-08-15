-- ============================================================
-- Cek SEMUA equipment yang punya "Catat PM Selesai" duplikat
-- (pola bug yang sama dengan TRANS-H35KD: submit dobel dari 1
-- klik menghasilkan >1 baris downtime_events kembar)
-- Jalankan di Supabase SQL Editor, kirim hasilnya ke Claude.
-- ============================================================

SELECT
  e.tag_number,
  e.nama_equipment,
  de.notes,
  de.start_at,
  COUNT(*) AS jumlah_duplikat,
  MIN(de.created_at) AS pertama_dicatat,
  MAX(de.created_at) AS terakhir_dicatat,
  array_agg(de.id) AS ids
FROM downtime_events de
JOIN equipment e ON e.id = de.equipment_id
WHERE de.category = 'pm'
GROUP BY e.tag_number, e.nama_equipment, de.notes, de.start_at
HAVING COUNT(*) > 1
ORDER BY jumlah_duplikat DESC, e.tag_number;
