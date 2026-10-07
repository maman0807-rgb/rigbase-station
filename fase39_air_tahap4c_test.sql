-- ============================================================
-- UJI FASE 39 (AIR Tahap 4C) — jalankan SETELAH fase39_air_tahap4c.sql
--
-- AMAN: semua uji dalam satu blok yang DIBATALKAN otomatis di akhir.
-- Hasil yang diharapkan: pesan ERROR
--   "SEMUA UJI LULUS (... uji) — data uji dibatalkan otomatis"
-- Pesan lain = ada uji yang GAGAL — kirim pesannya.
--
-- Uji memakai bulan fiktif Januari 2020 supaya data asli tidak ikut terhitung.
-- ============================================================
DO $$
DECLARE
  per DATE := '2020-01-01';
  a UUID; b UUID; c UUID; x UUID; rc UUID;
  v RECORD;
  n INT := 0;
  m JSONB := '{}';
  r RECORD;
  ids UUID[];
BEGIN
  -- Tiga unit uji aktif sejak 2019 + satu unit di luar lingkup
  INSERT INTO equipment (tag_number, nama_equipment, tanggal_masuk_operasi) VALUES ('__T4C_A__','a','2019-01-01') RETURNING id INTO a;
  INSERT INTO equipment (tag_number, nama_equipment, tanggal_masuk_operasi) VALUES ('__T4C_B__','b','2019-01-01') RETURNING id INTO b;
  INSERT INTO equipment (tag_number, nama_equipment, tanggal_masuk_operasi) VALUES ('__T4C_C__','c','2020-01-16') RETURNING id INTO c;  -- mulai operasi tengah bulan
  INSERT INTO equipment (tag_number, nama_equipment, tanggal_masuk_operasi, alasan_di_luar_lingkup) VALUES ('__T4C_X__','x','2019-01-01','SEWA') RETURNING id INTO x;

  -- Penilaian per akhir Jan 2020: a vital & Low, b vital & High, c belum dinilai
  INSERT INTO criticality_assessment (equipment_id, tanggal, metode, hasil) VALUES (a, '2020-01-05', 'PHA', 'SECE'), (b, '2020-01-05', 'PHA', 'PCE');
  INSERT INTO integrity_assessment (equipment_id, tanggal, s1, s2) VALUES (a, '2020-01-10', false, true);          -- LOW
  INSERT INTO integrity_assessment (equipment_id, tanggal, s1, s2, s3) VALUES (b, '2020-01-10', false, false, false); -- HIGH
  INSERT INTO integrity_assessment (equipment_id, tanggal, s1) VALUES (b, '2020-02-10', true);                    -- Feb: tidak boleh ikut Jan
  -- Izin: a berlaku, b kedaluwarsa per akhir Jan
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_terbit, tgl_kedaluwarsa) VALUES (a, 'SKPI', 'A1', '2019-06-01', '2021-06-01'), (b, 'SKPI', 'B1', '2018-01-01', '2020-01-20');
  -- Downtime Jan 2020: a breakdown 10 jam (mode+cause), b troubleshoot 20 jam (mode tanpa cause), gejala 100 jam (tidak dihitung), x di luar lingkup
  INSERT INTO downtime_events (equipment_id, start_at, end_at, category, failure_mode, failure_cause) VALUES
    (a, '2020-01-02 00:00+00', '2020-01-02 10:00+00', 'breakdown', 'VIB', '3.4'),
    (b, '2020-01-03 00:00+00', '2020-01-03 20:00+00', 'troubleshoot', 'ELU', NULL),
    (b, '2020-01-05 00:00+00', '2020-01-09 04:00+00', 'gejala', NULL, NULL),
    (x, '2020-01-05 00:00+00', '2020-01-06 00:00+00', 'breakdown', 'VIB', '3.4');

  ids := ARRAY[a, b, c, x];
  FOR r IN SELECT * FROM air_kpi_hitung(per, ids) LOOP m := m || jsonb_build_object(r.kode, r.nilai); END LOOP;

  -- 1. Penilaian: 2 dari 3 dinilai lengkap (x di luar lingkup tidak dihitung)
  IF (m->>'PENILAIAN')::numeric <> 66.7 THEN RAISE EXCEPTION 'GAGAL 1: PENILAIAN harus 66.7, dapat %', m->>'PENILAIAN'; END IF;
  -- 2. Vital baik: 1 dari 2 (a Low, b High; kejadian Feb tidak ikut)
  IF (m->>'INTEG_VITAL')::numeric <> 50 THEN RAISE EXCEPTION 'GAGAL 2: INTEG_VITAL harus 50, dapat %', m->>'INTEG_VITAL'; END IF;
  -- 3. Izin berlaku: 1 dari 2
  IF (m->>'IZIN')::numeric <> 50 THEN RAISE EXCEPTION 'GAGAL 3: IZIN harus 50, dapat %', m->>'IZIN'; END IF;
  -- 4. Ao: periode a,b = 744 jam, c = 16 hari (384 jam) → 1872; downtime 30 jam → (1872-30)/1872 = 98.40
  IF (m->>'AO')::numeric <> 98.40 THEN RAISE EXCEPTION 'GAGAL 4: AO harus 98.40, dapat %', m->>'AO'; END IF;
  -- 5. MTBF = 1842 / 2 = 921; MTTR = (10+20)/2 = 15
  IF (m->>'MTBF')::numeric <> 921 OR (m->>'MTTR')::numeric <> 15 THEN RAISE EXCEPTION 'GAGAL 5: MTBF 921 / MTTR 15, dapat % / %', m->>'MTBF', m->>'MTTR'; END IF;
  -- 6. Failure tercatat lengkap: 1 dari 2 (b ditutup tanpa cause)
  IF (m->>'FAIL_REC')::numeric <> 50 THEN RAISE EXCEPTION 'GAGAL 6: FAIL_REC harus 50, dapat %', m->>'FAIL_REC'; END IF;
  n := n + 6;

  -- 7. RCA tindak lanjut terlambat per akhir Jan
  INSERT INTO rca_records (equipment_id, failure_date, failure_description, status) VALUES (a, '2020-01-02', 'uji', 'TINDAK_LANJUT') RETURNING id INTO rc;
  INSERT INTO rca_tindakan (rca_id, aksi, due_date, status) VALUES
    (rc, 'telat open', '2020-01-15', 'OPEN'),
    (rc, 'selesai tepat', '2020-01-15', 'SELESAI'),
    (rc, 'selesai telat (Feb)', '2020-01-20', 'SELESAI'),
    (rc, 'belum due', '2020-03-01', 'OPEN');
  UPDATE rca_tindakan SET tgl_selesai = '2020-01-14' WHERE rca_id = rc AND aksi = 'selesai tepat';
  UPDATE rca_tindakan SET tgl_selesai = '2020-02-05' WHERE rca_id = rc AND aksi = 'selesai telat (Feb)';
  SELECT nilai INTO v FROM air_kpi_hitung(per, ids) WHERE kode = 'RCA_TELAT';
  IF v.nilai <> 2 THEN RAISE EXCEPTION 'GAGAL 7: RCA_TELAT harus 2, dapat %', v.nilai; END IF;
  n := n + 1;

  -- 8. Isi otomatis → realisasi + tercapai
  PERFORM air_kpi_isi_otomatis(per, ids);
  IF (SELECT status FROM laporan_air_bulanan WHERE periode = per) <> 'DRAFT' THEN RAISE EXCEPTION 'GAGAL 8a: laporan dibuat DRAFT'; END IF;
  SELECT * INTO v FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'AO';
  IF v.tercapai IS NOT TRUE OR v.target_saat_itu <> 90 THEN RAISE EXCEPTION 'GAGAL 8b: AO 98.4 ≥ 90 tercapai'; END IF;
  IF (SELECT tercapai FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'IZIN') IS NOT FALSE THEN RAISE EXCEPTION 'GAGAL 8c: IZIN 50 < 100 tidak tercapai'; END IF;
  IF (SELECT tercapai FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'MTBF') IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 8d: MTBF tanpa target = NULL'; END IF;
  IF (SELECT tercapai FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'RCA_TELAT') IS NOT FALSE THEN RAISE EXCEPTION 'GAGAL 8e: RCA_TELAT 2 > 0 (MAX) tidak tercapai'; END IF;
  -- KPI manual
  INSERT INTO kpi_air_realisasi (periode, kpi_kode, nilai) VALUES (per, 'SAFETY', 0);
  IF (SELECT tercapai FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'SAFETY') IS NOT TRUE THEN RAISE EXCEPTION 'GAGAL 8f: SAFETY 0 ≤ 0 tercapai'; END IF;
  -- isi ulang tidak menghapus SAMBAL
  UPDATE kpi_air_realisasi SET sambal_siapa = 'Spv' WHERE periode = per AND kpi_kode = 'IZIN';
  PERFORM air_kpi_isi_otomatis(per, ids);
  IF (SELECT sambal_siapa FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'IZIN') <> 'Spv' THEN RAISE EXCEPTION 'GAGAL 8g: isi ulang menghapus SAMBAL'; END IF;
  n := n + 7;

  -- 9. FINAL ditolak kalau SAMBAL belum lengkap
  BEGIN
    UPDATE laporan_air_bulanan SET status = 'FINAL' WHERE periode = per;
    RAISE EXCEPTION 'GAGAL 9a: FINAL tanpa SAMBAL harus ditolak';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%Izin operasi berlaku%' THEN RAISE EXCEPTION 'GAGAL 9b: pesan harus sebut KPI-nya, dapat %', SQLERRM; END IF;
  END;
  UPDATE kpi_air_realisasi SET sambal_siapa = 'Spv', sambal_apa = 'x', sambal_mengapa = 'x', sambal_bagaimana = 'x', sambal_aksi_lanjut = 'x'
   WHERE periode = per AND tercapai = false;
  UPDATE laporan_air_bulanan SET status = 'FINAL', difinalkan_oleh = 'uji' WHERE periode = per;
  IF (SELECT tgl_final FROM laporan_air_bulanan WHERE periode = per) IS NULL THEN RAISE EXCEPTION 'GAGAL 9c: tgl_final terisi'; END IF;
  n := n + 3;

  -- 10. Laporan FINAL terkunci; dibuka lagi → boleh ubah
  BEGIN
    UPDATE kpi_air_realisasi SET nilai = 1 WHERE periode = per AND kpi_kode = 'SAFETY';
    RAISE EXCEPTION 'GAGAL 10a: FINAL harus terkunci';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  UPDATE laporan_air_bulanan SET status = 'DRAFT' WHERE periode = per;
  UPDATE kpi_air_realisasi SET nilai = 1 WHERE periode = per AND kpi_kode = 'SAFETY';
  IF (SELECT tercapai FROM kpi_air_realisasi WHERE periode = per AND kpi_kode = 'SAFETY') IS NOT FALSE THEN RAISE EXCEPTION 'GAGAL 10b: SAFETY 1 > 0 tidak tercapai'; END IF;
  n := n + 2;

  -- 11. Periode yang belum dimulai ditolak
  BEGIN
    PERFORM * FROM air_kpi_hitung((date_trunc('month', NOW()) + interval '1 month')::date);
    RAISE EXCEPTION 'GAGAL 11: periode mendatang harus ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  n := n + 1;

  RAISE EXCEPTION 'SEMUA UJI LULUS (% uji) — data uji dibatalkan otomatis', n;
END $$;
