-- ============================================================
-- FASE 41: Koreksi kategori equipment + typo nama equipment
-- Sumber: usulan_kategori_eramhoist.xlsx (sheet "Perubahan", 101 baris)
--         + 8 fire pump portable (keputusan Maman 2026-10-14)
-- Keputusan Maman 2026-10-14:
--   - Semua usulan kategori dijalankan.
--   - Typo nama equipment dibetulkan.
--   - SL-KB150C ("TIDAK ADA") dibiarkan dulu, parent "Independent"
--     tetap (unit sudah tidak beroperasi), Fire Jeep tetap di Damkar.
--   - Fire pump dibedakan menurut cara pasang: yang terpasang tetap di
--     SP/SKG/SPG/P3/Powerplant/Handak/KM 3 Plaju = "Fire Pump Fixed";
--     yang ikut rig pindah sumur + MTU-01, Ziegler, Fire Station =
--     "Fire Pump Portable".
--
-- Catatan:
--   - Typo kategori (Auxilary System, Primover) di-RENAME barisnya,
--     bukan pindah equipment, supaya pemetaan AIR, performance
--     standard, mapping CSPP & RCA yang menempel ke kategori itu ikut.
--   - "Fire Pump Portable" lama (isinya mayoritas fixed) di-RENAME jadi
--     "Fire Pump Fixed"; "Fire Pump Portable" dibuat baru.
--   - Kategori baru: Head Truck, Crane Truck, Truck, Forklift, Powerpack,
--     Fire Pump Portable.
--   - kategori_aset (AIR) per equipment TIDAK diubah. Cek hasil
--     bagian 6 untuk equipment yang AIR-nya beda dari default kategori
--     barunya, putuskan manual.
--   - Kategori lama yang jadi kosong TIDAK dihapus otomatis (lihat
--     bagian 7, opsional).
--   - Semua dalam 1 transaksi. Kalau ada error, tidak ada yang berubah.
--     Aman di-run ulang.
-- ============================================================

BEGIN;

-- 1. Rename typo kategori
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES ('Auxilary System','Auxiliary System'),
                                 ('Primover','Prime Mover')) v(lama, baru) LOOP
    IF EXISTS (SELECT 1 FROM categories WHERE name = r.lama)
       AND EXISTS (SELECT 1 FROM categories WHERE name = r.baru) THEN
      RAISE EXCEPTION 'Kategori "%" dan "%" dua-duanya ada. Perlu digabung manual, kabari Claude.', r.lama, r.baru;
    END IF;
    UPDATE categories SET name = r.baru WHERE name = r.lama;
  END LOOP;
END $$;

-- 1b. Fire Pump Portable lama -> Fire Pump Fixed (sekali saja; saat re-run
--     "Fire Pump Portable" sudah kategori baru, jangan di-rename lagi)
UPDATE categories SET name = 'Fire Pump Fixed'
 WHERE name = 'Fire Pump Portable'
   AND NOT EXISTS (SELECT 1 FROM categories WHERE name = 'Fire Pump Fixed');

-- 2. Kategori baru (parent_unit_type ikut kategori asal)
INSERT INTO categories (name, parent_unit_type, kategori_aset_default)
SELECT v.baru, COALESCE(c.parent_unit_type, 'Standalone'), v.aset
  FROM (VALUES
    ('Head Truck',  'MTU',                   'TRK'),
    ('Crane Truck', 'MTU',                   'LFT'),
    ('Truck',       'MTU',                   'TRK'),
    ('Forklift',    'SCM',                   'GSP'),  -- ikut keputusan fase35b: alat gudang = GSP
    ('Powerpack',   'Powerpack (Slickline)', 'ROT')
  ) v(baru, asal, aset)
  LEFT JOIN categories c ON c.name = v.asal
ON CONFLICT (name) DO NOTHING;

-- Fire pump portable ada di rig & di Fire & Safety -> Both
INSERT INTO categories (name, parent_unit_type, kategori_aset_default)
VALUES ('Fire Pump Portable', 'Both', 'SNE')
ON CONFLICT (name) DO NOTHING;

-- 3. Daftar usulan
CREATE TEMP TABLE _usulan (tag TEXT, lama TEXT, baru TEXT) ON COMMIT DROP;
INSERT INTO _usulan (tag, lama, baru) VALUES
  ('COMP-100A',               'Auxilary System', 'Auxiliary System'),
  ('COMP-ACID',               'Auxilary System', 'Auxiliary System'),
  ('COMP-H35KD',              'Auxilary System', 'Auxiliary System'),
  ('COMP-KB150A',             'Auxilary System', 'Auxiliary System'),
  ('COMP-KB150B',             'Auxilary System', 'Auxiliary System'),
  ('COMP-KB150C',             'Auxilary System', 'Auxiliary System'),
  ('PORT-CREW-100A',          'Auxilary System', 'Auxiliary System'),
  ('PORT-CREW-H35KD',         'Auxilary System', 'Auxiliary System'),
  ('PORT-CREW-KB150A',        'Auxilary System', 'Auxiliary System'),
  ('PORT-CREW-KB150B',        'Auxilary System', 'Auxiliary System'),
  ('PORT-CREW-KB150C',        'Auxilary System', 'Auxiliary System'),
  ('PORT-FOREMAN-100A',       'Auxilary System', 'Auxiliary System'),
  ('PORT-FOREMAN-H35KD',      'Auxilary System', 'Auxiliary System'),
  ('PORT-FOREMAN-KB150A',     'Auxilary System', 'Auxiliary System'),
  ('PORT-FOREMAN-KB150B',     'Auxilary System', 'Auxiliary System'),
  ('PORT-FOREMAN-KB150C',     'Auxilary System', 'Auxiliary System'),
  ('PORT-OFFICE-100A',        'Auxilary System', 'Auxiliary System'),
  ('PORT-OFFICE-H35KD',       'Auxilary System', 'Auxiliary System'),
  ('PORT-OFFICE-KB150A',      'Auxilary System', 'Auxiliary System'),
  ('PORT-OFFICE-KB150B',      'Auxilary System', 'Auxiliary System'),
  ('PORT-OFFICE-KB150C',      'Auxilary System', 'Auxiliary System'),
  ('SL-KB150A',               'Auxilary System', 'Auxiliary System'),
  ('SL-KB150B',               'Auxilary System', 'Auxiliary System'),
  ('SL-KB150C',               'Auxilary System', 'Auxiliary System'),
  ('TL-H35KD',                'Auxilary System', 'Auxiliary System'),
  ('TL-KB150A',               'Auxilary System', 'Auxiliary System'),
  ('TL-KB150C',               'Auxilary System', 'Auxiliary System'),
  ('TL-RAM Electrical',       'Auxilary System', 'Auxiliary System'),
  ('TNK-COMP-KB150A',         'BOP System', 'Auxiliary System'),
  ('TNK-COMP-KB150B',         'BOP System', 'Auxiliary System'),
  ('TNK-COMP-KB150C',         'BOP System', 'Auxiliary System'),
  ('MP-ACID-01',              'MUDPUMP Acid', 'Circulating System'),
  ('PUMP-ACID-01',            'Pompa', 'Circulating System'),
  ('PUMP-BACKUP-01',          'Pompa', 'Circulating System'),
  ('PUMP-BACKUP-02',          'Pompa', 'Circulating System'),
  ('CT-BG8200CE',             'MTU', 'Crane Truck'),
  ('FL-FORKLIFT-01',          'SCM', 'Forklift'),
  ('FL-FORKLIFT-02',          'SCM', 'Forklift'),
  ('SLG-01',                  'Generator (Slickline)', 'Generator Set'),
  ('HYDTONG-Wellkin-01',      'Auxilary System', 'Handling Tools'),
  ('HYDTONG-Wellkin-04',      'Circulating System', 'Handling Tools'),
  ('HYDTONG-Wellkin-05',      'Auxilary System', 'Handling Tools'),
  ('MUBO-BW-KB150C',          'Mast Component', 'Handling Tools'),
  ('HT-BG8077CE',             'MTU', 'Head Truck'),
  ('HT-BG8078CE',             'MTU', 'Head Truck'),
  ('AuxB-BW 100 A',           'Carrier', 'Hoisting System'),
  ('AuxB-BW H35KD',           'Carrier', 'Hoisting System'),
  ('AuxB-BW KB 150 A',        'Carrier', 'Hoisting System'),
  ('AuxB-BW KB 150 B',        'Carrier', 'Hoisting System'),
  ('AuxB-BW KB 150 C',        'Carrier', 'Hoisting System'),
  ('CRWN-BW-KB150.C',         'Mast Component', 'Hoisting System'),
  ('Crwn- BW H35KD',          'Mast', 'Hoisting System'),
  ('Dealine-BW-KB150.C',      'Carrier', 'Hoisting System'),
  ('LP-100A',                 'Mast Component', 'Mast'),
  ('LP-H35KD',                'Mast Component', 'Mast'),
  ('LP-KB150A',               'Mast Component', 'Mast'),
  ('LP-KB150B',               'Mast Component', 'Mast'),
  ('LP-KB150C',               'Mast Component', 'Mast'),
  ('PadEye-BW-KB150C',        'Carrier', 'Mast'),
  ('Rai-BW-KB150.C',          'Safety Equipment', 'Mast'),
  ('TCP-BW H35KD',            'Hoisting System', 'Mast'),
  ('TCP-BW-KB150C',           'Mast Component', 'Mast'),
  ('WPF-BW-KB150.C',          'Auxilary System', 'Mast'),
  ('SLP-01',                  'Powerpack (Slickline)', 'Powerpack'),
  ('SLP-02',                  'Powerpack (Slickline)', 'Powerpack'),
  ('ENGINE-MP-100A',          'Primover', 'Prime Mover'),
  ('ENGINE-MP-ACID-01',       'Primover', 'Prime Mover'),
  ('ENGINE-MP-BACKUP-01',     'Primover', 'Prime Mover'),
  ('ENGINE-MP-BACKUP-02',     'Primover', 'Prime Mover'),
  ('ENGINE-MP-H35KD',         'Primover', 'Prime Mover'),
  ('ENGINE-MP-KB150A',        'Primover', 'Prime Mover'),
  ('ENGINE-MP-KB150B',        'Primover', 'Prime Mover'),
  ('ENGINE-MP-KB150C',        'Primover', 'Prime Mover'),
  ('MOBENG-100A',             'Primover', 'Prime Mover'),
  ('MOBENG-H35KD',            'Primover', 'Prime Mover'),
  ('MOBENG-KB150A',           'Primover', 'Prime Mover'),
  ('MOBENG-KB150B',           'Primover', 'Prime Mover'),
  ('MOBENG-KB150C',           'Primover', 'Prime Mover'),
  ('Mobeng-Backup-DetroitGM', 'Primover', 'Prime Mover'),
  ('Mobeng-Ex-BWKB150B',      'Primover', 'Prime Mover'),
  ('Mobeng-PWS-002',          'Circulating System', 'Prime Mover'),
  ('TRANS-100A',              'Primover', 'Prime Mover'),
  ('TRANS-BACKUP-CLT750',     'Mobile Rig', 'Prime Mover'),
  ('TRANS-BW 84',             'Primover', 'Prime Mover'),
  ('TRANS-H35KD',             'Primover', 'Prime Mover'),
  ('TRANS-KB150A',            'Primover', 'Prime Mover'),
  ('TRANS-KB150B',            'Primover', 'Prime Mover'),
  ('TRANS-KB150C',            'Primover', 'Prime Mover'),
  ('TRANS-MP-100A',           'Primover', 'Prime Mover'),
  ('TRANS-MP-ACID-01',        'Primover', 'Prime Mover'),
  ('TRANS-MP-BACKUP-01',      'Primover', 'Prime Mover'),
  ('TRANS-MP-BACKUP-02',      'Primover', 'Prime Mover'),
  ('TRANS-MP-H35KD',          'Primover', 'Prime Mover'),
  ('TRANS-MP-KB150A',         'Primover', 'Prime Mover'),
  ('TRANS-MP-KB150B',         'Primover', 'Prime Mover'),
  ('TRANS-MP-KB150C',         'Primover', 'Prime Mover'),
  ('TRANS-STANDBY-01',        'Primover', 'Prime Mover'),
  ('TRANS-STANDBY-02',        'Primover', 'Prime Mover'),
  ('MTU-BG8199CE',            'MTU', 'Truck'),
  ('SLT-01-BG8066CZ',         'Truck (Slickline)', 'Truck'),
  ('SLT-02',                  'Truck (Slickline)', 'Truck'),
  -- Fire pump portable (ikut rig pindah sumur)
  ('FP-100A',                 'Safety Equipment', 'Fire Pump Portable'),
  ('FP-H35KD',                'Safety Equipment', 'Fire Pump Portable'),
  ('FP-KB150A',               'Safety Equipment', 'Fire Pump Portable'),
  ('FP-KB150B',               'Safety Equipment', 'Fire Pump Portable'),
  ('FP-KB150C',               'Safety Equipment', 'Fire Pump Portable'),
  -- "lama" = nama setelah rename langkah 1b
  ('FP-MTU-01',               'Fire Pump Fixed',  'Fire Pump Portable'),
  ('FP-PORTABLE ZIEGLER',     'Fire Pump Fixed',  'Fire Pump Portable'),
  ('FP-FIRE STATION',         'Fire Pump Fixed',  'Fire Pump Portable');

-- Typo kategori sudah di-rename di langkah 1
UPDATE _usulan SET lama = 'Auxiliary System' WHERE lama = 'Auxilary System';
UPDATE _usulan SET lama = 'Prime Mover'      WHERE lama = 'Primover';

DO $$
DECLARE x TEXT;
BEGIN
  SELECT string_agg(DISTINCT u.baru, ', ') INTO x
    FROM _usulan u LEFT JOIN categories c ON c.name = u.baru
   WHERE c.id IS NULL;
  IF x IS NOT NULL THEN
    RAISE EXCEPTION 'Kategori tujuan belum ada di tabel categories: %', x;
  END IF;
END $$;

-- 4. Pindahkan equipment (hanya yang kategorinya masih sesuai "Kategori Lama")
UPDATE equipment e
   SET kategori_id = cb.id
  FROM _usulan u
  JOIN categories cl ON cl.name = u.lama
  JOIN categories cb ON cb.name = u.baru
 WHERE btrim(e.tag_number) = btrim(u.tag)
   AND e.kategori_id = cl.id
   AND cl.id <> cb.id;

-- 5. Typo nama equipment
UPDATE equipment
   SET nama_equipment = n.baru
  FROM (
    SELECT id,
      btrim(regexp_replace(
      regexp_replace(regexp_replace(regexp_replace(regexp_replace(
      regexp_replace(regexp_replace(regexp_replace(regexp_replace(
      regexp_replace(regexp_replace(nama_equipment,
        'Mug Gas Separator',   'Mud Gas Separator', 'g'),
        'Dealine Achor',       'Deadline Anchor',   'g'),
        '\mHydrolik\M',        'Hydraulic',         'g'),
        'JHON DEERE',          'JOHN DEERE',        'g'),
        'Cron[ko] O [Mm]atic', 'Crown-O-Matic',     'g'),
        'Hydrill',             'Hydril',            'g'),
        'MC Kissick',          'McKissick',         'g'),
        '\mMudPump\M',         'Mudpump',           'g'),
        '\mPowertong\M',       'Power Tong',        'g'),
        ' -BG ',               ' - BG ',            'g'),
        '\s{2,}',              ' ',                 'g')) AS baru
      FROM equipment
  ) n
 WHERE equipment.id = n.id
   AND equipment.nama_equipment IS DISTINCT FROM n.baru;

-- 6. Verifikasi (hasil tampil di bawah editor)
SELECT * FROM (
  SELECT 1 AS urut, 'Usulan: tag tidak ditemukan' AS cek, u.tag AS detail
    FROM _usulan u LEFT JOIN equipment e ON btrim(e.tag_number) = btrim(u.tag)
   WHERE e.id IS NULL
  UNION ALL
  SELECT 2, 'Usulan: kategori belum sesuai',
         u.tag || ' sekarang ' || COALESCE(c.name, '(kosong)') || ', mestinya ' || u.baru
    FROM _usulan u
    JOIN equipment e ON btrim(e.tag_number) = btrim(u.tag)
    LEFT JOIN categories c ON c.id = e.kategori_id
   WHERE c.name IS DISTINCT FROM u.baru
  UNION ALL
  SELECT 3, 'AIR beda dari default kategori baru (cek manual)',
         e.tag_number || ': ' || COALESCE(e.kategori_aset, '-') || ' vs default '
         || COALESCE(c.kategori_aset_default, '-') || ' (' || c.name || ')'
    FROM _usulan u
    JOIN equipment e ON btrim(e.tag_number) = btrim(u.tag)
    JOIN categories c ON c.id = e.kategori_id
   WHERE e.kategori_aset IS DISTINCT FROM c.kategori_aset_default
  UNION ALL
  SELECT 4, 'Kategori lama sekarang kosong', c.name
         || ' | perf std: ' || (SELECT count(*) FROM performance_standard p WHERE p.kategori_id = c.id)
         || ' | cspp: '     || (SELECT count(*) FROM cspp_kategori_mapping m WHERE m.kategori_id = c.id)
         || ' | rca: '      || (SELECT count(*) FROM rca_records r WHERE r.kategori_id = c.id)
    FROM categories c
   WHERE c.name IN ('MTU','SCM','Mast Component','Pompa','MUDPUMP Acid',
                    'Generator (Slickline)','Powerpack (Slickline)','Truck (Slickline)')
     AND NOT EXISTS (SELECT 1 FROM equipment e WHERE e.kategori_id = c.id)
  UNION ALL
  SELECT 5, 'Ringkasan', 'Usulan sudah sesuai: '
         || (SELECT count(*) FROM _usulan u
               JOIN equipment e ON btrim(e.tag_number) = btrim(u.tag)
               JOIN categories c ON c.id = e.kategori_id
              WHERE c.name = u.baru)
         || '/' || (SELECT count(*) FROM _usulan)
) v ORDER BY urut, detail;

COMMIT;

-- ============================================================
-- 7. OPSIONAL, jalankan terpisah setelah hasil di atas OK:
-- hapus kategori lama yang sudah kosong supaya tidak muncul lagi di
-- dropdown. Hanya yang tidak dipakai di mana pun (performance standard
-- & mapping CSPP ikut terhapus kalau ada, makanya dicek dulu).
-- ============================================================
-- DELETE FROM categories c
--  WHERE c.name IN ('MTU','SCM','Mast Component','Pompa','MUDPUMP Acid',
--                   'Generator (Slickline)','Powerpack (Slickline)','Truck (Slickline)')
--    AND NOT EXISTS (SELECT 1 FROM equipment e             WHERE e.kategori_id = c.id)
--    AND NOT EXISTS (SELECT 1 FROM performance_standard p  WHERE p.kategori_id = c.id)
--    AND NOT EXISTS (SELECT 1 FROM cspp_kategori_mapping m WHERE m.kategori_id = c.id)
--    AND NOT EXISTS (SELECT 1 FROM rca_records r           WHERE r.kategori_id = c.id);
