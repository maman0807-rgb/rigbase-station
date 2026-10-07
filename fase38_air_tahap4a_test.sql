-- ============================================================
-- UJI FASE 38 (AIR Tahap 4A) — jalankan SETELAH fase38_air_tahap4a.sql
--
-- AMAN: semua uji dalam satu blok yang DIBATALKAN otomatis di akhir.
-- Hasil yang diharapkan: pesan ERROR
--   "SEMUA UJI LULUS (... uji) — data uji dibatalkan otomatis"
-- Pesan lain = ada uji yang GAGAL — kirim pesannya.
-- ============================================================
DO $$
DECLARE
  e UUID; c UUID; p UUID;
  i1 UUID; i2 UUID; rla UUID; d UUID; rc UUID;
  v RECORD;
  n INT := 0;
  cnt INT;
  t TEXT;
BEGIN
  INSERT INTO equipment (tag_number, nama_equipment, criticality) VALUES ('__T4_E__','uji 4A','PCE') RETURNING id INTO e;

  -- 1. Izin → sinkron ke kolom lama
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'SKPI', 'SKPI-LAMA', '2023-01-01', '2026-01-01');
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'SKPI', 'SKPI-BARU', '2026-01-02', '2029-01-01') RETURNING id INTO i1;
  SELECT * INTO v FROM equipment WHERE id = e;
  IF v.nomor_skpi <> 'SKPI-BARU' OR v.skpi_end_date <> '2029-01-01' OR v.skpi_start_date <> '2026-01-02' THEN
    RAISE EXCEPTION 'GAGAL 1a: kolom SKPI lama harus dari izin SKPI terbaru (dapat %)', v.nomor_skpi;
  END IF;
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, penerbit, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'COI', 'COI-1', 'Lembaga A', '2026-01-01', '2027-06-01');
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, penerbit, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'LOAD_TEST', 'LT-1', 'Lembaga B', '2026-02-01', '2026-12-01') RETURNING id INTO i2;
  INSERT INTO izin_operasi (equipment_id, jenis, nomor) VALUES (e, 'COC', 'COC-9');
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_kedaluwarsa) VALUES (e, 'PLO', 'PLO-1', '2026-02-01');  -- PLO tidak masuk "sertifikat lain"
  SELECT * INTO v FROM equipment WHERE id = e;
  IF v.nomor_sertifikat_lain <> 'LT-1' OR v.tgl_expired_sertifikat <> '2026-12-01' OR v.lembaga_penerbit <> 'Lembaga B' OR v.coc_number <> 'COC-9' THEN
    RAISE EXCEPTION 'GAGAL 1b: sertifikat lain = yang paling cepat habis (LT-1), COC-9 (dapat %, %)', v.nomor_sertifikat_lain, v.coc_number;
  END IF;
  DELETE FROM izin_operasi WHERE id = i2;
  IF (SELECT nomor_sertifikat_lain FROM equipment WHERE id = e) <> 'COI-1' THEN RAISE EXCEPTION 'GAGAL 1c: hapus LT → COI-1'; END IF;
  DELETE FROM izin_operasi WHERE equipment_id = e AND jenis = 'SKPI';
  IF (SELECT skpi_end_date FROM equipment WHERE id = e) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 1d: semua SKPI dihapus → kolom kosong'; END IF;
  n := n + 4;

  -- 2. Status izin di view
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'SKPI', 'S-EXP', CURRENT_DATE - 400, CURRENT_DATE - 1);
  SELECT * INTO v FROM v_izin_operasi WHERE equipment_id = e AND nomor = 'S-EXP';
  IF v.status <> 'KEDALUWARSA' OR NOT v.terbaru THEN RAISE EXCEPTION 'GAGAL 2a: KEDALUWARSA'; END IF;
  IF NOT EXISTS (SELECT 1 FROM v_air_lifecycle_alert WHERE equipment_id = e AND tipe = 'IZIN' AND status = 'KEDALUWARSA') THEN RAISE EXCEPTION 'GAGAL 2b: alert izin'; END IF;
  INSERT INTO izin_operasi (equipment_id, jenis, nomor, tgl_terbit, tgl_kedaluwarsa) VALUES (e, 'SKPI', 'S-NEW', CURRENT_DATE, CURRENT_DATE + 30);
  IF (SELECT status FROM v_izin_operasi WHERE nomor = 'S-NEW' AND equipment_id = e) <> 'AKAN_HABIS' THEN RAISE EXCEPTION 'GAGAL 2c: AKAN_HABIS'; END IF;
  IF (SELECT terbaru FROM v_izin_operasi WHERE nomor = 'S-EXP' AND equipment_id = e) THEN RAISE EXCEPTION 'GAGAL 2d: S-EXP sudah bukan terbaru'; END IF;
  IF EXISTS (SELECT 1 FROM v_air_lifecycle_alert WHERE equipment_id = e AND item LIKE '%S-EXP%') THEN RAISE EXCEPTION 'GAGAL 2e: izin lama yang sudah diperpanjang tidak boleh alert'; END IF;
  IF (SELECT status FROM v_izin_operasi WHERE nomor = 'COC-9' AND equipment_id = e) <> 'TANPA_BATAS' THEN RAISE EXCEPTION 'GAGAL 2f: COC tanpa batas'; END IF;
  n := n + 6;

  -- 3. RLA → kolom master + draft integrity
  INSERT INTO rla_assessment (equipment_id, tanggal, kesimpulan, batas_layan_baru, tgl_rla_berikutnya, nomor_laporan)
    VALUES (e, '2026-03-01', 'LAYAK_LANJUT', '2031-03-01', '2029-03-01', 'RLA-1');
  SELECT * INTO v FROM equipment WHERE id = e;
  IF v.sisa_umur_layan_sampai <> '2031-03-01' OR v.rla_kesimpulan <> 'LAYAK_LANJUT' THEN RAISE EXCEPTION 'GAGAL 3a: sinkron RLA'; END IF;
  IF EXISTS (SELECT 1 FROM integrity_assessment WHERE equipment_id = e AND sumber = 'RLA') THEN RAISE EXCEPTION 'GAGAL 3b: layak lanjut tidak membuat draft'; END IF;
  INSERT INTO rla_assessment (equipment_id, tanggal, kesimpulan, batas_layan_baru, syarat_rekomendasi, nomor_laporan)
    VALUES (e, '2026-06-01', 'LAYAK_DENGAN_SYARAT', CURRENT_DATE + 60, 'Ganti sling', 'RLA-2') RETURNING id INTO rla;
  SELECT * INTO v FROM integrity_assessment WHERE equipment_id = e AND sumber = 'RLA';
  IF v.status <> 'MEDIUM' OR v.konfirmasi <> 'DRAFT' OR v.sumber_ref_id <> rla::text THEN RAISE EXCEPTION 'GAGAL 3c: bersyarat → draft MEDIUM'; END IF;
  IF (SELECT status_integrity FROM equipment WHERE id = e) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 3d: draft tidak boleh mengubah master'; END IF;
  INSERT INTO rla_assessment (equipment_id, tanggal, kesimpulan, nomor_laporan) VALUES (e, '2026-01-01', 'TIDAK_LAYAK', 'RLA-0');
  IF NOT EXISTS (SELECT 1 FROM integrity_assessment WHERE equipment_id = e AND sumber = 'RLA' AND status = 'LOW') THEN RAISE EXCEPTION 'GAGAL 3e: tidak layak → draft LOW'; END IF;
  IF (SELECT rla_kesimpulan FROM equipment WHERE id = e) <> 'LAYAK_DENGAN_SYARAT' THEN RAISE EXCEPTION 'GAGAL 3f: master = RLA terbaru (bukan yang tanggalnya lebih lama)'; END IF;
  IF NOT EXISTS (SELECT 1 FROM v_air_lifecycle_alert WHERE equipment_id = e AND tipe = 'BATAS_LAYAN') THEN RAISE EXCEPTION 'GAGAL 3g: batas layan ≤ 90 hari harus alert'; END IF;
  n := n + 7;

  -- 4. Biaya tahunan (Peminjaman/Permintaan tidak dihitung)
  INSERT INTO daily_logs (log_date, equipment_id, maintenance_type, subtotals, total) VALUES
    ('2025-05-01', e, 'CM', '{"manpower":100,"parts":200,"transport":0,"vendor":50}', 350),
    ('2025-07-01', e, 'PM', '{"manpower":10,"parts":20,"transport":5,"vendor":0}', 35),
    ('2025-08-01', e, 'Peminjaman', '{"parts":999}', 999);
  SELECT * INTO v FROM v_biaya_pemeliharaan_tahunan WHERE equipment_id = e AND tahun = 2025;
  IF v.biaya_total <> 385 OR v.biaya_part <> 220 OR v.jumlah_kegiatan <> 2 THEN RAISE EXCEPTION 'GAGAL 4: biaya 2025 harus 385 (part 220, 2 kegiatan), dapat %', v.biaya_total; END IF;
  n := n + 1;

  -- 5. Decommissioning
  INSERT INTO equipment (tag_number, nama_equipment, parent_equipment_id) VALUES ('__T4_C__','komponen', e) RETURNING id INTO c;
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e, NOW(), 'breakdown', 'BRD') RETURNING id INTO d;
  INSERT INTO rla_tindakan (rla_id, aksi) VALUES (rla, 'Ganti sling');
  BEGIN
    UPDATE equipment SET status_aset = 'DECOMMISSIONED', decommission_ref = 'ND-001' WHERE id = e;
    RAISE EXCEPTION 'GAGAL 5a: harus ditolak (masih ada item terbuka)';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
    IF SQLERRM NOT LIKE '%Downtime masih terbuka%' OR SQLERRM NOT LIKE '%Komponen%' OR SQLERRM NOT LIKE '%RLA%' THEN
      RAISE EXCEPTION 'GAGAL 5b: pesan harus menyebut semua penghalang, dapat: %', SQLERRM;
    END IF;
  END;
  SELECT count(*) INTO cnt FROM air_decommission_blockers(e);
  IF cnt < 3 THEN RAISE EXCEPTION 'GAGAL 5c: blockers >= 3, dapat %', cnt; END IF;
  -- tanpa referensi dokumen → ditolak
  UPDATE downtime_events SET end_at = NOW(), failure_cause = '3.4' WHERE id = d;
  UPDATE rla_tindakan SET status = 'SELESAI' WHERE rla_id = rla;
  UPDATE equipment SET status_aset = 'DECOMMISSIONED', decommission_ref = 'ND-C' WHERE id = c;
  -- RCA terbuka yang memuat unit ini lewat equipment_ids juga menghalangi
  INSERT INTO rca_records (equipment_id, equipment_ids, failure_date, failure_description, status) VALUES (c, ARRAY[c, e], CURRENT_DATE, 'uji', 'ANALISIS') RETURNING id INTO rc;
  IF NOT EXISTS (SELECT 1 FROM air_decommission_blockers(e) WHERE jenis = 'RCA belum Closed') THEN RAISE EXCEPTION 'GAGAL 5d: RCA lewat equipment_ids harus menghalangi'; END IF;
  UPDATE rca_records SET status = 'CLOSED' WHERE id = rc;
  BEGIN
    UPDATE equipment SET status_aset = 'DECOMMISSIONED' WHERE id = e;
    RAISE EXCEPTION 'GAGAL 5e: tanpa referensi dokumen harus ditolak';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  UPDATE equipment SET status_aset = 'DECOMMISSIONED', decommission_ref = 'ND-001' WHERE id = e;
  SELECT * INTO v FROM equipment WHERE id = e;
  IF v.status_operasi <> 'Scrap' OR v.decommission_tgl <> CURRENT_DATE THEN RAISE EXCEPTION 'GAGAL 5f: decommission → status_operasi Scrap + tanggal'; END IF;
  IF EXISTS (SELECT 1 FROM v_air_lifecycle_alert WHERE equipment_id = e) THEN RAISE EXCEPTION 'GAGAL 5g: unit decommissioned tidak muncul di alert'; END IF;
  n := n + 5;

  -- 6. Penanda riwayat (untuk mengarahkan Hapus → Decommissioning)
  t := air_equipment_punya_riwayat(e);
  IF t IS NULL OR t NOT LIKE '%downtime%' OR t NOT LIKE '%Input Harian%' OR t NOT LIKE '%izin operasi%' THEN RAISE EXCEPTION 'GAGAL 6a: riwayat e, dapat %', t; END IF;
  INSERT INTO equipment (tag_number, nama_equipment) VALUES ('__T4_P__','baru salah input') RETURNING id INTO p;
  IF air_equipment_punya_riwayat(p) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 6b: unit baru tanpa riwayat → NULL'; END IF;
  n := n + 2;

  RAISE EXCEPTION 'SEMUA UJI LULUS (% uji) — data uji dibatalkan otomatis', n;
END $$;
