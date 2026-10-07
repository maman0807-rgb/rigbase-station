-- ============================================================
-- FASE 35b: Koreksi pemetaan kategori eRAMHoist → Kategori Aset AIR
-- Berdasarkan nama kategori di database live (2026-10-07) dan
-- keputusan Maman:
--   Carrier = WIN (bagian bawah rig: axle, drivetrain)
--   Alat berat (Backhoe, Bulldozer, Compactor, Excavator, Motor Grader) = GSP
--   SCM (alat pendukung operasi gudang) = GSP
--   Fire Pump Portable = SNE (fungsinya alat pemadam)
--   Auxilary System = AUX
-- Koreksi pola fase35: Well Control System → STA (bukan ICC),
--   Generator (Slickline) → ELE, Powerpack (Slickline) → ROT.
--
-- Equipment ikut diperbarui HANYA kalau kategori_aset-nya masih
-- kosong atau masih sama dengan pemetaan lama (= isian otomatis).
-- Yang sudah diubah manual lewat form tidak disentuh.
-- updated_at tidak berubah. Aman re-run.
-- ============================================================

-- Pemetaan baru (dipakai di langkah 1 & 2 lewat view sementara)
CREATE OR REPLACE VIEW _air_peta_35b AS
SELECT * FROM (VALUES
  ('Auxilary System',       'AUX'),
  ('Backhoe Loader',        'GSP'),
  ('Bulldozer',             'GSP'),
  ('Compactor',             'GSP'),
  ('Excavator',             'GSP'),
  ('Motor Grader',          'GSP'),
  ('SCM',                   'GSP'),
  ('Carrier',               'WIN'),
  ('Hoisting System',       'WIN'),
  ('Circulating System',    'ROT'),
  ('Pompa',                 'ROT'),
  ('Rotating System',       'ROT'),
  ('Powerpack (Slickline)', 'ROT'),
  ('Generator Set',         'ELE'),
  ('Generator (Slickline)', 'ELE'),
  ('Well Control System',   'STA'),
  ('Primover',              'TRK'),
  ('Damkar',                'SNE'),
  ('Fire Pump Portable',    'SNE')
) AS v(name, kode);

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_equipment_updated_at' AND tgrelid = 'equipment'::regclass) THEN
    EXECUTE 'ALTER TABLE equipment DISABLE TRIGGER trg_equipment_updated_at';
  END IF;
END $$;

-- 1. Equipment: ikut pemetaan baru (yang masih isian otomatis saja)
UPDATE equipment e
   SET kategori_aset = p.kode
  FROM categories c
  JOIN _air_peta_35b p ON p.name = c.name
 WHERE e.kategori_id = c.id
   AND (e.kategori_aset IS NULL OR e.kategori_aset IS NOT DISTINCT FROM c.kategori_aset_default)
   AND e.kategori_aset IS DISTINCT FROM p.kode;

-- 2. Categories: simpan pemetaan baru (dipakai trigger untuk equipment baru)
UPDATE categories c
   SET kategori_aset_default = p.kode
  FROM _air_peta_35b p
 WHERE p.name = c.name
   AND c.kategori_aset_default IS DISTINCT FROM p.kode;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_equipment_updated_at' AND tgrelid = 'equipment'::regclass) THEN
    EXECUTE 'ALTER TABLE equipment ENABLE TRIGGER trg_equipment_updated_at';
  END IF;
END $$;

DROP VIEW IF EXISTS _air_peta_35b;

-- 3. Verifikasi: semua kategori sudah terpetakan & jumlah equipment per kategori AIR
SELECT c.name, c.kategori_aset_default,
       (SELECT count(*) FROM equipment e WHERE e.kategori_id = c.id) AS jml,
       (SELECT count(*) FROM equipment e WHERE e.kategori_id = c.id
          AND e.kategori_aset IS DISTINCT FROM c.kategori_aset_default) AS beda_manual
  FROM categories c
 ORDER BY c.kategori_aset_default NULLS FIRST, c.name;
