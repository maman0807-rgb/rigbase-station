-- ============================================================
-- SEED running_hours dari "Running Hours.xlsx" (pembacaan terkini)
-- Sumber: C:\FOTO Peralatan\Running Hours.xlsx  (pembacaan ke-2 / kolom HM/KM2)
-- Dibuat: 2026-05-26. Jalankan di Supabase SQL Editor (bypass RLS).
-- Match key = serial_number fisik (paling andal).
-- CEK hasil setelah jalan:
--   select tag_number, nama_equipment, running_hours, last_pm_hours from equipment
--   where tag_number in (...) order by tag_number;
-- ============================================================

-- ====== BAGIAN A: SUDAH DIEKSEKUSI 2026-05-26 (9/11 sukses, via REST service key) ======
-- CATATAN: DB live di-restruktur setelah backup 24 Mei (202->194 record, tag DEG-*/GEG-* di-rename).
-- Tag di bawah = tag LIVE hasil relink by serial number. last_pm_hours = baseline OPSI B.
UPDATE equipment SET running_hours = 466,   last_pm_hours = 466,   last_pm_date = '2026-04-19', updated_at = now() WHERE tag_number = 'MOBENG-KB150B';   -- Engine Rig KB150.B (SN 6TB06124)  [eks DEG-ENGINE-01]
UPDATE equipment SET running_hours = 3412,  last_pm_hours = 3412,  last_pm_date = '2026-05-18', updated_at = now() WHERE tag_number = 'MOBENG-H35KD';    -- Engine Rig H35KD (SN 6TB06109)  [eks DEG-ENGINE]
UPDATE equipment SET running_hours = 4656,  last_pm_hours = 4656,  last_pm_date = '2026-04-27', updated_at = now() WHERE tag_number = 'MOBENG-100A';     -- Engine BW-100A (SN 3ER07110)  [eks DEG-Engine-02]
UPDATE equipment SET running_hours = 887,   last_pm_hours = 887,   last_pm_date = '2026-05-12', updated_at = now() WHERE tag_number = 'ENGINE-MP-KB150C';-- Engine MP KB150.C (SN 3ER08763)
UPDATE equipment SET running_hours = 8430,  last_pm_hours = 8430,  last_pm_date = '2026-04-27', updated_at = now() WHERE tag_number = 'GS-100A-2';       -- Genset FG Wilson BW-100A (SN R032913H)  [eks GEG-Genset-4]
UPDATE equipment SET running_hours = 92,    last_pm_hours = 92,    last_pm_date = '2026-05-09', updated_at = now() WHERE tag_number = 'GS-KB150A-2';     -- Genset DE165ED KB150.A (SN KRG16477)  [eks GEG-Genset-8]
UPDATE equipment SET running_hours = 144,   last_pm_hours = 144,   last_pm_date = '2026-05-19', updated_at = now() WHERE tag_number = 'GS-KB150B-2';     -- Genset DE165ED KB150.B (SN KRG16013)  [eks GEG-Genset-2]
-- (lokasi Excel beda dgn nama DB — Maman konfirmasi DB yang salah; nilai HM benar krn match SN)
UPDATE equipment SET running_hours = 3698,  last_pm_hours = 3698,  last_pm_date = '2026-04-09', updated_at = now() WHERE tag_number = 'ENGINE-MP-H35KD'; -- SN MCW04569: Excel=WOWS/Yard Lapes
UPDATE equipment SET running_hours = 3979,  last_pm_hours = 3979,  last_pm_date = '2026-04-20', updated_at = now() WHERE tag_number = 'GS-KB150B';       -- SN 60386305: Excel=BW100A

-- ====== PENDING: 2 unit record-nya HILANG di live DB (perlu konfirmasi Maman) ======
-- SN MCW18294  Mud Pump JWS-400 H35KD  = 239 jam  -> eks GEG-Engine, tidak ada di live DB
-- SN 7K304827  Genset CAT C4.4 KB150.C = 13178 jam -> eks GEG-Genset-6, tidak ada di live DB
--   (kandidat live: GS-KB150C "Genset C4.4 100Kva" SN ECL04798 -> SN beda, cek fisik)
-- UPDATE equipment SET running_hours = 13178, last_pm_hours = 13178, last_pm_date = '2026-05-12', updated_at = now() WHERE tag_number = '<tag_genset_kb150c_yg_benar>';

-- ====== BAGIAN B: MANUAL oleh Maman (6 unit independent, edit sendiri) ======
-- Referensi nilai dari Excel (biarkan commented; Maman input lewat app):
-- UPDATE equipment SET running_hours = 1597,  updated_at = now() WHERE tag_number = 'ENGINE-MP-KB150B'; -- Mudpump GD KB150.B: SN 3ZJ61815 vs DB 3ZJ061815 (beda 1 angka 0)
-- UPDATE equipment SET running_hours = 1239,  updated_at = now() WHERE tag_number = 'ENGINE-MP-ACID-01';-- Mudpump Acid (DB tanpa SN; cocok by nama)
-- UPDATE equipment SET running_hours = 287,   updated_at = now() WHERE tag_number = 'GEG-MudPump-5';    -- MudPump LWS-440 (cocok by nama)
-- UPDATE equipment SET running_hours = 8653,  updated_at = now() WHERE tag_number = 'GEG-Genset-3';     -- Genset FG Wilson H35KD (DB tanpa SN)
-- UPDATE equipment SET running_hours = 12831, updated_at = now() WHERE tag_number = 'GEG-Genset';       -- Genset Krisbow KB150.B: SN 87555974 vs DB 130831H (beda) - RAGU
-- UPDATE equipment SET running_hours = 0,     updated_at = now() WHERE tag_number = 'GS-100A';          -- Genset Olympian: Excel MTU vs DB BW-100A - RAGU

-- ====== CATATAN: baseline last_pm_hours ======
-- OPSI B sudah DITERAPKAN di Bagian A (last_pm_hours = running_hours, last_pm_date = tgl baca).
-- Kalau nanti ketemu HM saat PM terakhir ASLI (opsi A, dari catatan kantor), tinggal:
--   UPDATE equipment SET last_pm_hours = <hm_pm_asli>, last_pm_date = '<tgl_pm_asli>' WHERE tag_number = '<tag>';
