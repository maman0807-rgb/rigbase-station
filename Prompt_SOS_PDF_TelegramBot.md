# PROMPT — SOS Lab Report via PDF ke Telegram Bot (eRAMHoist)

## STATUS PER 27 Jul 2026 — Tahap 1, 2, 3 SELESAI & TERUJI

Alur lengkap sudah jalan end-to-end di production (workflow "Lap Harian
RAM" di n8n): kirim PDF ke @Eramhoist_bot → reply `/sos` → bot balas
ringkasan semua komponen + tombol `✅ Simpan Semua` / `❌ Batal` → pencet
Simpan Semua → data masuk `sos_samples` dengan `component_id` yang benar
→ muncul di app eRAMHoist (menu SOS Lab per equipment). Diuji pakai PDF
Trakindo asli (motor grader MG-MRG-051, 8 komponen sekaligus dalam 1 PDF).

**PR/cleanup yang masih menggantung (opsional, sistem sudah jalan tanpa ini):**
1. Node `Kirim Hasil Mentah SOS` (sisa Tahap 1, kirim JSON mentah) masih
   aktif — bikin user dapat 2 pesan tiap kirim PDF (JSON mentah + ringkasan
   resmi). Aman dihapus/dinonaktifkan sekarang.
2. NDT (`Filter Temuan` → ... → `Cek Siklus Existing`) masih ikut
   ke-trigger tiap PDF SOS dikirim (buang 1 Claude API call + muncul error
   di log NDT, karena PDF SOS nggak match rig manapun). Nggak merusak data,
   cuma noise & biaya kecil. Belum ditambal.
3. Tombol Telegram nggak berhenti animasi "loading" setelah dipencet
   (`answerCallbackQuery` ke Telegram API belum diimplementasi). Kosmetik.
4. Chat ID di beberapa node masih **hardcode ke Maman** (`5997132177`),
   bukan dinamis Maman/Bian — sesuai keputusan awal ("Bian nggak usah
   dulu"). Kalau nanti Bian perlu akses jalur ini juga, perlu dibalikin ke
   expression dinamis (`String($('Build Prompt SOS').first().json.chatId)`
   pola-nya sudah ada, tinggal diterapkan konsisten).
5. Kategori `component_type` masih terbatas ENGINE/GEARBOX/TRANSMISSION/
   FUEL/HYDRAULIC — kalau ketemu PDF dengan jenis komponen baru lagi
   (bukan salah satu dari itu), perlu diperluas lagi constraint + prompt
   Claude-nya (pola sudah ada dari nambah HYDRAULIC kemarin).

**Insiden yang sempat terjadi & sudah dibereskan (dicatat buat referensi):**
- SOS report PDF pertama (motor grader) awalnya salah dikira "MRG-050"
  (dari file backup lokal yang usang) padahal equipment asli di app itu
  **MRG-051** — 8 `equipment_components` + `sos_samples` yang sempat
  ke-insert di equipment_id MRG-050 sudah dipindah (`UPDATE
  equipment_components SET equipment_id = ...`) ke MRG-051 yang benar.
  Pelajaran: selalu cek equipment_id dari tabel `equipment` yang LIVE,
  jangan dari file backup/export lokal yang bisa sudah usang.

---

> Tempel prompt ini ke Claude Code / dipakai sebagai brief untuk workflow n8n.
> Kerjakan BERTAHAP — berhenti di tiap checkpoint untuk konfirmasi sebelum lanjut.
> Referensi wajib dibaca dulu: `Prompt_SOS_Module_eRAMHoist.md` (schema &
> field SOS_Sample), `fase13_sos_schema.sql` / `fase14_sos_baseline.sql`
> (skema aktual di Supabase), dan `docs/waha/N8N_WAHA_ERAMHOIST_PROMPT.md`
> (pola alur bot yang sudah established — draft/session, chat pribadi vs
> grup, insert bersama) supaya konsisten dengan konvensi yang sudah ada.

---

## KONTEKS

eRAMHoist punya modul **SOS (Scheduled Oil Sampling)** — saat ini entry
sample dilakukan **manual** lewat form di app, user menyalin angka satu-satu
dari PDF report Trakindo (lihat `Prompt_SOS_Module_eRAMHoist.md` Sub-fase 1A).

**Yang diminta:** tambah jalur baru — user kirim PDF report Trakindo
langsung ke **Telegram bot @Eramhoist_bot** (bot & n8n instance yang sama
yang sudah dipakai untuk Laporan Harian RAM & Temuan NDT/Inspeksi), bot
membaca isi PDF, dan hasil ekstraksinya dipakai untuk **mengisi entry SOS**
di app — bukan sekadar arsip file.

**Prinsip yang WAJIB dipertahankan** (sama seperti pola bot yang sudah ada):
- Report WAHA (jam jalan) dan report Telegram (Laporan Harian RAM, Temuan
  NDT/Inspeksi) **tetap jalan seperti sekarang, tidak diubah/disentuh**.
  Fitur ini murni tambahan cabang baru di bot Telegram yang sama.
- Hasil parse PDF **TIDAK langsung commit** ke `sos_samples` — harus lewat
  **draft/review** dulu (user konfirmasi di chat) sebelum tersimpan
  permanen, konsisten dengan pola Laporan Harian RAM & NDT yang sudah jalan,
  dan dengan prinsip Modul SOS: *"app = pencatat + penerjemah, keputusan
  akhir manusia"*.
- PDF asli tetap diarsipkan ke bucket `sos-reports` (sudah ada, private,
  RLS `is_sr_mekanik_or_above()`) — bot cuma mempercepat *entry*, bukan
  menggantikan arsip.

---

## INFO TEKNIS YANG SUDAH TERSEDIA

### Telegram & n8n (existing, sudah jalan untuk Laporan Harian RAM & NDT)
- **Bot:** @Eramhoist_bot
- **n8n instance:** `https://n8n-production-0080b.up.railway.app`
- Sudah ada workflow n8n yang menerima file dari Telegram, kirim ke Claude
  untuk parse, lalu draft/review sebelum masuk app — **pola ini yang
  di-reuse**, bukan dibangun dari nol. (Kalau workflow existing itu belum
  diexport ke repo ini, minta Maman export/screenshot dulu sebagai referensi
  sebelum bangun cabang baru, supaya konsisten gaya penamaan node & error
  handling.)

### Supabase
- **Project (satu sama semua modul eRAMHoist):** `olmowzrlokajhniqijfq`
- **Tabel terkait SOS** (dari `fase13_sos_schema.sql`):
  - `equipment_components` (`id, equipment_id, component_type, name, ...`)
  - `sos_samples` (`id, component_id, sampled_date, meter_hr, lab_status,
    lab_recommendation, pdf_attachment_path, data JSONB, ...`)
- **Storage bucket:** `sos-reports` (private, RLS Sr Mekanik+)
- **RLS:** semua tabel SOS pakai `is_sr_mekanik_or_above()` — jalur bot
  HARUS menghormati batasan role yang sama (lihat "Kontrol Akses" di bawah)

### Yang BELUM ADA (perlu dibuat)
- Pemetaan **Telegram user id → role/profile** untuk validasi Sr Mekanik+
  di jalur bot (kalau workflow existing RAM/NDT sudah punya mekanisme ini,
  reuse; kalau belum, perlu dibuat — lihat Tahap 0)
- Tabel session draft untuk hasil parse PDF SOS sebelum commit

---

## ARSITEKTUR ALUR (usulan, konfirmasi di CHECKPOINT 1)

```
User kirim PDF ke bot (chat pribadi)
  → n8n webhook terima message (type=document, mime=application/pdf)
  → Cek pengirim terdaftar & role Sr Mekanik+ (tolak diam-diam kalau tidak)
  → Download file dari Telegram (getFile)
  → Kirim ke Claude (API) dengan prompt ekstraksi terstruktur,
    field mengikuti schema data JSONB per component_type
    (lihat "Parameter per Component type" di Prompt_SOS_Module_eRAMHoist.md)
  → Resolve equipment_component:
      - Kalau caption user sertakan nama/kode komponen → match langsung
      - Kalau tidak / ambigu → balas daftar komponen bernomor
        (mirip /form [rig] di alur WA), user balas nomor
  → Simpan hasil parse + component_id ke tabel draft (belum commit),
    expiry pendek (mis. 30-60 menit, PDF lab jarang perlu sesi lama)
  → Balas ke user: ringkasan terformat (tanggal sample, lab_status,
    lab_recommendation, parameter kunci) + inline button:
      [ ✅ Simpan ]  [ ✏️ Edit di app ]  [ ❌ Batal ]
  → callback "✅ Simpan":
      - INSERT ke sos_samples (kolom top-level + data JSONB)
      - Upload PDF asli ke bucket sos-reports, isi pdf_attachment_path
      - Hapus draft session
      - Balas konfirmasi + link ke halaman Component di app
  → callback "✏️ Edit di app":
      - Balas link ke form manual di app (pre-fill draft kalau
        memungkinkan; kalau tidak, cukup arahkan ke form kosong +
        sebutkan draft belum hilang sampai expiry)
  → callback "❌ Batal": hapus draft, konfirmasi dibatalkan
```

**Kenapa draft table, bukan langsung insert:** parsing PDF (apalagi tabel
angka padat seperti report Trakindo) berisiko salah baca kolom/baris. Jeda
review sebelum commit adalah pengaman utama, sama seperti alasan Modul SOS
sendiri didesain "sinyal, bukan vonis" — kesalahan baca angka wear metal
bisa mengarahkan keputusan TOH/GOH yang salah.

---

## KONTROL AKSES

**Dikonfirmasi Maman (25 Jul 2026):** sama seperti jalur lapor siklus
inspeksi sekarang — yang boleh akses **cuma 2 orang: Maman & Bian**.
User lain belum diberi akses. Untuk SOS via bot, berlaku pembatasan yang
sama persis (bukan role Sr Mekanik+ secara umum, tapi eksplisit 2 orang
ini dulu).

Mekanisme: pakai kolom `profiles.telegram_user_id` yang sudah ada di
tabel (kolomnya ada, terverifikasi via `information_schema.columns`) —
cek nomor Telegram pengirim cocok dengan `telegram_user_id` milik profile
Maman atau Bian, baru diproses. Kalau nanti mau dibuka ke role Sr
Mekanik+ secara umum, tinggal ganti kondisi cek-nya belakangan (tidak
perlu ubah struktur tabel).

**Status per 25 Jul 2026 — RESOLVED.** Ternyata workflow RAM/NDT existing
di n8n sudah lama validasi pengirim pakai node hardcode:
```
{{ [5997132177, 6001873019].includes($json.message.chat.id) }}
```
Dicocokkan (dites kirim pesan ke @Eramhoist_bot, dicek execution log
n8n): `5997132177` = Maman (Abdul Rachman), `6001873019` = Bian Semok.

Kolom `profiles.telegram_user_id` sebelumnya kosong untuk keduanya — sudah
diisi dengan angka yang sama supaya konsisten dengan n8n:
```sql
UPDATE profiles SET telegram_user_id = '5997132177' WHERE full_name = 'Abdul Rachman';
UPDATE profiles SET telegram_user_id = '6001873019' WHERE full_name = 'Bian Semok';
```
SOS bot bisa pakai kondisi yang identik dengan node RAM/NDT di atas
(`[5997132177, 6001873019].includes(...)`) untuk cabang validasi
pengirimnya — konsisten dengan pola existing, dan sekaligus tercatat di
`profiles` untuk referensi/role.

---

## TUGAS BERTAHAP

### Tahap 0 — SQL: tabel draft (whitelist tidak perlu, sudah eksplisit 2 orang via `profiles.telegram_user_id`)
Buat SQL idempoten untuk:
```sql
CREATE TABLE sos_pdf_draft (
  id            uuid primary key default gen_random_uuid(),
  telegram_chat_id text not null,
  component_id  uuid references equipment_components(id),
  component_list_snapshot jsonb,       -- daftar komponen bernomor SAAT draft dibuat (dipakai
                                        -- resolve balasan angka user — jangan query ulang, supaya
                                        -- nomor tetap konsisten walau equipment_components berubah)
  parsed_data   jsonb not null,        -- hasil ekstraksi Claude, mentah
  file_telegram_id text,               -- file_id Telegram (belum diupload ke storage)
  status        text default 'awaiting_component',  -- 'awaiting_component' | 'ready' | 'confirmed' | 'cancelled'
  created_at    timestamptz default now(),
  expires_at    timestamptz default now() + interval '60 minutes'
);
```
Plus RLS dasar (service role only — draft ini ditulis/dibaca oleh n8n via
service key, bukan langsung oleh user app). Sertakan
`NOTIFY pgrst, 'reload schema';`.

**>> CHECKPOINT 0: SELESAI — `profiles.telegram_user_id` Maman & Bian
sudah terisi, ID sudah dikonfirmasi cocok dengan node n8n existing. Lanjut
ke Tahap 1.**

### Tahap 1 — Node parse PDF (test end-to-end, tanpa insert dulu)
1. Trigger: reuse webhook Telegram existing → **`Filter SOS`** (tambah 1
   cabang IF baru, paralel `Filter Temuan`/`Filter Dokumen`): kondisi
   **`message.document.mime_type == 'application/pdf'` DAN caption diawali
   `/sos`** (dikonfirmasi 25 Jul 2026 — tidak perlu auto-detect dari
   konten, wajib ketik `/sos` di caption saat kirim PDF)
2. Node: download file via `getFile` Telegram API → **`Convert PDF Base64`**
   (sama persis dengan cabang NDT, output field `base64Pdf`)
3. Node: **`Ambil Data Equipment`** — query `equipment_components` (join nama
   equipment) → hasilkan `componentList` (array `{id, equipment_name, name,
   component_type}`), paralel dengan `Ambil Data rig` di cabang NDT tapi
   sumbernya `equipment_components`, bukan `parent_units`. **Catatan:
   `id` di sini UUID (string), beda dari `parent_unit_id` di NDT yang
   integer** — jangan disamakan formatnya di prompt.
4. Node: **`Build Prompt SOS`** (Code node, gaya identik `Build Prompt NDT`)
   — lihat isi lengkap di bawah
5. Node: **`HTTP Request SOS`** — konfigurasi persis `HTTP Request NDT`
   (dikonfirmasi 25 Jul 2026, lihat detail di bawah), cuma `model` beda.
6. Node: balas ke chat — **tampilkan mentah hasil ekstraksi JSON** (belum
   resolve final, belum simpan draft) supaya kualitas parsing bisa dicek
   dulu pakai beberapa contoh PDF report asli.

PDF ke Claude **native, tidak perlu beta header** — cukup content block
`type: "document"` dengan base64, sama seperti yang sudah dipakai di
`Build Prompt NDT`.

#### Konfigurasi node "HTTP Request SOS" (HTTP Request, disalin dari `HTTP Request NDT`)

- **Method:** POST
- **URL:** `https://api.anthropic.com/v1/messages`
- **Authentication:** Generic Credential Type → Header Auth → **pakai
  kredensial yang sama** dengan NDT (`Header Auth account 2`, sudah
  berisi `x-api-key`) — jangan bikin kredensial baru
- **Headers:** `anthropic-version` = `2023-06-01`
- **Send Body:** ON, Body Content Type: JSON, Specify Body: Using Fields Below
- **Body Parameters:**
  | Name | Value |
  |---|---|
  | `model` | `claude-sonnet-5` (naik dari Haiku yang dipakai NDT — dipilih Maman
  25 Jul 2026 karena tabel wear-metal SOS padat angka dan jadi dasar
  keputusan TOH/GOH, beda karakter dari temuan NDT yang berbasis teks) |
  | `max_tokens` | `{{ 8192 }}` (sama dengan NDT) |
  | `system` | `{{ $json.systemPrompt }}` |
  | `messages` | `{{ $json.messagesArray }}` |

#### Isi node "Build Prompt SOS" (Code node, paralel `Build Prompt NDT`)

**Revisi 26 Jul 2026 (setelah test PDF asli pertama):** ternyata 1 PDF
Trakindo bisa berisi **beberapa laporan komponen sekaligus** (test case:
1 PDF motor grader berisi 8 laporan — Wheel Bearings, Tandem, Circle
Drive Box, Transmission Diff, Engine, Hydraulic, dst). Skema output
diubah dari **1 object** jadi **array of objects**, satu object per
komponen/titik sampling yang ditemukan.

```javascript
const componentList = $json.componentList || [];
const componentLines = componentList
  .map(c => `${c.id} — ${c.equipment_name} / ${c.name} (${c.component_type})`)
  .join('\n');

const filterNode = $('Filter SOS').first().json;
const chatId = filterNode.message.chat.id;
const caption = filterNode.message.text || '(tidak ada teks)';

const base64Pdf = $('Convert PDF Base65').first().json.base64Pdf;

const systemPrompt = `Kamu adalah parser laporan SOS (Scheduled Oil Sampling) dari lab Trakindo untuk equipment Hoist & Heavy Equipment Pertamina EP.

Satu PDF bisa berisi LEBIH DARI SATU laporan komponen/titik sampling
sekaligus (mis. 1 unit dengan beberapa titik: Engine, Transmission,
Wheel Bearings, dst — masing-masing punya data wear metal sendiri).

OUTPUT: HANYA satu JSON ARRAY valid, TANPA teks lain, TANPA markdown code fence, TANPA penjelasan. Array berisi SATU object per komponen/titik sampling yang ditemukan di PDF ini (bisa 1, bisa lebih — WAJIB ekstrak SEMUA, jangan pilih satu saja). Skema tiap object:

{
  "component_id": string atau null — cocokkan dari DAFTAR KOMPONEN di bawah ke equipment/komponen yang disebut di PDF (nama unit & serial number), isi UUID persis dari daftar. null kalau tidak yakin/tidak terdaftar,
  "component_name_raw": string — nama komponen/titik sampling PERSIS seperti tertulis di PDF (mis. "Wheel Bearings Front Right", "Engine"), WAJIB diisi supaya bisa dibedakan dari komponen lain di PDF yang sama,
  "component_type_guess": "ENGINE" | "GEARBOX" | "TRANSMISSION" | "FUEL" | "HYDRAULIC",
  "sampled_date": "YYYY-MM-DD" atau null,
  "sample_id": string atau null,
  "lab_date": "YYYY-MM-DD" atau null,
  "meter_hr": number atau null,
  "meter_on_fluid": number atau null,
  "fluid_change": boolean atau null,
  "filter_change": boolean atau null,
  "fluid_type": string atau null,
  "fluid_brand": string atau null,
  "lab_status": string atau null — verdict Trakindo APA ADANYA (mis. "No Action Required"),
  "lab_recommendation": string atau null — rekomendasi Trakindo APA ADANYA,
  "data": {
    "wear_metals": { "fe":null,"cu":null,"pb":null,"cr":null,"al":null,"sn":null,"ni":null,"si":null,"na":null,"k":null },
    "oil_condition": { "soot":null,"oxidation":null,"nitration":null,"sulfation":null,"water":null,"tbn":null,"tan":null,"viscosity_100c":null,"pq_index":null },
    "additives": { "ca":null,"p":null,"zn":null,"mg":null,"mo":null,"b":null }
  },
  "catatan": string atau null — hal ambigu yang perlu dicek manual
}

ATURAN PENTING:
1. JANGAN mengarang nilai — field yang tidak ada di PDF WAJIB null.
2. Konversi angka Indonesia (koma sebagai desimal) ke format number JSON standar (titik desimal).
3. Isi parameter HANYA yang relevan dengan component_type_guess (mis. jangan isi soot kalau ini GEARBOX) — sisanya null.
4. lab_status dan lab_recommendation diambil APA ADANYA dari kalimat verdict Trakindo, jangan diringkas/diubah/diterjemahkan.
5. WAJIB ekstrak SEMUA komponen/titik sampling yang ada di PDF ini — kalau PDF berisi 8 laporan, array HARUS berisi 8 object, bukan 1.
6. Klasifikasi component_type_guess: Wheel Bearings, Tandem, Circle Drive Box, Final Drive → "GEARBOX" (satu grup parameter yang sama). Differential/Transmission → "TRANSMISSION". Hydraulic System → "HYDRAULIC". Engine → "ENGINE".

DAFTAR KOMPONEN (buat referensi cocokkan component_id, id berupa UUID):
${componentLines}

PETUNJUK PENGIRIM (teks balasan Telegram, opsional):
${caption}`;

const messagesArray = [
  {
    role: 'user',
    content: [
      { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: base64Pdf } },
      { type: 'text', text: 'Parse laporan SOS di PDF ini sesuai instruksi system prompt.' }
    ]
  }
];

return [{ json: { chatId, systemPrompt, messagesArray } }];
```

**Tahap 1 sengaja TIDAK pakai `output_config.format` (structured
outputs/strict schema) dulu** — field yang benar per component_type
belum divalidasi terhadap PDF asli (Checkpoint 1 tujuannya justru
mengecek itu). Minta JSON via prompt (seperti di atas) dulu, baru
dikunci ke schema resmi di Tahap 2 setelah akurasi field dikonfirmasi
— sama seperti pola NDT yang juga tidak pakai strict schema.

**Catatan tentang blok "thinking":** `claude-sonnet-5` otomatis pakai
adaptive thinking meski parameter `thinking` tidak di-set, jadi
`response.content[0]` sering berupa blok `type: "thinking"`, BUKAN blok
teks. Node manapun yang baca hasil Claude (baik node balasan mentah di
Tahap 1 maupun `Parse SOS Response` di Tahap 2) **WAJIB** cari blok teks
dengan filter, bukan asumsi index tetap:
```javascript
const textBlock = response.content.find(b => b.type === 'text');
```

**>> CHECKPOINT 1: uji dengan 2-3 PDF report Trakindo asli (komponen
berbeda kalau bisa — ENGINE & GEARBOX), review akurasi ekstraksi manual
sebelum lanjut ke resolve-component & draft. Kalau akurasi sudah stabil,
Tahap 2 baru mengunci field final via `output_config.format` (json_schema)
supaya output selalu valid tanpa perlu parse-guard manual.**

### Tahap 2 — Simpan draft batch + ringkasan review

**Revisi 26 Jul 2026 — desain batch (1 PDF = 1 batch draft):** karena 1
PDF bisa berisi banyak komponen (test case: 8), konfirmasi Telegram
disederhanakan jadi **1 pesan ringkasan semua komponen + 1 tombol
"Simpan Semua"**, bukan konfirmasi per-komponen. Kalau ada komponen yang
`component_id`-nya null (nggak ke-match), draft-nya tetap ikut tersimpan
saat "Simpan Semua" ditekan — koreksi manual dilakukan di app setelah
itu, **bukan** lewat tanya-jawab nomor di Telegram (fitur "pilih nomor
komponen" yang dirancang sebelumnya di-drop, kurang cocok untuk banyak
komponen sekaligus).

**Perubahan skema `sos_pdf_draft`** (tambahan dari Tahap 0):
```sql
ALTER TABLE sos_pdf_draft ADD COLUMN IF NOT EXISTS batch_id uuid;
NOTIFY pgrst, 'reload schema';
```
(`component_list_snapshot` & status `awaiting_component` dari desain
lama boleh dibiarkan menganggur di skema, tidak dipakai lagi — tidak
perlu drop kolom demi kesederhanaan migrasi)

**Node 1 — `Parse SOS Response`** (Code node, Run Once for All Items,
input dari `HTTP Request SOS`):
```javascript
const textBlock = $json.content.find(b => b.type === 'text');
let raw = textBlock.text.trim();
raw = raw.replace(/^```json\s*/i, '').replace(/```\s*$/i, '').trim();

function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

let components;
try {
  components = JSON.parse(raw);
} catch (e) {
  return [{ json: { parseError: true, rawText: raw, chatId: String($('Build Prompt SOS').first().json.chatId) } }];
}

const chatId = String($('Build Prompt SOS').first().json.chatId);
const batchId = uuidv4();

return components.map(c => ({ json: { ...c, chatId, batchId } }));
```
Catatan: `chatId` dibungkus `String(...)` — waktu Tahap 1 ketemu bug
"chat not found" di Telegram kalau `chat_id` yang dikirim berupa tipe
number dari expression (bukan string), jadi semua node yang teruskan
`chatId` ke Telegram HARUS pastikan itu string.

**Node 2 — IF `parseError` = true?** True → kirim pesan error ke
`chatId` ("Gagal baca hasil parse, coba kirim ulang PDF-nya") → STOP.
False → lanjut Node 3 (jalan N kali, sekali per komponen dalam array).

**Node 3 — `Simpan Draft Batch SOS`** (Supabase, Create Row, jalan
per-item — N kali untuk N komponen): INSERT ke `sos_pdf_draft` —
`telegram_chat_id` = `chatId`, `component_id` = `component_id` (boleh
null), `parsed_data` = seluruh object komponen (`{{ $json }}` minus
`chatId`/`batchId` kalau mau rapi, atau simpan apa adanya juga tidak
masalah), `batch_id` = `batchId`, `status` = `'ready'`.

**Node 4 — `Format Ringkasan SOS`** (Code node, **Run Once for All
Items** — ini yang mengumpulkan balik semua N hasil insert jadi 1):
```javascript
const items = $input.all().map(item => item.json);
const chatId = items[0].chatId;
const batchId = items[0].batchId;

const lines = items.map((c, i) => {
  const flag = c.component_id ? '✅' : '⚠️ belum match';
  return `${i + 1}. ${c.component_name_raw || c.component_type_guess} — ${c.lab_status || '(status?)'} ${flag}`;
});

const ringkasan = `📋 Draft SOS — ${items.length} komponen terdeteksi\n\n${lines.join('\n')}\n\nCek detail tiap komponen di app sebelum simpan final. Tekan Simpan buat commit semua ke sos_samples.`;

return [{ json: { chatId, batchId, ringkasan } }];
```

**Node 5 — `Kirim Konfirmasi SOS`** (Telegram `sendMessage`, jalan 1x
karena Node 4 output 1 item) — Parse Mode: **None/HTML sesuai yang
terbukti jalan di Tahap 1** (hindari Markdown, ketemu bug "can't parse
entities" kalau teks ada underscore/backtick). `callback_data` bawa
`batchId`, bukan `draft_id` per-komponen:
```json
{
  "chat_id": "{{ $json.chatId }}",
  "text": "{{ $json.ringkasan }}",
  "reply_markup": {
    "inline_keyboard": [[
      { "text": "✅ Simpan Semua", "callback_data": "sos_confirm_batch:{{ $json.batchId }}" },
      { "text": "❌ Batal", "callback_data": "sos_cancel_batch:{{ $json.batchId }}" }
    ]]
  }
}
```

**>> CHECKPOINT 2: kirim PDF SOS asli sampai muncul 1 pesan ringkasan
semua komponen + 2 tombol (Simpan Semua/Batal). Cek row `sos_pdf_draft`
kebentuk benar (N baris, `batch_id` sama semua) sebelum lanjut Tahap 3.**

### Tahap 3 — Callback handler (confirm/cancel batch) + insert final
1. Node: webhook `callback_query` — parse `callback_data` (split by `:`)
   → `action` (`sos_confirm_batch`/`sos_cancel_batch`) + `batchId`,
   routing 2 cabang sesuai `action`. Jangan lupa `answerCallbackQuery`
   (Telegram API) supaya tombol di HP user berhenti "loading".
2. Cabang Simpan Semua: SELECT semua row `sos_pdf_draft` WHERE
   `batch_id` = `batchId` → INSERT masing-masing ke `sos_samples` (dari
   `parsed_data` + `component_id`), upload PDF sekali saja ke bucket
   `sos-reports` (path per component, mis.
   `sos-reports/{component_id atau batchId kalau null}/{sampled_date}.pdf`),
   isi `pdf_attachment_path`, DELETE semua row draft `batch_id` itu,
   balas konfirmasi jumlah komponen tersimpan + link app.
3. Cabang Batal: DELETE semua row draft `batch_id` itu, balas konfirmasi
   batal.
4. Cron/trigger cleanup draft yang `expires_at` lewat tanpa aksi
   (opsional, boleh manual dulu).

**>> CHECKPOINT 3: tunjukkan hasil end-to-end (kirim PDF → review batch →
Simpan Semua → cek semua row muncul benar di `sos_samples` dan file
muncul di storage) sebelum dianggap selesai.**

---

## CATATAN
- Format PDF Trakindo relatif konsisten per lab/region tapi tidak dijamin
  100% seragam antar component_type — jangan asumsikan satu prompt Claude
  cocok untuk semua, uji tiap tipe komponen di Checkpoint 1.
- Form manual entry yang sudah ada (Sub-fase 1A) **tetap dipertahankan**
  sebagai jalur utama/koreksi — jalur PDF bot ini pelengkap, bukan
  pengganti.
- Jangan sentuh workflow Laporan Harian RAM & Temuan NDT/Inspeksi yang
  sudah jalan — cabang baru harus terisolasi (IF/Switch terpisah) supaya
  tidak ada regresi di jalur yang sudah stabil.
