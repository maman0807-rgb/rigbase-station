# N8N WAHA WhatsApp Integration eRAMHoist — Prompt untuk Claude Code

## Konteks Proyek

Saya (Abdul Rachman / Maman) sudah punya n8n (self-hosted di Railway) yang
sebelumnya dipakai untuk otomasi Telegram bot eRAMHoist (@Eramhoist_bot).
Sekarang saya mau tambah channel kedua: **WhatsApp via WAHA**, supaya team
rig yang lebih familiar WhatsApp bisa lapor **jam jalan** (running hours per
shift) langsung dari grup WA, tanpa buka app.

WAHA sudah di-deploy, di-pairing ke nomor WA, dan tested end-to-end (semua
detail teknis di bawah). Sekarang saatnya bangun workflow n8n yang
menghubungkan WAHA ↔ Supabase ↔ grup WhatsApp.

**Konsep lengkap & semua keputusan desain** ada di file
`WAHA_ERAMHOIST_KONSEP.md` (satu folder dengan prompt ini) — baca dulu
sebelum mulai, terutama bagian "Konsep Pengisian — Selaras dengan App
Logbook" DAN "Alur Utama: /rig → /form [rig] → Balasan Angka", karena ada
detail penting yang TIDAK boleh dilewatkan:
- eRAMHoist & app Logbook (`~/logbook-equipment`) **satu Supabase yang
  sama** — WAHA harus tulis ke tabel `logbook` (bukan bikin tabel baru),
  supaya tidak jadi jalur ketiga yang tidak sinkron dengan app.
- `reporter_id` di tabel `logbook` kemungkinan besar tipe **UUID** —
  JANGAN masukkan nomor WA mentah ke situ, pakai `wa_whitelist.id`.
- Jam jalan = delta (additive), BUKAN HM absolut — desain ini sengaja
  supaya validasi "HM tidak boleh turun" otomatis aman tanpa reject-logic
  terpisah.
- **Operator TIDAK mengetik `tag_number` langsung.** Alur utamanya:
  `/rig` (lihat daftar rig) → `/form [rig]` (lihat equipment rig itu,
  bernomor, sistem simpan "sesi" untuk nomor WA itu selama 4 jam) →
  operator balas **nomor urut saja** (`2 6 baik, 4 12 baik` — bisa banyak
  equipment sekaligus dalam 1 pesan, dipisah koma). `/jamjalan [tag] ...`
  tetap ada sebagai jalur cepat opsional buat yang sudah hafal tag-nya.
- **Shift ditentukan otomatis dari jam kirim pesan** (06:00-17:59=Siang,
  18:00-05:59=Malam) untuk jalur nomor — operator TIDAK perlu sebut shift.
  Jalur `/jamjalan` tetap wajib sebut shift manual.
- **Window lapor cuma soal kapan bot proaktif push**, BUKAN pembatas —
  entry di luar window (17:00-20:00 Siang / 05:00-09:00 Malam) tetap
  diterima kapan saja.
- **Grup vs chat pribadi (REVISI 11 Jul 2026):** grup WhatsApp cuma
  read-only, cuma nerima push laporan terjadwal. **SEMUA interaksi (`/rig`,
  `/form`, balasan angka, `/jamjalan`) HANYA diproses kalau sumbernya chat
  pribadi ke nomor bot** (`chatId` berakhiran `@c.us`), bukan grup
  (`@g.us`) — kalau ada command dikirim di grup, abaikan total. Ini
  menghilangkan kebutuhan quote-reply sama sekali (chat 1:1 tidak ada
  ambiguitas), jadi Tahap 2 di bawah **tidak perlu** quote/reply-to.

## Info Teknis yang Sudah Tersedia

### n8n & Telegram (existing, sudah jalan)
- **n8n instance:** `https://n8n-production-0080b.up.railway.app`
- **Telegram Bot:** @Eramhoist_bot, Chat ID grup `-1003788042916` — dipakai
  juga sebagai **channel monitoring** kalau session WAHA putus (lihat Tahap 4)

### WAHA (sudah di-deploy & tested)
- **Platform:** Railway, project `vivacious-caring`, environment `production`
- **Base URL API:** `https://waha-production-f995.up.railway.app`
- **Auth:** header `X-Api-Key` — nilai ada di Railway env var `WAHA_API_KEY`,
  **JANGAN hardcode di JSON workflow**, isi lewat n8n Credentials
- **Session name:** `eramhoist2`
- **Grup target:** "Team Merah - Is the Best", Group ID `120363237618454780@g.us`
  (selalu diakhiri `@g.us`, bukan `@c.us`)
- **Endpoint kirim pesan:** `POST /api/sendText` — body
  `{ "chatId": "120363237618454780@g.us", "text": "...", "session": "eramhoist2" }`
- **Endpoint terima pesan (webhook):** perlu dikonfigurasi di WAHA supaya
  **semua pesan masuk** (grup maupun chat pribadi) di-forward ke webhook
  n8n — cek dokumentasi WAHA versi yang dipakai untuk cara setup webhook
  (event `message`). Filtering grup vs pribadi dilakukan di n8n (lihat
  Tahap 2), bukan di level WAHA
- **Tidak perlu quote-reply** — karena semua interaksi command sekarang
  cuma di chat pribadi 1:1 (lihat "Grup vs chat pribadi" di atas), balasan
  bot cukup `POST /api/sendText` biasa ke `chatId` pengirim, tidak perlu
  field `reply_to`/`quotedMessageId`

### Supabase
- **Project eRAMHoist (= project Logbook, SATU project yang sama):**
  `olmowzrlokajhniqijfq`
- **Tabel yang akan disentuh:**
  - `logbook` — tulis entry baru ke sini (skema lihat konsep doc, kolom:
    `equipment_id, equipment_name, reporter_id, reporter_name,
    reporter_role, shift_hours, condition, temuan, status, data` JSONB)
  - `equipment` — baca `tag_number` → `id` untuk resolve equipment dari
    command, lalu update `running_hours` (additive)
  - `wa_whitelist` — **BELUM ADA, perlu dibuat dulu** (SQL di Tahap 0)
  - `wa_form_session` — **BELUM ADA, perlu dibuat dulu** (SQL di Tahap 0) —
    nyimpen "sesi aktif" tiap nomor WA hasil `/form [rig]` terakhir, supaya
    balasan angka bisa di-resolve ke equipment yang benar
- **API Key:** service role atau anon sesuai kebutuhan node — isi lewat n8n
  Credentials, jangan hardcode

## Tugas yang Saya Minta

### Tahap 0 — SQL: buat tabel `wa_whitelist` dan `wa_form_session`
Bukan workflow n8n, tapi SQL yang saya jalankan manual di Supabase SQL
Editor. Tolong generate SQL untuk:
```sql
CREATE TABLE wa_whitelist (
  id         uuid primary key default gen_random_uuid(),
  nomor_wa   text unique not null,
  nama       text not null,
  rig        text,          -- NULL = admin (akses semua rig)
  aktif      boolean default true,
  created_at timestamptz default now()
);

CREATE TABLE wa_form_session (
  nomor_wa     text primary key,
  rig          text not null,
  mapping      jsonb not null,   -- { "1": "TT-100A", "2": "DC-100A", ... }
  generated_at timestamptz default now()
);
```
Plus RLS policy dasar untuk keduanya (proyek ini pakai RLS di semua tabel —
ikuti pola yang sudah ada di eRAMHoist, lihat tabel `pemasangan` sebagai
referensi kalau perlu contoh). Sertakan juga `NOTIFY pgrst, 'reload
schema';` di akhir.

### Tahap 1 — Workflow sederhana (test end-to-end kirim pesan)
1. Trigger: Manual Trigger
2. Node HTTP Request: `POST /api/sendText` ke WAHA, kirim teks test ke grup
3. Simpan sebagai `workflow-waha-test.json`, siap import via **Workflow →
   Import from File**

Jangan lanjut ke tahap berikutnya sebelum saya konfirmasi tahap ini berhasil
kirim ke grup.

### Tahap 2 — Workflow Pull: `/rig`, `/form [rig]`, dan entry (2 jalur)
Satu webhook, tapi n8n perlu route ke 4 cabang logic berbeda tergantung isi
pesan. Urutan pengecekan (pesan yang tidak match semuanya → stop tanpa balas):

**Router awal (semua cabang):**
1. Trigger: Webhook (menerima event pesan masuk dari WAHA, termasuk dari
   grup — filtering terjadi di langkah berikut)
2. Node IF: cek `chatId` pesan masuk berakhiran `@c.us` (chat pribadi) —
   kalau berakhiran `@g.us` (grup) → **stop total, tidak balas apapun**,
   grup cuma boleh nerima push, bukan sumber command
3. Node Supabase: query `wa_whitelist` by nomor pengirim, `aktif=true` —
   kalau tidak ketemu → **stop, tidak balas** (bukan target bot)
4. Node Switch/IF, route berdasar isi pesan:

**Cabang A — `/rig`**
- Node Supabase: query tabel **`parent_units`** (`id, name`) — INI tabel
  rig yang benar, BUKAN kolom di `equipment` (verifikasi 12 Jul 2026 dari
  `index.html`: `equipment.assigned_unit_id` adalah FK ke `parent_units.id`)
- Node Function: format jadi daftar bernomor
- Node HTTP Request: kirim balasan ke `chatId` pengirim (chat pribadi, BUKAN grup)

**Cabang B — `/form [rig]`**
- Node Supabase: cari `parent_units` by `name` (match nama rig dari
  command) → dapat `id`. Kalau tidak ketemu → balas "Rig tidak dikenali"
- Node Supabase: query `equipment` filter `assigned_unit_id = <parent_units.id>`
  → ambil `id, tag_number, nama_equipment`
- Node Function: bikin numbering (urutan konsisten, misal alfabetis by
  `tag_number`) → bangun `mapping` JSON `{ "1": "TT-100A", "2": "DC-100A", ... }`
- Node Supabase: UPSERT ke `wa_form_session` (`nomor_wa`, `rig`, `mapping`,
  `generated_at = now()`) — **timpa sesi lama nomor itu kalau ada**
- Node HTTP Request: kirim balasan daftar bernomor + instruksi cara balas
  (lihat format di konsep doc)

**Cabang C — balasan angka (jalur utama, mis. `2 6 baik, 4 12 baik`)**
- Deteksi: pesan **tidak** diawali `/` DAN diawali angka
- Node Supabase: ambil `wa_form_session` by nomor pengirim
  - Kalau tidak ada / `generated_at` lebih dari 4 jam lalu → balas
    `"Sesi sudah tidak berlaku, kirim /form [rig] dulu."`, stop
- Node Function: **split pesan by koma** → tiap segmen parse
  `[nomor] [jam] [kondisi] [catatan opsional]` → lookup `nomor` di
  `mapping` sesi → dapat `tag_number` per segmen
  - Shift: **hitung otomatis dari jam pesan diterima** — 06:00-17:59 WIB
    (Asia/Jakarta) = Siang, 18:00-05:59 = Malam (lihat detail di konsep doc
    bagian "Shift, Window Lapor & Deteksi Otomatis")
  - Mapping kondisi: `baik→baik`, `waspada→perlu_perhatian`, `rusak→rusak`
- Lanjut ke langkah insert bersama (lihat "Insert bersama" di bawah) untuk
  **tiap segmen**, lalu **satu balasan gabungan** mencakup semua segmen
  dalam pesan itu (bukan reply terpisah per segmen)

**Cabang D — `/jamjalan [tag_number] [siang|malam] [jam] [kondisi] [catatan]` (jalur cepat opsional)**
- Node Function: parse command, validasi 4 argumen wajib pertama ada &
  valid, kalau tidak → balas error format
- Node Supabase: query `equipment` by `tag_number` langsung (tidak butuh
  sesi `/form`) — kalau tag tidak ditemukan → balas "Tag tidak dikenali"
- Shift **wajib disebut manual** di jalur ini (beda dari Cabang C)
- Lanjut ke "Insert bersama" di bawah, balasan konfirmasi 1 entry

**Insert bersama (dipakai Cabang C & D, per equipment yang di-entry):**
1. Node IF: kalau `wa_whitelist.rig` **terisi** (bukan admin) → equipment
   yang di-entry harus milik rig itu, tolak kalau beda rig
2. Node Supabase: INSERT ke tabel `logbook` — **kolom asli**: `equipment_id,
   equipment_name, reporter_id (= wa_whitelist.id, BUKAN nomor WA mentah),
   reporter_name, reporter_role ('operator'/'admin' tergantung rig IS NULL),
   shift_hours, condition, temuan (null, tidak dipakai jalur Operator),
   status ('pending')`. **Kolom `data` (JSONB)**: `{ shift, date, findings
   (catatan opsional dari command), source: 'whatsapp' }`. JANGAN taruh
   `shift`/`date`/`findings` sebagai kolom top-level — kolom itu tidak ada
   di tabel, lihat detail lengkap di konsep doc bagian "Kolom asli vs
   JSONB data"
3. Node Supabase: UPDATE `equipment.running_hours` = `running_hours +
   shift_hours` (additive, tidak perlu cek turun karena selalu nambah)
4. Balasan konfirmasi — kirim langsung ke `chatId` pengirim (chat pribadi,
   tanpa quote/reply-to, lihat catatan "Tidak perlu quote-reply" di atas),
   beda format kalau `reporter_role='admin'` (sertakan nama admin +
   keterangan "pengganti sementara", lihat contoh format di konsep doc).
   Untuk Cabang C dengan >1 segmen, gabung semua hasil jadi satu list
   dalam satu balasan (lihat contoh format di konsep doc)

Simpan sebagai `workflow-waha-entry.json`.

### Tahap 3 — Workflow Push: laporan awal + reminder susulan (2x per window)
**Revisi 12 Jul 2026: 2 pesan per window**, bukan cuma 1. Bisa 1 workflow
dengan 4 schedule trigger, atau 2 workflow terpisah (awal vs reminder) —
pilih yang lebih rapi di n8n, yang penting logic-nya sama.

**A. Push awal window** — trigger **17:00 WIB** (Siang) dan **05:00 WIB**
(Malam), timezone Asia/Jakarta:
1. Node Supabase: query semua rig + equipment-nya + `logbook` entries
   shift yang baru selesai (Siang untuk trigger 17:00 → shift Siang hari
   ini; Malam untuk trigger 05:00 → shift Malam semalam)
2. Node Function: per rig, tentukan equipment yang **sudah** vs **belum**
   entry shift itu — **cukup status ✅/⚠️ per equipment, TANPA nomor.**
   Push ini kirim ke grup (bukan ke 1 nomor spesifik), jadi TIDAK
   upsert `wa_form_session` di tahap ini — sesi cuma dibuat per-operator
   saat mereka sendiri kirim `/form [rig]` (Cabang B, Tahap 2). Kalau push
   ini ikut assign nomor, operator berbeda yang balas ke broadcast yang
   sama bisa salah acu equipment
3. Node Function: format pesan — ringkasan status per rig (✅/⚠️, SEMUA
   equipment ditampilkan, sudah maupun belum) + ajakan eksplisit `/form
   [rig]` untuk lihat nomor & lapor (lihat contoh format di konsep doc)
4. Node HTTP Request: kirim ke grup via WAHA

**B. Reminder susulan** — trigger **19:45 WIB** (Siang, 15 menit sebelum
window 20:00 tutup) dan **08:45 WIB** (Malam, 15 menit sebelum window
09:00 tutup):
1. Node Supabase: query sama seperti push awal, cek ulang status
   sudah/belum terbaru (kemungkinan ada yang sudah lapor sejak push awal)
2. Node Function: filter **cuma rig/equipment yang MASIH belum lapor**
   (yang sudah tidak ikut ditampilkan)
3. Node IF: kalau hasil filter **kosong** (semua rig sudah lapor) →
   **stop, jangan kirim apapun** — tidak perlu reminder kalau tidak ada
   yang perlu diingatkan
4. Node Function: format pesan reminder (lihat contoh format "⏰
   Reminder — masih belum lapor" di konsep doc)
5. Node HTTP Request: kirim ke grup via WAHA

Simpan sebagai `workflow-waha-laporan-jadwal.json`.

### Tahap 4 — Workflow Monitoring session WAHA
1. Trigger: Schedule tiap 1 jam
2. Node HTTP Request: `GET /api/sessions` ke WAHA, cek status session `eramhoist2`
3. Node IF: kalau status **≠** `WORKING` → lanjut ke alert
4. Node Telegram: kirim alert ke @Eramhoist_bot / chat `-1003788042916`
   ("⚠️ WAHA session eramhoist2 status: [status] — cek Railway dashboard")

Simpan sebagai `workflow-waha-monitoring.json`.

### Tahap 5 — Dokumentasi ringkas
Setelah semua workflow jadi, tuliskan `README-n8n-waha-eramhoist.md` berisi:
- Cara import tiap file JSON ke n8n
- Cara isi credential WAHA (`X-Api-Key`) dan Supabase di n8n Credentials
- Cara setup webhook WAHA supaya pesan masuk ke-forward ke n8n (termasuk
  cara dapat URL webhook dari n8n untuk didaftarkan di WAHA)
- Cara aktifkan (toggle "Active") tiap workflow terjadwal
- Catatan keamanan: jangan hardcode API key di JSON manapun
- **Onboarding operator:** cara operator mulai chat pribadi ke nomor bot
  (simpan nomor bot sebagai kontak dulu di HP mereka, baru bisa kirim
  pesan langsung — WhatsApp tidak bisa mulai chat ke nomor yang belum
  disimpan tanpa link `wa.me/<nomor>`, jadi sertakan juga opsi kirim link
  `wa.me/<nomor bot tanpa +>` di pesan sosialisasi awal supaya operator
  tinggal klik)

## Batasan & Preferensi

- Saya pemula di n8n — jelaskan istilah teknis di README dengan bahasa
  sederhana
- **Jangan hardcode API key (WAHA maupun Supabase) di file JSON** — pakai
  placeholder/n8n Credentials, jelaskan cara isi di README
- Gunakan bahasa Indonesia untuk semua teks pesan yang dikirim ke WhatsApp
- **Ikuti gaya kerja saya: iteratif, tiap tahap saya review dulu sebelum
  lanjut ke tahap berikutnya** — jangan generate semua tahap sekaligus
  tanpa konfirmasi
- Field quote-reply WAHA (Tahap 2 langkah 9) — kalau belum yakin nama
  field-nya dari dokumentasi, tandai jelas sebagai placeholder yang perlu
  saya cek manual, jangan menebak dan membuat workflow gagal silent
