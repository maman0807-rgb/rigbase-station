-- ============================================================
-- TAMBAH 7 UNIT YANG BELUM ADA DI SISTEM
-- Hasil cross-check daftar "UNIT A2B & KENDARAAN RINGAN HOIST & HEAVY
-- EQUIPMENT — PRABUMULIH FIELD" vs export eRAMHoist (12 Agustus 2026).
-- ============================================================
-- 4 Heavy Equipment (Alat Berat Civil) + 3 Kendaraan Ringan.
-- (FL-01 semula dikira belum ada, ternyata SUDAH ADA sbg
-- FL-FORKLIFT-01 dgn S/N sedikit typo — lihat catatan data quality
-- terpisah, TIDAK di-insert ulang di sini.)
-- Status default: Aktif, Good, Permanent — sesuaikan lewat Edit di app
-- kalau ada yang beda.
--
-- CATATAN MTU-BG8199CE: kategori "MTU" sudah pasti benar (armada Unit
-- MTU), tapi fungsi truk spesifiknya (Crane Truck / Head Truck / dll,
-- lihat pola CT-/HT- di unit MTU lain) TIDAK bisa dipastikan dari data
-- PDF sumber (cuma ada kode chassis, bukan fungsi truk). Cek fisik unit
-- lalu sesuaikan tag_number & nama_equipment kalau perlu.
--
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING).
-- ============================================================

BEGIN;

-- ============================================================
-- HEAVY EQUIPMENT (4) — armada "Alat Berat Civil"
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, pm_type, pm_interval_hours, vendor_supplier, remarks)
VALUES
  ('EXCA-01',         'Excavator Exca-01',     (SELECT id FROM categories WHERE name='Excavator'),      (SELECT id FROM parent_units WHERE name='Alat Berat Civil'),  'Permanent', 'CATERPILLAR', '320C',   'CCD00922',   'Aktif', 'Good', 'Civil', 'hours', 500, 'TRAKINDO', 'Ditambahkan dari cross-check daftar A2B Agustus 2026.'),
  ('EXCA-03',         'Excavator Exca-03',     (SELECT id FROM categories WHERE name='Excavator'),      (SELECT id FROM parent_units WHERE name='Alat Berat Civil'),  'Permanent', 'CATERPILLAR', '320D',   'BZP02708',   'Aktif', 'Good', 'Civil', 'hours', 500, 'TRAKINDO', 'Ditambahkan dari cross-check daftar A2B Agustus 2026.'),
  ('BDZ-BDEH435',     'Bulldozer BDEH 435',    (SELECT id FROM categories WHERE name='Bulldozer'),      (SELECT id FROM parent_units WHERE name='Alat Berat Civil'),  'Permanent', 'CATERPILLAR', 'D7G2',   '7MB05654',   'Aktif', 'Good', 'Civil', 'hours', 500, 'TRAKINDO', 'Ditambahkan dari cross-check daftar A2B Agustus 2026.'),
  ('BHL-03',          'Backhoe Loader BHL-03', (SELECT id FROM categories WHERE name='Backhoe Loader'), (SELECT id FROM parent_units WHERE name='Alat Berat Civil'),  'Permanent', 'CATERPILLAR', '428D',   'BXC01427',   'Aktif', 'Good', 'Civil', 'hours', 500, 'TRAKINDO', 'Ditambahkan dari cross-check daftar A2B Agustus 2026.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- KENDARAAN RINGAN (3)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, brand, model, status_operasi, kondisi_fisik, pm_type, remarks)
VALUES
  ('DT-BG9019CZ',   'Dump Truck BG 9019 CZ', (SELECT id FROM categories WHERE name='Dump Truck'), (SELECT id FROM parent_units WHERE name='Kendaraan'), 'Permanent', 'NISSAN', 'PKD 211',       'Aktif', 'Good', 'hours', 'Ditambahkan dari cross-check daftar A2B Agustus 2026.'),
  ('DT-BG8012CZ',   'Dump Truck BG 8012 CZ', (SELECT id FROM categories WHERE name='Dump Truck'), (SELECT id FROM parent_units WHERE name='Kendaraan'), 'Permanent', 'HINO',   'FG 235 TI',     'Aktif', 'Good', 'hours', 'Sebelumnya "TS 02" di daftar A2B — dikategorikan Dump Truck, konsisten dengan TS 03 (BG 8013 CZ) yang sudah ada di sistem sbg DT-BG8013CZ.'),
  ('MTU-BG8199CE',  'Unit Truck MTU BG 8199 CE', (SELECT id FROM categories WHERE name='MTU'),     (SELECT id FROM parent_units WHERE name='Unit MTU'),  'Permanent', 'HINO',   'FM8JW1A-EGJ / FM350TH', 'Aktif', 'Good', 'km', 'Sebelumnya "MTU 04" di daftar A2B. CEK FISIK: fungsi truk (Crane Truck/Head Truck/dll) belum pasti dari data sumber, sesuaikan tag/nama kalau perlu.')
ON CONFLICT (tag_number) DO NOTHING;

COMMIT;

-- ============================================================
-- VERIFIKASI — jalankan setelah INSERT, harus muncul 7 baris baru
-- ============================================================
SELECT tag_number, nama_equipment, kategori_id, assigned_unit_id, status_operasi
FROM equipment
WHERE tag_number IN ('EXCA-01','EXCA-03','BDZ-BDEH435','BHL-03','DT-BG9019CZ','DT-BG8012CZ','MTU-BG8199CE')
ORDER BY tag_number;
-- harusnya 7 baris

NOTIFY pgrst, 'reload schema';

-- ============================================================
-- OPSIONAL — DATA QUALITY: 4 unit sudah ada tapi field-nya typo
-- (dari cross-check yang sama). REVIEW dulu sebelum jalankan —
-- ini UPDATE, bukan sekadar tambah data baru. Jalankan satu-satu
-- kalau sudah yakin.
-- ============================================================
-- UPDATE equipment SET serial_number = 'TJL00861' WHERE tag_number = 'CMP-VIBRO-02';       -- was TLJ00861
-- UPDATE equipment SET serial_number = 'TDPH03448' WHERE tag_number = 'BHL-05';             -- was DPH03448 (kurang huruf T)
-- UPDATE equipment SET serial_number = 'T28L50013' WHERE tag_number = 'FL-FORKLIFT-01';     -- was T28C50013
-- UPDATE equipment SET tag_number    = 'ML-BG9886SIA' WHERE tag_number = 'ML-B9886SIA';     -- kurang huruf G
