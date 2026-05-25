-- =====================================================================
-- Tambah kategori 'troubleshoot' ke CHECK constraint downtime_events
-- (Fase 2 — MTBF: breakdown + troubleshoot = kejadian kerusakan)
-- Jalankan SEKALI di Supabase SQL Editor (project olmowzrlokajhniqijfq).
-- =====================================================================
alter table public.downtime_events
  drop constraint if exists downtime_events_category_check;

alter table public.downtime_events
  add constraint downtime_events_category_check
  check (category in ('breakdown','troubleshoot','tunggu_spare','pm','mobilisasi','lainnya'));
