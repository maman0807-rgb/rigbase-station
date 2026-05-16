-- ============================================================
-- RIGBASE STATION — SEED DATA
-- ============================================================
-- 8 parent_units + 29 categories.
-- Aman dijalankan ulang (ON CONFLICT DO NOTHING).
-- Jalankan SETELAH supabase_schema.sql.
-- ============================================================

-- ============================================================
-- PARENT UNITS (8 unit)
-- ============================================================
INSERT INTO parent_units (name, type) VALUES
  ('BW-100A',          'Rig'),
  ('BW H35KD',         'Rig'),
  ('BW KB150.A',       'Rig'),
  ('BW KB150.B',       'Rig'),
  ('BW KB150.C',       'Rig'),
  ('Unit MTU',         'Standalone'),
  ('Unit Slickline',   'Standalone'),
  ('Independent',      'Standalone')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- CATEGORIES (29 kategori)
-- ============================================================

-- Untuk Rig (20)
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Drawwork',              'Rig'),
  ('Mast',                  'Rig'),
  ('Mobile Engine',         'Rig'),
  ('Mudpump',               'Rig'),
  ('Travelling Block',      'Rig'),
  ('Swivel / Power Swivel', 'Rig'),
  ('Rotary Table',          'Rig'),
  ('BOP Annular',           'Rig'),
  ('BOP Single Ram',        'Rig'),
  ('BOP Double Ram',        'Rig'),
  ('Accumulator',           'Rig'),
  ('Genset',                'Rig'),
  ('Rotary Tong',           'Rig'),
  ('Tubing Tong',           'Rig'),
  ('Weight Indicator',      'Rig'),
  ('Stand Lamp',            'Rig'),
  ('Lampu Menara',          'Rig'),
  ('Portacamp',             'Rig'),
  ('Tower Light',           'Rig'),
  ('Sub Structure',         'Rig')
ON CONFLICT (name) DO NOTHING;

-- Untuk MTU (4) — type Standalone
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Pump (MTU)',            'Standalone'),
  ('Tank (MTU)',            'Standalone'),
  ('Engine (MTU)',          'Standalone'),
  ('Manifold (MTU)',        'Standalone')
ON CONFLICT (name) DO NOTHING;

-- Untuk Slickline (4) — type Standalone
INSERT INTO categories (name, parent_unit_type) VALUES
  ('Winch Unit (Slickline)',    'Standalone'),
  ('Wireline Reel (Slickline)', 'Standalone'),
  ('Mast (Slickline)',          'Standalone'),
  ('Lubricator (Slickline)',    'Standalone')
ON CONFLICT (name) DO NOTHING;

-- Untuk Independent (1) — type Standalone
INSERT INTO categories (name, parent_unit_type) VALUES
  ('MUDPUMP Acid', 'Standalone')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- VERIFIKASI
-- ============================================================
-- Jalankan query berikut buat cek hasil seed:
--   SELECT type, COUNT(*) FROM parent_units GROUP BY type;
--     -> Rig: 5, Standalone: 3
--   SELECT parent_unit_type, COUNT(*) FROM categories GROUP BY parent_unit_type;
--     -> Rig: 20, Standalone: 9
-- ============================================================
