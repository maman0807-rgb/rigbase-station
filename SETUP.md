# 🛢️ Rigbase Station — Setup Guide (Fase 1)

Panduan step-by-step bikin Supabase project untuk Rigbase Station.
Total waktu: ~30 menit. Biaya: **Rp 0** (free tier Supabase).

---

## ✅ Checklist Fase 1

- [ ] 1. Bikin akun Supabase
- [ ] 2. Bikin project baru "rigbase-station"
- [ ] 3. Jalankan `supabase_schema.sql`
- [ ] 4. Jalankan `supabase_seed.sql`
- [ ] 5. Verifikasi tabel + data masuk
- [ ] 6. Verifikasi Storage buckets terbuat
- [ ] 7. Bikin user admin pertama
- [ ] 8. Catat Project URL & anon key

---

## 1. Bikin Akun Supabase

1. Buka [https://supabase.com](https://supabase.com)
2. Klik **Start your project** → sign up pakai GitHub / email
3. Konfirmasi email kalau diminta

---

## 2. Bikin Project Baru

1. Di dashboard, klik **New project**
2. Isi form:
   - **Name**: `rigbase-station`
   - **Database Password**: bikin password kuat — **CATAT & SIMPAN!**
     (dibutuhkan kalau mau akses DB langsung via psql)
   - **Region**: pilih yang terdekat → **Southeast Asia (Singapore)**
   - **Pricing Plan**: **Free**
3. Klik **Create new project**
4. Tunggu ~2 menit sampai project ready (provisioning database)

---

## 3. Jalankan Schema SQL

1. Di sidebar kiri, klik ikon **SQL Editor** (🗎)
2. Klik **+ New query**
3. Buka file `supabase_schema.sql` di komputer, copy **semua** isinya
4. Paste ke SQL Editor
5. Klik **Run** (atau `Ctrl+Enter`)
6. Pastikan ada notif **Success. No rows returned.** di bawah

> ⚠️ **Kalau error**: baca pesan error, biasanya karena project belum fully ready. Tunggu 1 menit lalu coba lagi.

### Yang dibuat oleh schema ini:
- ✅ 8 tabel: `profiles`, `parent_units`, `categories`, `equipment`, `maintenance_log`, `mutation_log`, `documents`, `alert_log`
- ✅ Trigger auto-update `updated_at`
- ✅ Trigger auto-bikin profile saat user baru daftar
- ✅ Helper function `is_admin()`
- ✅ Row Level Security (RLS) policies untuk semua tabel
- ✅ 2 Storage buckets: `equipment-photos` (public), `equipment-documents` (auth-only)
- ✅ Storage policies (public read foto, admin-only write/delete)

---

## 4. Jalankan Seed Data

1. Di SQL Editor, klik **+ New query** lagi
2. Buka `supabase_seed.sql`, copy semua isinya
3. Paste ke SQL Editor → klik **Run**
4. Harus muncul **Success**

### Yang masuk:
- 8 `parent_units` (5 Rig + 3 Standalone)
- 29 `categories` (20 Rig + 9 Standalone)

---

## 5. Verifikasi Data

Di SQL Editor, jalankan query ini buat double-check:

```sql
-- Cek parent_units (harusnya 8 baris)
SELECT type, COUNT(*) FROM parent_units GROUP BY type;
-- Hasil: Rig=5, Standalone=3

-- Cek categories (harusnya 29 baris)
SELECT parent_unit_type, COUNT(*) FROM categories GROUP BY parent_unit_type;
-- Hasil: Rig=20, Standalone=9

-- List semua parent_units
SELECT * FROM parent_units ORDER BY id;

-- List semua categories
SELECT * FROM categories ORDER BY parent_unit_type, name;
```

Atau via UI:
- Sidebar → **Table Editor** → pilih tabel `parent_units` / `categories`

---

## 6. Verifikasi Storage Buckets

1. Sidebar kiri → **Storage**
2. Pastikan ada 2 bucket:
   - `equipment-photos` (public)
   - `equipment-documents` (private)

> Kalau bucket-nya belum ada (script storage gagal karena izin), buat manual:
> klik **New bucket** → nama `equipment-photos` → centang **Public bucket** → Create.
> Ulangi untuk `equipment-documents` tanpa centang public.

---

## 7. Bikin User Admin Pertama

Trigger `handle_new_user()` otomatis bikin profile dengan role `'user'` saat orang sign up.
Admin pertama harus di-promote manual lewat SQL.

### Step A: Sign up via dashboard

1. Sidebar kiri → **Authentication** → **Users**
2. Klik **Add user** → **Create new user**
3. Isi:
   - Email: `maman@example.com` (ganti pakai email kamu)
   - Password: bikin password kuat
   - **Auto Confirm User**: ✅ centang (biar gak perlu verifikasi email)
4. Klik **Create user**

### Step B: Promote jadi admin

Buka SQL Editor, jalankan:

```sql
UPDATE profiles
SET role = 'admin', full_name = 'Maman (Abdul Rachman)'
WHERE email = 'maman@example.com';

-- Verifikasi
SELECT id, email, full_name, role FROM profiles WHERE email = 'maman@example.com';
-- role harus = 'admin'
```

---

## 8. Catat Project URL & Anon Key

Dibutuhkan di Fase 2 (Frontend).

1. Sidebar kiri → **Project Settings** (ikon gear) → **API**
2. Catat 2 nilai ini:

```
SUPABASE_URL      = https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> 🔐 **anon key aman dipublikasikan** di frontend — yang melindungi data adalah RLS.
> Yang **TIDAK BOLEH** dishare: `service_role key` (jangan pernah taro di frontend!)

Simpan dua nilai ini di file `.env.local` atau notes pribadi.

---

## 🧪 Test Akhir Fase 1

Buka SQL Editor, jalankan:

```sql
-- Cek RLS aktif di semua tabel
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
-- Semua tabel harus rowsecurity = true

-- Cek admin pertama
SELECT email, role FROM profiles WHERE role = 'admin';
-- Harus ada minimal 1 baris
```

Kalau semua ✅, **Fase 1 selesai!** 🎉

---

## ⚠️ Troubleshooting

| Masalah | Solusi |
|--------|--------|
| `permission denied for schema auth` saat run schema | Pastikan kamu run di SQL Editor dashboard Supabase (bukan psql), karena editor pakai role superuser |
| Bucket gagal dibuat via SQL | Buat manual di tab Storage (lihat step 6) |
| User sudah dibuat tapi profile kosong | Cek trigger: `SELECT * FROM pg_trigger WHERE tgname = 'trg_on_auth_user_created';` — kalau gak ada, run ulang schema |
| Lupa password DB | Reset via **Project Settings → Database → Reset password** |
| Mau reset semua | Drop project di Settings, bikin ulang dari step 2 |

---

## 📌 Catatan untuk Fase 2

Setelah selesai, kasih tau Claude untuk lanjut **Fase 2: Frontend Skeleton**.
Siapkan 2 nilai ini di tangan:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
