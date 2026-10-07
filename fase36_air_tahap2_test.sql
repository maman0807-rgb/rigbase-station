-- ============================================================
-- UJI FASE 36 (AIR Tahap 2) — jalankan SETELAH fase36_air_tahap2.sql
--
-- AMAN: semua uji dalam satu blok yang DIBATALKAN otomatis di akhir.
-- Hasil yang diharapkan: pesan ERROR
--   "SEMUA UJI LULUS (... uji) — data uji dibatalkan otomatis"
-- Pesan lain = ada uji yang GAGAL — kirim pesannya.
-- ============================================================
DO $$
DECLARE
  kat INT; kat2 INT;
  e1 UUID; e2 UUID; e3 UUID; ex UUID;
  d1 UUID; d2 UUID; d3 UUID; d4 UUID; dx UUID;
  r UUID;
  n INT := 0;
  h TEXT; c INT; arr UUID[];
  v RECORD;
BEGIN
  -- ---------- Persiapan ----------
  INSERT INTO categories (name) VALUES ('__TEST_KAT_AIR2__') RETURNING id INTO kat;
  INSERT INTO categories (name) VALUES ('__TEST_KAT_AIR2B__') RETURNING id INTO kat2;
  INSERT INTO equipment (tag_number, nama_equipment, kategori_id) VALUES ('__T2_A__','uji A',kat) RETURNING id INTO e1;
  INSERT INTO equipment (tag_number, nama_equipment, kategori_id) VALUES ('__T2_B__','uji B',kat) RETURNING id INTO e2;
  INSERT INTO equipment (tag_number, nama_equipment, kategori_id) VALUES ('__T2_C__','uji C',kat) RETURNING id INTO e3;
  INSERT INTO equipment (tag_number, nama_equipment, kategori_id) VALUES ('__T2_X__','uji X',kat2) RETURNING id INTO ex;

  -- 1. Strategi pemeliharaan: semua jalur M1–M4
  INSERT INTO maintenance_strategy_assessment (equipment_id, m1, m2) VALUES (e1, false, false) RETURNING hasil INTO h;
  IF h <> 'REACTIVE' THEN RAISE EXCEPTION 'GAGAL 1a: % (harus REACTIVE)', h; END IF;
  INSERT INTO maintenance_strategy_assessment (equipment_id, m1, m2, m3) VALUES (e1, false, true, true) RETURNING hasil INTO h;
  IF h <> 'CBM_PREDICTIVE' THEN RAISE EXCEPTION 'GAGAL 1b: %', h; END IF;
  INSERT INTO maintenance_strategy_assessment (equipment_id, m1, m3) VALUES (e1, true, true) RETURNING hasil INTO h;
  IF h <> 'CBM_PREDICTIVE' THEN RAISE EXCEPTION 'GAGAL 1c: %', h; END IF;
  INSERT INTO maintenance_strategy_assessment (equipment_id, m1, m3, m4) VALUES (e1, true, false, true) RETURNING hasil INTO h;
  IF h <> 'PREVENTIVE' THEN RAISE EXCEPTION 'GAGAL 1d: %', h; END IF;
  INSERT INTO maintenance_strategy_assessment (equipment_id, m1, m2, m3, m4) VALUES (e1, false, true, false, false) RETURNING hasil INTO h;
  IF h <> 'REDESIGN' THEN RAISE EXCEPTION 'GAGAL 1e: %', h; END IF;
  n := n + 5;
  BEGIN
    INSERT INTO maintenance_strategy_assessment (equipment_id, m1) VALUES (e1, false);
    RAISE EXCEPTION 'GAGAL 1f: M2 kosong harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO maintenance_strategy_assessment (equipment_id, m1) VALUES (e1, true);
    RAISE EXCEPTION 'GAGAL 1g: M3 kosong harusnya ditolak';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'GAGAL%' THEN RAISE; END IF;
  END;
  n := n + 2;
  -- Sinkron ke master: terbaru menang
  DELETE FROM maintenance_strategy_assessment WHERE equipment_id = e1;
  IF (SELECT strategi_pemeliharaan FROM equipment WHERE id = e1) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 1h: hapus semua → NULL'; END IF;
  INSERT INTO maintenance_strategy_assessment (equipment_id, tanggal, m1, m3, m4) VALUES (e1, '2026-05-01', true, false, true);
  INSERT INTO maintenance_strategy_assessment (equipment_id, tanggal, m1, m2) VALUES (e1, '2026-01-01', false, false);
  IF (SELECT strategi_pemeliharaan FROM equipment WHERE id = e1) <> 'PREVENTIVE' THEN RAISE EXCEPTION 'GAGAL 1i: terbaru harus menang'; END IF;
  n := n + 2;

  -- 2. Klasifikasi kegiatan
  INSERT INTO downtime_events (equipment_id, start_at, end_at, category) VALUES (e1, '2026-02-01 08:00', '2026-02-01 10:00', 'pm') RETURNING id INTO dx;
  SELECT * INTO v FROM v_kegiatan_pemeliharaan WHERE id = dx;
  IF v.jenis_utama <> 'PREVENTIVE' OR v.sub_jenis <> 'SCHEDULED_SERVICE' OR v.predictive THEN RAISE EXCEPTION 'GAGAL 2a: pm'; END IF;
  INSERT INTO downtime_events (equipment_id, start_at, category, jenis_corrective) VALUES (ex, '2026-02-02 08:00', 'breakdown', 'DEFERRED') RETURNING id INTO dx;
  SELECT * INTO v FROM v_kegiatan_pemeliharaan WHERE id = dx;
  IF v.jenis_utama <> 'CORRECTIVE' OR v.sub_jenis <> 'DEFERRED' THEN RAISE EXCEPTION 'GAGAL 2b: override jenis_corrective'; END IF;
  INSERT INTO downtime_events (equipment_id, start_at, category) VALUES (ex, '2026-02-03 08:00', 'troubleshoot') RETURNING id INTO dx;
  IF (SELECT sub_jenis FROM v_kegiatan_pemeliharaan WHERE id = dx) <> 'IMMEDIATE' THEN RAISE EXCEPTION 'GAGAL 2c: default troubleshoot'; END IF;
  INSERT INTO downtime_events (equipment_id, start_at, category) VALUES (ex, '2026-02-04 08:00', 'gejala') RETURNING id INTO dx;
  SELECT * INTO v FROM v_kegiatan_pemeliharaan WHERE id = dx;
  IF NOT v.predictive OR v.jenis_utama <> 'PREVENTIVE' THEN RAISE EXCEPTION 'GAGAL 2d: gejala = predictive'; END IF;
  INSERT INTO downtime_events (equipment_id, start_at, category) VALUES (ex, '2026-02-05 08:00', 'tunggu_spare') RETURNING id INTO dx;
  IF EXISTS (SELECT 1 FROM v_kegiatan_pemeliharaan WHERE id = dx) THEN RAISE EXCEPTION 'GAGAL 2e: tunggu_spare bukan kegiatan'; END IF;
  n := n + 5;

  -- 3. Status RCA: lama ditolak, baru diterima, default DRAFT
  BEGIN
    INSERT INTO rca_records (equipment_id, failure_date, failure_description, status) VALUES (e1, '2026-01-01', 'x', 'Open');
    RAISE EXCEPTION 'GAGAL 3a: status lama Open harusnya ditolak';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO rca_records (equipment_id, failure_date, failure_description) VALUES (ex, '2026-01-01', 'manual') RETURNING id INTO r;
  IF (SELECT status FROM rca_records WHERE id = r) <> 'DRAFT' OR (SELECT pemicu FROM rca_records WHERE id = r) <> 'MANUAL' THEN
    RAISE EXCEPTION 'GAGAL 3b: default DRAFT/MANUAL';
  END IF;
  INSERT INTO rca_tindakan (rca_id, aksi, pic, due_date) VALUES (r, 'Buat SOP alignment', 'Sr Mekanik', '2026-12-01');
  DELETE FROM rca_records WHERE id = r;
  IF EXISTS (SELECT 1 FROM rca_tindakan WHERE rca_id = r) THEN RAISE EXCEPTION 'GAGAL 3c: tindakan harus ikut terhapus'; END IF;
  n := n + 3;

  -- 4. Repetitive failure → RCA DRAFT otomatis
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e1, '2026-01-10', 'breakdown', 'VIB') RETURNING id INTO d1;
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e2, '2026-03-10', 'troubleshoot', 'VIB') RETURNING id INTO d2;
  IF EXISTS (SELECT 1 FROM rca_records WHERE kategori_id = kat) THEN RAISE EXCEPTION 'GAGAL 4a: 2 kejadian belum boleh memicu RCA'; END IF;
  -- mode beda & gejala tidak dihitung
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e3, '2026-04-10', 'breakdown', 'OHE');
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e3, '2026-04-11', 'gejala', 'VIB');
  IF EXISTS (SELECT 1 FROM rca_records WHERE kategori_id = kat) THEN RAISE EXCEPTION 'GAGAL 4b: mode beda / gejala tidak boleh dihitung'; END IF;
  -- kejadian ke-3 (unit lain, kategori sama) → DRAFT
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e3, '2026-06-10', 'breakdown', 'VIB') RETURNING id INTO d3;
  SELECT count(*) INTO c FROM rca_records WHERE kategori_id = kat AND pemicu = 'REPETITIVE';
  IF c <> 1 THEN RAISE EXCEPTION 'GAGAL 4c: harus 1 RCA, dapat %', c; END IF;
  SELECT id, downtime_event_ids INTO r, arr FROM rca_records WHERE kategori_id = kat AND pemicu = 'REPETITIVE';
  IF (SELECT status FROM rca_records WHERE id = r) <> 'DRAFT' OR cardinality(arr) <> 3 OR NOT (arr @> ARRAY[d1,d2,d3])
     OR cardinality((SELECT equipment_ids FROM rca_records WHERE id = r)) <> 3 THEN
    RAISE EXCEPTION 'GAGAL 4d: RCA harus DRAFT dengan 3 downtime & 3 unit';
  END IF;
  -- kejadian ke-4 → RCA yang sama diperbarui, tidak dobel
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e1, '2026-07-01', 'breakdown', 'VIB') RETURNING id INTO d4;
  SELECT count(*) INTO c FROM rca_records WHERE kategori_id = kat AND pemicu = 'REPETITIVE';
  IF c <> 1 OR NOT ((SELECT downtime_event_ids FROM rca_records WHERE id = r) @> ARRAY[d4]) THEN
    RAISE EXCEPTION 'GAGAL 4e: kejadian ke-4 harus masuk RCA yang sama';
  END IF;
  -- RCA ditutup → kejadian berikutnya membuat RCA baru
  UPDATE rca_records SET status = 'CLOSED' WHERE id = r;
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (e2, '2026-07-15', 'breakdown', 'VIB');
  SELECT count(*) INTO c FROM rca_records WHERE kategori_id = kat AND pemicu = 'REPETITIVE' AND status = 'DRAFT';
  IF c <> 1 THEN RAISE EXCEPTION 'GAGAL 4f: setelah CLOSED harus muncul DRAFT baru, dapat %', c; END IF;
  n := n + 6;

  -- 5. Tersebar > 12 bulan tidak memicu; klasifikasi belakangan (UPDATE) di tengah jendela memicu
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, '2023-01-10', 'breakdown', 'FTS');
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, '2024-03-10', 'breakdown', 'FTS');
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, '2025-05-10', 'breakdown', 'FTS');
  IF EXISTS (SELECT 1 FROM rca_records WHERE kategori_id = kat2 AND pemicu = 'REPETITIVE') THEN
    RAISE EXCEPTION 'GAGAL 5a: 3 kejadian tersebar >12 bulan tidak boleh memicu';
  END IF;
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, '2022-01-10', 'breakdown', 'ELU');
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, '2022-11-10', 'breakdown', 'ELU');
  INSERT INTO downtime_events (equipment_id, start_at, category) VALUES (ex, '2022-06-10', 'breakdown') RETURNING id INTO dx;
  IF EXISTS (SELECT 1 FROM rca_records WHERE kategori_id = kat2 AND failure_mode = 'ELU') THEN
    RAISE EXCEPTION 'GAGAL 5b: belum diklasifikasi, belum boleh memicu';
  END IF;
  UPDATE downtime_events SET failure_mode = 'ELU' WHERE id = dx;   -- diklasifikasi belakangan, berada di tengah
  IF NOT EXISTS (SELECT 1 FROM rca_records WHERE kategori_id = kat2 AND failure_mode = 'ELU' AND status = 'DRAFT') THEN
    RAISE EXCEPTION 'GAGAL 5c: klasifikasi di tengah jendela harus memicu RCA';
  END IF;
  n := n + 3;

  -- 6. View kandidat: kombinasi >=2 dalam 12 bulan terakhir muncul
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, NOW() - interval '10 days', 'breakdown', 'NOI');
  INSERT INTO downtime_events (equipment_id, start_at, category, failure_mode) VALUES (ex, NOW() - interval '5 days', 'troubleshoot', 'NOI');
  SELECT * INTO v FROM v_air_repetitive_kandidat WHERE kategori_id = kat2 AND failure_mode = 'NOI';
  IF v.jumlah <> 2 OR v.rca_id IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 6: kandidat NOI harus 2 kejadian tanpa RCA'; END IF;
  n := n + 1;

  -- 7. Hapus downtime yang dirujuk komponen_id / equipment tidak error
  UPDATE downtime_events SET komponen_id = e2 WHERE id = d1;
  DELETE FROM equipment WHERE id = e2;
  IF (SELECT komponen_id FROM downtime_events WHERE id = d1) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 7: komponen_id harus jadi NULL'; END IF;
  n := n + 1;

  RAISE EXCEPTION 'SEMUA UJI LULUS (% uji) — data uji dibatalkan otomatis', n;
END $$;
