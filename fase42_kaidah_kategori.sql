-- ============================================================
-- FASE 42: Kunci kaidah kategori equipment
-- Jalankan SETELAH fase41_koreksi_kategori.sql (butuh nama kategori
-- & nama equipment yang sudah dibetulkan).
--
-- Kaidah = daftar pola kata kunci (dicocokkan ke tag + nama equipment,
-- tidak peduli huruf besar/kecil) -> kategori yang BOLEH dipakai.
-- Dicek berurutan (urutan terkecil dulu), kaidah pertama yang cocok
-- yang berlaku. Contoh: "Engine Power Swivel" kena kaidah engine
-- (Prime Mover) sebelum kaidah power swivel (Rotating System).
--
-- Penegakan:
--   - Form equipment: kategori otomatis terpilih & terkunci.
--   - Database (trigger): INSERT/UPDATE yang melanggar ditolak; kategori
--     kosong diisi otomatis kalau kaidahnya cuma 1 pilihan,
--     termasuk dari import/SQL. Edit equipment yang tidak mengubah
--     tag/nama/kategori/parent unit tidak dicek.
--   - Equipment yang tidak cocok kaidah mana pun = bebas pilih
--     kategori. Jenis alat baru: tambah kaidahnya (admin) di sini.
--
-- Juga: hapus kategori lama yang sudah kosong (sisa fase41) supaya
-- tidak bisa dipilih lagi.
-- Aman di-run ulang.
-- ============================================================

BEGIN;

-- 1. Tabel kaidah
CREATE TABLE IF NOT EXISTS kategori_kaidah (
  id                SERIAL PRIMARY KEY,
  urutan            INT  NOT NULL,
  pola              TEXT NOT NULL,          -- regex, case-insensitive, ke "tag nama"
  khusus_unit_type  TEXT,                   -- NULL = semua; 'Rig' = hanya kalau parent unit bertipe Rig
  kategori_ids      INT[] NOT NULL,         -- kategori yang boleh
  keterangan        TEXT,
  aktif             BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_kategori_kaidah_urutan ON kategori_kaidah(urutan);

ALTER TABLE kategori_kaidah ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "kategori_kaidah_read"  ON kategori_kaidah;
CREATE POLICY "kategori_kaidah_read"  ON kategori_kaidah FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "kategori_kaidah_write" ON kategori_kaidah;
CREATE POLICY "kategori_kaidah_write" ON kategori_kaidah FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- 2. Isi kaidah (nama kategori diubah ke id)
DO $$
DECLARE x TEXT;
BEGIN
  CREATE TEMP TABLE _kaidah (urutan INT, pola TEXT, unit_type TEXT, kategori TEXT[], ket TEXT) ON COMMIT DROP;
  INSERT INTO _kaidah VALUES
    (10,  'fire jeep|damkar',                                   NULL,  ARRAY['Damkar'],                              'Mobil damkar & fire jeep'),
    (19,  'fire ?pump',                                         'Rig', ARRAY['Fire Pump Portable'],                  'Fire pump di rig ikut pindah sumur'),
    (20,  'fire ?pump',                                         NULL,  ARRAY['Fire Pump Fixed','Fire Pump Portable'],'Fire pump di luar rig: fixed atau portable'),
    (30,  'engine|transmisi|transmission',                      NULL,  ARRAY['Prime Mover'],                         'Engine & transmisi (rig, mudpump, power swivel)'),
    (40,  'pompa|mud ?pump',                                    NULL,  ARRAY['Circulating System'],                  'Mudpump & pompanya'),
    (50,  'compressor|kompresor|portacamp|tower light|stand lamp|air receiver', NULL, ARRAY['Auxiliary System'],      NULL),
    (60,  'o.?matic|escape chair|blower',                       NULL,  ARRAY['Safety Equipment'],                    'Crown-O-Matic, escape chair, blower'),
    (70,  'crown +block|drawwork|travel+ing block|auxiliary brake|dead ?line|dealine|sand ?dr|winch', NULL, ARRAY['Hoisting System'], NULL),
    (80,  'mast|monkey board|telescope|locking pawl|raising ram|working floor|pad ?eye|guyline', NULL, ARRAY['Mast'], NULL),
    (90,  'carrier|axle|hydraulic jack',                        NULL,  ARRAY['Carrier'],                             NULL),
    (100, 'mobile rig',                                         NULL,  ARRAY['Mobile Rig'],                          NULL),
    (110, 'tong|elevator|slip|clamp|wrench|make up',            NULL,  ARRAY['Handling Tools'],                      NULL),
    (120, 'bop|accumulator',                                    NULL,  ARRAY['BOP System'],                          NULL),
    (130, 'bpm|gas separator|choke manifold|kill manifold',     NULL,  ARRAY['Well Control System'],                 NULL),
    (140, 'genset|generator',                                   NULL,  ARRAY['Generator Set'],                       NULL),
    (150, 'power ?pack',                                        NULL,  ARRAY['Powerpack'],                           NULL),
    (160, 'power swivel',                                       NULL,  ARRAY['Rotating System'],                     NULL),
    (170, 'console',                                            NULL,  ARRAY['Control & Instrumentation'],           NULL),
    (180, 'forklift',                                           NULL,  ARRAY['Forklift'],                            NULL),
    (181, 'head truck',                                         NULL,  ARRAY['Head Truck'],                          NULL),
    (182, 'crane truck',                                        NULL,  ARRAY['Crane Truck'],                         NULL),
    (183, 'dump truck',                                         NULL,  ARRAY['Dump Truck'],                          NULL),
    (184, 'skimmer',                                            NULL,  ARRAY['Skimmer Truck'],                       NULL),
    (185, 'man ?lift',                                          NULL,  ARRAY['Manlift'],                             NULL),
    (186, 'excavator',                                          NULL,  ARRAY['Excavator'],                           NULL),
    (187, 'backhoe',                                            NULL,  ARRAY['Backhoe Loader'],                      NULL),
    (188, 'bulldozer|dozer',                                    NULL,  ARRAY['Bulldozer'],                           NULL),
    (189, 'compactor|vibro',                                    NULL,  ARRAY['Compactor'],                           NULL),
    (190, 'grader',                                             NULL,  ARRAY['Motor Grader'],                        NULL),
    (200, 'truck',                                              NULL,  ARRAY['Truck'],                               'Truk umum (MTU, slickline) — setelah truk khusus');

  SELECT string_agg(DISTINCT k.nm, ', ') INTO x
    FROM _kaidah, unnest(kategori) AS k(nm)
   WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.name = k.nm);
  IF x IS NOT NULL THEN
    RAISE EXCEPTION 'Kategori belum ada (fase41 sudah dijalankan?): %', x;
  END IF;

  INSERT INTO kategori_kaidah (urutan, pola, khusus_unit_type, kategori_ids, keterangan)
  SELECT k.urutan, k.pola, k.unit_type,
         ARRAY(SELECT c.id FROM unnest(k.kategori) AS n(nm) JOIN categories c ON c.name = n.nm),
         k.ket
    FROM _kaidah k
  ON CONFLICT (urutan) DO UPDATE
    SET pola = EXCLUDED.pola, khusus_unit_type = EXCLUDED.khusus_unit_type,
        kategori_ids = EXCLUDED.kategori_ids, keterangan = EXCLUDED.keterangan;
END $$;

-- 3. Fungsi: kaidah yang berlaku untuk satu equipment
CREATE OR REPLACE FUNCTION fn_kaidah_kategori(p_tag TEXT, p_nama TEXT, p_unit_id INT)
RETURNS kategori_kaidah AS $$
  SELECT k.*
    FROM kategori_kaidah k
   WHERE k.aktif
     AND (COALESCE(p_tag, '') || ' ' || COALESCE(p_nama, '')) ~* k.pola
     AND (k.khusus_unit_type IS NULL
          OR k.khusus_unit_type = (SELECT u.type FROM parent_units u WHERE u.id = p_unit_id))
   ORDER BY k.urutan
   LIMIT 1;
$$ LANGUAGE sql STABLE;

-- 4. Trigger penjaga
CREATE OR REPLACE FUNCTION fn_guard_kaidah_kategori()
RETURNS TRIGGER AS $$
DECLARE
  k kategori_kaidah;
  boleh TEXT;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.tag_number       IS NOT DISTINCT FROM OLD.tag_number
     AND NEW.nama_equipment   IS NOT DISTINCT FROM OLD.nama_equipment
     AND NEW.kategori_id      IS NOT DISTINCT FROM OLD.kategori_id
     AND NEW.assigned_unit_id IS NOT DISTINCT FROM OLD.assigned_unit_id THEN
    RETURN NEW;
  END IF;

  k := fn_kaidah_kategori(NEW.tag_number, NEW.nama_equipment, NEW.assigned_unit_id);
  IF k.id IS NULL OR NEW.kategori_id = ANY (k.kategori_ids) THEN
    RETURN NEW;
  END IF;

  -- Kategori kosong (mis. tambah equipment dari app logbook-equipment yang
  -- tidak punya isian kategori): isi otomatis kalau kaidahnya cuma 1 pilihan,
  -- kalau lebih dari 1 dibiarkan kosong seperti sebelumnya.
  IF NEW.kategori_id IS NULL THEN
    IF array_length(k.kategori_ids, 1) = 1 THEN
      NEW.kategori_id := k.kategori_ids[1];
    END IF;
    RETURN NEW;
  END IF;

  SELECT string_agg(c.name, ' / ' ORDER BY c.name) INTO boleh
    FROM categories c WHERE c.id = ANY (k.kategori_ids);
  RAISE EXCEPTION 'Kategori tidak sesuai kaidah: "%" harus masuk kategori %.', NEW.nama_equipment, boleh
    USING ERRCODE = 'check_violation',
          HINT = 'Kaidah #' || k.urutan || ' (' || k.pola || '). Kalau memang jenis alat lain, minta admin ubah kaidahnya.';
END;
$$ LANGUAGE plpgsql;

-- Nama "trg_a0_..." supaya jalan SEBELUM trg_air_equipment_defaults (trigger
-- BEFORE dijalankan urut abjad), jadi kategori yang diisi otomatis di sini
-- ikut dapat kategori_aset AIR default.
DROP TRIGGER IF EXISTS trg_guard_kaidah_kategori ON equipment;
DROP TRIGGER IF EXISTS trg_a0_kaidah_kategori ON equipment;
CREATE TRIGGER trg_a0_kaidah_kategori
  BEFORE INSERT OR UPDATE OF tag_number, nama_equipment, kategori_id, assigned_unit_id ON equipment
  FOR EACH ROW EXECUTE FUNCTION fn_guard_kaidah_kategori();

-- 5. Hapus kategori lama yang sudah kosong & tidak dipakai di mana pun.
--    Pemakaian dicek otomatis di SEMUA tabel yang punya foreign key ke
--    categories (equipment, performance standard, RCA, dll. — tabel yang
--    tidak ada di database ini otomatis terlewati).
CREATE OR REPLACE FUNCTION pg_temp.kategori_dipakai(p_id INT) RETURNS BOOLEAN AS $f$
DECLARE r record; ada BOOLEAN;
BEGIN
  FOR r IN SELECT c.conrelid::regclass AS tbl, a.attname AS col
             FROM pg_constraint c
             JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
            WHERE c.contype = 'f' AND c.confrelid = 'categories'::regclass LOOP
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s WHERE %I = $1)', r.tbl, r.col) INTO ada USING p_id;
    IF ada THEN RETURN true; END IF;
  END LOOP;
  RETURN false;
END $f$ LANGUAGE plpgsql;

DELETE FROM categories c
 WHERE c.name IN ('MTU','SCM','Mast Component','Pompa','MUDPUMP Acid',
                  'Generator (Slickline)','Powerpack (Slickline)','Truck (Slickline)')
   AND NOT pg_temp.kategori_dipakai(c.id);

-- 6. Verifikasi: equipment yang sekarang melanggar kaidah (harus kosong,
--    kecuali baris terakhir yang berisi ringkasan)
SELECT * FROM (
  SELECT 1 AS urut, e.tag_number, e.nama_equipment, c.name AS kategori_sekarang,
         (SELECT string_agg(c2.name, ' / ') FROM categories c2 WHERE c2.id = ANY (k.kategori_ids)) AS mestinya
    FROM equipment e
    LEFT JOIN categories c ON c.id = e.kategori_id
    CROSS JOIN LATERAL fn_kaidah_kategori(e.tag_number, e.nama_equipment, e.assigned_unit_id) k
   WHERE k.id IS NOT NULL AND NOT (e.kategori_id = ANY (k.kategori_ids))
  UNION ALL
  SELECT 2, 'RINGKASAN',
         (SELECT count(*) FROM kategori_kaidah)::TEXT || ' kaidah',
         'kategori lama tersisa: ' || COALESCE((SELECT string_agg(name, ', ') FROM categories
            WHERE name IN ('MTU','SCM','Mast Component','Pompa','MUDPUMP Acid',
                           'Generator (Slickline)','Powerpack (Slickline)','Truck (Slickline)')), 'tidak ada'),
         NULL
) v ORDER BY urut, tag_number;

COMMIT;

-- ROLLBACK (kalau perlu):
-- DROP TRIGGER IF EXISTS trg_a0_kaidah_kategori ON equipment;
-- DROP FUNCTION IF EXISTS fn_guard_kaidah_kategori();
-- DROP FUNCTION IF EXISTS fn_kaidah_kategori(TEXT, TEXT, INT);
-- DROP TABLE IF EXISTS kategori_kaidah;
