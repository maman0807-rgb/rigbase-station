-- ============================================================
-- Fix typo HM equipment FP-SP6TLJ-01: tersimpan 3105 (harusnya 310.5)
-- Catatan: "3.105" di tampilan cuma format ribuan Indonesia = 3105 asli.
-- Jalankan satu-satu (1 -> cek, 2 -> update, 3 -> verifikasi),
-- copy-paste hasilnya balik ke Claude kalau ada yang beda dari dugaan.
-- ============================================================

-- 1) Cek data saat ini dulu, pastikan memang 3105 sebelum diubah
SELECT id, tag_number, nama_equipment, running_hours, last_pm_hours,
       last_pm_date, updated_at, updated_by
FROM equipment
WHERE tag_number = 'FP-SP6TLJ-01';

-- 2) Update HM jadi 310.5 — hanya jalan kalau nilai lama memang 3105
--    (biar aman, nggak nimpa kalau ternyata sudah berubah)
UPDATE equipment
SET running_hours = 310.5
WHERE tag_number = 'FP-SP6TLJ-01'
  AND running_hours = 3105;

-- 3) Verifikasi hasil
SELECT id, tag_number, nama_equipment, running_hours, updated_at
FROM equipment
WHERE tag_number = 'FP-SP6TLJ-01';
