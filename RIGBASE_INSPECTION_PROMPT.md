# 🔍 RIGBASE INSPECTION — Execution Prompt

> **Master prompt untuk menambahkan modul Rekap Inspeksi Cat 3 & Cat 4 ke Rigbase Station yang sudah ada.**
> Pakai prompt ini setelah Rigbase Station Fase 1-7 selesai.

---

## 📋 INSTRUKSI UNTUK CLAUDE

Tambahkan modul **Rigbase Inspection** ke aplikasi Rigbase Station yang sudah ada. Modul ini **tidak menggantikan** struktur yang sudah dibangun, melainkan **menambah** tabel baru + halaman baru yang reference ke `parent_units`, `equipment`, `profiles`, dan `alert_log` yang sudah ada.

Kerjakan **bertahap per fase**, konfirmasi ke user setelah setiap fase selesai.

**Bahasa**: Indonesia/Malay casual untuk komunikasi & UI. Code & variabel pakai English.

---

## 🎯 PROJECT OVERVIEW

**Nama Modul:** Rigbase Inspection
**Parent App:** Rigbase Station (sudah ada)
**Tujuan:** Merekap semua temuan inspeksi teknik (Cat 3 rutin & Cat 4 perpanjangan PLO) dari seluruh Rig, apapun PI yang melaksanakan (PT PJ-Tek Mandiri, PT BKI, dll.)

**Value Utama:**
- Database tersentralisasi semua temuan inspeksi historis
- Tracking status closing temuan (Open → Closed)
- **Deteksi temuan berulang otomatis** di posisi yang sama → input keputusan replacement/overhaul
- Alert Critical real-time ke Telegram
- Riwayat lengkap per Rig (timeline view)

**Tech Stack:** Sama dengan Rigbase Station
- Frontend: Tambahan ke `index.html` yang sudah ada
- Backend: Supabase (tabel baru + bucket baru)
- Alert: Reuse Telegram bot yang sudah ada
- Hosting: GitHub Pages

---

## 🏗️ KONTEKS BISNIS

**PI (Perusahaan Inspeksi)** melakukan inspeksi rig dan mengeluarkan laporan harian PDF. Satu siklus inspeksi berlangsung beberapa hari sampai semua equipment selesai diinspeksi.

**Alur:**
1. PI mulai inspeksi Rig (H1, H2, H3, ...)
2. Setiap hari PI keluarkan laporan PDF dengan progres harian + akumulatif
3. Temuan dilaporkan dengan kategori: **Critical / Major / N/A**
4. Tim internal perbaikan **berbarengan** sambil inspeksi berjalan
5. PI re-inspeksi equipment yang sudah diperbaiki → kalau OK, status **Closed**
6. Semua selesai → siklus inspeksi **Completed**

**Kategori Inspeksi:**
- **Cat 3**: rutin (umumnya 6 bulan sekali)
- **Cat 4**: 4 tahunan, syarat perpanjangan PLO (Persetujuan Layak Operasi)

**Kategori Temuan:**
- **Critical**: kerusakan/kegagalan dapat menyebabkan kerusakan area atau nyawa manusia (komponen beban utama)
- **Major**: kerusakan/kegagalan dapat merusak peralatan utama atau menghambat operasi
- **N/A**: tidak ada temuan / equipment dalam kondisi baik

**Struktur Mast (Penting):**
Mast = 1 equipment dengan 5 bagian. Bagian-bagian ini jadi *posisi temuan*, bukan equipment terpisah:
- A-Frame
- Crown Block
- Upper
- Lower
- Monkey Board

---

## 💾 DATABASE SCHEMA (TAMBAHAN)

Schema ini **menambah** ke schema Rigbase Station yang sudah ada. Tidak mengubah tabel existing.

```sql
-- =============================================
-- TABEL 1: Siklus Inspeksi
-- =============================================
CREATE TABLE inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_code TEXT UNIQUE NOT NULL,           -- SIKLUS-2026-001 (auto-generated)

  -- Referensi ke tabel existing
  parent_unit_id INT NOT NULL REFERENCES parent_units(id),

  -- Kategori
  kategori_inspeksi TEXT NOT NULL CHECK (kategori_inspeksi IN ('Cat 3', 'Cat 4')),

  -- Info Client & Specs (snapshot saat inspeksi)
  client TEXT,
  service TEXT,
  rig_type TEXT,
  manufacturer TEXT,
  year_manufactured INT,
  model_serial TEXT,
  height_of_mast NUMERIC,
  hook_load NUMERIC,
  power_hp NUMERIC,
  place_of_inspection TEXT,

  -- Tanggal
  start_date DATE NOT NULL,
  end_date DATE,                                  -- NULL = on progress

  -- PI
  pi_company TEXT NOT NULL,                     -- PT PJ-Tek Mandiri, PT BKI, dll.
  rig_inspector TEXT NOT NULL,

  -- Status & Progress
  status TEXT NOT NULL CHECK (status IN ('On Progress', 'Completed')) DEFAULT 'On Progress',
  progress_akumulatif NUMERIC DEFAULT 0 CHECK (progress_akumulatif >= 0 AND progress_akumulatif <= 100),

  -- Notes
  catatan TEXT,

  -- System
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_inspections_parent_unit ON inspections(parent_unit_id);
CREATE INDEX idx_inspections_status ON inspections(status);
CREATE INDEX idx_inspections_start_date ON inspections(start_date DESC);

-- =============================================
-- TABEL 2: Temuan Inspeksi
-- =============================================
CREATE TABLE inspection_findings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,

  -- Urutan & Equipment
  no_urut INT NOT NULL,
  equipment_id UUID REFERENCES equipment(id),     -- FK ke equipment Rigbase Station (nullable)
  equipment_name_snapshot TEXT NOT NULL,          -- Cadangan kalau equipment_id null (data lama dari PI)
  qty TEXT,                                       -- "3ea" (optional)

  -- POSISI TEMUAN (untuk equipment kompleks seperti Mast)
  bagian TEXT,                                    -- A-Frame / Crown Block / Upper / Lower / Monkey Board

  -- Klasifikasi
  category TEXT NOT NULL CHECK (category IN ('N/A', 'Major', 'Critical')),
  finding TEXT,                                   -- Deskripsi temuan
  mpi_result TEXT CHECK (mpi_result IN ('Discontinuity', 'No Discontinuity', 'N/A')),
  acceptance_criteria TEXT,                       -- API RP 8B Sect 5.3.2.4
  recommendation TEXT,

  -- Tracking
  tgl_ditemukan DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('Open', 'Closed')) DEFAULT 'Open',
  tgl_closed DATE,
  pic_perbaikan TEXT,

  -- Foto (URL ke bucket inspection-photos)
  photos_before JSONB DEFAULT '[]'::JSONB,        -- Array URL, max 4
  photos_after JSONB DEFAULT '[]'::JSONB,         -- Array URL, max 4

  -- Notes
  catatan TEXT,

  -- System
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  updated_by UUID REFERENCES profiles(id),

  -- Auto-trigger ke maintenance_log saat Closed (lihat trigger di bawah)
  maintenance_log_id UUID REFERENCES maintenance_log(id)
);

CREATE INDEX idx_findings_inspection ON inspection_findings(inspection_id);
CREATE INDEX idx_findings_equipment ON inspection_findings(equipment_id);
CREATE INDEX idx_findings_status ON inspection_findings(status);
CREATE INDEX idx_findings_category ON inspection_findings(category);
-- Index untuk deteksi temuan berulang
CREATE INDEX idx_findings_recurring ON inspection_findings(equipment_id, bagian) WHERE category != 'N/A';

-- =============================================
-- TRIGGER: Auto-update updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_inspections_modtime
BEFORE UPDATE ON inspections
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_findings_modtime
BEFORE UPDATE ON inspection_findings
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- =============================================
-- TRIGGER: Auto-create maintenance_log saat finding Closed
-- =============================================
CREATE OR REPLACE FUNCTION create_maintenance_from_finding()
RETURNS TRIGGER AS $$
DECLARE
  new_log_id UUID;
BEGIN
  -- Hanya jalankan kalau status berubah jadi Closed dan ada equipment_id
  IF NEW.status = 'Closed' AND OLD.status = 'Open' AND NEW.equipment_id IS NOT NULL THEN
    INSERT INTO maintenance_log (equipment_id, maintenance_date, maintenance_type, pic_mechanic, notes, created_by)
    VALUES (
      NEW.equipment_id,
      NEW.tgl_closed,
      'Inspection Closing - ' || NEW.category,
      NEW.pic_perbaikan,
      'Auto-generated dari temuan inspeksi. ' ||
        COALESCE('Bagian: ' || NEW.bagian || '. ', '') ||
        COALESCE('Finding: ' || NEW.finding || '. ', '') ||
        COALESCE('Recommendation: ' || NEW.recommendation, ''),
      NEW.updated_by
    )
    RETURNING id INTO new_log_id;

    NEW.maintenance_log_id = new_log_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_finding_closed
BEFORE UPDATE ON inspection_findings
FOR EACH ROW EXECUTE FUNCTION create_maintenance_from_finding();

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_findings ENABLE ROW LEVEL SECURITY;

-- Read: semua user authenticated bisa baca
CREATE POLICY "Inspections: read all authenticated" ON inspections
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Findings: read all authenticated" ON inspection_findings
  FOR SELECT TO authenticated USING (true);

-- Insert/Update: semua user authenticated bisa (User & Admin)
CREATE POLICY "Inspections: insert all authenticated" ON inspections
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Inspections: update all authenticated" ON inspections
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Findings: insert all authenticated" ON inspection_findings
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Findings: update all authenticated" ON inspection_findings
  FOR UPDATE TO authenticated USING (true);

-- Delete: hanya Admin
CREATE POLICY "Inspections: delete admin" ON inspections
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Findings: delete admin" ON inspection_findings
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- =============================================
-- STORAGE BUCKET: inspection-pdfs & inspection-photos
-- =============================================
-- Lewat Supabase Dashboard atau via SQL:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('inspection-pdfs', 'inspection-pdfs', false);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('inspection-photos', 'inspection-photos', true);
```

---

## 📋 MASTER DATA (Enum/Dropdown)

### Kategori Inspeksi
```
- Cat 3 (rutin 6 bulan)
- Cat 4 (4 tahunan, untuk PLO)
```

### Bagian Mast (dropdown muncul kalau equipment kategori = Mast)
```
- A-Frame
- Crown Block
- Upper
- Lower
- Monkey Board
```

### Category Temuan
```
- N/A
- Major
- Critical
```

### MPI Result
```
- Discontinuity
- No Discontinuity
- N/A
```

### Status Temuan
```
- Open
- Closed
```

### Status Siklus
```
- On Progress
- Completed
```

---

## 🎨 UI/UX SPESIFIKASI

### Brand (Konsisten dengan Rigbase Station):
- **Navy** #1E3A8A · **Oranye** #F97316
- Tambahan untuk modul ini:
  - **Critical badge**: #DC2626 (red)
  - **Major badge**: #D97706 (amber)
  - **Closed badge**: #059669 (green)
  - **Recurring badge**: #7C2D12 (dark orange) — untuk temuan berulang

### Penambahan ke Sidebar Navigation:
Setelah menu "Equipment", tambahkan:
- 🔍 **Inspeksi** (icon clipboard-check)

### Halaman Baru:

**1. Inspeksi List (Dashboard Modul)**
- 4 KPI cards di atas: Total Rig diinspeksi, Siklus Aktif, Critical Open (urgent!), Total Open
- Filter bar: Kategori Inspeksi (Cat 3/Cat 4/Semua) · Rig · Status (Aktif/Critical/Selesai) · Search
- Toggle view: **List** | **Timeline**
- List view: cards per siklus, expandable untuk lihat temuan
- Timeline view: grouped per Rig, kronologis + section "Temuan Berulang"

**2. Siklus Detail**
- Header: info siklus (Rig, kategori, PI, tanggal, progress bar)
- Action buttons: Tambah Temuan, Edit, Upload PDF, Selesaikan Siklus
- List semua temuan dalam siklus
- Tab: Temuan | PDF Harian | Catatan

**3. Form Tambah/Edit Siklus**
- Section A: Info Dasar (Rig select dari parent_units, Kategori, PI, Inspector, Tanggal)
- Section B: Specs (auto-fill dari Rig kalau ada, bisa override)
- Section C: Catatan

**4. Form Tambah/Edit Temuan**
- Pilih Equipment (autocomplete dari `equipment` table, filter by Rig)
- **Conditional**: kalau equipment kategori = "Mast" → muncul dropdown "Bagian" (A-Frame/Crown Block/Upper/Lower/Monkey Board)
- Category (Critical/Major/N/A)
- Finding, MPI Result, Acceptance Criteria, Recommendation
- Tanggal ditemukan
- Upload 4 Foto Before
- Status & Tanggal Closed (kalau Closed) + 4 Foto After
- PIC Perbaikan

**5. Upload Excel Modal**
- Drop zone + file picker
- Preview parsing sebelum commit
- Validasi: ID Siklus konsisten, Rig terdaftar, Equipment ter-resolve
- Tombol "Import" → bulk insert

**6. Tab Tambahan di Equipment Detail**
- Setelah tab existing (Info, Maintenance, Sertifikasi, Dokumen, History)
- Tambahkan tab: **Riwayat Inspeksi**
- Tampilkan list semua finding untuk equipment ini, urut tanggal terbaru
- Highlight kalau ada temuan berulang di bagian yang sama

---

## ⚙️ FITUR UTAMA

### F1. Bulk Upload Excel (CARA UTAMA INPUT DATA)

**Konteks:** PI keluarin laporan PDF, tim Maman ekstrak datanya ke Template Excel v5 (sudah disiapkan), lalu upload Excel ke app. Foto Before/After di-upload terpisah secara drag-drop di halaman temuan setelah Excel berhasil di-import.

**Tech:** Library SheetJS (xlsx) — sudah include di Rigbase Station

**Template Excel:** Template_Rekap_Inspeksi_v5.xlsx (disertakan), terdiri dari 4 sheet:
- **PETUNJUK** — panduan pengisian
- **SIKLUS INSPEKSI** — header laporan (1 baris per siklus)
- **TEMUAN** — detail per equipment (banyak baris per siklus)
- **REKAP** — auto-summary

**Kolom penting di sheet TEMUAN:**
```
ID Siklus | No | Komponen Utama | Equipment/Bagian | Qty | Category
| Finding | MPI Result | Acceptance Criteria | Recommendation
| Tanggal Ditemukan | Status | Tanggal Closed | PIC Perbaikan
| Foto Before 1-4 | Foto After 1-4 | Catatan
```

> **Catatan:** Kolom Foto Before/After di Excel boleh kosong — foto upload terpisah via drag-drop di halaman temuan setelah import sukses.

**Workflow Upload:**

1. **Trigger Upload**
   - Tombol "Upload Excel" di halaman Inspeksi List (FAB atau action bar)
   - Atau di halaman Siklus Detail → "Import Temuan dari Excel"

2. **File Picker / Drop Zone**
   - Accept: `.xlsx, .xls`
   - Max size: 10MB
   - Show loading spinner saat parsing

3. **Parsing & Validasi (di client, sebelum kirim ke DB)**

   Validasi sheet SIKLUS INSPEKSI:
   - ID Siklus tidak boleh kosong, harus unik (cek ke DB)
   - Rig ID harus match dengan `parent_units.name` di Rigbase Station
   - Kategori harus "Cat 3" atau "Cat 4"
   - Tanggal Mulai wajib, format valid
   - PI Company & Rig Inspector wajib

   Validasi sheet TEMUAN:
   - ID Siklus harus match dengan sheet SIKLUS INSPEKSI (atau siklus yang sudah ada di DB)
   - Equipment di-resolve ke `equipment` table:
     - Match exact dulu (nama_equipment + rig)
     - Kalau tidak ketemu → flag sebagai "UNRESOLVED" (tetap bisa import dengan equipment_name_snapshot saja, equipment_id = NULL)
   - Komponen Utama (kalau diisi "Mast") + Bagian harus dari daftar valid (A-Frame/Crown Block/Upper/Lower/Monkey Board)
   - Category wajib (N/A/Major/Critical)
   - Tanggal Ditemukan wajib
   - Status wajib (Open/Closed)
   - Kalau Status = Closed → Tanggal Closed wajib

4. **Preview Modal (WAJIB sebelum commit)**

   Tampilkan tabel preview dengan:
   - **Tab "Siklus"**: data siklus yang akan dibuat/update
   - **Tab "Temuan"**: semua temuan dengan kolom-kolomnya
   - Status indicator per baris:
     - 🟢 Valid (siap import)
     - 🟡 Warning (equipment unresolved, tapi tetap bisa import)
     - 🔴 Error (data invalid, harus diperbaiki di Excel dulu)
   - Summary di atas: "✅ 8 temuan valid · ⚠ 2 warning · ❌ 0 error"
   - Tombol:
     - **Import Semua** (disable kalau ada error)
     - **Batal**
     - **Download Error Report** (Excel berisi baris yang error, untuk diperbaiki)

5. **Commit ke Database**
   - Transaction:
     - Insert/Update ke `inspections`
     - Bulk insert ke `inspection_findings`
   - Progress bar (kalau banyak temuan)
   - Setelah sukses → toast "✅ 8 temuan berhasil di-import" → redirect ke Siklus Detail

6. **Setelah Import — Upload Foto**
   - Di Siklus Detail, tiap card temuan ada slot 4 foto Before + 4 foto After
   - Drag-drop foto langsung ke slot (atau klik untuk pilih file)
   - Multiple file selection allowed
   - Foto otomatis di-compress client-side (max 1MB per foto)
   - Upload ke bucket `inspection-photos`
   - URL foto tersimpan di `inspection_findings.photos_before[]` atau `photos_after[]`

**Error Handling:**
- Network error → retry button + simpan draft di localStorage
- Validasi gagal → tampilkan error message yang jelas + highlight baris bermasalah
- Equipment unresolved → tampilkan suggestion list (equipment yang mirip)
- Duplicate ID Siklus → tanya user mau Update atau Cancel

### F2. Form Input Manual (CARA ALTERNATIF)
- Untuk kasus: tambah 1-2 temuan susulan, edit temuan existing, atau bikin siklus baru manual
- Web form untuk siklus & temuan
- Mobile-responsive (banyak dipakai di lapangan)
- Auto-save draft di localStorage (buat kasus konektivitas spotty)

### F3. Deteksi Temuan Berulang (Insight Engine)
Query SQL untuk deteksi:

```sql
-- Temuan berulang per Rig per equipment+bagian
SELECT
  pu.name AS rig_name,
  e.nama_equipment,
  f.bagian,
  COUNT(*) AS occurrence_count,
  array_agg(json_build_object(
    'inspection_code', i.inspection_code,
    'date', f.tgl_ditemukan,
    'category', f.category
  ) ORDER BY f.tgl_ditemukan) AS history
FROM inspection_findings f
JOIN inspections i ON f.inspection_id = i.id
JOIN parent_units pu ON i.parent_unit_id = pu.id
LEFT JOIN equipment e ON f.equipment_id = e.id
WHERE f.category != 'N/A'
GROUP BY pu.name, e.nama_equipment, f.bagian
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;
```

Tampilkan di:
- Timeline view (per Rig) → section "Temuan Berulang"
- Badge "Ke-N" di temuan yang sudah berulang
- Warning di Equipment Detail → tab "Riwayat Inspeksi"

### F4. Auto-Create Maintenance Log
- Trigger SQL (sudah di schema atas) otomatis bikin entry di `maintenance_log` saat temuan di-Closed
- Maintenance type: `"Inspection Closing - Critical"` atau `"Inspection Closing - Major"`
- Notes: auto-fill dari finding + bagian + recommendation
- Link bidirectional: `inspection_findings.maintenance_log_id`

### F5. Real-time Telegram Alert untuk Critical
Reuse Telegram bot Rigbase Station. Tambahkan Edge Function baru:

```
supabase/functions/critical-inspection-alert/index.ts
```

Trigger: Supabase Realtime subscribe pada INSERT `inspection_findings` WHERE `category = 'Critical'`.

Format pesan:
```
🚨 CRITICAL FINDING ALERT

Rig: {rig_name}
Equipment: {equipment_name} {bagian ? '(' + bagian + ')' : ''}
PI: {pi_company}
Date: {tgl_ditemukan}

Finding:
{finding}

Recommendation:
{recommendation}

🔗 Buka Rigbase: {app_url}/inspeksi/{inspection_id}
```

### F6. Export & Reporting
- Export Excel rekap per Rig
- Export PDF laporan ringkas siklus (header + tabel temuan + total)
- Filter export sesuai filter dashboard aktif

### F7. PDF Laporan Harian PI
- Bucket Supabase: `inspection-pdfs`
- Path: `/inspections/{inspection_id}/H{day}_{date}.pdf`
- Upload dari halaman Siklus Detail, tab "PDF Harian"
- Display sebagai list dengan tombol Download

### F8. Foto Before/After
- Bucket Supabase: `inspection-photos`
- Path: `/findings/{finding_id}/before_{n}.jpg` atau `/findings/{finding_id}/after_{n}.jpg`
- Max 4 foto per slot
- Display thumbnail + lightbox saat di-klik
- Compress di client sebelum upload (max 1MB per foto)

---

## 🚀 FASE IMPLEMENTASI

### **FASE 1: Database Schema** ⏱️ ~20 menit
- [ ] Generate file `inspection_schema.sql` (tabel + index + trigger + RLS)
- [ ] Run di Supabase SQL Editor
- [ ] Buat bucket `inspection-pdfs` (private) & `inspection-photos` (public read)
- [ ] Test query: insert sample siklus + temuan

**Output:** `supabase/inspection_schema.sql`

### **FASE 2: List & Detail View** ⏱️ ~2 jam
- [ ] Tambah menu "Inspeksi" di sidebar
- [ ] Halaman Inspeksi List dengan 4 KPI cards
- [ ] Filter bar (Kategori, Rig, Status, Search)
- [ ] List view: cards per siklus
- [ ] Siklus Detail page dengan tab Temuan
- [ ] CSS konsisten dengan brand Rigbase Station

**Output:** Update `index.html`

### **FASE 3: Form Input Manual** ⏱️ ~2 jam
- [ ] Form Tambah Siklus
- [ ] Form Tambah Temuan (dengan conditional dropdown Bagian untuk Mast)
- [ ] Upload Foto Before/After (max 4)
- [ ] Validasi & error handling
- [ ] Toast notification

**Output:** Update `index.html`

### **FASE 4: Bulk Upload Excel (PRIORITAS UTAMA)** ⏱️ ~2.5 jam
- [ ] Drop zone & file picker di Inspeksi List & Siklus Detail
- [ ] Parse Excel pakai SheetJS (sheet SIKLUS INSPEKSI + TEMUAN)
- [ ] Validasi client-side lengkap (rig match, equipment resolve, format)
- [ ] Preview modal dengan 2 tab + status indicator per baris
- [ ] Equipment auto-resolve ke tabel `equipment` (match by nama + rig)
- [ ] Bulk insert ke Supabase dengan transaction
- [ ] Progress bar untuk upload banyak temuan
- [ ] Error report download (Excel berisi baris error)
- [ ] Drag-drop foto Before/After di Siklus Detail (terpisah dari Excel)
- [ ] Auto-compress foto client-side (max 1MB)
- [ ] Upload foto ke bucket `inspection-photos`

**Output:** Update `index.html` + dokumentasi cara isi template Excel

### **FASE 5: Timeline View & Recurring Detection** ⏱️ ~2 jam
- [ ] Toggle view List | Timeline
- [ ] Timeline view dengan grouping per Rig
- [ ] Query & display "Temuan Berulang" section
- [ ] Badge "Ke-N" di temuan recurring
- [ ] Tab "Riwayat Inspeksi" di Equipment Detail

**Output:** Update `index.html`

### **FASE 6: Telegram Alert Real-time** ⏱️ ~1 jam
- [ ] Edge Function `critical-inspection-alert`
- [ ] Supabase Realtime subscription setup
- [ ] Test trigger dengan insert manual

**Output:** `supabase/functions/critical-inspection-alert/index.ts`

### **FASE 7: Export & Auto-maintenance Trigger** ⏱️ ~1 jam
- [ ] Verifikasi trigger auto-create maintenance_log jalan
- [ ] Export Excel rekap
- [ ] Export PDF siklus
- [ ] Test end-to-end

**Output:** Update `index.html`

### **FASE 8: Polish & Deploy** ⏱️ ~30 menit
- [ ] Mobile responsive check
- [ ] Loading states & error handling
- [ ] Push ke GitHub Pages
- [ ] Update README

---

## ✅ ACCEPTANCE CRITERIA

Modul dianggap selesai kalau:

- [ ] Menu "Inspeksi" muncul di sidebar
- [ ] User & Admin bisa input siklus & temuan
- [ ] Admin bisa delete siklus & temuan
- [ ] Conditional dropdown Bagian muncul untuk equipment kategori Mast
- [ ] Filter Kategori/Rig/Status/Search jalan
- [ ] Timeline view menampilkan temuan berulang
- [ ] Upload Excel bulk jalan
- [ ] Upload foto Before/After (max 4 each) jalan
- [ ] Upload PDF laporan harian PI jalan
- [ ] Temuan di-Closed → otomatis muncul di `maintenance_log` equipment
- [ ] Critical finding → real-time Telegram alert
- [ ] Tab "Riwayat Inspeksi" di Equipment Detail jalan
- [ ] Export Excel & PDF jalan
- [ ] Mobile responsive (test di HP)

---

## 🎬 START COMMAND

```
Claude, mulai FASE 1 Rigbase Inspection: generate file inspection_schema.sql
dengan semua tabel, index, trigger, dan RLS sesuai spec.
```

---

## 📞 KONTAK PROJECT

- **Owner:** Maman (Abdul Rachman)
- **AI Builder:** Claude (Chanis)
- **Parent App:** Rigbase Station
- **Industry:** Oil & Gas — Drilling Operations

---

**Selamat menambahkan modul inspeksi! 🔍📊**
