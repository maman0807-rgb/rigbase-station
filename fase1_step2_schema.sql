-- ============================================================
-- eRAMHoist Fase 1 - STEP 2: Schema changes utk armada baru
-- Jalankan SEKALI di Supabase SQL Editor.
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING utk INSERT).
-- ============================================================

-- 2.1 Perluas CHECK constraint armada
ALTER TABLE parent_units DROP CONSTRAINT IF EXISTS parent_units_type_check;
ALTER TABLE parent_units ADD  CONSTRAINT parent_units_type_check
  CHECK (type IN ('Rig','Standalone','Alat Berat','Kendaraan','Fire & Safety'));

ALTER TABLE categories   DROP CONSTRAINT IF EXISTS categories_parent_unit_type_check;
ALTER TABLE categories   ADD  CONSTRAINT categories_parent_unit_type_check
  CHECK (parent_unit_type IN ('Rig','Standalone','Alat Berat','Kendaraan','Fire & Safety','Both'));

-- 2.2 Parent_units baru (3 armada bucket)
INSERT INTO parent_units (name, type) VALUES
  ('Alat Berat Civil', 'Alat Berat'),
  ('Kendaraan',        'Kendaraan'),
  ('Fire & Safety',    'Fire & Safety')
ON CONFLICT (name) DO NOTHING;

-- 2.3 Categories baru
-- Alat Berat (6)
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Motor Grader',   'Alat Berat'),
  ('Bulldozer',      'Alat Berat'),
  ('Excavator',      'Alat Berat'),
  ('Compactor',      'Alat Berat'),
  ('Backhoe Loader', 'Alat Berat'),
  ('Forklift',       'Alat Berat')
ON CONFLICT (name) DO NOTHING;

-- Kendaraan (6)
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Cargo Truck',   'Kendaraan'),
  ('Head Truck',    'Kendaraan'),
  ('Dump Truck',    'Kendaraan'),
  ('Crane Truck',   'Kendaraan'),
  ('Manlift',       'Kendaraan'),
  ('Skimmer Truck', 'Kendaraan')
ON CONFLICT (name) DO NOTHING;

-- Fire & Safety (2)
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Fire Pump Portable', 'Fire & Safety'),
  ('Damkar',             'Fire & Safety')
ON CONFLICT (name) DO NOTHING;

-- Slickline tambahan (3) - Standalone
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Powerpack (Slickline)', 'Standalone'),
  ('Generator (Slickline)', 'Standalone'),
  ('Truck (Slickline)',     'Standalone')
ON CONFLICT (name) DO NOTHING;

-- Tower Light (Rig) - kalau belum ada di cats live
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Tower Light', 'Rig')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- VERIFIKASI - jalankan dan kirim hasilnya ke Chanis
-- ============================================================
SELECT 'parent_units' AS tabel, COUNT(*) AS jumlah FROM parent_units
UNION ALL
SELECT 'categories', COUNT(*) FROM categories;

-- harusnya:
--   parent_units = 11 (8 lama + 3 baru)
--   categories   = 27 lama + 18 baru = 45 (kurang lebih, tergantung yang sudah ada)

SELECT type, COUNT(*) FROM parent_units GROUP BY type ORDER BY type;
-- harusnya: Rig=5, Standalone=3, Alat Berat=1, Kendaraan=1, Fire & Safety=1

SELECT id, name, type FROM parent_units WHERE type IN ('Alat Berat','Kendaraan','Fire & Safety') ORDER BY id;
-- catat id-nya, Chanis perlu utk Step 3 INSERT equipment
