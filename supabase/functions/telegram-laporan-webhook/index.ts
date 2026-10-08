// Edge Function: telegram-laporan-webhook
// "Opsi B" dari docs/LAPORAN_HARIAN_V2.md — Perangkum kirim rangkuman Laporan
// Harian ke bot Telegram (chat pribadi, bot yang sama dengan bot alert), bot
// langsung bikin draft di eRAMHoist lewat function ini (tanpa n8n, karena n8n
// sudah dimatikan — lihat reference_eramhoist_repo.md soal WAHA/n8n).
//
// Pakai parser yang SAMA PERSIS dengan tombol "📋 Tempel Laporan" di app
// (supabase/functions/_shared/laporan_harian_v2.js, salinan dari
// js/laporan_harian_v2.js — WAJIB disalin ulang kalau aturan parser berubah).
//
// Setup (lihat README.md di folder ini untuk langkah lengkap):
//   - Deploy: supabase functions deploy telegram-laporan-webhook --no-verify-jwt
//     (--no-verify-jwt WAJIB -- Telegram tidak bisa kirim header Authorization
//     Supabase sendiri, jadi proteksi dipindah ke secret_token Telegram di bawah)
//   - Secrets yang perlu di-set (supabase secrets set ...):
//       TELEGRAM_BOT_TOKEN        -- sudah ada (dipakai send-telegram-alert)
//       TELEGRAM_REPORT_CHAT_ID   -- chat ID pribadi Perangkum dgn bot (BUKAN group alert)
//       TELEGRAM_WEBHOOK_SECRET   -- string acak bebas, didaftarkan ke Telegram saat setWebhook
//       TELEGRAM_REPORT_USER_ID   -- UUID user eRAMHoist yg jadi "created_by" draft dari bot
//   - Daftarkan webhook ke Telegram (sekali saja, lihat README.md)
//
// Desain aman: kalau draft tanggal itu SUDAH ADA (final ATAU draft), function
// ini TIDAK menimpa otomatis -- cuma balas chat kasih tau, biar penggantian
// draft tetap lewat konfirmasi manual di app (sama kehati-hatiannya kayak
// tombol "Buat Draft" yang nanya dulu sebelum ganti).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const LaporanHarianV2 = require("../_shared/laporan_harian_v2.js");

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const REPORT_CHAT_ID = Deno.env.get("TELEGRAM_REPORT_CHAT_ID")!;
const WEBHOOK_SECRET = Deno.env.get("TELEGRAM_WEBHOOK_SECRET")!;
const REPORT_USER_ID = Deno.env.get("TELEGRAM_REPORT_USER_ID")!;
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEYS")!;

const corsHeaders = { "Access-Control-Allow-Origin": "*" };

function fmtDateID(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleDateString("id-ID", { day: "2-digit", month: "long", year: "numeric" });
}

async function sendTelegram(chatId: string | number, text: string): Promise<void> {
  try {
    await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text, parse_mode: "HTML", disable_web_page_preview: true }),
    });
  } catch (e) {
    console.error("Gagal balas Telegram:", e);
  }
}

// Padanan persis lhv2KeEntry() di index.html -- JANGAN biarkan menyimpang,
// biar hasil draft dari bot & dari "Tempel Laporan" identik strukturnya.
function keEntry(p: any, eq: any | null) {
  const label = [
    p.unit_rig ? p.unit : (p.unit && p.unit !== p.equipment ? p.unit : null),
    p.equipment || p.judul,
  ].filter(Boolean).join(" – ");
  const catatan = [
    p.status_asli ? `Status: ${p.status_asli}` : null,
    p.judul_ket ? `Ket. judul: ${p.judul_ket}` : null,
  ].filter(Boolean).join("\n");
  return {
    equipment_id: eq ? eq.id : null,
    equipment_manual_nama: eq ? null : label,
    site: p.lokasi || "",
    status_kerja: p.status_kerja || "Lainnya",
    job_desc: [p.jenis_asli || p.jenis, p.gejala].filter(Boolean).join(" – "),
    brand: eq?.brand || "", model: eq?.model || "", sn: p.sn || eq?.serial_number || "",
    rh: p.meter_nilai ?? null,
    waktu_mulai: null, waktu_selesai: null,
    checklist: (p.deskripsi || []).map((item: string) => ({ item, checked: true })),
    progress_pct: p.progress ?? null,
    notes: catatan || null,
    follow_up_items: p.status === "Tunggu" ? [`Tunggu ${p.status_ket || ""}`.trim()] : [],
    tipe_v2: p.tipe, no_urut: p.no, unit_lapor: p.unit, judul_lapor: p.equipment || p.judul,
    jenis: p.jenis, jenis_asli: p.jenis_asli, gejala: p.gejala,
    mulai_pekerjaan: p.mulai, selesai_pekerjaan: p.selesai, jam_mulai: p.jam_mulai, jam_selesai: p.jam_selesai,
    meter_tipe: p.meter_tipe, rig_stop: p.rig_stop, rig_stop_ket: p.rig_stop_ket, pic: p.pic, no_wo: p.no_wo,
    status_v2: p.status, status_ket: p.status_ket, status_asli: p.status_asli,
    part: p.part, flags: p.flags,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  // Verifikasi ini beneran dari Telegram -- Telegram ngirim balik secret_token
  // yang kita daftarkan saat setWebhook, di header ini.
  const gotSecret = req.headers.get("x-telegram-bot-api-secret-token");
  if (gotSecret !== WEBHOOK_SECRET) {
    return new Response("forbidden", { status: 403, headers: corsHeaders });
  }

  let update: any;
  try {
    update = await req.json();
  } catch {
    return new Response("ok", { headers: corsHeaders }); // body aneh, jangan bikin Telegram retry terus
  }

  const msg = update?.message;
  const text: string | undefined = msg?.text;
  const chatId = msg?.chat?.id;

  // Bukan pesan teks, atau bukan dari chat pelapor yang terdaftar -> diemin aja
  // (200 OK biar Telegram gak nge-retry), jangan proses & jangan balas apa-apa.
  if (!text || String(chatId) !== String(REPORT_CHAT_ID)) {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const sb = createClient(SB_URL, SB_SERVICE_KEY);

    const r = LaporanHarianV2.parseLaporan(text);

    if (!r.tanggal && !r.pekerjaan.length && !r.status_rig.length) {
      await sendTelegram(chatId,
        "⚠️ Pesan ini gak kebaca sebagai Laporan Harian (judul/tanggal/isi gak ketemu). " +
        "Pastikan diawali \"*LAPORAN HARIAN HOIST & HEAVY EQUIPMENT*\" dan dikirim sebagai SATU pesan " +
        "(kalau kepanjangan sampai Telegram motong jadi beberapa pesan, bot cuma baca yang pertama kali masuk).");
      return new Response("ok", { headers: corsHeaders });
    }
    if (!r.tanggal) {
      await sendTelegram(chatId, "⛔ Tanggal laporan gak kebaca di judul. Cek format tanggalnya (dd/mm/yyyy), lalu kirim ulang.");
      return new Response("ok", { headers: corsHeaders });
    }

    // Cek laporan tanggal ini udah ada belum -- JANGAN auto-timpa, biar aman.
    const { data: ada, error: eCek } = await sb.from("laporan_harian").select("id, status").eq("tanggal", r.tanggal);
    if (eCek) throw eCek;
    if ((ada || []).some((x: any) => x.status === "final")) {
      await sendTelegram(chatId, `⛔ Laporan ${fmtDateID(r.tanggal)} sudah FINAL di app — gak dibuat ulang. Buka app kalau perlu edit.`);
      return new Response("ok", { headers: corsHeaders });
    }
    if ((ada || []).length) {
      await sendTelegram(chatId, `⚠️ Sudah ada draft ${fmtDateID(r.tanggal)} di app. Bot gak nimpa otomatis — buka app, hapus/ganti draft lama secara manual kalau mau pakai hasil kiriman ini.`);
      return new Response("ok", { headers: corsHeaders });
    }

    // Equipment list + parent units, buat cocokkanEquipment() -- field yang
    // dipilih sama persis dengan lhEnsureEquipmentList() di index.html.
    const [{ data: eqList, error: eEq }, { data: units, error: eUnit }] = await Promise.all([
      sb.from("equipment").select("id, tag_number, nama_equipment, brand, model, serial_number, running_hours, status_operasi, assigned_unit_id, pm_type").order("tag_number"),
      sb.from("parent_units").select("id, name"),
    ]);
    if (eEq) throw eEq;
    if (eUnit) throw eUnit;

    r.pekerjaan.forEach((p: any) => {
      p._match = LaporanHarianV2.cocokkanEquipment(p, eqList || [], units || []);
      if (!p._match) p.flags.push({ level: "cek", kode: "equipment_belum_cocok", pesan: "Belum dicocokkan ke master equipment — pilih di kartu" });
    });

    const { data: hdr, error: eHdr } = await sb.from("laporan_harian").insert({
      tanggal: r.tanggal, tim: "RAM Hoist & Heavy Equipment", status: "draft", sumber: "bot_telegram",
      raw_text: text, format_versi: "v2", status_rig: r.status_rig, created_by: REPORT_USER_ID,
    }).select("id").single();
    if (eHdr) throw eHdr;

    const rows = r.pekerjaan.map((p: any) => {
      const eq = p._match ? (eqList || []).find((x: any) => x.id === p._match.id) : null;
      return { ...keEntry(p, eq), laporan_id: hdr.id };
    });
    if (rows.length) {
      const { error: eRows } = await sb.from("laporan_harian_entries").insert(rows);
      if (eRows) throw eRows;
    }

    await sb.from("activity_log").insert({
      user_id: REPORT_USER_ID, user_name: "Bot Telegram", action: "laporan_harian_tempel",
      entity_type: "laporan_harian", entity_id: String(hdr.id), entity_label: fmtDateID(r.tanggal),
      details: { pekerjaan: rows.length, via: "telegram_bot" },
    });

    const nKurang = r.pekerjaan.reduce((a: number, p: any) => a + p.flags.filter((f: any) => f.level === "kurang").length, 0) + r.flags.filter((f: any) => f.level === "kurang").length;
    const nCek = r.pekerjaan.reduce((a: number, p: any) => a + p.flags.filter((f: any) => f.level === "cek").length, 0) + r.flags.filter((f: any) => f.level === "cek").length;
    const nBaru = r.pekerjaan.filter((p: any) => p.tipe === "BARU").length;
    const nLanjut = r.pekerjaan.filter((p: any) => p.tipe === "LANJUT").length;
    const nSelesai = r.pekerjaan.filter((p: any) => p.status === "Selesai").length;

    await sendTelegram(chatId,
      `✅ <b>Draft ${fmtDateID(r.tanggal)} dibuat</b>\n` +
      `Status rig: ${r.status_rig.length} · Pekerjaan: ${r.pekerjaan.length} (${nBaru} baru, ${nLanjut} lanjut, ${nSelesai} selesai)\n` +
      (nKurang ? `⛔ Isian kurang: ${nKurang}\n` : "") +
      (nCek ? `⚠️ Perlu dicek: ${nCek}\n` : "") +
      `\nBuka app eRAMHoist → Laporan Harian → ${fmtDateID(r.tanggal)} buat lengkapi & Simpan Final.`);

    return new Response(JSON.stringify({ ok: true, laporan_id: hdr.id }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    console.error("telegram-laporan-webhook error:", err);
    await sendTelegram(chatId, `⛔ Gagal bikin draft: ${String((err as Error)?.message || err)}`);
    return new Response("ok", { headers: corsHeaders }); // tetap 200 ke Telegram, errornya udah dibalas ke chat
  }
});
