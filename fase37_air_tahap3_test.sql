-- ============================================================
-- UJI FASE 37 (AIR Tahap 3) — jalankan SETELAH fase37_air_tahap3.sql
--
-- AMAN: semua uji dalam satu blok yang DIBATALKAN otomatis di akhir.
-- Hasil yang diharapkan: pesan ERROR
--   "SEMUA UJI LULUS (... uji) — data uji dibatalkan otomatis"
-- Pesan lain = ada uji yang GAGAL — kirim pesannya.
-- ============================================================
DO $$
DECLARE
  eV UUID; eI UUID; eS UUID;
  m1 UUID; m2 UUID; m3 UUID; m4 UUID; m5 UUID; m6 UUID; m7 UUID; m8 UUID; m9 UUID;
  dl UUID; dl2 UUID;
  v RECORD;
  n INT := 0;
BEGIN
  -- ---------- Persiapan ----------
  INSERT INTO equipment (tag_number, nama_equipment, criticality) VALUES ('__T3_V__','uji vital','SECE') RETURNING id INTO eV;
  INSERT INTO equipment (tag_number, nama_equipment, criticality) VALUES ('__T3_I__','uji important','IMPORTANT') RETURNING id INTO eI;
  INSERT INTO equipment (tag_number, nama_equipment, criticality) VALUES ('__T3_S__','uji secondary','SECONDARY') RETURNING id INTO eS;

  INSERT INTO materials (part_number, description, category, stok, safety_stock, related_equipments)
    VALUES ('__T3_M1__','vital lewat related_equipments','Critical',0,1, jsonb_build_array(eV::text, 'bukan-uuid')) RETURNING id INTO m1;
  INSERT INTO materials (part_number, description, category, stok) VALUES ('__T3_M2__','important lewat CSPP','Fast Moving',3) RETURNING id INTO m2;
  INSERT INTO cspp_equipment_mapping (equipment_id, material_id) VALUES (eI, m2), (eS, m2);
  INSERT INTO materials (part_number, description, category, stok) VALUES ('__T3_M3__','tidak dipetakan','Consumable',1) RETURNING id INTO m3;
  INSERT INTO materials (part_number, description, category, stok, safety_stock, related_equipments)
    VALUES ('__T3_M4__','vital habis permanen','Critical',0,2, jsonb_build_array(eV::text)) RETURNING id INTO m4;
  INSERT INTO materials (part_number, description, category, stok, safety_stock, related_equipments)
    VALUES ('__T3_M5__','vital di minimum','Critical',2,2, jsonb_build_array(eV::text)) RETURNING id INTO m5;
  INSERT INTO materials (part_number, description, category, stok) VALUES ('__T3_M6__','oli lama','Lubricant',5) RETURNING id INTO m6;
  INSERT INTO materials (part_number, description, category, stok) VALUES ('__T3_M7__','oli baru','Lubricant',3) RETURNING id INTO m7;
  INSERT INTO materials (part_number, description, category, stok, tgl_masuk) VALUES ('__T3_M8__','stok awal import','Fast Moving',10,'2020-01-15') RETURNING id INTO m8;
  INSERT INTO materials (part_number, description, category, stok, safety_stock) VALUES ('__T3_M9__','pemakaian','Fast Moving',4,3) RETURNING id INTO m9;

  -- 1. Kelas VIS otomatis
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m1;
  IF v.kelas_vis <> 'V' OR v.jumlah_equipment <> 1 THEN RAISE EXCEPTION 'GAGAL 1a: m1 harus V (1 equipment, elemen non-uuid diabaikan), dapat % / %', v.kelas_vis, v.jumlah_equipment; END IF;
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m2;
  IF v.kelas_vis <> 'I' OR v.jumlah_equipment <> 2 THEN RAISE EXCEPTION 'GAGAL 1b: m2 harus I (Important + Secondary)'; END IF;
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m3;
  IF v.kelas_vis <> 'S' OR v.dipetakan THEN RAISE EXCEPTION 'GAGAL 1c: m3 tidak dipetakan → S'; END IF;
  UPDATE materials SET kelas_vis_override = 'V' WHERE id = m3;
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m3;
  IF v.kelas_vis <> 'V' OR v.kelas_vis_otomatis <> 'S' THEN RAISE EXCEPTION 'GAGAL 1d: override V'; END IF;
  -- criticality equipment berubah → kelas ikut berubah
  UPDATE equipment SET criticality = 'PCE' WHERE id = eI;
  IF (SELECT kelas_vis FROM v_sparepart_vis WHERE id = m2) <> 'V' THEN RAISE EXCEPTION 'GAGAL 1e: eI jadi PCE → m2 harus V'; END IF;
  UPDATE equipment SET criticality = 'IMPORTANT' WHERE id = eI;
  n := n + 5;

  -- 2. Habis vs dipinjam
  INSERT INTO stock_transactions (material_id, tipe, jumlah, sumber, created_at) VALUES (m1, 'masuk', 2, 'manual', NOW() - interval '60 days');
  INSERT INTO daily_logs (log_date, maintenance_type, notes) VALUES (CURRENT_DATE - 5, 'Peminjaman', 'uji pinjam') RETURNING id INTO dl;
  INSERT INTO stock_transactions (material_id, tipe, jumlah, sumber, daily_log_id, created_at) VALUES (m1, 'keluar', 2, 'dailyLog', dl, NOW() - interval '5 days');
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m1;
  IF v.status_stok <> 'DIPINJAM' OR v.qty_dipinjam <> 2 OR v.alert_vital_habis THEN
    RAISE EXCEPTION 'GAGAL 2a: m1 stok 0 karena dipinjam → DIPINJAM, tanpa alert habis (dapat %, %)', v.status_stok, v.qty_dipinjam;
  END IF;
  -- part kembali (masuk manual) → bukan dipinjam lagi
  UPDATE materials SET stok = 2 WHERE id = m1;
  INSERT INTO stock_transactions (material_id, tipe, jumlah, sumber, created_at) VALUES (m1, 'masuk', 2, 'manual', NOW() - interval '1 day');
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m1;
  IF v.qty_dipinjam <> 0 OR v.status_stok = 'DIPINJAM' THEN RAISE EXCEPTION 'GAGAL 2b: setelah kembali tidak boleh DIPINJAM'; END IF;
  -- vital habis permanen
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m4;
  IF v.status_stok <> 'HABIS' OR NOT v.alert_vital_habis THEN RAISE EXCEPTION 'GAGAL 2c: m4 harus HABIS + alert'; END IF;
  -- vital di minimum (≤)
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m5;
  IF v.status_stok <> 'RENDAH' OR NOT v.alert_vital_rendah OR v.alert_vital_habis THEN RAISE EXCEPTION 'GAGAL 2d: m5 stok = minimum → RENDAH + alert rendah'; END IF;
  -- vital tanpa stok minimum ditandai
  IF NOT (SELECT alert_vital_tanpa_minimum FROM v_sparepart_vis WHERE id = m3) THEN RAISE EXCEPTION 'GAGAL 2e: vital tanpa minimum harus ditandai'; END IF;
  n := n + 5;

  -- 3. Usia simpan FIFO
  INSERT INTO stock_transactions (material_id, tipe, jumlah, sumber, created_at) VALUES
    (m6, 'masuk', 3, 'manual', NOW() - interval '30 months'), (m6, 'masuk', 4, 'manual', NOW() - interval '2 months'),
    (m7, 'masuk', 3, 'manual', NOW() - interval '30 months'), (m7, 'masuk', 4, 'manual', NOW() - interval '2 months');
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m6;
  IF v.usia_bulan < 29 OR NOT v.alert_usia_simpan OR v.usia_maks_bulan <> 24 OR v.usia_perkiraan THEN
    RAISE EXCEPTION 'GAGAL 3a: m6 stok 5 butuh penerimaan 30 bln lalu → usia ~30 > 24 (dapat % / %)', v.usia_bulan, v.usia_maks_bulan;
  END IF;
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m7;
  IF v.usia_bulan > 3 OR v.alert_usia_simpan THEN RAISE EXCEPTION 'GAGAL 3b: m7 stok 3 cukup dari penerimaan terbaru → usia ~2 bln'; END IF;
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m8;
  IF NOT v.usia_perkiraan OR v.tgl_stok_tertua <> '2020-01-15' OR NOT v.alert_usia_simpan THEN
    RAISE EXCEPTION 'GAGAL 3c: m8 tanpa riwayat masuk → pakai tgl_masuk 2020-01-15 (perkiraan)';
  END IF;
  IF (SELECT usia_bulan FROM v_sparepart_vis WHERE id = m4) IS NOT NULL THEN RAISE EXCEPTION 'GAGAL 3d: stok 0 → usia NULL'; END IF;
  n := n + 4;

  -- 4. Proyeksi 2 tahun: semua keluar dihitung (termasuk Peminjaman), koreksi edit dikurangi,
  --    audit gudang diabaikan, transaksi di luar 24 bulan diabaikan
  INSERT INTO daily_logs (log_date, maintenance_type) VALUES (CURRENT_DATE - 30, 'CM') RETURNING id INTO dl2;
  INSERT INTO stock_transactions (material_id, tipe, jumlah, sumber, daily_log_id, created_at) VALUES
    (m9, 'keluar', 10, 'dailyLog', dl2, NOW() - interval '30 days'),
    (m9, 'masuk',   2, 'dailyLog', dl2, NOW() - interval '29 days'),     -- koreksi edit Input Harian
    (m9, 'keluar',  3, 'dailyLog', dl,  NOW() - interval '4 days'),      -- Peminjaman tetap dihitung
    (m9, 'keluar',  4, 'manual',   NULL, NOW() - interval '10 days'),
    (m9, 'keluar',  5, 'audit_gudang', NULL, NOW() - interval '9 days'), -- penyesuaian, bukan pemakaian
    (m9, 'keluar',100, 'dailyLog', dl2, NOW() - interval '30 months');   -- di luar periode
  SELECT * INTO v FROM v_sparepart_vis WHERE id = m9;
  IF v.pakai_periode <> 15 THEN RAISE EXCEPTION 'GAGAL 4a: pemakaian bersih harus 15, dapat %', v.pakai_periode; END IF;
  IF v.bulan_data <> 24 OR v.kebutuhan_2th <> 15 THEN RAISE EXCEPTION 'GAGAL 4b: kebutuhan 2 th harus 15 (bulan data %)', v.bulan_data; END IF;
  IF v.rekomendasi_pengadaan <> 14 THEN RAISE EXCEPTION 'GAGAL 4c: rekomendasi = 15 + min 3 - stok 4 = 14, dapat %', v.rekomendasi_pengadaan; END IF;
  n := n + 3;

  -- 5. Stok berlebih
  UPDATE materials SET stok_maksimum = 3 WHERE id = m8;
  IF (SELECT status_stok FROM v_sparepart_vis WHERE id = m8) <> 'BERLEBIH' THEN RAISE EXCEPTION 'GAGAL 5: stok 10 > maks 3 → BERLEBIH'; END IF;
  n := n + 1;

  -- 6. Reservasi SAP
  INSERT INTO reservasi_sparepart (material_id, equipment_id, qty, sap_reservation_no) VALUES (m1, eV, 1, '0099887766');
  BEGIN
    INSERT INTO reservasi_sparepart (material_id, qty) VALUES (m1, 0);
    RAISE EXCEPTION 'GAGAL 6a: qty 0 harus ditolak';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM materials WHERE id = m1;
  IF EXISTS (SELECT 1 FROM reservasi_sparepart WHERE material_id = m1) THEN RAISE EXCEPTION 'GAGAL 6b: reservasi ikut terhapus'; END IF;
  n := n + 2;

  RAISE EXCEPTION 'SEMUA UJI LULUS (% uji) — data uji dibatalkan otomatis', n;
END $$;
