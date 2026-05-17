-- ============================================================
-- RIGBASE STATION — TAMBAH KATEGORI & 25 HANDLING TOOLS
-- ============================================================
-- Tujuan: prepare equipment list sebelum import data inspeksi historis
-- Penambahan:
--   - 1 kategori baru: "Handling Tools"
--   - 5 jenis tool × 5 rig = 25 equipment baru
--
-- Tag pattern:
--   - SS-{rig}  Spider Slip
--   - PW-{rig}  Petol Wrench
--   - MT-{rig}  Manual Tong
--   - SC-{rig}  Safety Clamp
--   - LE-{rig}  Link Elevator
--
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING).
-- ============================================================

BEGIN;

-- 1. Kategori baru
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Handling Tools', 'Rig')
ON CONFLICT (name) DO NOTHING;

-- 2. Helper CTE (resolve IDs sekali, dipakai berkali-kali)
-- Pakai approach: insert per equipment dengan subquery (sesuai pattern existing migration)

-- ============================================================
-- A. SPIDER SLIP (5 unit)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('SS-100A',   'Spider Slip BW-100A',     (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Handling tool — multiple ea per rig.'),
  ('SS-H35KD',  'Spider Slip BW H35KD',    (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Handling tool — multiple ea per rig.'),
  ('SS-KB150A', 'Spider Slip BW KB150.A',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Handling tool — multiple ea per rig.'),
  ('SS-KB150B', 'Spider Slip BW KB150.B',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Handling tool — multiple ea per rig.'),
  ('SS-KB150C', 'Spider Slip BW KB150.C',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Handling tool — multiple ea per rig.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- B. PETOL WRENCH (5 unit)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PW-100A',   'Petol Wrench BW-100A',     (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Handling tool.'),
  ('PW-H35KD',  'Petol Wrench BW H35KD',    (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Handling tool.'),
  ('PW-KB150A', 'Petol Wrench BW KB150.A',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Handling tool.'),
  ('PW-KB150B', 'Petol Wrench BW KB150.B',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Handling tool.'),
  ('PW-KB150C', 'Petol Wrench BW KB150.C',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Handling tool.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- C. MANUAL TONG (5 unit)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('MT-100A',   'Manual Tong BW-100A',     (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Tubing/casing tong manual.'),
  ('MT-H35KD',  'Manual Tong BW H35KD',    (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Tubing/casing tong manual.'),
  ('MT-KB150A', 'Manual Tong BW KB150.A',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Tubing/casing tong manual.'),
  ('MT-KB150B', 'Manual Tong BW KB150.B',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Tubing/casing tong manual.'),
  ('MT-KB150C', 'Manual Tong BW KB150.C',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Tubing/casing tong manual.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- D. SAFETY CLAMP (5 unit)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('SC-100A',   'Safety Clamp BW-100A',     (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Clamp keselamatan untuk pipe.'),
  ('SC-H35KD',  'Safety Clamp BW H35KD',    (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Clamp keselamatan untuk pipe.'),
  ('SC-KB150A', 'Safety Clamp BW KB150.A',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Clamp keselamatan untuk pipe.'),
  ('SC-KB150B', 'Safety Clamp BW KB150.B',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Clamp keselamatan untuk pipe.'),
  ('SC-KB150C', 'Safety Clamp BW KB150.C',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Clamp keselamatan untuk pipe.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- E. LINK ELEVATOR (5 unit)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('LE-100A',   'Link Elevator BW-100A',     (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Elevator untuk lift pipe.'),
  ('LE-H35KD',  'Link Elevator BW H35KD',    (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Elevator untuk lift pipe.'),
  ('LE-KB150A', 'Link Elevator BW KB150.A',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Elevator untuk lift pipe.'),
  ('LE-KB150B', 'Link Elevator BW KB150.B',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Elevator untuk lift pipe.'),
  ('LE-KB150C', 'Link Elevator BW KB150.C',  (SELECT id FROM categories WHERE name='Handling Tools'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Elevator untuk lift pipe.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'TOTAL EQUIPMENT' AS info, COUNT(*)::TEXT AS jumlah FROM equipment
UNION ALL
SELECT 'KATEGORI Handling Tools', COUNT(*)::TEXT FROM categories WHERE name='Handling Tools'
UNION ALL
SELECT 'HANDLING TOOLS equipment', COUNT(*)::TEXT FROM equipment WHERE kategori_id = (SELECT id FROM categories WHERE name='Handling Tools')
UNION ALL
SELECT '  Spider Slip',    COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'SS-%'
UNION ALL
SELECT '  Petol Wrench',   COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'PW-%'
UNION ALL
SELECT '  Manual Tong',    COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'MT-%'
UNION ALL
SELECT '  Safety Clamp',   COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'SC-%'
UNION ALL
SELECT '  Link Elevator',  COUNT(*)::TEXT FROM equipment WHERE tag_number LIKE 'LE-%';
-- Ekspektasi:
--   TOTAL EQUIPMENT: 155 (sebelumnya 130 + 25 baru)
--   KATEGORI Handling Tools: 1
--   HANDLING TOOLS equipment: 25
--   Spider Slip: 5, Petol Wrench: 5, Manual Tong: 5, Safety Clamp: 5, Link Elevator: 5

COMMIT;

-- ============================================================
-- ROLLBACK (kalau perlu undo):
-- ============================================================
-- BEGIN;
-- DELETE FROM equipment WHERE tag_number LIKE 'SS-%' OR tag_number LIKE 'PW-%'
--   OR tag_number LIKE 'MT-%' OR tag_number LIKE 'SC-%' OR tag_number LIKE 'LE-%';
-- DELETE FROM categories WHERE name='Handling Tools';
-- COMMIT;
