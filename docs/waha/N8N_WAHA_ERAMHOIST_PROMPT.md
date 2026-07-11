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
Logbook", karena ada detail penting yang TIDAK boleh dilewatkan:
- eRAMHoist & app Logbook (`~/logbook-equipment`) **satu Supabase yang
  sama** — WAHA harus tulis ke tabel `logbook` (bukan bikin tabel baru),
  supaya tidak jadi jalur ketiga yang tidak sinkron dengan app.
- `reporter_id` di tabel `logbook` kemungkinan besar tipe **UUID** —
  JANGAN masukkan nomor WA mentah ke situ, pakai `wa_whitelist.id`.
- Jam jalan = delta (additive), BUKAN HM absolut — desain ini sengaja
  supaya validasi "HM tidak boleh turun" otomatis aman tanpa reject-logic
  terpisah.

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
  tiap pesan masuk grup di-forward ke webhook n8n — cek dokumentasi WAHA
  versi yang dipakai untuk cara setup webhook (event `message`)
- **Field quote-reply:** belum dicek exact nama field-nya (`reply_to` /
  `quotedMessageId`, tergantung versi WAHA) — **cek dokumentasi API/response
  contoh pesan masuk dulu sebelum implementasi reply**

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
- **API Key:** service role atau anon sesuai kebutuhan node — isi lewat n8n
  Credentials, jangan hardcode

## Tugas yang Saya Minta

### Tahap 0 — SQL: buat tabel `wa_whitelist`
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
```
Plus RLS policy dasar (proyek ini pakai RLS di semua tabel — ikuti pola yang
sudah ada di eRAMHoist, lihat tabel `pemasangan` sebagai referensi kalau
perlu contoh). Sertakan juga `NOTIFY pgrst, 'reload schema';` di akhir.

### Tahap 1 — Workflow sederhana (test end-to-end kirim pesan)
1. Trigger: Manual Trigger
2. Node HTTP Request: `POST /api/sendText` ke WAHA, kirim teks test ke grup
3. Simpan sebagai `workflow-waha-test.json`, siap import via **Workflow →
   Import from File**

Jangan lanjut ke tahap berikutnya sebelum saya konfirmasi tahap ini berhasil
kirim ke grup.

### Tahap 2 — Workflow Pull: terima & proses command `/jamjalan`
1. Trigger: Webhook (menerima event pesan masuk dari WAHA)
2. Node IF/Filter: cek prefix command `/jamjalan` DAN nomor pengirim ada di
   `wa_whitelist` dengan `aktif=true` — kalau tidak match keduanya, **stop
   tanpa balas** (tidak ganggu chat biasa di grup)
3. Node Function: parse command —
   format `/jamjalan [tag_number] [siang|malam] [jam] [baik|waspada|rusak] [catatan opsional]`
   - Validasi format: 4 argumen wajib pertama harus ada & valid, kalau
     tidak → balas pesan error format (lihat contoh di konsep doc)
   - Mapping kondisi: `baik→baik`, `waspada→perlu_perhatian`, `rusak→rusak`
4. Node Supabase: query `wa_whitelist` by nomor pengirim → ambil `id, nama, rig`
5. Node Supabase: query `equipment` by `tag_number` → ambil `id, running_hours`
   - Kalau tag tidak ditemukan → balas error "Tag tidak dikenali"
6. Node IF: kalau whitelist row `rig` **terisi** (bukan admin) → cek
   equipment yang di-entry harus milik rig itu, tolak kalau beda rig
7. Node Supabase: INSERT ke tabel `logbook` —
   `reporter_id = wa_whitelist.id` (BUKAN nomor WA mentah — lihat catatan
   penting di konsep doc), `reporter_name`, `reporter_role` ('operator'
   atau 'admin' tergantung `rig IS NULL`), `shift`, `condition`,
   `shift_hours`, `temuan` (dari catatan opsional), `status: 'pending'`
8. Node Supabase: UPDATE `equipment.running_hours` =
   `running_hours + shift_hours` (additive, tidak perlu cek turun karena
   selalu nambah)
9. Node HTTP Request: reply (quote) ke grup dengan pesan konfirmasi —
   beda format kalau `reporter_role='admin'` (sertakan nama admin +
   keterangan "pengganti sementara", lihat contoh format di konsep doc)

Simpan sebagai `workflow-waha-jamjalan-entry.json`.

### Tahap 3 — Workflow Push: laporan & reminder terjadwal
1. Trigger: Schedule, jalan **06:00 WIB dan 18:00 WIB** (dua schedule
   trigger terpisah atau satu dengan cron yang cover keduanya)
2. Node Supabase: query `equipment` (filter rig aktif) + `logbook` entries
   hari ini/shift ini
3. Node Function: hitung equipment yang **sudah** vs **belum** entry shift
   berjalan (siang untuk trigger 06:00 → shift sebelumnya='malam' semalam;
   18:00 → shift 'siang' hari ini — sesuaikan logika periode sesuai jadwal)
4. Node Function: format 2 bagian pesan — laporan (equipment yang sudah
   entry + jam jalan + kondisi) dan reminder (equipment yang belum, dengan
   format command sebagai bantuan)
5. Node HTTP Request: kirim ke grup via WAHA

Simpan sebagai `workflow-waha-laporan-reminder.json`.

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
