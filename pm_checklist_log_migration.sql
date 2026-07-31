-- Migration: audit trail checklist PM3-PM6 yang dicentang mekanik saat "Catat PM Selesai"
-- Checklist item-nya generik per-tier (hardcode di JS, PM_CHECKLIST_INCREMENTAL), bukan per-equipment.
-- Tabel ini cuma nyimpen catatan APA YANG DICENTANG tiap kali PM selesai dikerjakan.

CREATE TABLE IF NOT EXISTS pm_checklist_log (
  id                 uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  equipment_id       uuid REFERENCES equipment(id) ON DELETE CASCADE,
  downtime_event_id  uuid REFERENCES downtime_events(id) ON DELETE CASCADE,
  pm_type            text,
  item_text          text NOT NULL,
  checked            boolean NOT NULL DEFAULT false,
  created_at         timestamptz DEFAULT now()
);

ALTER TABLE pm_checklist_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pm_checklist_log_select" ON pm_checklist_log FOR SELECT TO authenticated USING (true);
CREATE POLICY "pm_checklist_log_insert" ON pm_checklist_log FOR INSERT TO authenticated WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
