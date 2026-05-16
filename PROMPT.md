# 🛢️ RIGBASE STATION — Execution Prompt

> **Master prompt untuk membangun web app Rigbase Station dari nol sampai deploy.**
> Pakai prompt ini di Claude Code (terminal) untuk eksekusi cepat.

---

## 📋 INSTRUKSI UNTUK CLAUDE

Build aplikasi **Rigbase Station** secara lengkap berdasarkan spesifikasi di bawah. Kerjakan **bertahap per fase**, konfirmasi ke user setelah setiap fase selesai sebelum lanjut. Output harus production-ready, mobile-responsive, dan bisa langsung di-deploy ke GitHub Pages.

**Bahasa**: User berbahasa Indonesia/Malay casual. Output code dalam bahasa Inggris (variabel, function), comment & UI dalam bahasa Indonesia.

---

## 🎯 PROJECT OVERVIEW

**Nama:** Rigbase Station  
**Tipe:** Web app database equipment rig drilling  
**User:** Tim operasional rig (Admin & User)  
**Tech stack:**
- Frontend: HTML + Tailwind CSS + Vanilla JavaScript (single file)
- Backend: Supabase (PostgreSQL + Auth + Storage)
- Alert: Telegram Bot API (GRATIS)
- Hosting: GitHub Pages (GRATIS)
- Total biaya: Rp 0/bulan

---

## 🏗️ STRUKTUR DATA

### 1. Parent Units (8 unit)

| No | Nama | Type |
|----|------|------|
| 1 | BW-100A | Rig |
| 2 | BW H35KD | Rig |
| 3 | BW KB150.A | Rig |
| 4 | BW KB150.B | Rig |
| 5 | BW KB150.C | Rig |
| 6 | Unit MTU | Standalone |
| 7 | Unit Slickline | Standalone |
| 8 | Independent | Standalone |

### 2. Categories (29 kategori awal, bisa ditambah Admin)

**Untuk Rig (20):**
Drawwork, Mast, Mobile Engine, Mudpump, Travelling Block, Swivel / Power Swivel, Rotary Table, BOP Annular, BOP Single Ram, BOP Double Ram, Accumulator, Genset, Rotary Tong, Tubing Tong, Weight Indicator, Stand Lamp, Lampu Menara, Portacamp, Tower Light, Sub Structure

**Untuk MTU (4):**
Pump (MTU), Tank (MTU), Engine (MTU), Manifold (MTU)

**Untuk Slickline (4):**
Winch Unit (Slickline), Wireline Reel (Slickline), Mast (Slickline), Lubricator (Slickline)

**Untuk Independent (1):**
MUDPUMP Acid

### 3. Tipe Kepemilikan
- **Permanent**: nempel di 1 parent unit (default)
- **Mobile-Backup**: shared pool, bisa pindah antar rig

### 4. User Roles
- **Admin**: Full access (CRUD, mutasi, kelola user, tambah kategori)
- **User**: View only + input maintenance/inspeksi

---

## 💾 DATABASE SCHEMA (SUPABASE)

### Tables:

```sql
-- 1. Profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT CHECK (role IN ('admin', 'user')) DEFAULT 'user',
  telegram_user_id TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Parent Units
CREATE TABLE parent_units (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  type TEXT CHECK (type IN ('Rig', 'Standalone')) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 3. Categories
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  parent_unit_type TEXT CHECK (parent_unit_type IN ('Rig', 'Standalone', 'Both')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 4. Equipment (main table - 43 fields)
CREATE TABLE equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- A. Identitas
  tag_number TEXT UNIQUE NOT NULL,
  nama_equipment TEXT NOT NULL,
  kategori_id INT REFERENCES categories(id),
  assigned_unit_id INT REFERENCES parent_units(id),
  tipe_kepemilikan TEXT CHECK (tipe_kepemilikan IN ('Permanent', 'Mobile-Backup')) DEFAULT 'Permanent',
  -- B. Spesifikasi
  brand TEXT, model TEXT, serial_number TEXT,
  tahun_pembuatan INT, tahun_commissioning INT, year_used INT,
  country_of_origin TEXT, spek_khusus TEXT,
  -- C. Status
  status_operasi TEXT CHECK (status_operasi IN ('Aktif','Standby','Repair','Down','Scrap')) DEFAULT 'Aktif',
  kondisi_fisik TEXT CHECK (kondisi_fisik IN ('Good','Fair','Poor')) DEFAULT 'Good',
  lokasi_fisik TEXT, running_hours NUMERIC,
  -- D. Maintenance
  last_maintenance_date DATE, last_maintenance_type TEXT,
  next_maintenance_date DATE, maintenance_interval TEXT,
  pic_mechanic TEXT, goh_year INT,
  -- E. Sertifikasi & Refurbish
  nomor_skpi TEXT, skpi_start_date DATE, skpi_end_date DATE,
  coc_number TEXT, arf_lembaga TEXT,
  refurbish_year INT, refurbish_by TEXT, load_test_result TEXT,
  nomor_sertifikat_lain TEXT,
  tgl_terbit_sertifikat DATE, tgl_expired_sertifikat DATE,
  lembaga_penerbit TEXT,
  -- F. Finansial
  tgl_pembelian DATE, harga_perolehan NUMERIC,
  nomor_po_invoice TEXT, vendor_supplier TEXT, cost_center TEXT,
  -- G. Safety
  pressure_test_date DATE, pressure_test_result TEXT,
  -- H. Catatan
  remarks TEXT,
  -- System
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  updated_by UUID REFERENCES profiles(id)
);

-- 5. Maintenance Log
CREATE TABLE maintenance_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  maintenance_date DATE NOT NULL,
  maintenance_type TEXT,
  pic_mechanic TEXT,
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 6. Mutation Log
CREATE TABLE mutation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  from_unit_id INT REFERENCES parent_units(id),
  to_unit_id INT REFERENCES parent_units(id),
  mutation_date DATE NOT NULL,
  reason TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 7. Documents
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  uploaded_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- 8. Alert Log
CREATE TABLE alert_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL,
  equipment_id UUID REFERENCES equipment(id),
  message TEXT,
  sent_to TEXT,
  status TEXT,
  sent_at TIMESTAMP DEFAULT NOW()
);
```

### Row Level Security (RLS):
```sql
-- Admin: full access
-- User: SELECT all, INSERT to maintenance_log only

ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE mutation_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Equipment: read all authenticated" ON equipment
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Equipment: admin write" ON equipment
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Maintenance: insert all authenticated" ON maintenance_log
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Maintenance: read all authenticated" ON maintenance_log
  FOR SELECT TO authenticated USING (true);

-- (Lengkap-kan RLS untuk semua tabel sesuai pattern di atas)
```

### Storage Buckets:
- `equipment-photos` (public read, auth write)
- `equipment-documents` (auth read & write)

---

## 🎨 UI/UX SPESIFIKASI

### Brand:
- **Nama:** Rigbase Station
- **Warna utama:** Navy #1E3A8A
- **Warna aksen:** Oranye safety #F97316
- **Font:** Inter (atau system default)
- **Logo:** Emoji 🛢️ + teks "Rigbase Station"

### Layout:
- **Mobile-first** responsive (banyak dipakai di lapangan)
- **Sidebar** navigasi di desktop, **bottom nav** di mobile
- **Header**: logo + lonceng notif + profile user
- **Toast notification** untuk success/error
- **Modal konfirmasi** untuk delete/mutasi

### Halaman:
1. **Login Screen** — email + password, logo besar
2. **Dashboard** — overview cards + charts + alert center
3. **Equipment List** — tabel + filter + search
4. **Equipment Detail** — tabs (Info, Maintenance, Sertifikasi, Dokumen, History)
5. **Form Tambah/Edit** — multi-section form
6. **Mutasi** — modal pindah antar parent unit
7. **Maintenance Input** — form khusus
8. **Alert Center** — list semua alert
9. **Category Management** (Admin)
10. **User Management** (Admin)
11. **Settings** — profile, password, telegram link

---

## 🚀 FASE IMPLEMENTASI

Kerjakan **bertahap** dan konfirmasi user setelah tiap fase.

### **FASE 1: Setup Supabase** ⏱️ ~30 menit
- [ ] Generate SQL schema lengkap (semua tabel + RLS + seed data)
- [ ] Instruksi user untuk buat project Supabase baru ("rigbase-station")
- [ ] Instruksi run SQL di Supabase SQL Editor
- [ ] Setup Storage buckets
- [ ] Copy Project URL & anon key

**Output Fase 1:**
- File: `supabase_schema.sql` (lengkap)
- File: `supabase_seed.sql` (data awal: 8 parent_units + 29 categories)
- Dokumentasi step-by-step setup

### **FASE 2: Frontend Skeleton** ⏱️ ~1 jam
- [ ] Buat `index.html` dengan struktur dasar
- [ ] Setup Tailwind CDN + Supabase JS SDK
- [ ] Implementasi Login Screen
- [ ] Implementasi layout utama (sidebar/bottom nav)
- [ ] Test koneksi ke Supabase

**Output Fase 2:**
- File: `index.html` (dengan login & layout dasar)

### **FASE 3: Core Features** ⏱️ ~2-3 jam
- [ ] Dashboard dengan cards & charts
- [ ] Equipment List dengan filter & search
- [ ] Equipment Detail dengan tabs
- [ ] Form Tambah/Edit Equipment (multi-section)
- [ ] Upload foto & dokumen
- [ ] CRUD lengkap (sesuai role)

**Output Fase 3:**
- Update `index.html` dengan semua fitur core

### **FASE 4: Advanced Features** ⏱️ ~2 jam
- [ ] Mutasi equipment antar parent unit
- [ ] Maintenance log & history
- [ ] Category Management (Admin)
- [ ] User Management (Admin)
- [ ] Export Excel & PDF

**Output Fase 4:**
- Update `index.html` lengkap

### **FASE 5: Telegram Bot Alert** ⏱️ ~1 jam
- [ ] Instruksi setup bot via @BotFather
- [ ] Instruksi buat group + ambil Chat ID
- [ ] Buat Supabase Edge Function untuk send Telegram
- [ ] Setup scheduled function (daily 08:00) untuk cek alert
- [ ] Trigger real-time alert untuk mutasi & status Down

**Output Fase 5:**
- File: `supabase/functions/send-telegram-alert/index.ts`
- File: `supabase/functions/daily-alert-check/index.ts`
- Setup cron schedule

### **FASE 6: Import Data Awal** ⏱️ ~30 menit
- [ ] Convert Excel template v3 → CSV
- [ ] Import via Supabase Table Editor (CSV import)
- [ ] Verifikasi data masuk benar
- [ ] Upload foto-foto equipment (kalau udah ada)

### **FASE 7: Deploy ke GitHub Pages** ⏱️ ~15 menit
- [ ] Inisialisasi git repo
- [ ] Push ke GitHub
- [ ] Enable GitHub Pages
- [ ] Test URL final
- [ ] Setup custom domain (opsional)

**Output Fase 7:**
- URL aktif: `https://[username].github.io/rigbase-station/`

---

## 📦 OUTPUT DELIVERABLES

Setelah selesai, deliverables yang harus ada:

```
rigbase-station/
├── index.html                          # Main app (single file)
├── README.md                           # Dokumentasi
├── PROMPT.md                           # File ini
├── supabase/
│   ├── schema.sql                      # DB schema
│   ├── seed.sql                        # Initial data
│   └── functions/
│       ├── send-telegram-alert/
│       │   └── index.ts
│       └── daily-alert-check/
│           └── index.ts
├── docs/
│   ├── SETUP.md                        # Instruksi setup
│   ├── USER_GUIDE.md                   # Cara pakai
│   └── ADMIN_GUIDE.md                  # Admin features
└── .gitignore
```

---

## ⚙️ KONFIGURASI USER

**Yang Maman perlu siapin sebelum eksekusi:**

```bash
# 1. Akun Supabase
# Daftar di https://supabase.com (gratis)
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJxxx...

# 2. Telegram Bot
# Buat via @BotFather di Telegram
TELEGRAM_BOT_TOKEN=1234567890:ABCxxx...
TELEGRAM_GROUP_CHAT_ID=-1001234567890

# 3. Admin Pertama
ADMIN_EMAIL=maman@example.com
ADMIN_PASSWORD=[bikin password kuat]

# 4. GitHub Account
GITHUB_USERNAME=[username Maman]
```

---

## 🔧 PRINSIP PENGEMBANGAN

1. **Single file HTML** sebisa mungkin (gampang di-deploy)
2. **Mobile-first** — test di HP dulu, baru desktop
3. **Bahasa Indonesia di UI** — tim lapangan
4. **Error handling** — semua tool calls pake try-catch
5. **Loading states** — semua async action ada indicator
6. **Confirmation modal** untuk destructive action
7. **Toast notification** untuk feedback
8. **Offline-ready** — minimal cache data terakhir (PWA opsional)
9. **Print-friendly** untuk halaman detail
10. **Accessibility** — keyboard nav, alt text, contrast

---

## ✅ ACCEPTANCE CRITERIA

App dianggap selesai kalau:

- [ ] Login Admin & User berfungsi
- [ ] Admin bisa CRUD equipment
- [ ] User bisa view + input maintenance
- [ ] Filter by parent unit, kategori, status, tipe_kepemilikan jalan
- [ ] Search by tag/nama/serial jalan
- [ ] Upload foto & PDF jalan
- [ ] Mutasi equipment ke-log otomatis
- [ ] Alert Telegram terkirim ke group
- [ ] Daily alert (08:00) jalan otomatis
- [ ] Export Excel & PDF jalan
- [ ] Responsive di HP & desktop
- [ ] Deployed di GitHub Pages, accessible publik

---

## 🎬 START COMMAND

Buat memulai eksekusi, jalankan:

```
Claude, mulai FASE 1: Setup Supabase. Generate file supabase_schema.sql, 
supabase_seed.sql, dan dokumentasi setup step-by-step.
```

Lanjutkan fase berikutnya setelah konfirmasi dari user.

---

## 📞 KONTAK PROJECT

- **Owner:** Maman (Abdul Rachman)
- **AI Builder:** Claude (Chanis)
- **Industry:** Oil & Gas — Drilling Operations
- **Location:** Indonesia

---

**Selamat membangun! 🛢️🚀**
