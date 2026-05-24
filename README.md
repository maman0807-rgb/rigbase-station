# 🛢️ eRAMHoist

Web app database equipment & Asset Reliability (RAM) untuk Hoist & Heavy Equipment — PT Pertamina Hulu Rokan.

**Live app:** [https://eramhoist.vercel.app](https://eramhoist.vercel.app)
**(URL lama `rigbase.vercel.app` otomatis redirect ke sini.)**

---

## 📋 Fitur

- **Authentication** — Login admin & user via Supabase Auth
- **Equipment Management** — CRUD lengkap 43 field per equipment (identitas, spek, sertifikasi, finansial, dll)
- **Hierarki Equipment** — Mobile Rig & Mudpump sebagai container dengan komponen anak (Engine, Transmisi, Drawwork, Pompa, dll)
- **Filter & Search** — by parent unit, kategori, status, tipe kepemilikan, atau search tag/nama/serial
- **Mutasi Equipment** — pindah antar parent unit dengan log audit + cascade option untuk container
- **Penggantian Equipment** — replace equipment lama dengan baru, lama otomatis ke Independent pool sebagai backup
- **Pinjam-Meminjam** — flow lengkap pinjam equipment antar rig (dengan loan_log tracking + return flow)
- **Maintenance Log** — riwayat servis tiap equipment
- **Document Upload** — foto (auto-compress max 1920px) + PDF dengan storage Supabase
- **Dashboard** — stat cards, maintenance due 30 hari, sertifikat expired 60 hari, pinjaman aktif, bar chart per unit
- **Role-based** — Admin full CRUD, User view only + input maintenance
- **Mobile-first** — responsive untuk akses dari HP di lapangan

---

## 🏗️ Tech Stack

- **Frontend:** HTML + Tailwind CSS (CDN) + Vanilla JavaScript (single file)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Row Level Security)
- **Hosting:** GitHub Pages (free tier)
- **Total biaya:** Rp 0/bulan

---

## 🚀 Setup

Lihat [SETUP.md](SETUP.md) untuk panduan lengkap setup Supabase project + konfigurasi awal.

### Quick start untuk developer baru:

1. Clone repo
2. Setup Supabase project — Run SQL files secara berurutan:
   - `supabase_schema.sql`
   - `supabase_seed.sql`
   - `loan_log_schema.sql`
   - `import_data.sql` (data sample, optional)
   - `migration_restructure.sql` (hierarki container)
   - `fix_transmisi_parent.sql`
   - `add_standalone_equipment.sql`
3. Edit `index.html` line 174-175 — ganti `SUPABASE_URL` & `SUPABASE_ANON_KEY` dengan project kamu
4. Buka `index.html` di browser

---

## 📁 Struktur Project

```
rigbase-station/
├── index.html                       # Main app (single file)
├── README.md                        # File ini
├── PROMPT.md                        # Spec original
├── SETUP.md                         # Panduan setup Supabase
├── supabase_schema.sql              # DB schema dasar
├── supabase_seed.sql                # Seed: 8 parent_units + 29 kategori
├── loan_log_schema.sql              # Tabel loan_log
├── import_data.sql                  # 49 equipment sample
├── migration_restructure.sql        # Migrasi hierarki Mobile Rig & Mudpump
├── fix_transmisi_parent.sql         # Fix bug parent_equipment_id
└── add_standalone_equipment.sql     # 45 standalone (Tower Light, dll)
```

---

## 🔒 Keamanan

- **Anon key** di `index.html` aman dipublikasikan — yang lindungi data adalah Row Level Security (RLS) di Supabase
- **Login required** — semua data hanya bisa diakses setelah authenticated
- **Role-based access** — Admin & User dengan permission berbeda
- File `data_equipment.xlsx` tidak ditrack git (di `.gitignore`)

---

## 👤 Owner

**Abdul Rachman (Maman)** — Pertamina EP, Drilling Operations

🤖 Built with [Claude](https://claude.ai)
