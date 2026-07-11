-- ============================================================
-- SIKLUS INSPEKSI CAT III — RIG BW KB150.C — DESEMBER 2025
-- ============================================================
-- Sumber: 5 laporan "Daily Inspection CAT III" (5-9 Des 2025),
--   PT PJ-Tek Mandiri, Inspector: Yandi Handiyan
--   + Berita Acara penggantian Sheave Traveling Block (18 Des 2025)
-- inspection_code : SIKLUS-2025-001 (belum ada SIKLUS-2025-* lain di DB,
--   jadi ini nomor pertama untuk tahun 2025 — mengikuti tahun inspeksi asli)
-- parent_unit_id  : 5 (BW KB150.C)
--
-- CATATAN PENTING — REVISI STATUS (instruksi tambahan dari user):
--   SEMULA rencana: N/A -> Closed, Major/Critical -> Open (kecuali 2 baris
--   Traveling Sheave & Bearing Sheave Crown -> Closed via Berita Acara).
--   REVISI FINAL: SEMUA 71 baris = 'Closed' (inspeksi historis, seluruh
--   temuan sudah ditindaklanjuti per konfirmasi user):
--     - category = 'N/A'                         -> Closed, tgl_closed NULL, catatan NULL
--     - category = 'Major'/'Critical' (25 baris,  -> Closed, tgl_closed = tgl_ditemukan,
--       selain 2 baris sheave)                       pic_perbaikan NULL, catatan = standar
--                                                     (lihat CLOSED_NOTE di bawah)
--     - 'Traveling Sheave' & 'Bearing Sheave Crown'
--       (Hari 5, baris 26 & 27)                   -> Closed, tgl_closed = 2025-12-18,
--                                                     pic_perbaikan = 'RAM Hoist & Heavy
--                                                     Equipment', catatan spesifik Berita Acara
--
-- CATATAN: karena semua baris di-INSERT langsung dengan status='Closed'
-- (bukan INSERT Open lalu UPDATE ke Closed), trigger trg_finding_closed
-- (create_maintenance_from_finding, yang hanya jalan BEFORE UPDATE saat
-- Open->Closed) TIDAK akan terpicu. Ini disengaja — tidak akan ada
-- maintenance_log otomatis dibuat dari baris-baris ini.
--
-- CATATAN JUMLAH BARIS: total baris finding hasil hitung ulang dari data
-- 5 hari = 71 baris (bukan 68 seperti perkiraan awal). Rincian: Hari1=12,
-- Hari2=5, Hari3=9, Hari4=18, Hari5=27 => 71. Breakdown kategori hasil
-- hitung: N/A=48 (cocok dengan ekspektasi awal), Major=4 (cocok), tapi
-- Critical=19 (bukan 16 seperti perkiraan awal) — selisih +3 baris Critical
-- yang sebelumnya tidak terhitung. Query verifikasi di bagian bawah file
-- ini sudah disesuaikan dengan angka hasil hitung ulang (N/A=48, Major=4,
-- Critical=19, Total=71).
--
-- MATCHING equipment_id: dilakukan KONSERVATIF terhadap 44 equipment
-- bertag KB150C. 34 dari 71 baris berhasil di-match ke equipment_id yang
-- jelas; 37 baris sisanya (alat kerja lepas/tool generik atau equipment
-- tanpa record jelas di tabel equipment) dibiarkan equipment_id NULL dan
-- hanya mengandalkan equipment_name_snapshot.
--
-- FOTO (photos_before): diekstrak dari 5 PDF "Daily Report" (pdfimages),
-- dicocokkan visual per baris No./Equipment persis sesuai tabel di tiap
-- PDF (tabel PDF dan urutan no_urut di sini identik 1:1), lalu diupload
-- ke Supabase Storage bucket 'inspection-photos' di path
-- SIKLUS-2026-005/<tanggal>/no<no_urut>-<seq>.png. Total 100 foto
-- berhasil diupload, tersebar di 71 baris (setiap baris finding di
-- laporan PDF punya minimal 1 foto dokumentasi; baris Major/Critical
-- umumnya 2-5 foto). Tidak ada baris yang di-skip — seluruh 71 baris
-- foto-nya jelas & tidak ambigu karena tabel PDF sumber sudah particular
-- per baris (bukan galeri foto lepas yang perlu ditebak).
-- Berita Acara Traveling Block TIDAK diekstrak fotonya (dokumen
-- teks/tanda tangan, tidak ada foto temuan) sesuai arahan.
--
-- AMAN dijalankan SEKALI sebagai 1 statement atomik (BEGIN...COMMIT).
-- ============================================================

BEGIN;

WITH ins AS (
  INSERT INTO inspections (
    inspection_code, parent_unit_id, kategori_inspeksi,
    client, service, rig_type, manufacturer, year_manufactured, model_serial,
    height_of_mast, hook_load, power_hp, place_of_inspection,
    start_date, end_date, pi_company, rig_inspector,
    status, progress_akumulatif, catatan
  ) VALUES (
    'SIKLUS-2025-001', 5, 'Cat 3',
    'PT Pertamina EP Zona 4 Field Prabumulih', 'Service Rig', 'Truck Mounted',
    'PT Petrodrill Manufaktur Indonesia', 2016, 'PD30-M075-069',
    21.03, 34.02, 200, 'Prabumulih',
    '2025-12-05', '2025-12-09', 'PT PJ-Tek Mandiri', 'Yandi Handiyan',
    'Completed', 100,
    'Disetujui oleh Rosy Anzrianto (5-6 Des) dan Sainal Abidin (8-9 Des), PT Pertamina EP Zona 4 Field Prabumulih.'
  )
  RETURNING id
)
INSERT INTO inspection_findings (
  inspection_id, no_urut, equipment_id, equipment_name_snapshot, qty, bagian,
  category, finding, mpi_result, acceptance_criteria, recommendation,
  tgl_ditemukan, status, tgl_closed, pic_perbaikan, catatan, photos_before
)
SELECT ins.id, v.*
FROM ins, (VALUES
  (1, NULL::uuid, 'Elevator Tubing 2 3/8''''', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.3.2.4', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no01-1.png"]'::jsonb),
  (2, NULL::uuid, 'Elevator Tubing 2 7/8''''', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.3.2.4', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no02-1.png"]'::jsonb),
  (3, NULL::uuid, 'Elevator Tubing 3 1/2''''', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.3.2.4', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no03-1.png"]'::jsonb),
  (4, NULL::uuid, 'Elevator Sucker Rod', '5ea', NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.3.2.4', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no04-1.png"]'::jsonb),
  (5, NULL::uuid, 'Back Up Tong', '3ea', NULL, 'N/A', NULL, 'No Discontinuity', 'API 7L Sect. 4.1.3', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no05-1.png"]'::jsonb),
  (6, '1cf76526-7919-4a5c-bb39-767babba3105'::uuid, 'Spider Slip 3 1/2''''', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API 7L Sect. 4.1.3', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no06-1.png"]'::jsonb),
  (7, NULL::uuid, 'Ridgid Pipe', '6ea', NULL, 'N/A', NULL, 'No Discontinuity', 'API 7L Sect. 4.1.3', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no07-1.png"]'::jsonb),
  (8, 'a586dc08-6c65-47f7-baf3-c6ea9aba27f6'::uuid, 'Petol Wrench', '4ea', NULL, 'N/A', NULL, 'No Discontinuity', 'API 7L Sect. 4.1.3', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no08-1.png"]'::jsonb),
  (9, NULL::uuid, 'Shackle 35 T', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'ASME B30.26', NULL, '2025-12-05'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no09-1.png"]'::jsonb),
  (10, NULL::uuid, 'Sucker Rod Hook', NULL, NULL, 'Critical', 'Terdapat pengelasan dan crack di area critical', 'Discontinuity', 'API 8B Sect. 5.2.3.4', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-05'::date, 'Closed', '2025-12-05'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no10-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no10-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no10-3.png"]'::jsonb),
  (11, '6cd7e0fa-808d-4c4d-af27-8c195d1f9e5c'::uuid, 'Manual Tong', NULL, NULL, 'Critical', 'Crack 1 titik; Terdapat pengelasan di area critical', 'Discontinuity', 'API 7L Sect. 4.1.3', 'Segera lakukan pergantian sesuai spesifikasi pabrikan.', '2025-12-05'::date, 'Closed', '2025-12-05'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no11-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no11-2.png"]'::jsonb),
  (12, '1cf76526-7919-4a5c-bb39-767babba3105'::uuid, 'Tubing Spider Slip 2 7/8''''', NULL, NULL, 'Critical', 'Crack 2 titik pada structure pad eyes', 'Discontinuity', 'API 7L Sect. 4.1.3', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-05'::date, 'Closed', '2025-12-05'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no12-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-05/no12-2.png"]'::jsonb),
  (1, NULL::uuid, 'Turnbuckle 1''''', '8ea', NULL, 'N/A', NULL, 'No Discontinuity', 'ASME B30.26', NULL, '2025-12-06'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no01-1.png"]'::jsonb),
  (2, 'a1a137ed-b214-4c5f-ad9f-ea85d56c305b'::uuid, 'Make Up Brake Out', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-06'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no02-1.png"]'::jsonb),
  (3, '2c04d8d4-93c6-4d97-8683-0cb705b9d187'::uuid, 'Telescopic Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-06'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no03-1.png"]'::jsonb),
  (4, '93e20131-bbf1-4da7-b086-45b6d89cf74d'::uuid, 'Traveling Hook Block', NULL, NULL, 'Critical', 'Terdapat indikasi crack 1 titik', 'Discontinuity', 'API RP 8B Sect. 5.3.2.4', 'Lakukan grinding permukaan dan lakukan MPI ulang; Lakukan perbaikan dengan mengacu standar dan prosedur yang berlaku.', '2025-12-06'::date, 'Closed', '2025-12-06'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no04-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no04-2.png"]'::jsonb),
  (5, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Lower Mast', NULL, NULL, 'Critical', 'Terdapat crack 4 titik di area lasan', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan dengan mengacu standar dan prosedur yang berlaku.', '2025-12-06'::date, 'Closed', '2025-12-06'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no05-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no05-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no05-3.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no05-4.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-06/no05-5.png"]'::jsonb),
  (1, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Upper Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no01-1.png"]'::jsonb),
  (2, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Base Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no02-1.png"]'::jsonb),
  (3, NULL::uuid, 'Raising Jack', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no03-1.png"]'::jsonb),
  (4, 'a7b182cc-b704-434b-aaf0-ca0833c28d6b'::uuid, 'Pin Locking Pawl Upper Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no04-1.png"]'::jsonb),
  (5, 'a7b182cc-b704-434b-aaf0-ca0833c28d6b'::uuid, 'Pin Locking Pawl Base Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no05-1.png"]'::jsonb),
  (6, 'ec6933a7-5ce8-45aa-97f1-21bca76f0519'::uuid, 'Link Elevator', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.2.3.4', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no06-1.png"]'::jsonb),
  (7, NULL::uuid, 'Sheave Crown Block', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect. 5.2.3.4', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no07-1.png"]'::jsonb),
  (8, NULL::uuid, 'Frame Crown Block', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-07'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no08-1.png"]'::jsonb),
  (9, NULL::uuid, 'Hose Hydraulic', NULL, NULL, 'Critical', 'Terdapat kerusakan lapisan Hose Hydraulic', 'N/A', 'API RP 4G Sect 6.1', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-07'::date, 'Closed', '2025-12-07'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no09-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no09-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no09-3.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no09-4.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-07/no09-5.png"]'::jsonb),
  (1, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Rest Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no01-1.png"]'::jsonb),
  (2, NULL::uuid, 'Sucker Rod Hook', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect.5.2.3.4', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no02-1.png"]'::jsonb),
  (3, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Drawwork -Lebus -Brake Rims', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no03-1.png"]'::jsonb),
  (4, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Send Line -Lebus -Brake Rims', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no04-1.png"]'::jsonb),
  (5, NULL::uuid, 'Turnbucke Guy Line', '4ea', NULL, 'N/A', NULL, 'No Discontinuity', 'ASME B30.26', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no05-1.png"]'::jsonb),
  (6, NULL::uuid, 'Pin Raising Jack', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no06-1.png"]'::jsonb),
  (7, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Brake Band', '2set', NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no07-1.png"]'::jsonb),
  (8, '12c114d5-3f68-493b-a9f2-d3616107ded3'::uuid, 'Mounting Axle Front', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no08-1.png"]'::jsonb),
  (9, NULL::uuid, 'Sensator WI', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no09-1.png"]'::jsonb),
  (10, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Pin Mast', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no10-1.png"]'::jsonb),
  (11, NULL::uuid, 'Air Winch', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 4G Sect 6.1', NULL, '2025-12-08'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no11-1.png"]'::jsonb),
  (12, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Equalizer Drawwork', NULL, NULL, 'Critical', 'Crack 2 titik', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan atau pergantian sesuai standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no12-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no12-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no12-3.png"]'::jsonb),
  (13, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Handle Brake', NULL, NULL, 'Critical', 'Crack 1 titik', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan mengacu standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no13-1.png"]'::jsonb),
  (14, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Brake Lingkage', NULL, NULL, 'Critical', 'Crack 1 titik pada lasan', 'No Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan mengacu standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no14-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no14-2.png"]'::jsonb),
  (15, NULL::uuid, 'Leveling Jack', NULL, 'DS-ODS', 'Critical', 'Crack 2 titik DS - ODS', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan dengan mengacu standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no15-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no15-2.png"]'::jsonb),
  (16, NULL::uuid, 'Sling Inner Guy Line ODS', NULL, NULL, 'Critical', 'Sling putus lebih dari 3 lay', 'N/A', 'API RP 9B Sect.7.1', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no16-1.png"]'::jsonb),
  (17, NULL::uuid, 'Manual Leveling Jack', '2ea', NULL, 'Critical', 'Incomplete penetration', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan dengan mengacu standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no17-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no17-2.png"]'::jsonb),
  (18, NULL::uuid, 'Pad Eyes Sensator WI', NULL, NULL, 'Critical', 'Terdapat kerusakan atau pengurangan material pad eyes', 'Discontinuity', 'API RP 4G Sect 6.1', 'Segera lakukan perbaikan dengan mengacu standar dan prosedur.', '2025-12-08'::date, 'Closed', '2025-12-08'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no18-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-08/no18-2.png"]'::jsonb),
  (1, '833540df-62e5-4a7a-8eb2-499329c08c26'::uuid, 'Mud Gas Separator', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API STD 53', NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no01-1.png"]'::jsonb),
  (2, 'ec1a55bd-765a-4879-9e13-707ae8a851e6'::uuid, 'Mud Pump -Dischage Line -Extention Rod', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect.4.1.3', NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no02-1.png"]'::jsonb),
  (3, '93e20131-bbf1-4da7-b086-45b6d89cf74d'::uuid, 'Traveling Block -Base Plate -Sheave', '2ea', NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 8B Sect 5.2.3.4', NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no03-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no03-2.png"]'::jsonb),
  (4, '2589ffde-157c-4aa8-aa9c-bcdba6013a27'::uuid, 'Power Tubing Tong', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no04-1.png"]'::jsonb),
  (5, NULL::uuid, 'Power Sucker Rod Tong', NULL, NULL, 'N/A', NULL, 'No Discontinuity', 'API RP 7L Sect 4.1.3', NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no05-1.png"]'::jsonb),
  (6, 'c1a9402f-da4d-4499-95c3-3670529d2bdf'::uuid, 'Air Tank 1.2', NULL, NULL, 'N/A', 'Wallthickness, hasil 3.14 mm (hasil ukur wall thickness)', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no06-1.png"]'::jsonb),
  (7, NULL::uuid, 'Hydraulic Tank', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no07-1.png"]'::jsonb),
  (8, '833540df-62e5-4a7a-8eb2-499329c08c26'::uuid, 'MGS', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no08-1.png"]'::jsonb),
  (9, '62cb323f-63bf-495c-8290-e338aebd8b7a'::uuid, 'BPM', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no09-1.png"]'::jsonb),
  (10, NULL::uuid, 'Water Tank', NULL, NULL, 'N/A', 'Wallthickness, hasil 8.05 mm', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no10-1.png"]'::jsonb),
  (11, '41531932-2a77-4b1d-ab2d-90e87c30a201'::uuid, 'Brake Rims -Drawwork -Send Line', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no11-1.png"]'::jsonb),
  (12, NULL::uuid, 'Fuel Tank Rig Carrier', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no12-1.png"]'::jsonb),
  (13, NULL::uuid, 'Comppressor Engine Mud Pump', NULL, NULL, 'N/A', 'Wallthickness, hasil 4.73 mm', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no13-1.png"]'::jsonb),
  (14, NULL::uuid, 'Mud Tank Tank 1.2', NULL, NULL, 'N/A', 'Wallthickness, hasil 9.35 mm', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no14-1.png"]'::jsonb),
  (15, NULL::uuid, 'Discharge Line', NULL, NULL, 'N/A', 'Wallthickness, hasil 14.66 mm', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no15-1.png"]'::jsonb),
  (16, '1bdee156-657e-4c2d-8245-3702b0a4d1d2'::uuid, 'Accumulator', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no16-1.png"]'::jsonb),
  (17, '8f2f0c57-a1a6-419b-825a-77e28306a0fe'::uuid, 'Mast', NULL, NULL, 'N/A', 'Wallthickness', 'N/A', NULL, NULL, '2025-12-09'::date, 'Closed', NULL::date, NULL, NULL, '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no17-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no17-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no17-3.png"]'::jsonb),
  (18, NULL::uuid, 'WPF', NULL, NULL, 'Critical', 'Terdapat kerusakan struktur', 'No Discontinuity', 'API RP 4G Sect 6.1 Table 3', 'Segera lakukan perbaikan sesuai standar dan mengacu dengan prosedur.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no18-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no18-2.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no18-3.png"]'::jsonb),
  (19, NULL::uuid, 'Clamp Rod', NULL, NULL, 'Critical', '1 spot crack', 'Discontinuity', 'API RP 7L Sect 4.1.3', 'Segera lakukan perbaikan atau pergantian sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no19-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no19-2.png"]'::jsonb),
  (20, NULL::uuid, 'Mud Inlet Line', NULL, NULL, 'Critical', 'Porositi cluster welding', 'Discontinuity', 'API RP 4G Sect 6.1 Table 3', 'Segera lakukan perbaikan dengan mengacu standar dan prosedur.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no20-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no20-2.png"]'::jsonb),
  (21, NULL::uuid, 'Pressure Gauge Air Tank 1', NULL, NULL, 'Major', 'Kerusakan pada cover', 'N/A', 'API RP 54 Sect 7.11', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no21-1.png"]'::jsonb),
  (22, NULL::uuid, 'Lightning Area Rig', NULL, NULL, 'Major', 'Lampu penerang tidak dilengkapi pengaman', 'N/A', 'API RP 54 Sect 7.4.12', 'Segera lakukan pengamanan pemasangan sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no22-1.png"]'::jsonb),
  (23, NULL::uuid, 'Hose Compressore Mud Pump', NULL, NULL, 'Major', '3 spot kerusakan hose', 'N/A', 'API RP 54 Sect 7.11.4', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no23-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no23-2.png"]'::jsonb),
  (24, NULL::uuid, 'Air Regulator', NULL, NULL, 'Major', 'Regulator buram', 'N/A', 'API RP 54 Sect 7.11', 'Segera lakukan perbaikan atau pergantian sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no24-1.png"]'::jsonb),
  (25, '2589ffde-157c-4aa8-aa9c-bcdba6013a27'::uuid, 'Hydrualic Pressure Power Tubing Tong', NULL, NULL, 'Critical', 'Pressure Gauge buram', 'N/A', 'API RP 54 Sect 7.11', 'Segera lakukan perbaikan mengacu standar dan prosedur.', '2025-12-09'::date, 'Closed', '2025-12-09'::date, NULL, 'Status closed berdasarkan konfirmasi user — seluruh temuan CAT III Desember 2025 sudah ditindaklanjuti, dokumentasi tindak lanjut detail per-item tidak tersedia terpisah dari Berita Acara Traveling Block.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no25-1.png"]'::jsonb),
  (26, '93e20131-bbf1-4da7-b086-45b6d89cf74d'::uuid, 'Traveling Sheave', NULL, NULL, 'Critical', 'Sheave 1 Groove tidak sesuai spesifikasi drilling line 7/8'''' atau wear menjadi 1'''' dengan kedalaman yang sudah melewati batas maximum yang diijinkan', 'N/A', 'API RP 9B Sect 3.8.1', 'Segera lakukan perbaikan atau pergantian dengan mengacu standar dan prosedur.', '2025-12-09'::date, 'Closed', '2025-12-18'::date, 'RAM Hoist & Heavy Equipment', 'Ditindaklanjuti via penggantian Sheave Traveling Block (Berita Acara 18 Desember 2025) — sheave lama diganti dengan unit dari BW KB150.B, function test hasil BAIK.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no26-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no26-2.png"]'::jsonb),
  (27, NULL::uuid, 'Brearing Sheave Crown', NULL, NULL, 'Critical', '1 Bearing rusak atau haus', 'N/A', 'API RP 7L Sect.6.8', 'Segera lakukan pergantian sesuai spesifikasi.', '2025-12-09'::date, 'Closed', '2025-12-18'::date, 'RAM Hoist & Heavy Equipment', 'Ditindaklanjuti via penggantian Sheave Traveling Block (Berita Acara 18 Desember 2025), function test hasil BAIK.', '["https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no27-1.png", "https://olmowzrlokajhniqijfq.supabase.co/storage/v1/object/public/inspection-photos/SIKLUS-2026-005/2025-12-09/no27-2.png"]'::jsonb)
) AS v(
  no_urut, equipment_id, equipment_name_snapshot, qty, bagian,
  category, finding, mpi_result, acceptance_criteria, recommendation,
  tgl_ditemukan, status, tgl_closed, pic_perbaikan, catatan, photos_before
);

-- ============================================================
-- VERIFIKASI
-- ============================================================
-- Ekspektasi (hasil hitung ulang dari 5 laporan harian):
--   N/A = 48, Major = 4, Critical = 19, TOTAL = 71
--   Semua 71 baris berstatus 'Closed'.
--   34 baris equipment_id terisi (matched), 37 baris NULL (unmatched).
--   71 baris photos_before terisi (100 foto total), 0 baris kosong.
SELECT
  category,
  COUNT(*) AS jumlah,
  COUNT(*) FILTER (WHERE status = 'Closed') AS jumlah_closed,
  COUNT(*) FILTER (WHERE equipment_id IS NOT NULL) AS jumlah_matched_equipment,
  COUNT(*) FILTER (WHERE jsonb_array_length(photos_before) > 0) AS jumlah_ada_foto
FROM inspection_findings
WHERE inspection_id = (SELECT id FROM inspections WHERE inspection_code = 'SIKLUS-2025-001')
GROUP BY category
ORDER BY category;

SELECT
  COUNT(*) AS total_baris,
  COUNT(*) FILTER (WHERE status = 'Closed') AS total_closed,
  COUNT(*) FILTER (WHERE status != 'Closed') AS total_bukan_closed,
  COUNT(*) FILTER (WHERE equipment_id IS NOT NULL) AS total_matched_equipment,
  COUNT(*) FILTER (WHERE equipment_id IS NULL) AS total_null_equipment,
  COUNT(*) FILTER (WHERE jsonb_array_length(photos_before) > 0) AS total_ada_foto,
  SUM(jsonb_array_length(photos_before)) AS total_jumlah_foto
FROM inspection_findings
WHERE inspection_id = (SELECT id FROM inspections WHERE inspection_code = 'SIKLUS-2025-001');
-- Ekspektasi: total_baris=71, total_closed=71, total_bukan_closed=0,
--             total_matched_equipment=34, total_null_equipment=37,
--             total_ada_foto=71, total_jumlah_foto=100

COMMIT;
