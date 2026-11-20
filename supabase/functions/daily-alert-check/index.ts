// Edge Function: daily-alert-check
// Cek SKPI expired + maintenance due + status Down → kirim summary ke Telegram
// Dijadwal tiap pagi 08:00 WIB via pg_cron

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID")!;
const APP_URL = Deno.env.get("APP_URL") || "https://eramhoist.vercel.app";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEYS")!;

const corsHeaders = { "Access-Control-Allow-Origin": "*" };

// GS-KB150A-CAT/GS-KB150B-CAT pindah ke jadwal Caterpillar C7.1 (index.html
// CAT_C71_PM_LADDER + tabel cat_c71_pm_log) -- dikecualikan dari due-check
// pm_interval_hours generik di bawah, sama seperti fix di Dashboard app
// (fetchPMDueByHours()). Edge function ini terpisah dari index.html (deploy
// & runtime beda), jadi tag di-hardcode ulang di sini, bukan di-share.
const CAT_C71_PM_TAGS = ["GS-KB150A-CAT", "GS-KB150B-CAT"];

function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("id-ID", { day: "2-digit", month: "short", year: "numeric" });
}
function daysUntil(d: string | null): number {
  if (!d) return 0;
  return Math.floor((new Date(d).setHours(0,0,0,0) - new Date().setHours(0,0,0,0)) / 86400000);
}

async function sendTelegram(message: string): Promise<void> {
  await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: CHAT_ID,
      text: message,
      parse_mode: "HTML",
      disable_web_page_preview: true,
    }),
  });
}

serve(async (_req) => {
  try {
    const sb = createClient(SB_URL, SB_SERVICE_KEY);
    const now = new Date();
    const next30 = new Date(now.getTime() + 30 * 86400000).toISOString().slice(0, 10);
    const next14 = new Date(now.getTime() + 14 * 86400000).toISOString().slice(0, 10);

    // SKPI / sertifikat expired atau ≤ 30 hari
    const { data: skpi } = await sb.from("equipment")
      .select("tag_number, nama_equipment, skpi_end_date, tgl_expired_sertifikat, assigned_unit_id")
      .or(`skpi_end_date.lte.${next30},tgl_expired_sertifikat.lte.${next30}`)
      .order("skpi_end_date", { nullsFirst: false })
      .limit(30);

    // Maintenance due ≤ 14 hari
    const { data: maint } = await sb.from("equipment")
      .select("tag_number, nama_equipment, next_maintenance_date, assigned_unit_id")
      .not("next_maintenance_date", "is", null)
      .lte("next_maintenance_date", next14)
      .order("next_maintenance_date")
      .limit(30);

    // Equipment Down
    const { data: down } = await sb.from("equipment")
      .select("id, tag_number, nama_equipment, assigned_unit_id")
      .eq("status_operasi", "Down")
      .order("tag_number");

    // Lokasi kejadian downtime yang masih ongoing (end_at null) — buat dilampirkan di list Down
    const { data: ongoingLokasi } = await sb.from("downtime_events")
      .select("equipment_id, lokasi, unit_name")
      .is("end_at", null);
    const lokasiByEqId: Record<string, string> = {};
    (ongoingLokasi || []).forEach((d) => {
      if (d.equipment_id && (d.lokasi || d.unit_name)) lokasiByEqId[d.equipment_id] = d.lokasi || d.unit_name;
    });

    // Get parent unit names (mapping)
    const { data: units } = await sb.from("parent_units").select("id, name");
    const unitName: Record<number, string> = {};
    (units || []).forEach((u) => unitName[u.id] = u.name);

    // PM & Overhaul berbasis JAM (HM) — hanya unit ber-HM
    const { data: hmEq } = await sb.from("equipment")
      .select("tag_number, nama_equipment, assigned_unit_id, running_hours, last_pm_hours, pm_interval_hours, toh_interval_hours, goh_interval_hours, last_toh_hours, last_goh_hours, economic_life_hours")
      .gt("running_hours", 0);

    // FASE 3: kategorisasi lebih granular sesuai panel Maintenance Due Soon
    const pmHoursDue: any[] = [];      // PM: sisa 0-100 jam (flat threshold, samakan dgn dashboard)
    const overhaulDue: any[] = [];     // TOH/GOH: sisa 0-2000 jam (PERLU PLAN)
    const nearEOL: any[] = [];         // Umur ekonomis >= 80%
    (hmEq || []).forEach((e) => {
      const rh = Number(e.running_hours) || 0;
      const pmInt = Number(e.pm_interval_hours) || 0;
      if (pmInt > 0 && !CAT_C71_PM_TAGS.includes(e.tag_number)) {
        const rem = pmInt - (rh - (Number(e.last_pm_hours) || 0));
        // Threshold flat 100 jam — samakan dgn kartu "Mendekati Maintenance PM" di dashboard app
        // (disepakati 2026-08-04, lihat commit 9ac53c5), biar alert & tampilan app konsisten.
        // Termasuk yang SUDAH LEWAT (rem < 0) — dulu cuma 0..100, jadi unit overdue 0-50 jam
        // gak muncul di report mana pun (morning briefing baru ambil lewat >50 jam). 2026-11-20
        if (rem <= 100) pmHoursDue.push({ ...e, _rem: rem });
      }
      const tohInt = Number(e.toh_interval_hours) || 0;
      const gohInt = Number(e.goh_interval_hours) || 0;
      const baseTOH = Number(e.last_toh_hours ?? e.last_goh_hours ?? 0) || 0;
      const baseGOH = Number(e.last_goh_hours ?? 0) || 0;
      let bestRem = Infinity, kind = "";
      if (tohInt > 0) { const r = tohInt - (rh - baseTOH); if (r < bestRem) { bestRem = r; kind = "TOH"; } }
      if (gohInt > 0) { const r = gohInt - (rh - baseGOH); if (r < bestRem) { bestRem = r; kind = "GOH"; } }
      // PERLU PLAN: 0-1000j ke TOH, 0-2000j ke GOH (positive remaining)
      const threshold = kind === "GOH" ? 2000 : 1000;
      if (kind && bestRem >= 0 && bestRem <= threshold) overhaulDue.push({ ...e, _rem: bestRem, _kind: kind });
      // NEAR EOL: pakai economic_life_hours (kalau ada)
      const ecoLife = Number(e.economic_life_hours) || 0;
      if (ecoLife > 0) {
        const pct = (rh / ecoLife) * 100;
        if (pct >= 80) nearEOL.push({ ...e, _pct: pct, _sisaEco: ecoLife - rh });
      }
    });
    pmHoursDue.sort((a, b) => a._rem - b._rem);

    // PM berbasis WAKTU (pm_type=time, mis. Fire Pump Fixed, TT): last_pm_date + pm_max_interval_days
    // (atau pm_interval_months x 30). Sama dgn panel "PM Berbasis Waktu" di Dashboard app:
    // tampil kalau sisa <=10% batas hari (min 7) atau sudah lewat. Ditambah 2026-11-20 — sebelumnya
    // report ini cuma PM-jam, jadi semua unit basis waktu gak pernah muncul di Telegram.
    // Unit basis JAM/KM yang diisi "Maks Hari Sejak PM" ikut dicek dari sisi waktu juga (mana duluan:
    // HM/KM atau batas hari) — sama dgn fallback waktu di Dashboard (fetchPMDueByHours/ByKm).
    const { data: timeEq } = await sb.from("equipment")
      .select("tag_number, nama_equipment, assigned_unit_id, status_operasi, pm_type, last_pm_date, pm_max_interval_days, pm_interval_months")
      .or("pm_type.eq.time,and(pm_type.in.(hours,km),pm_max_interval_days.not.is.null)");
    const pmTimeDue: any[] = [];
    let pmTimeUndated = 0;
    (timeEq || []).forEach((e) => {
      if (["Down", "Scrap"].includes(e.status_operasi)) return;
      const isTime = e.pm_type === "time";
      const maxDays = Number(e.pm_max_interval_days) || (isTime ? (Number(e.pm_interval_months) || 0) * 30 : 0);
      if (!maxDays) return;
      if (!e.last_pm_date) { if (isTime) pmTimeUndated++; return; }
      const rem = maxDays + daysUntil(e.last_pm_date);  // daysUntil(tgl lampau) negatif = hari sejak PM
      if (rem <= Math.max(7, Math.round(maxDays * 0.1))) pmTimeDue.push({ ...e, _rem: rem, _basis: isTime ? "" : (e.pm_type === "km" ? " · basis KM" : " · basis HM") });
    });
    pmTimeDue.sort((a, b) => a._rem - b._rem);
    overhaulDue.sort((a, b) => a._rem - b._rem);
    nearEOL.sort((a, b) => b._pct - a._pct);

    // Build message
    const lines: string[] = [`🛢️ <b>eRAMHoist Daily Alert</b>\n<i>${now.toLocaleDateString("id-ID", { weekday: "long", day: "2-digit", month: "long", year: "numeric" })}</i>`];

    if (skpi && skpi.length > 0) {
      lines.push(`\n📜 <b>Sertifikat Hampir/Sudah Expired (${skpi.length})</b>`);
      skpi.slice(0, 10).forEach((e) => {
        const exp = e.skpi_end_date || e.tgl_expired_sertifikat;
        const d = daysUntil(exp);
        const status = d < 0 ? `⚠️ EXPIRED ${-d}h lalu` : d <= 7 ? `🔴 ${d}h lagi` : `🟡 ${d}h lagi`;
        lines.push(`• <b>${e.tag_number}</b> — ${fmtDate(exp)} ${status}`);
      });
      if (skpi.length > 10) lines.push(`<i>...dan ${skpi.length - 10} lainnya</i>`);
    }

    if (maint && maint.length > 0) {
      lines.push(`\n🛠️ <b>Maintenance Jatuh Tempo (${maint.length})</b>`);
      maint.slice(0, 10).forEach((e) => {
        const d = daysUntil(e.next_maintenance_date);
        const status = d < 0 ? `⚠️ TELAT ${-d}h` : d <= 3 ? `🔴 ${d}h lagi` : `🟡 ${d}h lagi`;
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${fmtDate(e.next_maintenance_date)} ${status}`);
      });
      if (maint.length > 10) lines.push(`<i>...dan ${maint.length - 10} lainnya</i>`);
    }

    if (down && down.length > 0) {
      lines.push(`\n🛑 <b>Equipment Down (${down.length})</b>`);
      down.slice(0, 10).forEach((e) => {
        const lokasi = lokasiByEqId[e.id] || unitName[e.assigned_unit_id] || "—";
        lines.push(`• <b>${e.tag_number}</b> @ ${lokasi} — ${e.nama_equipment}`);
      });
      if (down.length > 10) lines.push(`<i>...dan ${down.length - 10} lainnya</i>`);
    }

    if (pmHoursDue.length > 0) {
      lines.push(`\n🟡 <b>PERLU PLAN — PM Berbasis Jam (${pmHoursDue.length})</b>`);
      pmHoursDue.slice(0, 15).forEach((e) => {
        const st = e._rem < 0 ? `⛔ LEWAT ${Math.round(-e._rem)} jam` : `sisa ${Math.round(e._rem)} jam`;
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${st}`);
      });
      if (pmHoursDue.length > 15) lines.push(`<i>...dan ${pmHoursDue.length - 15} lainnya (lihat Dashboard)</i>`);
    }

    if (pmTimeDue.length > 0) {
      lines.push(`\n⏰ <b>PM Berbasis Waktu (${pmTimeDue.length})</b>`);
      pmTimeDue.slice(0, 15).forEach((e) => {
        const st = e._rem < 0 ? `⛔ LEWAT ${-e._rem} hari` : `sisa ${e._rem} hari`;
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${st} (PM terakhir ${fmtDate(e.last_pm_date)}${e._basis})`);
      });
      if (pmTimeDue.length > 15) lines.push(`<i>...dan ${pmTimeDue.length - 15} lainnya (lihat Dashboard)</i>`);
    }
    if (pmTimeUndated > 0) lines.push(`<i>📅 ${pmTimeUndated} unit basis waktu belum ada tanggal PM terakhir.</i>`);

    if (overhaulDue.length > 0) {
      lines.push(`\n🟡 <b>PERLU PLAN — Overhaul (${overhaulDue.length})</b>`);
      overhaulDue.slice(0, 10).forEach((e) => {
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${e._kind} sisa ${Math.round(e._rem)} jam`);
      });
      if (overhaulDue.length > 10) lines.push(`<i>...dan ${overhaulDue.length - 10} lainnya</i>`);
    }

    if (nearEOL.length > 0) {
      lines.push(`\n⚫ <b>NEAR ECONOMIC LIFE — Review Replacement (${nearEOL.length})</b>`);
      nearEOL.slice(0, 5).forEach((e) => {
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — umur ${e._pct.toFixed(0)}% (sisa ${Math.round(e._sisaEco)}j)`);
      });
      if (nearEOL.length > 5) lines.push(`<i>...dan ${nearEOL.length - 5} lainnya</i>`);
      lines.push(`<i>💡 Masuk CAPEX planning kalau >85% umur.</i>`);
    }

    if ((skpi?.length || 0) + (maint?.length || 0) + (down?.length || 0) + pmHoursDue.length + pmTimeDue.length + overhaulDue.length + nearEOL.length === 0) {
      lines.push(`\n✅ <b>Semua aman.</b> Tidak ada SKPI expired, maintenance due, overhaul, atau equipment Down hari ini.`);
    }

    lines.push(`\n🔗 <a href="${APP_URL}">Buka eRAMHoist</a>`);

    await sendTelegram(lines.join("\n"));

    // Log ke alert_log
    await sb.from("alert_log").insert({
      alert_type: "daily-check",
      message: `Daily alert: ${skpi?.length || 0} SKPI, ${maint?.length || 0} maintenance, ${down?.length || 0} down, ${pmHoursDue.length} PM-jam, ${pmTimeDue.length} PM-waktu, ${overhaulDue.length} overhaul, ${nearEOL.length} near-EOL`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({
      ok: true,
      counts: { skpi: skpi?.length || 0, maintenance: maint?.length || 0, down: down?.length || 0, pmHours: pmHoursDue.length, pmTime: pmTimeDue.length, overhaul: overhaulDue.length, nearEOL: nearEOL.length }
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});