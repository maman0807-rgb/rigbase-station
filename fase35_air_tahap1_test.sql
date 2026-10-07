-- ============================================================
-- UJI FASE 35 (AIR Tahap 1) — jalankan SETELAH fase35_air_tahap1.sql
--
-- AMAN: seluruh uji berjalan dalam satu blok yang DIBATALKAN otomatis
-- di akhir. Tidak ada data yang tersimpan.
--
-- Hasil yang diharapkan: muncul pesan ERROR berbunyi
--   "SEMUA UJI LULUS (... uji) — data uji dibatalkan otomatis"
-- Itu tandanya sukses (ERROR sengaja dipakai untuk rollback).
-- Kalau muncul pesan lain, berarti ada uji yang GAGAL — kirim pesannya.
-- ============================================================
DO $$
DECLARE
  eq UUID;
  kat INT;
  n INT := 0;
  h TEXT; s INT; ks BOOLEAN;
  d INT; p INT; expected TEXT;
  e RECORD;
  v RECORD;
  combos TEXT[][];
  i INT;
BEGIN
  -- ---------- Persiapan: equipment uji ----------
  SELECT id INTO kat FROM categories WHERE name ILIKE '%accumulator%' LIMIT 1;
  INSERT INTO equipment (tag_number, nama_equipment, kategori_id, status_aset, kepemilikan)
  VALUES ('__TEST_AIR__', 'Equipment uji AIR', kat, NULL, NULL)
  RETURNING id INTO eq;

  -- 1. Default equipment: NULL → ACTIVE / MILIK, lingkup true, vital false
  SELECT * INTO e FROM equipment WHERE id = eq;
  IF e.status_aset <> 'ACTIVE' OR e.kepemilikan <> 'MILIK' THEN RAISE EXCEPTION 'GAGAL 1: default status_aset/kepemilikan'; END IF;
  IF e.dalam_lingkup_air IS NOT TRUE OR e.is_vital IS NOT FALSE THEN RAISE EXCEPTION 'GAGAL 1: default lingkup/vital'; END IF;
  IF kat IS NOT NULL AND e.kategori_aset IS DISTINCT FROM (SELECT kategori_aset_default FROM categories WHERE id = kat) THEN
    RAISE EXCEPTION 'GAGAL 1: kategori_aset tidak ikut categories.kategori_aset_default';
  END IF;
  n := n + 1;

  -- 2. Di luar lingkup AIR
  UPDATE equipment SET alasan_di_luar_lingkup = 'SEWA' WHERE id = eq;
  IF (SELECT dalam_lingkup_air FROM equipment WHERE id = eq) THEN RAISE EXCEPTION 'GAGAL 2: lingkup harus false'; END IF;
  UPDATE equipment SET alasan_di_luar_lingkup = NULL WHERE id = eq;
  IF NOT (SELECT dalam_lingkup_air FROM equipment WHERE id = eq) THEN RAISE EXCEPTION 'GAGAL 2: lingkup harus true lagi'; END IF;
  n := n + 1;

  -- 3. KUALITATIF: semua jalur Q1–Q5
  combos := ARRAY[
    -- q1,q2,q3,q4,q5, hasil
    ARRAY['t',NULL,NULL,NULL,NULL,'SECE'],
    ARRAY['f','t',NULL,NULL,NULL,'SECE'],
    ARRAY['f','f','t',NULL,NULL,'SECE'],
    ARRAY['f','f','f','t',NULL,'PCE'],
    ARRAY['f','f','f','f','t','IMPORTANT'],
    ARRAY['f','f','f','f','f','SECONDARY']
  ];
  FOR i IN 1..array_length(combos, 1) LOOP
    INSERT INTO criticality_assessment (equipment_id, metode, q1, q2, q3, q4, q5)
    VALUES (eq, 'KUALITATIF', combos[i][1]::boolean, combos[i][2]::boolean, combos[i][3]::boolean,
            combos[i][4]::boolean, combos[i][5]::boolean)
    RETURNING hasil INTO h;
    IF h <> combos[i][6] THEN RAISE EXCEPTION 'GAGAL 3.%: dapat %, harusnya %', i, h, combos[i][6]; END IF;
    n := n + 1;
  END LOOP;

  -- 4. KUALITATIF: jawaban bolong harus ditolak
  BEGIN
    INSERT INTO criticality_assessment (equipment_id, metode, q1, q2) VALUES (eq, 'KUALITATIF', false, NULL);
    RAISE EXCEPTION 'GAGAL 4: Q2 kosong harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  n := n + 1;

  -- 5. ECA: seluruh 25 kombinasi dampak × probabilitas
  FOR d IN 1..5 LOOP
    FOR p IN 1..5 LOOP
      expected := CASE WHEN d*p >= 15 THEN 'PCE' WHEN d*p >= 5 THEN 'IMPORTANT' ELSE 'SECONDARY' END;
      INSERT INTO criticality_assessment (equipment_id, metode, dampak, probabilitas)
      VALUES (eq, 'ECA', d, p) RETURNING hasil, skor, kandidat_sece INTO h, s, ks;
      IF h <> expected OR s <> d*p OR ks <> (d = 5) THEN
        RAISE EXCEPTION 'GAGAL 5: ECA d=% p=% → % skor % kandidat %', d, p, h, s, ks;
      END IF;
      n := n + 1;
    END LOOP;
  END LOOP;

  -- 6. ECA tanpa probabilitas ditolak; PHA tanpa hasil ditolak; PHA dengan hasil diterima
  BEGIN
    INSERT INTO criticality_assessment (equipment_id, metode, dampak) VALUES (eq, 'ECA', 3);
    RAISE EXCEPTION 'GAGAL 6a: ECA tanpa probabilitas harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO criticality_assessment (equipment_id, metode) VALUES (eq, 'PHA');
    RAISE EXCEPTION 'GAGAL 6b: PHA tanpa hasil harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  n := n + 2;

  -- 7. Sinkron ke master: penilaian TERBARU (by tanggal) yang menang
  DELETE FROM criticality_assessment WHERE equipment_id = eq;
  IF (SELECT criticality FROM equipment WHERE id = eq) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 7a: hapus semua → criticality harus NULL'; END IF;
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, hasil) VALUES (eq, '2026-01-10', 'PHA', 'PCE');
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, q1) VALUES (eq, '2026-03-01', 'KUALITATIF', true);
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, hasil) VALUES (eq, '2025-12-01', 'PHA', 'SECONDARY'); -- lebih lama, tidak boleh menang
  SELECT * INTO e FROM equipment WHERE id = eq;
  IF e.criticality <> 'SECE' OR e.criticality_metode <> 'KUALITATIF' OR e.criticality_tgl_penetapan <> '2026-03-01' THEN
    RAISE EXCEPTION 'GAGAL 7b: master harus SECE/KUALITATIF/2026-03-01, dapat %/%/%', e.criticality, e.criticality_metode, e.criticality_tgl_penetapan;
  END IF;
  IF e.criticality_tgl_validasi_ulang <> '2028-03-01' THEN RAISE EXCEPTION 'GAGAL 7c: validasi ulang harus 2028-03-01, dapat %', e.criticality_tgl_validasi_ulang; END IF;
  IF e.is_vital IS NOT TRUE THEN RAISE EXCEPTION 'GAGAL 7d: SECE harus vital'; END IF;
  -- Metode non-kualitatif → tanggal validasi ulang kosong
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, hasil) VALUES (eq, '2026-04-01', 'PHA', 'IMPORTANT');
  SELECT * INTO e FROM equipment WHERE id = eq;
  IF e.criticality <> 'IMPORTANT' OR e.criticality_tgl_validasi_ulang IS NOT NULL OR e.is_vital THEN
    RAISE EXCEPTION 'GAGAL 7e: PHA IMPORTANT → validasi ulang NULL & tidak vital';
  END IF;
  n := n + 5;

  -- 8. INTEGRITY: semua jalur S1–S3
  combos := ARRAY[
    ARRAY['t',NULL,NULL,'BREAKDOWN'],
    ARRAY['f','t',NULL,'LOW'],
    ARRAY['f','f','t','MEDIUM'],
    ARRAY['f','f','f','HIGH']
  ];
  FOR i IN 1..array_length(combos, 1) LOOP
    INSERT INTO integrity_assessment (equipment_id, s1, s2, s3)
    VALUES (eq, combos[i][1]::boolean, combos[i][2]::boolean, combos[i][3]::boolean)
    RETURNING status INTO h;
    IF h <> combos[i][4] THEN RAISE EXCEPTION 'GAGAL 8.%: dapat %, harusnya %', i, h, combos[i][4]; END IF;
    n := n + 1;
  END LOOP;
  BEGIN
    INSERT INTO integrity_assessment (equipment_id, s1) VALUES (eq, false);
    RAISE EXCEPTION 'GAGAL 8e: S2 kosong harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  n := n + 1;

  -- 9. DRAFT tidak meng-update master; konfirmasi baru meng-update
  DELETE FROM integrity_assessment WHERE equipment_id = eq;
  INSERT INTO integrity_assessment (equipment_id, tanggal, s1, s2, s3) VALUES (eq, '2026-05-01', false, false, false); -- HIGH
  INSERT INTO integrity_assessment (equipment_id, tanggal, s1, sumber, konfirmasi)
    VALUES (eq, '2026-06-01', true, 'LAPORAN_HARIAN', 'DRAFT');
  IF (SELECT status_integrity FROM equipment WHERE id = eq) <> 'HIGH' THEN RAISE EXCEPTION 'GAGAL 9a: DRAFT tidak boleh mengubah master'; END IF;
  UPDATE integrity_assessment SET konfirmasi = 'DIKONFIRMASI' WHERE equipment_id = eq AND konfirmasi = 'DRAFT';
  SELECT * INTO e FROM equipment WHERE id = eq;
  IF e.status_integrity <> 'BREAKDOWN' OR e.status_integrity_tgl <> '2026-06-01' THEN RAISE EXCEPTION 'GAGAL 9b: setelah konfirmasi harus BREAKDOWN'; END IF;
  n := n + 2;

  -- 10. Matriks: 16 sel lengkap
  IF (SELECT count(*) FROM matriks_tindak_lanjut_air) <> 16 THEN RAISE EXCEPTION 'GAGAL 10: matriks harus 16 sel'; END IF;
  n := n + 1;

  -- 11. View: IMPORTANT + BREAKDOWN → Repair / Replacement, prioritas 3
  SELECT * INTO v FROM v_equipment_air_status WHERE id = eq;
  IF v.aksi <> 'Repair / Replacement' OR v.prioritas <> 3 OR v.immediate OR v.belum_dinilai THEN
    RAISE EXCEPTION 'GAGAL 11a: view aksi/prioritas salah (% / %)', v.aksi, v.prioritas;
  END IF;
  -- SECE + BREAKDOWN → immediate, prioritas 1
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, hasil) VALUES (eq, '2026-07-01', 'PHA', 'SECE');
  SELECT * INTO v FROM v_equipment_air_status WHERE id = eq;
  IF v.prioritas <> 1 OR NOT v.immediate THEN RAISE EXCEPTION 'GAGAL 11b: SECE+BREAKDOWN harus prioritas 1 immediate'; END IF;
  -- Flag validasi ulang: KUALITATIF 2 tahun lalu → jatuh tempo ≤ 60 hari
  DELETE FROM criticality_assessment WHERE equipment_id = eq;
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, q1) VALUES (eq, CURRENT_DATE - 700, 'KUALITATIF', true);
  SELECT * INTO v FROM v_equipment_air_status WHERE id = eq;
  IF NOT v.perlu_validasi_criticality THEN RAISE EXCEPTION 'GAGAL 11c: dinilai 700 hari lalu harus perlu validasi'; END IF;
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, q1) VALUES (eq, CURRENT_DATE, 'KUALITATIF', true);
  SELECT * INTO v FROM v_equipment_air_status WHERE id = eq;
  IF v.perlu_validasi_criticality THEN RAISE EXCEPTION 'GAGAL 11d: baru dinilai hari ini, belum perlu validasi'; END IF;
  -- Taxonomy otomatis: tanpa parent = 6
  IF v.taxonomy_level <> 6 THEN RAISE EXCEPTION 'GAGAL 11e: taxonomy tanpa parent harus 6'; END IF;
  n := n + 5;

  -- 12. Hapus equipment → riwayat ikut terhapus (cascade), tidak error
  DELETE FROM equipment WHERE id = eq;
  IF EXISTS (SELECT 1 FROM criticality_assessment WHERE equipment_id = eq)
     OR EXISTS (SELECT 1 FROM integrity_assessment WHERE equipment_id = eq) THEN
    RAISE EXCEPTION 'GAGAL 12: riwayat harus ikut terhapus';
  END IF;
  n := n + 1;

  RAISE EXCEPTION 'SEMUA UJI LULUS (% uji) — data uji dibatalkan otomatis', n;
END $$;
