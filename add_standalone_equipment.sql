-- ============================================================
-- RIGBASE STATION — TAMBAH 45 EQUIPMENT STANDALONE PER RIG
-- ============================================================
-- 9 jenis equipment × 5 rig (BW-100A, BW H35KD, BW KB150.A/B/C):
--   Tower Light, Portacamp Crew, Portacamp Office, Portacamp Foreman,
--   Fire Pump, Blower, BPM, Compressor, Mug Gas Separator
--
-- Status default: Aktif, Good, Permanent.
-- Brand/model/SN: kosong (placeholder) — kamu lengkapi via Edit di app.
--
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING).
-- ============================================================

BEGIN;

-- ============================================================
-- TOWER LIGHT (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('TL-100A',   'Tower Light BW-100A',     (SELECT id FROM categories WHERE name='Tower Light'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder — lengkapi brand/model/serial.'),
  ('TL-H35KD',  'Tower Light BW H35KD',    (SELECT id FROM categories WHERE name='Tower Light'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder — lengkapi brand/model/serial.'),
  ('TL-KB150A', 'Tower Light BW KB150.A',  (SELECT id FROM categories WHERE name='Tower Light'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder — lengkapi brand/model/serial.'),
  ('TL-KB150B', 'Tower Light BW KB150.B',  (SELECT id FROM categories WHERE name='Tower Light'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder — lengkapi brand/model/serial.'),
  ('TL-KB150C', 'Tower Light BW KB150.C',  (SELECT id FROM categories WHERE name='Tower Light'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder — lengkapi brand/model/serial.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PORTACAMP CREW (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PORT-CREW-100A',   'Portacamp Crew BW-100A',     (SELECT id FROM categories WHERE name='Portacamp Crew'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('PORT-CREW-H35KD',  'Portacamp Crew BW H35KD',    (SELECT id FROM categories WHERE name='Portacamp Crew'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('PORT-CREW-KB150A', 'Portacamp Crew BW KB150.A',  (SELECT id FROM categories WHERE name='Portacamp Crew'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('PORT-CREW-KB150B', 'Portacamp Crew BW KB150.B',  (SELECT id FROM categories WHERE name='Portacamp Crew'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('PORT-CREW-KB150C', 'Portacamp Crew BW KB150.C',  (SELECT id FROM categories WHERE name='Portacamp Crew'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PORTACAMP OFFICE (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PORT-OFFICE-100A',   'Portacamp Office BW-100A',     (SELECT id FROM categories WHERE name='Portacamp Office'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('PORT-OFFICE-H35KD',  'Portacamp Office BW H35KD',    (SELECT id FROM categories WHERE name='Portacamp Office'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('PORT-OFFICE-KB150A', 'Portacamp Office BW KB150.A',  (SELECT id FROM categories WHERE name='Portacamp Office'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('PORT-OFFICE-KB150B', 'Portacamp Office BW KB150.B',  (SELECT id FROM categories WHERE name='Portacamp Office'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('PORT-OFFICE-KB150C', 'Portacamp Office BW KB150.C',  (SELECT id FROM categories WHERE name='Portacamp Office'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- PORTACAMP FOREMAN (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('PORT-FOREMAN-100A',   'Portacamp Foreman BW-100A',     (SELECT id FROM categories WHERE name='Portacamp Foreman'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('PORT-FOREMAN-H35KD',  'Portacamp Foreman BW H35KD',    (SELECT id FROM categories WHERE name='Portacamp Foreman'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('PORT-FOREMAN-KB150A', 'Portacamp Foreman BW KB150.A',  (SELECT id FROM categories WHERE name='Portacamp Foreman'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('PORT-FOREMAN-KB150B', 'Portacamp Foreman BW KB150.B',  (SELECT id FROM categories WHERE name='Portacamp Foreman'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('PORT-FOREMAN-KB150C', 'Portacamp Foreman BW KB150.C',  (SELECT id FROM categories WHERE name='Portacamp Foreman'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- FIRE PUMP (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('FP-100A',   'Fire Pump BW-100A',     (SELECT id FROM categories WHERE name='Fire Pump'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('FP-H35KD',  'Fire Pump BW H35KD',    (SELECT id FROM categories WHERE name='Fire Pump'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('FP-KB150A', 'Fire Pump BW KB150.A',  (SELECT id FROM categories WHERE name='Fire Pump'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('FP-KB150B', 'Fire Pump BW KB150.B',  (SELECT id FROM categories WHERE name='Fire Pump'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('FP-KB150C', 'Fire Pump BW KB150.C',  (SELECT id FROM categories WHERE name='Fire Pump'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- BLOWER (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('BLW-100A',   'Blower BW-100A',     (SELECT id FROM categories WHERE name='Blower'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('BLW-H35KD',  'Blower BW H35KD',    (SELECT id FROM categories WHERE name='Blower'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('BLW-KB150A', 'Blower BW KB150.A',  (SELECT id FROM categories WHERE name='Blower'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('BLW-KB150B', 'Blower BW KB150.B',  (SELECT id FROM categories WHERE name='Blower'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('BLW-KB150C', 'Blower BW KB150.C',  (SELECT id FROM categories WHERE name='Blower'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- BPM (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('BPM-100A',   'BPM BW-100A',     (SELECT id FROM categories WHERE name='BPM'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('BPM-H35KD',  'BPM BW H35KD',    (SELECT id FROM categories WHERE name='BPM'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('BPM-KB150A', 'BPM BW KB150.A',  (SELECT id FROM categories WHERE name='BPM'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('BPM-KB150B', 'BPM BW KB150.B',  (SELECT id FROM categories WHERE name='BPM'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('BPM-KB150C', 'BPM BW KB150.C',  (SELECT id FROM categories WHERE name='BPM'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- COMPRESSOR (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('COMP-100A',   'Compressor BW-100A',     (SELECT id FROM categories WHERE name='Compressor'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('COMP-H35KD',  'Compressor BW H35KD',    (SELECT id FROM categories WHERE name='Compressor'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('COMP-KB150A', 'Compressor BW KB150.A',  (SELECT id FROM categories WHERE name='Compressor'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('COMP-KB150B', 'Compressor BW KB150.B',  (SELECT id FROM categories WHERE name='Compressor'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('COMP-KB150C', 'Compressor BW KB150.C',  (SELECT id FROM categories WHERE name='Compressor'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- MUG GAS SEPARATOR (5)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, tipe_kepemilikan, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  ('MGS-100A',   'Mug Gas Separator BW-100A',     (SELECT id FROM categories WHERE name='Mug Gas Separator'), (SELECT id FROM parent_units WHERE name='BW-100A'),    'Permanent', 'Aktif', 'Good', 'BW-100A',    'Placeholder.'),
  ('MGS-H35KD',  'Mug Gas Separator BW H35KD',    (SELECT id FROM categories WHERE name='Mug Gas Separator'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   'Permanent', 'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('MGS-KB150A', 'Mug Gas Separator BW KB150.A',  (SELECT id FROM categories WHERE name='Mug Gas Separator'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), 'Permanent', 'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('MGS-KB150B', 'Mug Gas Separator BW KB150.B',  (SELECT id FROM categories WHERE name='Mug Gas Separator'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), 'Permanent', 'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('MGS-KB150C', 'Mug Gas Separator BW KB150.C',  (SELECT id FROM categories WHERE name='Mug Gas Separator'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), 'Permanent', 'Aktif', 'Good', 'BW KB150.C', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT 'TOTAL EQUIPMENT' AS info, COUNT(*) AS jumlah FROM equipment
UNION ALL SELECT 'TOWER LIGHT',        COUNT(*) FROM equipment WHERE tag_number LIKE 'TL-%'
UNION ALL SELECT 'PORTACAMP CREW',     COUNT(*) FROM equipment WHERE tag_number LIKE 'PORT-CREW-%'
UNION ALL SELECT 'PORTACAMP OFFICE',   COUNT(*) FROM equipment WHERE tag_number LIKE 'PORT-OFFICE-%'
UNION ALL SELECT 'PORTACAMP FOREMAN',  COUNT(*) FROM equipment WHERE tag_number LIKE 'PORT-FOREMAN-%'
UNION ALL SELECT 'FIRE PUMP',          COUNT(*) FROM equipment WHERE tag_number LIKE 'FP-%'
UNION ALL SELECT 'BLOWER',             COUNT(*) FROM equipment WHERE tag_number LIKE 'BLW-%'
UNION ALL SELECT 'BPM',                COUNT(*) FROM equipment WHERE tag_number LIKE 'BPM-%'
UNION ALL SELECT 'COMPRESSOR',         COUNT(*) FROM equipment WHERE tag_number LIKE 'COMP-%'
UNION ALL SELECT 'MUG GAS SEPARATOR',  COUNT(*) FROM equipment WHERE tag_number LIKE 'MGS-%';
-- Ekspektasi:
--   TOTAL EQUIPMENT: 130 (sebelumnya 85 + 45 baru)
--   Tiap jenis: 5

COMMIT;

-- ============================================================
-- ROLLBACK (kalau perlu undo):
-- ============================================================
-- BEGIN;
-- DELETE FROM equipment WHERE tag_number IN (
--   'TL-100A','TL-H35KD','TL-KB150A','TL-KB150B','TL-KB150C',
--   'PORT-CREW-100A','PORT-CREW-H35KD','PORT-CREW-KB150A','PORT-CREW-KB150B','PORT-CREW-KB150C',
--   'PORT-OFFICE-100A','PORT-OFFICE-H35KD','PORT-OFFICE-KB150A','PORT-OFFICE-KB150B','PORT-OFFICE-KB150C',
--   'PORT-FOREMAN-100A','PORT-FOREMAN-H35KD','PORT-FOREMAN-KB150A','PORT-FOREMAN-KB150B','PORT-FOREMAN-KB150C',
--   'FP-100A','FP-H35KD','FP-KB150A','FP-KB150B','FP-KB150C',
--   'BLW-100A','BLW-H35KD','BLW-KB150A','BLW-KB150B','BLW-KB150C',
--   'BPM-100A','BPM-H35KD','BPM-KB150A','BPM-KB150B','BPM-KB150C',
--   'COMP-100A','COMP-H35KD','COMP-KB150A','COMP-KB150B','COMP-KB150C',
--   'MGS-100A','MGS-H35KD','MGS-KB150A','MGS-KB150B','MGS-KB150C'
-- );
-- COMMIT;
