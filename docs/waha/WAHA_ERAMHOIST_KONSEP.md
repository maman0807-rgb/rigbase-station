# Konsep: WAHA WhatsApp Integration untuk eRAMHoist

**Status:** Konsep — belum masuk tahap spek teknis/eksekusi
**Tanggal diskusi:** 11 Juli 2026
**Konteks:** Extension dari eRAMHoist ecosystem, paralel dengan Telegram bot (@Eramhoist_bot) yang sudah jalan

---

## Latar Belakang

Team rig lebih familiar dengan WhatsApp dibanding Telegram. Tujuan: bikin channel report & entry HM via WA, tanpa mengganggu sistem Telegram bot yang sudah berjalan.

## Keputusan Arsitektur

```
eRAMHoist (Supabase) ←→ n8n (Railway) ←→ WAHA ←→ Grup WhatsApp
```

- **WAHA** = jembatan I/O saja (kirim/terima pesan), bukan penyimpan state
- **Supabase** tetap jadi single source of truth
- **n8n** pegang semua logic (filter, validasi, format, query)
- Pola ini paralel/mirror dari arsitektur Telegram bot yang sudah ada

## Status Biaya

WAHA 100% gratis & open source (versi 2026.6.1+, semua fitur eks-"Plus" sudah masuk Core, tanpa limit pesan/waktu). Biaya riil hanya di infrastruktur hosting (tambahan service di Railway, sama seperti n8n). Donasi opsional, bukan wajib.

## Setup Nomor & Grup

- **Nomor:** WA reguler (bukan WA Business), nomor dedicated/baru — jangan nomor pribadi. Perlu bisa terima OTP untuk pairing awal (scan QR).
- **Grup:** Pakai **grup existing yang sudah ada** (bukan bikin baru) — tinggal invite nomor bot sebagai member setelah connect ke WAHA.
- Satu grup dipakai untuk **semua rig & equipment** (tidak dipisah per rig).

## Model Akses di Grup

- **Whitelist nomor** → hanya nomor tertentu (PIC/operator resmi) yang bisa entry data HM
- **Member lain** → read-only: bisa lihat laporan, proses entry, dan status hasil (transparan, mirip pola Telegram bot sekarang)
- Bot **tidak merespon** pesan dari luar whitelist / tanpa format command → tidak mengganggu obrolan biasa di grup

## Cara Bot Mengenali Pesan yang Ditujukan Untuknya

Kombinasi (keduanya harus match):
1. **Prefix command** (`/rig`, `/form [rig]`, `/jamjalan ...`) ATAU **balasan angka** (`[nomor] [jam] [kondisi] [catatan opsional]`, boleh beberapa dipisah koma) selama nomor pengirim punya **sesi `/form` aktif**
2. **Nomor pengirim ada di whitelist**

Kode equipment pakai `tag_number` asli untuk jalur cepat `/jamjalan`. Untuk jalur utama (`/rig` → `/form` → nomor), operator tidak perlu ingat/ketik `tag_number` sama sekali — cukup nomor urut yang ditampilkan bot (lihat "Alur Utama: /rig → /form → Nomor" di bagian Konsep Pengisian).

## Empat Jenis Pesan/Interaksi

1. **Push — Laporan + Daftar Equipment per Window Shift**
   Terjadwal (n8n cron), 1x di awal tiap window lapor — **17:00 WIB** (shift Siang) dan **05:00 WIB** (shift Malam). Isi: rekap jam jalan yang sudah masuk + daftar equipment bernomor per rig untuk yang belum lapor (setara hasil `/form [rig]`, di-broadcast otomatis ke grup untuk semua rig sekaligus).

2. **Pull — `/rig`**
   On-demand, siapa saja di whitelist. Balas daftar semua rig bernomor, tanpa batasan (semua nomor lihat semua rig — lihat keputusan di bagian "Belum Diputuskan").

3. **Pull — `/form [rig]`**
   On-demand. Balas daftar equipment rig itu bernomor + upsert **sesi aktif** untuk nomor WA itu (berlaku 4 jam) supaya balasan angka berikutnya bisa di-resolve ke equipment yang benar.

4. **Pull — Entry Jam Jalan** (2 jalur, sama-sama berujung insert ke `logbook`)
   - **Jalur utama:** balasan angka (`2 6 baik, 4 12 baik`) → resolve nomor via sesi `/form` aktif → equipment
   - **Jalur cepat opsional:** `/jamjalan [tag_number] [siang|malam] [jam] [kondisi] [catatan]` → langsung pakai tag, tidak butuh sesi/`/form` dulu, shift wajib disebut manual di jalur ini (beda dari jalur utama yang deteksi shift otomatis dari jam kirim)

   Setelah resolve equipment (+ shift): validasi rig sesuai whitelist → **insert ke tabel `logbook`** (skema sama dengan app Logbook, lihat bagian "Konsep Pengisian" di bawah) → update `equipment.running_hours` (additive) → **reply** (quote) ke pesan command asli sebagai konfirmasi.

## Handling Pesan Bersamaan / Grup Rame

- Tiap pesan masuk = event terpisah dari WAHA ke webhook n8n, diproses independen — tidak saling blocking dengan chat biasa di grup
- Bot hanya membalas pesan yang match kriteria (whitelist + prefix); chat lain lewat begitu saja tanpa respon
- Balasan bot pakai **quote reply** (field `reply_to`/`quotedMessageId`, exact nama field tergantung versi WAHA — perlu dicek pas implementasi) supaya konfirmasi jelas nyambung ke command mana, walau grup sedang ramai
- Beberapa command dari operator berbeda hampir bersamaan aman diproses n8n selama tiap command target equipment yang unik (insert per-row, bukan overwrite bareng)

## Monitoring Session WAHA — WAJIB, bukan opsional

Beda dari Telegram Bot API (dikelola server Telegram), WAHA meniru sesi WhatsApp Web sehingga lebih rentan putus:
- HP pairing harus tetap online
- WhatsApp bisa force-logout kalau pola dianggap mencurigakan
- Restart container Railway bisa reset session kalau storage tidak persistent
- Update image WAHA kadang perlu re-auth

**Solusi:** Workflow n8n terpisah, cek status session WAHA berkala (misal tiap 1 jam via `GET /api/sessions`), kalau status ≠ `WORKING` → kirim alert ke Telegram bot (@Eramhoist_bot) yang sudah berjalan. Jadi Telegram bot berfungsi sebagai channel monitoring untuk WAHA.

## Risiko yang Perlu Diwaspadai

- WAHA adalah unofficial client — WhatsApp tidak mengizinkan bot/unofficial client secara resmi, ada risiko suspend/ban meski kecil untuk skala penggunaan ini (1 grup, volume rendah, terjadwal)
- Kalau ke depan scope melebar (banyak grup/nomor eksternal/butuh SLA tinggi) → pertimbangkan migrasi ke WhatsApp Cloud API resmi (Meta), meski setup jauh lebih kompleks (Business Manager, approval template)

## Konsep Pengisian — Selaras dengan App Logbook (finalisasi 11 Jul 2026)

**Temuan penting:** eRAMHoist dan app Logbook (`~/logbook-equipment`) satu Supabase yang sama (`olmowzrlokajhniqijfq`). Logbook adalah **sumber kebenaran** untuk `equipment.running_hours` — eRAMHoist cuma baca (read-only) untuk analisa RAM. Supaya WAHA tidak jadi jalur ketiga yang tidak sinkron, WAHA **menulis ke tabel `logbook` yang sama**, bukan tabel baru.

### Field yang ditangkap operator (dari `LogbookForm.jsx`)
Form web operator sebenarnya wajib isi 3 hal per submit (1 shift = 1 entry):
- `shift` — Siang ☀️ atau Malam 🌙
- `condition` — baik / perlu_perhatian / rusak
- `shiftHours` — **jam operasi shift itu ("jam jalan")** — inilah dasar perhitungan PM (`getPMType(hm)` dst di eRAMHoist), BUKAN kondisi equipment
- `hmSaatIni` (opsional) — HM absolut kalau operator sempat baca meter fisik

Field teknis lain (suhu, oli, getaran, kebisingan, foto) ada di form web tapi **sengaja tidak didukung via WA** — WA fokus laporan cepat, detail teknis tetap lewat app kalau perlu.

### Kenapa WAHA hanya pakai jam jalan (delta), tidak HM absolut
```js
// Logika sama seperti LogbookForm.jsx:
const newTotalHours = hmSaatIni
  ? Number(hmSaatIni)                          // absolut — TIDAK didukung via WA
  : currentHM + Number(shiftHours);            // delta — INI yang dipakai WAHA
```
Karena WA **selalu additive** (`currentHM + shiftHours`), validasi "HM tidak boleh turun" otomatis aman selama jam jalan yang diinput ≥ 0 — tidak perlu reject-logic terpisah seperti di form web (yang harus jaga-jaga karena orang bisa salah ketik angka absolut).

### Kondisi equipment — terpisah dari kalkulasi PM
Operator bisa laporkan kondisi (baik/waspada/rusak) bersamaan dengan jam jalan, tapi **kondisi ini tidak memengaruhi hitungan PM** — PM tetap murni dari akumulasi jam jalan. Kondisi cuma informasi/flag untuk SPV & mekanik (sama seperti fungsinya di app Logbook — trigger notifikasi ke SPV/mekanik kalau `rusak`).

Mapping kata WA → value DB: `baik→baik`, `waspada→perlu_perhatian`, `rusak→rusak`.

### Insert ke tabel `logbook` (mengikuti skema existing, jalur "Operator" — langsung, tanpa approval)

**Catatan penting soal `reporter_id` (koreksi 11 Jul 2026):** Kolom ini di semua entry app selalu diisi `userProfile.id` — UUID asli Supabase Auth (`src/supabase/logbook.js` KNOWN columns: `reporterId/reporterName/reporterRole`). Kemungkinan besar tipenya **UUID di Postgres**, bukan text bebas. Nomor WA (format `62817xxxxxxx`) BUKAN UUID valid → insert bisa gagal type-mismatch kalau nomor WA dipaksa masuk ke situ.

**Solusi:** pakai `wa_whitelist.id` (sudah didesain sebagai `uuid primary key`) sebagai `reporter_id`, BUKAN nomor WA mentah. Aman terpakai apa pun tipe kolom `reporter_id` sebenarnya (uuid atau text), karena `wa_whitelist.id` sudah pasti UUID valid.

```js
{
  equipment_id:   <resolved dari tag_number>,
  equipment_name: <dari equipment>,
  reporter_id:    <wa_whitelist.id>,       // UUID dari tabel whitelist, BUKAN nomor_wa mentah
  reporter_name:  <wa_whitelist.nama>,
  reporter_role:  'operator',              // atau 'admin' kalau rig IS NULL di whitelist
  shift, condition, shiftHours,
  findings:       <catatan opsional dari command>,
  date:           <timestamp saat pesan diterima>,
  source:         'whatsapp'               // penanda tambahan, tidak ada di app tapi berguna untuk audit/laporan asal data
}
```
Lalu `equipment.running_hours` di-update additive seperti di atas — **jalur ini setara "Operator" di Logbook (langsung, tanpa approval SPV)**, bukan jalur "Mekanik" yang perlu `approve_hm`. Alasan: operator lapangan lapor via WA fungsinya sama persis dengan operator yang isi form — bukan mekanik yang butuh review.

**Belum tervalidasi (cek saat eksekusi):** tipe kolom `reporter_id` di tabel `logbook` yang sebenarnya. Cara cek cepat di Supabase SQL Editor:
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'logbook' AND column_name = 'reporter_id';
```
Kalau ternyata kolomnya `text` (bukan `uuid`), desain di atas tetap jalan tanpa perlu diubah — `wa_whitelist.id` valid dicast ke text juga.

### Shift, Window Lapor & Deteksi Otomatis (finalisasi 11 Jul 2026, revisi "lebih santai")

| Shift | Jam operasi | Window lapor |
|---|---|---|
| **Siang** | 06:00 – 18:00 | **17:00 – 20:00** |
| **Malam** | 18:00 – 06:00 | **05:00 – 09:00** |

- **Push otomatis** dikirim 1x di awal tiap window: **17:00 WIB** (Siang) dan **05:00 WIB** (Malam) — tidak ada reminder susulan, sesuai keputusan "lebih santai" (operator punya 3-4 jam untuk lapor kapan saja dalam window itu)
- **Shift ditentukan otomatis dari jam kirim pesan, relatif ke JAM SHIFT ASLI (bukan window lapor):** pesan masuk 06:00–17:59 → shift **Siang**; pesan masuk 18:00–05:59 → shift **Malam**
- **Entry di LUAR window tetap diterima** — window cuma soal kapan bot proaktif nge-push, bukan pembatas kapan operator boleh lapor. Operator lapor jam 12:00 (tengah shift Siang) tetap tercatat shift Siang, tidak ditolak
- Deteksi ini berlaku untuk **jalur utama** (balasan angka). Jalur cepat `/jamjalan` tetap wajib sebut shift manual (`siang`/`malam`) karena operator mungkin lapor lintas-shift pakai jalur ini

### Alur Utama: `/rig` → `/form [rig]` → Balasan Angka (finalisasi 11 Jul 2026)

**Kenapa dibuat begini:** satu rig bisa punya banyak equipment (>2), dan `tag_number` sebagian panjang (`GS-KB150A-DEUTZ`) — berisiko salah ketik kalau operator harus mengetik tag lengkap tiap kali. Solusinya: operator lihat daftar bernomor dari bot, balas pakai nomor saja, bisa banyak equipment sekaligus dalam satu pesan.

**1. `/rig`** — bot balas daftar semua rig, bernomor:
```
Daftar Rig:
1. BW-100A
2. BW-100B
3. H35KD
4. KB150A
5. KB150B
```

**2. `/form [rig]`** — bot balas daftar equipment rig itu, bernomor, DAN simpan sesi:
```
Equipment BW-100A (berlaku 4 jam):
1. TT-100A
2. DC-100A
3. GS-KB150A-DEUTZ
4. BPM-100A
5. HJ-H35KD

Balas nomornya, contoh:
2 6 baik
Bisa sekaligus beberapa, pisah koma:
2 6 baik, 4 12 baik
```

Setiap `/form [rig]` yang berhasil, n8n **upsert** ke tabel sesi (menimpa sesi lama nomor itu kalau ada):
```sql
CREATE TABLE wa_form_session (
  nomor_wa     text primary key,
  rig          text not null,
  mapping      jsonb not null,   -- { "1": "TT-100A", "2": "DC-100A", ... }
  generated_at timestamptz default now()
);
```
Sesi berlaku **4 jam** dari `generated_at`. Kalau operator balas angka tapi sesinya sudah expired/belum pernah `/form` → bot tolak: `"Sesi sudah tidak berlaku, kirim /form [rig] dulu."`

**3. Balasan angka** — format per entry: `[nomor] [jam] [kondisi] [catatan opsional]`, **tanpa** kata "jamjalan" (sudah dalam konteks sesi `/form`). Beberapa entry dalam satu pesan dipisah koma:
```
2 6 baik, 4 12 baik, 5 8 waspada oli rembes
```
n8n parse per segmen (split by koma) → tiap segmen: nomor pertama → lookup `mapping[nomor]` dari sesi aktif nomor WA itu → dapat `tag_number` → proses sama seperti alur `/jamjalan` (resolve equipment, shift otomatis dari jam kirim, insert `logbook`, update `running_hours`) → **satu balasan konfirmasi mencakup semua entry** dalam pesan itu, bukan reply terpisah per entry.

### Command final (2 jalur)

**Jalur utama** (setelah `/form [rig]`):
```
/rig
/form BW-100A
2 6 baik, 4 12 baik, 5 8 waspada oli rembes
```

**Jalur cepat opsional** (langsung, tanpa `/form`):
```
/jamjalan TT-100A siang 8 baik
/jamjalan DC-100A malam 6 rusak gearbox bunyi kasar
```
Format: `/jamjalan [tag_number] [siang|malam] [jam] [baik|waspada|rusak] [catatan opsional]`

---

## Belum Diputuskan / PR untuk Sesi Berikutnya

- [x] Endpoint & auth WAHA (API key, base URL Railway) — sudah beres, lihat bagian "Setup WAHA yang Sudah Jalan" di bawah
- [x] Format kode equipment — **keputusan (11 Jul 2026): pakai `tag_number` asli langsung**, bukan shortcode terpisah. Contoh: `/jamjalan TT-100A siang 8 baik`. Alasan: sebagian besar tag sudah pendek, dan shortcode custom butuh tabel mapping tambahan yang harus disinkronkan tiap ada equipment baru/berubah.
- [x] Jadwal pesan — **keputusan final (revisi 11 Jul 2026, "lebih santai"): 17:00 WIB** (awal window lapor shift Siang, window 17:00-20:00) dan **05:00 WIB** (awal window lapor shift Malam, window 05:00-09:00). 1x push per window, tanpa reminder susulan. Entry di luar window tetap diterima, shift ditentukan otomatis dari jam kirim relatif ke jam shift asli (06:00-18:00=Siang, 18:00-06:00=Malam) — lihat detail di bagian "Shift, Window Lapor & Deteksi Otomatis"
- [x] Struktur tabel whitelist — **keputusan (update 11 Jul 2026, revisi untuk skenario operator sakit):**
  ```sql
  CREATE TABLE wa_whitelist (
    id         uuid primary key default gen_random_uuid(),
    nomor_wa   text unique not null,   -- format 62817xxxxxxx, tanpa + / spasi
    nama       text not null,
    rig        text,                   -- NULL = admin (akses SEMUA rig, pengganti operator sakit); diisi = operator dibatasi rig itu saja
    aktif      boolean default true,
    created_at timestamptz default now()
  );
  ```
  Validasi command WA: nomor harus match `nomor_wa` di whitelist DAN `aktif=true`. Kalau `rig IS NULL` (admin) → boleh entry equipment rig manapun. Kalau `rig` terisi (operator) → equipment yang di-entry harus milik rig itu, tolak kalau di luar rig-nya.

  **Skenario operator sakit/absen:** admin (rig=NULL) bisa entry HM menggantikan operator rig manapun tanpa perlu ubah whitelist. Ada **lebih dari 1 nomor admin** yang di-whitelist dengan rig=NULL (bukan cuma 1), supaya ada backup kalau satu admin juga tidak available.

  **Transparansi:** pesan konfirmasi untuk entry dari admin (rig=NULL) ditandai beda dari entry operator biasa, termasuk nama admin (karena admin lebih dari 1 orang, perlu jelas siapa yang entry) — lihat contoh di bagian format teks di bawah.
- [x] Format teks final tiap jenis pesan — **draft (revisi 11 Jul 2026, alur `/rig` → `/form` → nomor):**
  ```
  📋 Waktunya Lapor — Shift Malam (window 05:00-09:00)

  Rig BW-100A:
  1. TT-100A ✅ sudah (480 jam)
  2. DC-100A ⚠️ belum
  3. GS-KB150A-DEUTZ ⚠️ belum

  Balas: /form BW-100A untuk lihat nomor lengkap & lapor

  Daftar Rig:
  1. BW-100A
  2. BW-100B
  3. H35KD
  4. KB150A
  5. KB150B
  Balas /form [nama rig] untuk lihat equipment-nya

  Equipment BW-100A (berlaku 4 jam):
  1. TT-100A
  2. DC-100A
  3. GS-KB150A-DEUTZ
  Balas nomornya, contoh: 2 6 baik
  Bisa sekaligus: 2 6 baik, 4 12 baik

  ✅ Tercatat:
  - DC-100A +8 jam (total 480 jam) — baik
  - GS-KB150A-DEUTZ +6 jam (total 326 jam) — waspada: oli rembes

  ✅ Tercatat: DC-100A +8 jam (total 480 jam) — baik (dientry oleh Admin: Budi — pengganti sementara)

  ❌ Sesi sudah tidak berlaku, kirim /form [rig] dulu.

  ❌ Format salah. Contoh: /jamjalan TT-100A siang 8 baik
  ```
- [ ] Field exact untuk quote-reply di versi WAHA yang dipakai (cek dokumentasi API pas eksekusi) — **satu-satunya item yang masih perlu dicek saat eksekusi**, bukan keputusan desain

---

## Setup WAHA yang Sudah Jalan (Update 11 Juli 2026)

WAHA sudah berhasil di-deploy, di-pairing, dan tested end-to-end (kirim ke chat personal & grup berhasil). Detail teknis ini penting untuk sesi eksekusi n8n berikutnya.

### Infrastruktur
- **Platform:** Railway, project `vivacious-caring`, environment `production`
- **Base URL API:** `https://waha-production-f995.up.railway.app`
- **Docker image:** `devlikeapro/waha`
- **Volume:** terpasang di mount path `/app/.sessions` — wajib ada, tanpa ini session hilang tiap kali container restart
- **Engine:** `NOWEB` (di-set via env var `WHATSAPP_DEFAULT_ENGINE=NOWEB`) — jauh lebih ringan daripada default `WEBJS`, penting untuk stabilitas di Railway trial plan yang resource-nya terbatas

### Kredensial (tersimpan sebagai Railway env vars di service `waha`)
- `WAHA_API_KEY` — dipakai untuk autentikasi API (header `X-Api-Key`)
- `WAHA_DASHBOARD_USERNAME` / `WAHA_DASHBOARD_PASSWORD` — login dashboard WAHA (`/dashboard`)
- `WHATSAPP_SWAGGER_USERNAME` / `WHATSAPP_SWAGGER_PASSWORD` — login halaman Swagger (root `/`)
- Nilai-nilai ini disimpan di Railway Variables, bukan ditulis di file ini demi keamanan — cek langsung di Railway kalau butuh.

### Session WhatsApp Aktif
- **Session name:** `eramhoist2`
- **Nomor terhubung:** 62817106489 (nomor pribadi Maman — dipakai untuk tahap testing; pertimbangkan ganti ke nomor dedicated sebelum produksi penuh)
- Endpoint kirim pesan: `POST /api/sendText` dengan body `{ "chatId": "...", "text": "...", "session": "eramhoist2" }`

### Grup WhatsApp Target — "Team Merah - Is the Best"
```
Group ID: 120363237618454780@g.us
```
- Ini grup existing yang dipakai untuk eRAMHoist WA integration (bukan grup baru)
- Nomor bot sudah jadi anggota
- Format ID grup selalu diakhiri `@g.us` (beda dari chat personal yang diakhiri `@c.us`) — kesalahan ketik antara `@c.us`/`@g.us` atau typo digit ID adalah penyebab paling umum pesan gagal terkirim tanpa error jelas

### Cara Dapat Ulang Group ID (kalau perlu grup lain nanti)
```
GET /api/{session}/chats
```
Response berupa array semua chat, cari objek dengan `"name"` sesuai nama grup, ambil field `"id"` yang diakhiri `@g.us`.

### Pelajaran Penting dari Proses Setup (hindari terulang)
1. **Jangan panggil `/api/server/stop`** — endpoint ini mematikan seluruh container WAHA, bukan sekadar stop session. Beberapa kali kejadian tidak sengaja tombol di dashboard yang berkaitan dengan ini ke-klik dan bikin 502.
2. **Icon kotak (■) di baris session dashboard = Stop**, bukan restart. Pakai ▶ (play) untuk start, 🔄 untuk restart.
3. Kalau muncul error **"Importing a module script failed"** di dashboard, itu cache browser, bukan server error — fix dengan hard refresh (`Cmd+Shift+R`) atau buka di Private Window.
4. Kalau WhatsApp memutus sesi dengan pesan **"do not reconnect the session"**, session tersebut sudah dianggap tidak valid oleh WhatsApp — tidak bisa di-restart, harus dihapus dan dibuat session baru dari nol (scan QR ulang).
5. Setelah session baru berhasil connect, **biarkan idle 2-3 menit** sebelum mulai kirim pesan — mengurangi risiko WhatsApp menganggap koneksi mencurigakan dan memutusnya lagi.
6. Trial plan Railway rawan resource terbatas untuk WAHA — pertimbangkan upgrade ke Hobby plan sebelum produksi penuh, terutama kalau nanti WAHA harus jalan 24/7 berdampingan dengan n8n.

---
*File ini adalah catatan konsep + hasil setup teknis. Siap dilanjutkan ke tahap eksekusi n8n (workflow kirim/terima pesan grup) di sesi berikutnya — tinggal disusun jadi prompt file lengkap pola N8N_WAHA_ERAMHOIST_PROMPT.md, karena semua kredensial dan ID yang dibutuhkan sudah tersedia di atas.*
