-- ============================================================
-- FIX: TRANSMISI parent_equipment_id
-- Aman dijalankan: insert kalau missing, update kalau parent null.
-- ============================================================

BEGIN;

-- ============================================================
-- A. INSERT yang missing (idempoten: ON CONFLICT DO NOTHING)
-- ============================================================
INSERT INTO equipment (tag_number, nama_equipment, kategori_id, assigned_unit_id, parent_equipment_id, tipe_kepemilikan, brand, model, serial_number, status_operasi, kondisi_fisik, lokasi_fisik, remarks)
VALUES
  -- Transmisi Rig (5)
  ('TRANS-100A',   'Transmisi Mobile Rig BW-100A',    (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MR-100A'),   'Permanent', 'Allison', 'S6510-R',  '89384',       'Aktif', 'Good', 'BW-100A',    'Data dari MOBENG-100A spek lama.'),
  ('TRANS-H35KD',  'Transmisi Mobile Rig BW H35KD',   (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MR-H35KD'),  'Permanent', 'CLBT',    '5860-2',   '3110090563', 'Aktif', 'Good', 'BW H35KD',   'Data dari MOBENG-H35KD spek lama.'),
  ('TRANS-KB150A', 'Transmisi Mobile Rig BW KB150.A', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MR-KB150A'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.A', 'Placeholder.'),
  ('TRANS-KB150B', 'Transmisi Mobile Rig BW KB150.B', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MR-KB150B'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.B', 'Placeholder.'),
  ('TRANS-KB150C', 'Transmisi Mobile Rig BW KB150.C', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MR-KB150C'), 'Permanent', NULL,      NULL,       NULL,         'Aktif', 'Good', 'BW KB150.C', 'Placeholder.'),
  -- Transmisi Mudpump (7)
  ('TRANS-MP-100A',    'Transmisi Mudpump MP-100A',    (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW-100A'),    (SELECT id FROM equipment WHERE tag_number='MP-100A'),    'Permanent', 'Allison', 'S.5600 R',  '310105336',  'Aktif', 'Good', 'BW-100A',    'Dari spek lama MOBENG-100A.'),
  ('TRANS-MP-H35KD',   'Transmisi Mudpump MP-H35KD',   (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW H35KD'),   (SELECT id FROM equipment WHERE tag_number='MP-H35KD'),   'Permanent', NULL,      NULL,        NULL,         'Aktif', 'Good', 'BW H35KD',   'Placeholder.'),
  ('TRANS-MP-KB150A',  'Transmisi Mudpump MP-KB150A',  (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.A'), (SELECT id FROM equipment WHERE tag_number='MP-KB150A'),  'Permanent', 'Allison', 'CLT.754DB', '2510208479', 'Aktif', 'Good', 'BW KB150.A', 'Dari spek lama MP-KB150A.'),
  ('TRANS-MP-KB150B',  'Transmisi Mudpump MP-KB150B',  (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.B'), (SELECT id FROM equipment WHERE tag_number='MP-KB150B'),  'Permanent', 'Allison', 'HT.740',    '2510051777', 'Aktif', 'Good', 'BW KB150.B', 'Dari spek lama MP-KB150B.'),
  ('TRANS-MP-KB150C',  'Transmisi Mudpump MP-KB150C',  (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='BW KB150.C'), (SELECT id FROM equipment WHERE tag_number='MP-KB150C'),  'Permanent', 'Allison', 'S5610DR',   '3110049960', 'Aktif', 'Good', 'BW KB150.C', 'Dari spek lama MP-KB150C.'),
  ('TRANS-MP-BACKUP-01', 'Transmisi Mudpump Backup-01', (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-BACKUP-01'), 'Mobile-Backup', NULL, NULL, NULL, 'Standby', 'Good', 'Independent Pool', 'Placeholder.'),
  ('TRANS-MP-ACID-01',   'Transmisi Mudpump Acid-01',   (SELECT id FROM categories WHERE name='Transmisi'), (SELECT id FROM parent_units WHERE name='Independent'), (SELECT id FROM equipment WHERE tag_number='MP-ACID-01'),   'Permanent', NULL, NULL, NULL, 'Aktif', 'Good', 'Independent (Acid)', 'Placeholder.')
ON CONFLICT (tag_number) DO NOTHING;

-- ============================================================
-- B. UPDATE parent_equipment_id buat records yang sudah ada (parent NULL)
-- ============================================================
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-100A')   WHERE tag_number='TRANS-100A'   AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-H35KD')  WHERE tag_number='TRANS-H35KD'  AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150A') WHERE tag_number='TRANS-KB150A' AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150B') WHERE tag_number='TRANS-KB150B' AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MR-KB150C') WHERE tag_number='TRANS-KB150C' AND parent_equipment_id IS NULL;

UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-100A')    WHERE tag_number='TRANS-MP-100A'    AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-H35KD')   WHERE tag_number='TRANS-MP-H35KD'   AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-KB150A')  WHERE tag_number='TRANS-MP-KB150A'  AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-KB150B')  WHERE tag_number='TRANS-MP-KB150B'  AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-KB150C')  WHERE tag_number='TRANS-MP-KB150C'  AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-BACKUP-01') WHERE tag_number='TRANS-MP-BACKUP-01' AND parent_equipment_id IS NULL;
UPDATE equipment SET parent_equipment_id = (SELECT id FROM equipment WHERE tag_number='MP-ACID-01')   WHERE tag_number='TRANS-MP-ACID-01'   AND parent_equipment_id IS NULL;

-- ============================================================
-- VERIFIKASI
-- ============================================================
SELECT tag_number,
       (SELECT tag_number FROM equipment WHERE id = e.parent_equipment_id) AS parent_tag
FROM equipment e
WHERE tag_number LIKE 'TRANS-%'
ORDER BY tag_number;
-- Harus muncul 12 baris, semua parent_tag terisi (MR-XXX atau MP-XXX)

COMMIT;
