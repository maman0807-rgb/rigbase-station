# telegram-laporan-webhook — "Opsi B": bot Telegram → draft otomatis

> ⚠️ **TIDAK DIPAKAI.** Keputusan final 2026-10-09: alur produksi tetap pakai **n8n**
> (workflow "Laporan Harian RAM", masih AKTIF — bukan mati seperti dikira waktu function
> ini dibikin). JANGAN jalankan `?action=setup` (setWebhook) — bot Telegram cuma bisa
> punya 1 webhook, jadi itu bakal ngambil alih dari n8n dan laporan berhenti masuk ke
> sana (sudah kejadian sekali, 2026-10-09, diperbaiki pakai `?action=delete`). Lihat
> `docs/LAPORAN_HARIAN_V2.md` bagian "Keputusan 2026-10-09" sebelum menyentuh ini lagi.

Ganti alur "📋 Tempel Laporan" (paste manual di app) jadi: Perangkum kirim rangkuman
ke bot Telegram seperti dulu → bot langsung bikin draft Laporan Harian di eRAMHoist.
Dibikin dengan asumsi n8n sudah mati total — **asumsi itu salah**, lihat peringatan
di atas. Disimpan di repo buat referensi/opsi masa depan saja.

**Saya (Claude, sesi ini) gak punya akses CLI/deploy ke project Supabase-nya** — langkah
di bawah ini perlu Maman jalanin sendiri.

## 1. Deploy function-nya

```bash
cd rigbase-station
supabase link --project-ref olmowzrlokajhniqijfq   # kalau belum pernah link di laptop ini
supabase functions deploy telegram-laporan-webhook --no-verify-jwt
```

`--no-verify-jwt` **WAJIB** — Telegram gak bisa kirim header Authorization Supabase,
jadi proteksinya dipindah ke secret token Telegram sendiri (langkah 3).

## 2. Set secrets

```bash
supabase secrets set TELEGRAM_REPORT_CHAT_ID=xxxxxxxxx
supabase secrets set TELEGRAM_WEBHOOK_SECRET=isi-string-acak-bebas-minimal-20-karakter
supabase secrets set TELEGRAM_REPORT_USER_ID=uuid-user-eramhoist
```

`TELEGRAM_BOT_TOKEN` seharusnya **udah ada** (dipakai `send-telegram-alert`/
`daily-alert-check`) — gak perlu di-set ulang, cuma dipakai bareng.

- **TELEGRAM_REPORT_CHAT_ID**: chat ID pribadi antara Perangkum & bot (BUKAN chat_id
  group alert yang dipakai `send-telegram-alert`). Cara cepat cari tahu: dari HP yang
  dipakai Perangkum, kirim pesan apa aja ke bot-nya, lalu buka di browser:
  `https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getUpdates` — cari `"chat":{"id": ...}`
  di hasil JSON-nya, itu angkanya (biasanya negatif untuk group, positif untuk chat pribadi).
- **TELEGRAM_WEBHOOK_SECRET**: bebas, ketik string acak sendiri (gak perlu diingat,
  cuma dipakai sekali waktu daftarin webhook di langkah 3 dan dicocokkan tiap request masuk).
- **TELEGRAM_REPORT_USER_ID**: UUID akun eRAMHoist yang mau "memiliki" draft yang dibuat
  bot (kolom `created_by`). Ambil dari Supabase Dashboard → Authentication → Users,
  copy UUID akun yang sesuai (bisa punya Maman sendiri).

## 3. Daftarkan webhook ke Telegram (sekali aja, abis deploy)

Ganti `<TELEGRAM_BOT_TOKEN>`, `<SECRET_SAMA_DENGAN_LANGKAH_2>` sesuai punya sendiri:

```
https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook?url=https://olmowzrlokajhniqijfq.supabase.co/functions/v1/telegram-laporan-webhook&secret_token=<SECRET_SAMA_DENGAN_LANGKAH_2>
```

Buka URL itu di browser (GET request, boleh langsung dari address bar) — harus
muncul `{"ok":true,"result":true,"description":"Webhook was set"}`.

Cek statusnya kapan aja dengan:
```
https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo
```

## 4. Uji coba

Kirim satu rangkuman laporan lengkap (format sama kayak template yang ada di
Panduan app) ke chat pribadi bot itu. Dalam beberapa detik bot harus balas
ringkasan ("✅ Draft ... dibuat") atau pesan error yang jelas kalau ada masalah
(tanggal gak kebaca, draft tanggal itu udah ada, dll). Buka app → Laporan Harian
untuk lihat & lengkapi draft-nya sebelum Simpan Final.

## Batasan yang perlu diketahui

- **Satu pesan Telegram = satu laporan.** Kalau rangkumannya kepanjangan sampai
  Telegram motong jadi beberapa pesan terpisah (limit ~4096 karakter per pesan),
  bot cuma baca bagian yang pertama masuk — gak ada logic gabung-pesan di versi ini
  (itu baru ada di "Opsi C" yang belum dibangun). Kalau ini kejadian beneran,
  kabari supaya logic buffer-nya ditambahkan.
- **Gak menimpa draft yang sudah ada.** Kalau tanggal yang sama udah ada laporan
  (draft atau final) di app, bot cuma balas chat kasih tau, gak bikin/ganti apa-apa.
  Penggantian draft tetap manual lewat app (sama kayak tombol "Buat Draft" lama,
  yang juga minta konfirmasi sebelum timpa).
- **Equipment yang gak ke-cocokkan otomatis** tetap masuk draft (field equipment
  kosong + flag "cek"), sama kayak kalau pakai "Tempel Laporan" manual — perlu
  dicocokkan manual di kartu draft sebelum Simpan Final.
- Parser yang dipakai (`supabase/functions/_shared/laporan_harian_v2.js`) adalah
  **salinan** dari `js/laporan_harian_v2.js` (dipakai browser). Kalau nambah
  aturan parser baru, update DUA-DUANYA.
