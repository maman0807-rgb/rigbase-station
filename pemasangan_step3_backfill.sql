-- ============================================================
-- STEP 3 — Backfill pemasangan dari kondisi induk-anak SEKARANG
-- Rollback: TRUNCATE pemasangan;
-- ============================================================
-- Logika kalibrasi:
--   Mode NUMPANG (punya_meter_sendiri=FALSE, follow_parent_hm=TRUE):
--     hm_induk_pasang = induk.running_hours - anak.running_hours
--     → sehingga view: hm_running = induk_now - hm_induk_pasang = anak.running_hours  ✓
--     GREATEST(0,...) untuk mencegah negatif kalau data tidak konsisten
--
--   Mode METER SENDIRI (punya_meter_sendiri=TRUE, follow_parent_hm=FALSE):
--     hm_meter_pasang = 0
--     → sehingga view: hm_running = anak.running_hours - 0 = anak.running_hours  ✓
--     (running_hours anak = akumulasi sejak tracking mulai)
-- ============================================================

INSERT INTO pemasangan (
  induk_id,
  anak_tag,
  posisi,
  tanggal_pasang,
  punya_meter_sendiri,
  hm_induk_pasang,
  hm_meter_pasang,
  catatan
)
SELECT
  anak.parent_equipment_id                              AS induk_id,
  anak.tag_number                                       AS anak_tag,
  cat.name                                              AS posisi,
  CURRENT_DATE                                          AS tanggal_pasang,

  -- Mode: follow_parent_hm=TRUE → numpang (punya_meter_sendiri=FALSE)
  --        follow_parent_hm=FALSE → meter sendiri (punya_meter_sendiri=TRUE)
  NOT anak.follow_parent_hm                             AS punya_meter_sendiri,

  -- Snapshot numpang: mundurkan HM induk agar selisih = HM anak existing
  CASE
    WHEN NOT anak.follow_parent_hm THEN NULL           -- mode meter sendiri → tidak perlu
    ELSE GREATEST(
      0,
      COALESCE(induk.running_hours, 0)
      - COALESCE(anak.running_hours, 0)
    )
  END                                                   AS hm_induk_pasang,

  -- Snapshot meter sendiri: mulai dari 0 agar selisih = HM anak existing
  CASE
    WHEN anak.follow_parent_hm THEN NULL               -- mode numpang → tidak perlu
    ELSE 0
  END                                                   AS hm_meter_pasang,

  'backfill-awal: kondisi terpasang per ' || CURRENT_DATE::text   AS catatan

FROM equipment anak
JOIN equipment induk ON induk.id = anak.parent_equipment_id
LEFT JOIN categories cat ON cat.id = anak.kategori_id

WHERE anak.parent_equipment_id IS NOT NULL
  -- Skip kalau HM tidak tersedia (bisa jadi data belum lengkap)
  AND (
    -- Numpang: butuh HM induk untuk kalkulasi
    (anak.follow_parent_hm = TRUE  AND induk.running_hours IS NOT NULL)
    OR
    -- Meter sendiri: cukup dengan running_hours anak (boleh NULL, default 0)
    (anak.follow_parent_hm = FALSE)
  )
ON CONFLICT DO NOTHING;  -- safe jika dijalankan dua kali (idempoten via uq_anak_aktif)

-- Verifikasi langsung setelah backfill:
SELECT
  COUNT(*)                           AS total_rows,
  SUM(CASE WHEN NOT punya_meter_sendiri THEN 1 ELSE 0 END) AS mode_numpang,
  SUM(CASE WHEN punya_meter_sendiri THEN 1 ELSE 0 END)     AS mode_meter_sendiri
FROM pemasangan;
