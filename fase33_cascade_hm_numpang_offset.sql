-- ============================================================
-- FASE 33 — Cascade HM: dukung anak "Numpang" (tab Pemasangan) juga,
-- bukan cuma follow_parent_hm=TRUE.
-- ============================================================
-- Problem ditemukan Maman 2026-09-17 (TRANS-STANDBY-02, numpang ke
-- MOBENG-KB150B lewat tab Pemasangan, punya_meter_sendiri=false):
-- HM anak numpang itu HARUS = HM induk sekarang - HM induk saat dipasang
-- (v_hm_anak_aktif.hm_running), TAPI equipment.running_hours anak cuma
-- ke-set sekali pas dipasang (14 Juli 2026) dan tidak pernah ke-update
-- lagi setelahnya — karena trigger cascade_hm_to_children() yang ada
-- (fase12) HANYA jalan untuk anak follow_parent_hm=TRUE (raw copy, cocok
-- utk anak yang emang ikut HM ABSOLUT induk sejak awal), sedangkan anak
-- "Numpang" di tab Pemasangan sengaja follow_parent_hm=FALSE (biar gak
-- bentrok, lihat guard di toggleFollowParentHM()) — jadi gak kesentuh
-- sama sekali, HM-nya beku/basi.
--
-- Fix: tambah 1 UPDATE lagi di trigger, khusus anak yang punya baris
-- pemasangan AKTIF (tanggal_lepas IS NULL) dengan punya_meter_sendiri=
-- FALSE — HM-nya disamakan ke rumus offset (induk baru - hm_induk_pasang),
-- BUKAN raw copy. Ini otomatis kena tiap kali induk.running_hours
-- ke-update dari jalur manapun (Laporan Harian, Revisi HM, Foto HM),
-- karena trigger nempel di tabel, bukan di satu fungsi save spesifik.
-- ============================================================

CREATE OR REPLACE FUNCTION cascade_hm_to_children()
RETURNS TRIGGER AS $$
DECLARE
  affected INT;
BEGIN
  IF NEW.running_hours IS DISTINCT FROM OLD.running_hours THEN
    -- 1) Anak follow_parent_hm=TRUE TANPA pemasangan-numpang aktif (raw copy, perilaku lama)
    UPDATE equipment c
    SET running_hours = NEW.running_hours,
        updated_at    = NOW()
    WHERE c.parent_equipment_id = NEW.id
      AND c.follow_parent_hm = TRUE
      AND c.id != NEW.id
      AND NOT EXISTS (
        SELECT 1 FROM pemasangan p
        WHERE p.anak_tag = c.tag_number AND p.tanggal_lepas IS NULL AND p.punya_meter_sendiri = FALSE
      );
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected > 0 THEN
      RAISE NOTICE 'cascade_hm: % child (follow_parent_hm) di-sync ke HM %', affected, NEW.running_hours;
    END IF;

    -- 2) Anak "Numpang" aktif di tab Pemasangan — offset dari HM induk saat dipasang,
    --    BUKAN disamain ke total induk (biar histori sebelum dipasang gak ketiban).
    UPDATE equipment c
    SET running_hours = NEW.running_hours - p.hm_induk_pasang,
        updated_at    = NOW()
    FROM pemasangan p
    WHERE p.anak_tag = c.tag_number
      AND p.induk_id = NEW.id
      AND p.tanggal_lepas IS NULL
      AND p.punya_meter_sendiri = FALSE;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected > 0 THEN
      RAISE NOTICE 'cascade_hm: % child (numpang/Pemasangan) di-sync offset dari HM %', affected, NEW.running_hours;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Perbaikan data TRANS-STANDBY-02: last_pm_hours=900 tidak ada dasarnya
-- (last_pm_date kosong, lebih besar dari HM sekarang) — reset ke 0,
-- anggap belum pernah PM sejak transmisi ini dipasang ke MOBENG-KB150B.
UPDATE equipment
SET last_pm_hours = 0, last_pm_date = NULL
WHERE tag_number = 'TRANS-STANDBY-02';

-- Verifikasi:
-- SELECT tag_number, running_hours, last_pm_hours, last_pm_date, pm_cycle_count, pm_interval_hours
-- FROM equipment WHERE tag_number = 'TRANS-STANDBY-02';
