-- ============================================================
-- FASE 30 — Log Kerja Harian (Input Harian) jadi atomic + benerin
-- bug lama: mekanik gak pernah berhasil catat pemakaian spare part.
-- Jalankan di Supabase SQL Editor. Aman re-run (idempoten).
--
-- LATAR BELAKANG (2 masalah, ketemu bareng saat audit 2026-08-15):
--
-- 1) BUG LAMA (bukan dari perubahan kita, sudah ada sejak awal):
--    materials_write (RLS UPDATE stok) dikunci ke is_gudang(), yang
--    TIDAK termasuk role 'mekanik'/'sr_mekanik'. Tapi applyStock() di
--    maintenanceLogs.js (dipanggil tiap mekanik input Log Kerja
--    Harian yang pakai spare part) nulis UPDATE materials LANGSUNG
--    dari client. Akibatnya: mekanik yang isi Input Harian dengan
--    part terpakai SELALU gagal diam-diam -- RLS nolak baris update
--    (0 baris kena), kodenya salah baca itu jadi pesan "Stok berubah
--    saat proses, coba lagi" (seolah race condition, padahal
--    sebenarnya masalah IZIN). Log kerja harian dengan part
--    kemungkinan besar TIDAK PERNAH berhasil tersimpan buat mekanik
--    sejak fitur ini ada.
--
-- 2) BUG BARU (dari audit kemarin, temuan Medium #6): daily_logs
--    di-insert dulu, potong stok menyusul terpisah -- gak atomic,
--    kalau gagal di tengah bisa nyisa baris log tanpa stok terpotong
--    (atau sebaliknya pas edit/hapus).
--
-- FIX: 3 fungsi SECURITY DEFINER (pola sama seperti approve_hm() yg
-- sudah ada) yang ngerjain insert/update/delete daily_logs SEKALIGUS
-- potong/kembalikan stok + catat stock_transactions dalam 1 transaksi
-- PL/pgSQL (semua-atau-tidak-sama-sekali). Karena SECURITY DEFINER,
-- fungsi ini bypass RLS materials/stock_transactions -- makanya WAJIB
-- ada pengecekan role manual di dalam, PERSIS menyamai kebijakan RLS
-- daily_logs yang sudah ada (dailylogs_insert/update pakai
-- is_mekanik_or_above(), dailylogs_delete pakai is_manager()) --
-- supaya gak malah jadi buka celah baru.
-- ============================================================

CREATE OR REPLACE FUNCTION add_daily_log_atomic(
  p_log_date date, p_equipment_id uuid, p_equipment_name text,
  p_maintenance_type text, p_notes text,
  p_manpower jsonb, p_parts jsonb, p_transport jsonb, p_vendor jsonb,
  p_subtotals jsonb, p_parts_by_category jsonb, p_total numeric
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_log_id uuid;
  v_part jsonb;
  v_material_id uuid;
  v_qty numeric;
  v_stok_sebelum numeric;
  v_stok_sesudah numeric;
  v_part_number text;
  v_description text;
  v_uid uuid := auth.uid();
  v_uname text;
BEGIN
  IF NOT is_mekanik_or_above() THEN
    RAISE EXCEPTION 'Tidak punya akses untuk mencatat log kerja harian';
  END IF;
  SELECT full_name INTO v_uname FROM profiles WHERE id = v_uid;

  INSERT INTO daily_logs (
    log_date, equipment_id, equipment_name, maintenance_type, notes,
    manpower, parts, transport, vendor, subtotals, parts_by_category, total,
    user_id, user_name, created_by, created_by_name, updated_by, updated_by_name
  ) VALUES (
    p_log_date, p_equipment_id, p_equipment_name, p_maintenance_type, p_notes,
    p_manpower, p_parts, p_transport, p_vendor, p_subtotals, p_parts_by_category, p_total,
    v_uid, v_uname, v_uid, v_uname, v_uid, v_uname
  ) RETURNING id INTO v_log_id;

  FOR v_part IN SELECT * FROM jsonb_array_elements(p_parts) LOOP
    v_material_id := NULLIF(v_part->>'materialId', '')::uuid;
    IF v_material_id IS NULL THEN CONTINUE; END IF;
    v_qty := COALESCE((v_part->>'qty')::numeric, 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;

    -- FOR UPDATE: kunci baris material ini sampai transaksi selesai, cegah 2 log
    -- kerja yang pakai part sama diproses barengan saling timpa angka stok.
    SELECT stok, part_number, description INTO v_stok_sebelum, v_part_number, v_description
    FROM materials WHERE id = v_material_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;

    v_stok_sesudah := GREATEST(0, COALESCE(v_stok_sebelum, 0) - v_qty);
    UPDATE materials SET stok = v_stok_sesudah WHERE id = v_material_id;

    INSERT INTO stock_transactions (
      material_id, part_number, description, tipe, jumlah,
      stok_sebelum, stok_sesudah, keterangan, referensi, sumber, daily_log_id, user_id, user_name
    ) VALUES (
      v_material_id, v_part_number, v_description, 'keluar', v_qty,
      v_stok_sebelum, v_stok_sesudah, 'Pemakaian maintenance harian', v_log_id::text, 'dailyLog', v_log_id,
      v_uid, v_uname
    );
  END LOOP;

  RETURN v_log_id;
END;
$$;

CREATE OR REPLACE FUNCTION update_daily_log_atomic(
  p_id uuid, p_log_date date, p_equipment_id uuid, p_equipment_name text,
  p_maintenance_type text, p_notes text,
  p_manpower jsonb, p_parts jsonb, p_transport jsonb, p_vendor jsonb,
  p_subtotals jsonb, p_parts_by_category jsonb, p_total numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old_parts jsonb;
  v_rec RECORD;
  v_stok_sebelum numeric;
  v_stok_sesudah numeric;
  v_part_number text;
  v_description text;
  v_uid uuid := auth.uid();
  v_uname text;
BEGIN
  IF NOT is_mekanik_or_above() THEN
    RAISE EXCEPTION 'Tidak punya akses untuk mengubah log kerja harian';
  END IF;
  SELECT full_name INTO v_uname FROM profiles WHERE id = v_uid;

  SELECT parts INTO v_old_parts FROM daily_logs WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Log kerja harian tidak ditemukan'; END IF;
  v_old_parts := COALESCE(v_old_parts, '[]'::jsonb);

  -- Diff qty lama vs baru per material — cuma catat transaksi utk yang beneran berubah
  -- (bukan reverse-lalu-reapply semua part, biar histori stok_transactions gak berisik).
  FOR v_rec IN
    WITH old_q AS (
      SELECT NULLIF(p->>'materialId','')::uuid AS material_id, SUM(COALESCE((p->>'qty')::numeric,0)) AS qty
      FROM jsonb_array_elements(v_old_parts) p WHERE NULLIF(p->>'materialId','') IS NOT NULL GROUP BY 1
    ), new_q AS (
      SELECT NULLIF(p->>'materialId','')::uuid AS material_id, SUM(COALESCE((p->>'qty')::numeric,0)) AS qty
      FROM jsonb_array_elements(p_parts) p WHERE NULLIF(p->>'materialId','') IS NOT NULL GROUP BY 1
    )
    SELECT COALESCE(o.material_id, n.material_id) AS material_id,
           COALESCE(n.qty,0) - COALESCE(o.qty,0) AS delta
    FROM old_q o FULL OUTER JOIN new_q n ON o.material_id = n.material_id
  LOOP
    IF v_rec.delta = 0 THEN CONTINUE; END IF;

    SELECT stok, part_number, description INTO v_stok_sebelum, v_part_number, v_description
    FROM materials WHERE id = v_rec.material_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;

    v_stok_sesudah := GREATEST(0, COALESCE(v_stok_sebelum, 0) - v_rec.delta);
    UPDATE materials SET stok = v_stok_sesudah WHERE id = v_rec.material_id;

    INSERT INTO stock_transactions (
      material_id, part_number, description, tipe, jumlah,
      stok_sebelum, stok_sesudah, keterangan, referensi, sumber, daily_log_id, user_id, user_name
    ) VALUES (
      v_rec.material_id, v_part_number, v_description,
      CASE WHEN v_rec.delta > 0 THEN 'keluar' ELSE 'masuk' END, ABS(v_rec.delta),
      v_stok_sebelum, v_stok_sesudah,
      CASE WHEN v_rec.delta > 0 THEN 'Pemakaian tambahan (edit maintenance harian)' ELSE 'Pengembalian (edit maintenance harian)' END,
      p_id::text, 'dailyLog', p_id, v_uid, v_uname
    );
  END LOOP;

  UPDATE daily_logs SET
    log_date = p_log_date, equipment_id = p_equipment_id, equipment_name = p_equipment_name,
    maintenance_type = p_maintenance_type, notes = p_notes,
    manpower = p_manpower, parts = p_parts, transport = p_transport, vendor = p_vendor,
    subtotals = p_subtotals, parts_by_category = p_parts_by_category, total = p_total,
    updated_by = v_uid, updated_by_name = v_uname, updated_at = now()
  WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION delete_daily_log_atomic(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_parts jsonb;
  v_part jsonb;
  v_material_id uuid;
  v_qty numeric;
  v_stok_sebelum numeric;
  v_stok_sesudah numeric;
  v_part_number text;
  v_description text;
  v_uid uuid := auth.uid();
  v_uname text;
BEGIN
  -- Hapus log harian = operasi lebih sensitif (bisa nutup histori kerja + kembalikan
  -- stok) -- disamakan dgn kebijakan RLS dailylogs_delete yang sudah ada: is_manager().
  IF NOT is_manager() THEN
    RAISE EXCEPTION 'Tidak punya akses untuk menghapus log kerja harian';
  END IF;
  SELECT full_name INTO v_uname FROM profiles WHERE id = v_uid;

  SELECT parts INTO v_parts FROM daily_logs WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Log kerja harian tidak ditemukan'; END IF;
  v_parts := COALESCE(v_parts, '[]'::jsonb);

  FOR v_part IN SELECT * FROM jsonb_array_elements(v_parts) LOOP
    v_material_id := NULLIF(v_part->>'materialId', '')::uuid;
    IF v_material_id IS NULL THEN CONTINUE; END IF;
    v_qty := COALESCE((v_part->>'qty')::numeric, 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;

    SELECT stok, part_number, description INTO v_stok_sebelum, v_part_number, v_description
    FROM materials WHERE id = v_material_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;

    v_stok_sesudah := GREATEST(0, COALESCE(v_stok_sebelum, 0) + v_qty);
    UPDATE materials SET stok = v_stok_sesudah WHERE id = v_material_id;

    INSERT INTO stock_transactions (
      material_id, part_number, description, tipe, jumlah,
      stok_sebelum, stok_sesudah, keterangan, referensi, sumber, daily_log_id, user_id, user_name
    ) VALUES (
      v_material_id, v_part_number, v_description, 'masuk', v_qty,
      v_stok_sebelum, v_stok_sesudah, 'Pengembalian/koreksi maintenance', p_id::text, 'dailyLog', p_id,
      v_uid, v_uname
    );
  END LOOP;

  DELETE FROM daily_logs WHERE id = p_id;
END;
$$;

-- Verifikasi ketiga fungsi terpasang:
SELECT proname FROM pg_proc
WHERE proname IN ('add_daily_log_atomic', 'update_daily_log_atomic', 'delete_daily_log_atomic');

-- ============================================================
-- Bonus di file yang sama (bukan tabel/RLS baru, cuma nambah fungsi
-- helper) — atomic increment buat tabel `counters` (dipakai nomor
-- Work Order di Logbook). Sebelumnya genNomor() di workorders.js baca
-- last_number lalu upsert manual dari client (baca-lalu-tulis) — 2 WO
-- dibuat berdekatan waktu bisa dapat nomor kembar. Pola sama seperti
-- next_doc_seq() yang sudah ada buat doc_counters.
-- ============================================================
CREATE OR REPLACE FUNCTION next_counter(p_id TEXT)
RETURNS BIGINT
LANGUAGE SQL AS $$
  INSERT INTO counters (id, last_number) VALUES (p_id, 1)
  ON CONFLICT (id) DO UPDATE SET last_number = counters.last_number + 1
  RETURNING last_number;
$$;
GRANT EXECUTE ON FUNCTION next_counter(TEXT) TO authenticated;

SELECT proname FROM pg_proc WHERE proname = 'next_counter';
