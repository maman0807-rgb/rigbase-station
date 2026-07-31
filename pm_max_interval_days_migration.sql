-- Migration: fallback time-based buat PM equipment yang jarang jalan (mis. MP well-service,
-- cuma 3-5 jam/sumur — HM butuh waktu sangat lama utk capai interval). "Mana duluan": HM atau waktu.

ALTER TABLE equipment ADD COLUMN IF NOT EXISTS pm_max_interval_days integer;

COMMENT ON COLUMN equipment.pm_max_interval_days IS
  'Opsional: maksimal hari sejak last_pm_date sebelum PM wajib dilakukan, TERLEPAS dari HM/KM. '
  'Dipakai utk equipment yg jarang jalan (mis. MP well-service) supaya tetap ke-cover time-based, '
  'bukan cuma HM-based. NULL = fitur nggak aktif utk equipment ini (default, tidak mengubah perilaku lama).';

NOTIFY pgrst, 'reload schema';
