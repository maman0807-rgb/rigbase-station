-- ============================================================
-- Lanjutan investigasi: isi detail entry yang dobel, buat mastiin
-- itu duplikat persis atau dua pekerjaan beda yang harusnya digabung.
-- Jalankan SATU-SATU (jangan sekaligus), copy tiap hasilnya balik ke Claude.
-- ============================================================

-- 5) Isi lengkap 2 entry MR-KB150A tanggal 14 Agustus 2026 (harusnya 2 baris)
SELECT lh.tanggal, lh.id AS laporan_id, lh.created_at AS laporan_created_at,
       e.status_kerja, e.job_desc, e.notes, e.progress_pct, e.rh, e.created_at AS entry_created_at
FROM laporan_harian lh
JOIN laporan_harian_entries e ON e.laporan_id = lh.id
WHERE lh.tanggal = '2026-08-14' AND e.equipment_id = '38f379bb-84b4-47a4-9c62-2cae08cdb477'
ORDER BY e.created_at;

-- 6) Berapa laporan_harian yang ada di tanggal 14 Agustus 2026 (dugaan: 2 laporan
--    terpisah kayak kasus 1 September, bukan 1 laporan dgn entry dobel)
SELECT id, tanggal, sumber, status, created_at
FROM laporan_harian
WHERE tanggal = '2026-08-14'
ORDER BY created_at;

-- 7) Isi lengkap 2 entry MR-KB150C tanggal 1 Agustus 2026 (pola beda -- cuma unit ini doang dobel 5 hari)
SELECT lh.tanggal, lh.id AS laporan_id, lh.created_at AS laporan_created_at,
       e.status_kerja, e.job_desc, e.notes, e.progress_pct, e.rh, e.created_at AS entry_created_at
FROM laporan_harian lh
JOIN laporan_harian_entries e ON e.laporan_id = lh.id
WHERE lh.tanggal = '2026-08-01' AND e.equipment_id = 'a8c1d404-3beb-4b38-a4d0-1acee1721ac1'
ORDER BY e.created_at;
