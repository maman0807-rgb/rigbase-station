-- Nomor Work Order SAP yang diterbitkan Team Planner untuk perbaikan/downtime.
-- Ditampilkan di tabel "🔴 Sedang Down" pada halaman Availability RAM.
alter table public.downtime_events add column if not exists wo_number text;
