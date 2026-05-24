-- ============================================================
-- RIGBASE STATION — Tambah 3 Kategori Baru + 25 Equipment
-- ============================================================
-- Tujuan: prepare equipment yang muncul di laporan PI tapi belum di DB
--
-- Kategori Baru:
--   1. Mast Component  → Locking Pawl
--   2. Safety Equipment → Escape Chair
--   3. Control & Instrumentation → Drilling Console
--
-- Equipment baru (5 jenis × 5 rig = 25 unit):
--   - LP-{rig}  Locking Pawl       (Mast Component, parent MAST-XXX)
--   - EC-{rig}  Escape Chair       (Safety Equipment, parent MAST-XXX)
--   - DC-{rig}  Drilling Console   (Control & Instrumentation, parent MR-XXX)
--   - MA-{rig}  Mounting Axle      (Carrier, parent CARRIER-XXX)
--   - HJ-{rig}  Hydraulic Jack     (Carrier, parent CARRIER-XXX)
--
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING).
-- ============================================================

BEGIN;

-- ============================================================
-- 1. KATEGORI BARU (3)
-- ============================================================
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Mast Component',           'Rig'),
  ('Safety Equipment',         'Rig'),
  ('Control & Instrumentation', 'Rig')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- 2. LOCKING PAWL (5 unit) — parent: MAST-XXX
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('LP-100A',   'Locking Pawl BW-100A',     (SELECT id FROM categories WHERE name='Mast Component'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MAST-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Mekanisme pengunci telescopic Mast.'),
  ('LP-H35KD',  'Locking Pawl BW H35KD',    (SELECT id FROM categories WHERE name='Mast Component'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MAST-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Mekanisme pengunci telescopic Mast.'),
  ('LP-KB150A', 'Locking Pawl BW KB150.A',  (SELECT id FROM categories WHERE name='Mast Component'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Mekanisme pengunci telescopic Mast.'),
  ('LP-KB150B', 'Locking Pawl BW KB150.B',  (SELECT id FROM categories WHERE name='Mast Component'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Mekanisme pengunci telescopic Mast.'),
  ('LP-KB150C', 'Locking Pawl BW KB150.C',  (SELECT id FROM categories WHERE name='Mast Component'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Mekanisme pengunci telescopic Mast.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- 3. ESCAPE CHAIR (5 unit) — parent: MAST-XXX (mounted di Monkey Board area)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('EC-100A',   'Escape Chair BW-100A',     (SELECT id FROM categories WHERE name='Safety Equipment'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MAST-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Safety equipment evakuasi darurat dari Monkey Board. Standard API RP 54.'),
  ('EC-H35KD',  'Escape Chair BW H35KD',    (SELECT id FROM categories WHERE name='Safety Equipment'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MAST-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Safety equipment evakuasi darurat dari Monkey Board. Standard API RP 54.'),
  ('EC-KB150A', 'Escape Chair BW KB150.A',  (SELECT id FROM categories WHERE name='Safety Equipment'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Safety equipment evakuasi darurat dari Monkey Board. Standard API RP 54.'),
  ('EC-KB150B', 'Escape Chair BW KB150.B',  (SELECT id FROM categories WHERE name='Safety Equipment'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Safety equipment evakuasi darurat dari Monkey Board. Standard API RP 54.'),
  ('EC-KB150C', 'Escape Chair BW KB150.C',  (SELECT id FROM categories WHERE name='Safety Equipment'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MAST-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Safety equipment evakuasi darurat dari Monkey Board. Standard API RP 54.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- 4. DRILLING CONSOLE (5 unit) — parent: MR-XXX (Mobile Rig)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('DC-100A',   'Drilling Console BW-100A',     (SELECT id FROM categories WHERE name='Control & Instrumentation'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MR-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Panel kontrol driller. Standar API RP 54.'),
  ('DC-H35KD',  'Drilling Console BW H35KD',    (SELECT id FROM categories WHERE name='Control & Instrumentation'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MR-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Panel kontrol driller. Standar API RP 54.'),
  ('DC-KB150A', 'Drilling Console BW KB150.A',  (SELECT id FROM categories WHERE name='Control & Instrumentation'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MR-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Panel kontrol driller. Standar API RP 54.'),
  ('DC-KB150B', 'Drilling Console BW KB150.B',  (SELECT id FROM categories WHERE name='Control & Instrumentation'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MR-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Panel kontrol driller. Standar API RP 54.'),
  ('DC-KB150C', 'Drilling Console BW KB150.C',  (SELECT id FROM categories WHERE name='Control & Instrumentation'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MR-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Panel kontrol driller. Standar API RP 54.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- 5. MOUNTING AXLE (5 unit) — kategori Carrier (existing), parent: CARRIER-XXX
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('MA-100A',   'Mounting Axle BW-100A',     (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='CARRIER-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Axle struktural mounting carrier rig.'),
  ('MA-H35KD',  'Mounting Axle BW H35KD',    (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='CARRIER-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Axle struktural mounting carrier rig.'),
  ('MA-KB150A', 'Mounting Axle BW KB150.A',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Axle struktural mounting carrier rig.'),
  ('MA-KB150B', 'Mounting Axle BW KB150.B',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Axle struktural mounting carrier rig.'),
  ('MA-KB150C', 'Mounting Axle BW KB150.C',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Axle struktural mounting carrier rig.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- 6. HYDRAULIC JACK (5 unit) — kategori Carrier (existing), parent: CARRIER-XXX
--    Catatan: di PDF sering disebut "Leveling Jack" — fungsi sama
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('HJ-100A',   'Hydraulic Jack BW-100A',     (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='CARRIER-100A'),   'Permanent', 'Aktif', 'Good', 'BW-100A',    'Hydraulic Jack untuk leveling rig (juga disebut Leveling Jack di laporan PI).'),
  ('HJ-H35KD',  'Hydraulic Jack BW H35KD',    (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='CARRIER-H35KD'),  'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Hydraulic Jack untuk leveling rig (juga disebut Leveling Jack di laporan PI).'),
  ('HJ-KB150A', 'Hydraulic Jack BW KB150.A',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Hydraulic Jack untuk leveling rig (juga disebut Leveling Jack di laporan PI).'),
  ('HJ-KB150B', 'Hydraulic Jack BW KB150.B',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Hydraulic Jack untuk leveling rig (juga disebut Leveling Jack di laporan PI).'),
  ('HJ-KB150C', 'Hydraulic Jack BW KB150.C',  (SELECT id FROM categories WHERE name='Carrier'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='CARRIER-KB150C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Hydraulic Jack untuk leveling rig (juga disebut Leveling Jack di laporan PI).')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'TOTAL EQUIPMENT' AS info, COUNT(*)::TEXT AS jumlah FROM equipment
UNION ALL
SELECT 'TOTAL CATEGORIES', COUNT(*)::TEXT FROM categories
UNION ALL
SELECT 'Locking Pawl (LP-*)',  COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'LP-%'
UNION ALL
SELECT 'Escape Chair (EC-*)',  COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'EC-%'
UNION ALL
SELECT 'Drilling Console (DC-*)', COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'DC-%'
UNION ALL
SELECT 'Mounting Axle (MA-*)', COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'MA-%'
UNION ALL
SELECT 'Hydraulic Jack (HJ-*)', COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'HJ-%';
-- Ekspektasi:
--   TOTAL EQUIPMENT: 180 (sebelumnya 155 + 25 baru)
--   TOTAL CATEGORIES: 46 (sebelumnya 43 + 3 baru)
--   LP-*, EC-*, DC-*, MA-*, HJ-* masing-masing 5

COMMIT;

-- ============================================================
-- ROLLBACK (kalau perlu undo):
-- ============================================================
-- BEGIN;
-- DELETE FROM equipment WHERE tag_number LIKE 'LP-%' OR tag_number LIKE 'EC-%'
--   OR tag_number LIKE 'DC-%' OR tag_number LIKE 'MA-%' OR tag_number LIKE 'HJ-%';
-- DELETE FROM categories WHERE name IN ('Mast Component', 'Safety Equipment', 'Control & Instrumentation');
-- COMMIT;
