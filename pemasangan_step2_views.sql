-- ============================================================
-- STEP 2 — Views perhitungan HM anak (live, tanpa simpan angka)
-- Rollback: DROP VIEW IF EXISTS v_hm_anak_aktif, v_hm_anak_total;
-- ============================================================

-- 2a. HM anak yang SEDANG terpasang (running, satu baris per anak aktif)
CREATE OR REPLACE VIEW v_hm_anak_aktif AS
SELECT
  p.id                      AS pemasangan_id,
  p.anak_tag,
  p.induk_id,
  p.posisi,
  p.punya_meter_sendiri,
  p.tanggal_pasang,

  -- HM running = selisih dari snapshot saat pasang ke nilai terkini
  CASE
    WHEN p.punya_meter_sendiri THEN
      -- Mode meter sendiri: meter terkini anak (running_hours anak) - snapshot saat pasang
      anak.running_hours - p.hm_meter_pasang
    ELSE
      -- Mode numpang induk: HM induk terkini - snapshot saat pasang
      induk.running_hours - p.hm_induk_pasang
  END                       AS hm_running,

  -- Data pendukung untuk UI
  induk.tag_number          AS induk_tag,
  induk.nama_equipment      AS induk_nama,
  induk.running_hours       AS induk_hm_sekarang,
  anak.running_hours        AS anak_hm_sekarang,
  anak.nama_equipment       AS anak_nama,
  anak.kategori_id          AS anak_kategori_id

FROM pemasangan p
JOIN equipment induk ON induk.id    = p.induk_id
JOIN equipment anak  ON anak.tag_number = p.anak_tag
WHERE p.tanggal_lepas IS NULL;

-- ------------------------------------------------------------

-- 2b. HM TOTAL anak seumur hidup (akumulasi lintas SEMUA induk)
--     Kunci: COALESCE(hm_*_lepas, hm_*_sekarang)
--       → kalau sudah dilepas pakai snapshot beku
--       → kalau masih terpasang pakai nilai live
CREATE OR REPLACE VIEW v_hm_anak_total AS
SELECT
  p.anak_tag,
  MAX(anak.nama_equipment)  AS anak_nama,

  SUM(
    CASE
      WHEN p.punya_meter_sendiri THEN
        -- meter anak saat lepas (beku) atau terkini (aktif) - meter saat pasang
        COALESCE(p.hm_meter_lepas, anak.running_hours) - p.hm_meter_pasang
      ELSE
        -- HM induk saat lepas (beku) atau terkini (aktif) - HM induk saat pasang
        COALESCE(p.hm_induk_lepas, induk.running_hours) - p.hm_induk_pasang
    END
  )                         AS hm_total,

  COUNT(*)                  AS jumlah_sesi,
  SUM(CASE WHEN p.tanggal_lepas IS NULL THEN 1 ELSE 0 END) AS sesi_aktif

FROM pemasangan p
JOIN equipment induk ON induk.id        = p.induk_id
JOIN equipment anak  ON anak.tag_number = p.anak_tag
GROUP BY p.anak_tag;

-- Verifikasi Step 2:
-- SELECT * FROM v_hm_anak_aktif LIMIT 10;
-- SELECT * FROM v_hm_anak_total LIMIT 10;
-- SELECT COUNT(*) FROM v_hm_anak_aktif WHERE hm_running < 0;  -- harus 0
