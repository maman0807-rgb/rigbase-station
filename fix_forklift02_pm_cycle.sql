-- ============================================================
-- FL-FORKLIFT-02: sinkronin PM cycle count biar "PM Berikutnya" = PM4,
-- sesuai data Trakindo. HM belum tercapture di eRAMHoist (running_hours
-- masih 0) -- nanti menyusul begitu Maman punya angkanya.
--
-- Logic getPMTypeByCycle(n): next PM dihitung dari (pm_cycle_count + 1):
--   n%40==0 -> GOH, n%8==0 -> PM6, n%4==0 -> PM5, n%2==0 -> PM4, sisanya PM3
-- pm_cycle_count=1 -> next cycle=2 -> PM4. ✔
-- ============================================================

UPDATE equipment
SET pm_cycle_count = 1
WHERE tag_number = 'FL-FORKLIFT-02';

-- Cek hasilnya:
SELECT tag_number, running_hours, last_pm_hours, last_pm_date, pm_cycle_count
FROM equipment
WHERE tag_number = 'FL-FORKLIFT-02';
