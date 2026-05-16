-- ============================================================
-- RIGBASE STATION — MIGRATION: RESTRUCTURE EQUIPMENT HIERARCHY
-- ============================================================
-- Tujuan besar:
--   1. Tambah kolom parent_equipment_id (self-reference) → bikin tree
--   2. Tambah 10 kategori baru
--   3. Bikin 5 container Mobile Rig (MR-XXX)
--   4. Bikin 5 Carrier (child of Mobile Rig)
--   5. Bikin 5 Transmisi Rig (child of Mobile Rig)
--   6. Split 7 Mudpump jadi: container + 3 child (Pompa, Engine, Transmisi)
--   7. Re-parent existing children (Drawwork, Mast, MobileEngine, TravellingBlock) → Mobile Rig
--   8. Cleanup MOBENG spek_khusus (info transmisi pindah ke TRANS-XXX)
--
-- Aman dijalankan ulang berkat ON CONFLICT.
-- Pakai BEGIN/COMMIT — atomic.
-- Setelah Run: 49 → 85 equipment, 30 → 40 categories.
-- ============================================================

BEGIN;

-- ============================================================
-- PHASE 1: SCHEMA — Tambah parent_equipment_id
-- ============================================================
ALTER TABLE equipment
  ADD COLUMN IF NOT EXISTS parent_equipment_id UUID
    REFERENCES equipment(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_equipment_parent_eq ON equipment(parent_equipment_id);

-- ============================================================
-- PHASE 2: KATEGORI BARU (10 baru, semua untuk Rig)
-- ============================================================
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Mobile Rig',         'Rig'),
  ('Carrier',            'Rig'),
  ('Transmisi',          'Rig'),
  ('Engine Mudpump',     'Rig'),
  ('Pompa',              'Rig'),
  ('Portacamp Crew',     'Rig'),
  ('Portacamp Office',   'Rig'),
  ('Portacamp Foreman',  'Rig'),
  ('Fire Pump',          'Rig'),
  ('Blower',             'Rig'),
  ('BPM',                'Rig'),
  ('Compressor',         'Rig'),
  ('Mug Gas Separator',  'Rig')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- PHASE 3: MOBILE RIG CONTAINERS (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('MR-100A',   'Mobile Rig BW-100A',     (SELECT id FROM categories WHERE name='Mobile Rig'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Container: berisi Engine, Transmisi, Drawwork, Mast, Travelling Block, Carrier.'),
  ('MR-H35KD',  'Mobile Rig BW H35KD',    (SELECT id FROM categories WHERE name='Mobile Rig'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Container: berisi Engine, Transmisi, Drawwork, Mast, Travelling Block, Carrier.'),
  ('MR-KB150A', 'Mobile Rig BW KB150.A',  (SELECT id FROM categories WHERE name='Mobile Rig'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Container: berisi Engine, Transmisi, Drawwork, Mast, Travelling Block, Carrier.'),
  ('MR-KB150B', 'Mobile Rig BW KB150.B',  (SELECT id FROM categories WHERE name='Mobile Rig'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Container: berisi Engine, Transmisi, Drawwork, Mast, Travelling Block, Carrier.'),
  ('MR-KB150C', 'Mobile Rig BW KB150.C',  (SELECT id FROM categories WHERE name='Mobile Rig'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Container: berisi Engine, Transmisi, Drawwork, Mast, Travelling Block, Carrier.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PHASE 4: CARRIER (5) — child of Mobile Rig
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('CARRIER-100A',   'Carrier Mobile Rig BW-100A',    (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MR-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder — lengkapi brand/model/serial.'),
  ('CARRIER-H35KD',  'Carrier Mobile Rig BW H35KD',   (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MR-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder — lengkapi brand/model/serial.'),
  ('CARRIER-KB150A', 'Carrier Mobile Rig BW KB150.A', (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MR-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder — lengkapi brand/model/serial.'),
  ('CARRIER-KB150B', 'Carrier Mobile Rig BW KB150.B', (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MR-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder — lengkapi brand/model/serial.'),
  ('CARRIER-KB150C', 'Carrier Mobile Rig BW KB150.C', (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MR-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder — lengkapi brand/model/serial.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PHASE 5: TRANSMISI RIG (5) — child of Mobile Rig
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('TRANS-100A',   'Transmisi Mobile Rig BW-100A',    (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MR-100A'),   'Permanent', 'Allison', 'S6510-R',  '89384',       'Aktif', 'Good', 'BW-100A',    'Data dari MOBENG-100A spek lama.'),
  ('TRANS-H35KD',  'Transmisi Mobile Rig BW H35KD',   (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MR-H35KD'),  'Permanent', 'CLBT',    '5860-2',   '3110090563', 'Aktif', 'Good', 'BW H35KD',   'Data dari MOBENG-H35KD spek lama. Power Trans 500.'),
  ('TRANS-KB150A', 'Transmisi Mobile Rig BW KB150.A', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MR-KB150A'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.A', 'Placeholder — lengkapi brand/model/serial.'),
  ('TRANS-KB150B', 'Transmisi Mobile Rig BW KB150.B', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MR-KB150B'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.B', 'Placeholder — lengkapi brand/model/serial.'),
  ('TRANS-KB150C', 'Transmisi Mobile Rig BW KB150.C', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MR-KB150C'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.C', 'Placeholder — lengkapi brand/model/serial.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PHASE 6: RE-PARENT EXISTING EQUIPMENT KE MOBILE RIG
-- Drawwork, Mast, Mobile Engine, Travelling Block → child of Mobile Rig
-- ============================================================

-- BW-100A children
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-100A')
WHERE tag_number IN ('DW-100A', 'MAST-100A', 'MOBENG-100A', 'TB-100A');

-- BW H35KD children
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-H35KD')
WHERE tag_number IN ('DW-H35KD', 'MAST-H35KD', 'MOBENG-H35KD', 'TB-H35KD');

-- BW KB150.A children
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150A')
WHERE tag_number IN ('DW-KB150A', 'MAST-KB150A', 'TB-KB150A');

-- BW KB150.B children
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150B')
WHERE tag_number IN ('DW-KB150B', 'MAST-KB150B', 'TB-KB150B');

-- BW KB150.C children
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150C')
WHERE tag_number IN ('DW-KB150C', 'MAST-KB150C', 'TB-KB150C');

-- ============================================================
-- PHASE 7: MUDPUMP SPLIT (per Mudpump → Pompa + Engine + Transmisi)
-- 7 mudpump x 3 child = 21 new equipment
-- ============================================================

-- ---------- MP-100A ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, spek_khusus, remarks)
VALUES
  ('PUMP-100A',        'Pompa Mudpump MP-100A',        (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='BW-100A'), (SELECT id FROM equipment WHERE tag_number='MP-100A'), 'Permanent', 'National Oilwell', 'JWS-400', '2638857-1',  'Aktif', 'Good', 'BW-100A', 'Pump Type: NOV (Triplex). Dari spek lama MP-100A.', NULL),
  ('ENGINE-MP-100A',   'Engine Mudpump MP-100A',       (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='BW-100A'), (SELECT id FROM equipment WHERE tag_number='MP-100A'), 'Permanent', 'CAT',              'C13',     'RRA12541',   'Aktif', 'Good', 'BW-100A', 'Power: 440 HP. Dari spek lama MP-100A.', NULL),
  ('TRANS-MP-100A',    'Transmisi Mudpump MP-100A',    (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='BW-100A'), (SELECT id FROM equipment WHERE tag_number='MP-100A'), 'Permanent', 'Allison',          'S.5600 R','310105336',  'Aktif', 'Good', 'BW-100A', 'Dari spek lama MOBENG-100A.', NULL)
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-H35KD ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, spek_khusus, remarks)
VALUES
  ('PUMP-H35KD',       'Pompa Mudpump MP-H35KD',       (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='BW H35KD'), (SELECT id FROM equipment WHERE tag_number='MP-H35KD'), 'Permanent', NULL, 'JWS-400', '1296457-1', 'Aktif', 'Good', 'BW H35KD', 'TRIPLEX PUMP, Stroke Length 7". Dari spek lama MP-H35KD.', NULL),
  ('ENGINE-MP-H35KD',  'Engine Mudpump MP-H35KD',      (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='BW H35KD'), (SELECT id FROM equipment WHERE tag_number='MP-H35KD'), 'Permanent', 'CAT', 'C15',     'MCW04569',  'Aktif', 'Good', 'BW H35KD', 'Power: 440 HP. Dari spek lama MP-H35KD.', NULL),
  ('TRANS-MP-H35KD',   'Transmisi Mudpump MP-H35KD',   (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='BW H35KD'), (SELECT id FROM equipment WHERE tag_number='MP-H35KD'), 'Permanent', NULL,  NULL,      NULL,        'Aktif', 'Good', 'BW H35KD', 'Placeholder — lengkapi brand/model/serial.', NULL)
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-KB150A ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, spek_khusus, remarks)
VALUES
  ('PUMP-KB150A',      'Pompa Mudpump MP-KB150A',      (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MP-KB150A'), 'Permanent', 'OMEGA',   'W-500',         '51684',       'Aktif', 'Good', 'BW KB150.A', 'SINGLE ACTING TRIPLEX PUMP. Dari spek lama MP-KB150A.', NULL),
  ('ENGINE-MP-KB150A', 'Engine Mudpump MP-KB150A',     (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MP-KB150A'), 'Permanent', 'CAT',     'D3408',         '9ER00896',    'Aktif', 'Good', 'BW KB150.A', 'Power: 525 HP. Dari spek lama MP-KB150A.', NULL),
  ('TRANS-MP-KB150A',  'Transmisi Mudpump MP-KB150A',  (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MP-KB150A'), 'Permanent', 'Allison', 'CLT.754DB',     '2510208479',  'Aktif', 'Good', 'BW KB150.A', 'Dari spek lama MP-KB150A.', NULL)
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-KB150B ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, spek_khusus, remarks)
VALUES
  ('PUMP-KB150B',      'Pompa Mudpump MP-KB150B',      (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MP-KB150B'), 'Permanent', 'Gardner Denver', 'TGHP-200', '14942',      'Aktif', 'Good', 'BW KB150.B', '535 GPM, Liner 7", 286 RPM. Dari spek lama MP-KB150B.', NULL),
  ('ENGINE-MP-KB150B', 'Engine Mudpump MP-KB150B',     (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MP-KB150B'), 'Permanent', 'CAT',            'D3406',    '3ZJ061815',  'Aktif', 'Good', 'BW KB150.B', 'Dari spek lama MP-KB150B.', NULL),
  ('TRANS-MP-KB150B',  'Transmisi Mudpump MP-KB150B',  (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MP-KB150B'), 'Permanent', 'Allison',        'HT.740',   '2510051777', 'Aktif', 'Good', 'BW KB150.B', 'Dari spek lama MP-KB150B.', NULL)
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-KB150C ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, spek_khusus, remarks)
VALUES
  ('PUMP-KB150C',      'Pompa Mudpump MP-KB150C',      (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MP-KB150C'), 'Permanent', 'SPM',     'TWS600STD',   'F0904-2404', 'Aktif', 'Good', 'BW KB150.C', 'SINGLE ACTING TRIPLEX PUMP. Dari spek lama MP-KB150C.', NULL),
  ('ENGINE-MP-KB150C', 'Engine Mudpump MP-KB150C',     (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MP-KB150C'), 'Permanent', 'CAT',     'D.3406',      '3ER08763',   'Aktif', 'Good', 'BW KB150.C', 'Dari spek lama MP-KB150C.', NULL),
  ('TRANS-MP-KB150C',  'Transmisi Mudpump MP-KB150C',  (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MP-KB150C'), 'Permanent', 'Allison', 'S5610DR',     '3110049960', 'Aktif', 'Good', 'BW KB150.C', 'Dari spek lama MP-KB150C.', NULL)
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-BACKUP-01 (Independent pool) ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PUMP-BACKUP-01',      'Pompa Mudpump Backup-01',     (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-BACKUP-01'), 'Mobile-Backup', 'Standby', 'Good', 'Independent Pool', 'Placeholder — lengkapi data.'),
  ('ENGINE-MP-BACKUP-01', 'Engine Mudpump Backup-01',    (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-BACKUP-01'), 'Mobile-Backup', 'Standby', 'Good', 'Independent Pool', 'Placeholder — lengkapi data.'),
  ('TRANS-MP-BACKUP-01',  'Transmisi Mudpump Backup-01', (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-BACKUP-01'), 'Mobile-Backup', 'Standby', 'Good', 'Independent Pool', 'Placeholder — lengkapi data.')
ON CONFLICT (tag_number) DO NOTHING;

-- ---------- MP-ACID-01 ----------
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PUMP-ACID-01',      'Pompa Mudpump Acid-01',     (SELECT id FROM categories WHERE name='Pompa'),          (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-ACID-01'), 'Permanent', 'Aktif', 'Good', 'Independent (Acid)', 'Placeholder — lengkapi data.'),
  ('ENGINE-MP-ACID-01', 'Engine Mudpump Acid-01',    (SELECT id FROM categories WHERE name='Engine Mudpump'), (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-ACID-01'), 'Permanent', 'Aktif', 'Good', 'Independent (Acid)', 'Placeholder — lengkapi data.'),
  ('TRANS-MP-ACID-01',  'Transmisi Mudpump Acid-01', (SELECT id FROM categories WHERE name='Transmisi'),       (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-ACID-01'), 'Permanent', 'Aktif', 'Good', 'Independent (Acid)', 'Placeholder — lengkapi data.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PHASE 8: BERSIHKAN SPEK MP-XXX (sekarang jadi container, detail ada di children)
-- ============================================================
UPDATE equipment
SET brand = NULL,
    model = NULL,
    serial_number = NULL,
    spek_khusus = 'Container Mudpump — lihat detail di child equipment (Pompa, Engine, Transmisi).',
    remarks = COALESCE(remarks, '') || ' [Restructure: spek pindah ke PUMP/ENGINE-MP/TRANS-MP-XXX]'
WHERE tag_number IN ('MP-100A','MP-H35KD','MP-KB150A','MP-KB150B','MP-KB150C','MP-BACKUP-01','MP-ACID-01');

-- ============================================================
-- PHASE 9: CLEANUP MOBENG SPEK (info transmisi sudah pindah)
-- ============================================================
UPDATE equipment
SET spek_khusus = 'Power: 450/475 HP',
    remarks = COALESCE(remarks, '') || ' [Restructure: info transmisi pindah ke TRANS-100A]'
WHERE tag_number = 'MOBENG-100A';

UPDATE equipment
SET spek_khusus = 'Power: 350 HP',
    remarks = COALESCE(remarks, '') || ' [Restructure: info transmisi pindah ke TRANS-H35KD]'
WHERE tag_number = 'MOBENG-H35KD';

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'TOTAL CATEGORIES' AS info, COUNT(*) AS jumlah FROM categories
UNION ALL
SELECT 'TOTAL EQUIPMENT',          COUNT(*) FROM equipment
UNION ALL
SELECT 'CONTAINER (no parent_eq)', COUNT(*) FROM equipment WHERE parent_equipment_id IS NULL
UNION ALL
SELECT 'CHILD (with parent_eq)',   COUNT(*) FROM equipment WHERE parent_equipment_id IS NOT NULL
UNION ALL
SELECT 'MOBILE RIG containers',    COUNT(*) FROM equipment WHERE tag_number LIKE 'MR-%'
UNION ALL
SELECT 'MUDPUMP containers',       COUNT(*) FROM equipment WHERE tag_number LIKE 'MP-%' AND parent_equipment_id IS NULL
UNION ALL
SELECT 'PUMP children',            COUNT(*) FROM equipment WHERE tag_number LIKE 'PUMP-%'
UNION ALL
SELECT 'ENGINE-MP children',       COUNT(*) FROM equipment WHERE tag_number LIKE 'ENGINE-MP-%'
UNION ALL
SELECT 'TRANS rig children',       COUNT(*) FROM equipment WHERE tag_number LIKE 'TRANS-%' AND tag_number NOT LIKE 'TRANS-MP-%'
UNION ALL
SELECT 'TRANS-MP children',        COUNT(*) FROM equipment WHERE tag_number LIKE 'TRANS-MP-%';
-- Ekspektasi:
--   CATEGORIES: 42 (29 + 13 baru)
--   EQUIPMENT: 85 (49 + 5 MR + 5 Carrier + 5 Trans rig + 21 mudpump children)
--   CONTAINER no parent_eq: ~57 (top-level)
--   CHILD with parent_eq: ~28 (re-parented + new children)
--   MOBILE RIG containers: 5
--   MUDPUMP containers: 7
--   PUMP children: 7
--   ENGINE-MP children: 7
--   TRANS rig: 5
--   TRANS-MP: 7

COMMIT;

-- ============================================================
-- ROLLBACK (kalau perlu undo):
-- ============================================================
-- BEGIN;
-- -- Restore MOBENG specs
-- UPDATE equipment SET spek_khusus = 'Power: 450/475 HP | Transmission: Allison S6510-R / Allison S.5600 R | Trans SN: 89384 / 310105336 | Power Trans 500',
--   remarks = REPLACE(remarks, ' [Restructure: info transmisi pindah ke TRANS-100A]', '')
-- WHERE tag_number = 'MOBENG-100A';
-- UPDATE equipment SET spek_khusus = 'Power: 350 HP | Transmission: CLBT 5860-2, SN 3110090563 | Power Trans 500',
--   remarks = REPLACE(remarks, ' [Restructure: info transmisi pindah ke TRANS-H35KD]', '')
-- WHERE tag_number = 'MOBENG-H35KD';
-- -- Restore MP-XXX specs (lihat data asli sebelum migrasi)
-- -- Hapus child equipment
-- DELETE FROM equipment WHERE tag_number LIKE 'PUMP-%' OR tag_number LIKE 'ENGINE-MP-%' OR tag_number LIKE 'TRANS-MP-%';
-- DELETE FROM equipment WHERE tag_number LIKE 'TRANS-%';
-- DELETE FROM equipment WHERE tag_number LIKE 'CARRIER-%';
-- DELETE FROM equipment WHERE tag_number LIKE 'MR-%';
-- -- Clear parent_equipment_id from re-parented children
-- UPDATE equipment SET parent_equipment_id = NULL;
-- -- Drop categories baru
-- DELETE FROM categories WHERE name IN ('Mobile Rig','Carrier','Transmisi','Engine Mudpump','Pompa','Portacamp Crew','Portacamp Office','Portacamp Foreman','Fire Pump','Blower','BPM','Compressor','Mug Gas Separator');
-- -- Drop kolom
-- ALTER TABLE equipment DROP COLUMN parent_equipment_id;
-- COMMIT;
