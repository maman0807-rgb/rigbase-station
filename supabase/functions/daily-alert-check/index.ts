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
      .select("tag_number, nama_equipment, assigned_unit_id")
      .eq("status_operasi", "Down")
      .order("tag_number");

    // Get parent unit names (mapping)
    const { data: units } = await sb.from("parent_units").select("id, name");
    const unitName: Record<number, string> = {};
    (units || []).forEach((u) => unitName[u.id] = u.name);

    // PM & Overhaul berbasis JAM (HM) — hanya unit ber-HM
    const { data: hmEq } = await sb.from("equipment")
      .select("tag_number, nama_equipment, assigned_unit_id, running_hours, last_pm_hours, pm_interval_hours, toh_interval_hours, goh_interval_hours, last_toh_hours, last_goh_hours")
      .gt("running_hours", 0);

    const pmHoursDue: any[] = [];
    const overhaulDue: any[] = [];
    (hmEq || []).forEach((e) => {
      const rh = Number(e.running_hours) || 0;
      const pmInt = Number(e.pm_interval_hours) || 0;
      if (pmInt > 0) {
        const rem = pmInt - (rh - (Number(e.last_pm_hours) || 0));
        if (rem <= 50) pmHoursDue.push({ ...e, _rem: rem });
      }
      const tohInt = Number(e.toh_interval_hours) || 0;
      const gohInt = Number(e.goh_interval_hours) || 0;
      const baseTOH = Number(e.last_toh_hours ?? e.last_goh_hours ?? 0) || 0;
      const baseGOH = Number(e.last_goh_hours ?? 0) || 0;
      let bestRem = Infinity, kind = "";
      if (tohInt > 0) { const r = tohInt - (rh - baseTOH); if (r < bestRem) { bestRem = r; kind = "TOH"; } }
      if (gohInt > 0) { const r = gohInt - (rh - baseGOH); if (r < bestRem) { bestRem = r; kind = "GOH"; } }
      if (kind && bestRem <= 500) overhaulDue.push({ ...e, _rem: bestRem, _kind: kind });
    });
    pmHoursDue.sort((a, b) => a._rem - b._rem);
    overhaulDue.sort((a, b) => a._rem - b._rem);

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
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${e.nama_equipment}`);
      });
      if (down.length > 10) lines.push(`<i>...dan ${down.length - 10} lainnya</i>`);
    }

    if (pmHoursDue.length > 0) {
      lines.push(`\n⏱️ <b>PM Berbasis Jam (${pmHoursDue.length})</b>`);
      pmHoursDue.slice(0, 10).forEach((e) => {
        const t = e._rem < 0 ? `⚠️ lewat ${Math.round(-e._rem)} jam` : `🟡 sisa ${Math.round(e._rem)} jam`;
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${t}`);
      });
      if (pmHoursDue.length > 10) lines.push(`<i>...dan ${pmHoursDue.length - 10} lainnya</i>`);
    }

    if (overhaulDue.length > 0) {
      lines.push(`\n🔧 <b>Overhaul Jatuh Tempo — jam (${overhaulDue.length})</b>`);
      overhaulDue.slice(0, 10).forEach((e) => {
        const t = e._rem < 0 ? `⚠️ ${e._kind} lewat ${Math.round(-e._rem)} jam` : `🟡 ${e._kind} sisa ${Math.round(e._rem)} jam`;
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${t}`);
      });
      if (overhaulDue.length > 10) lines.push(`<i>...dan ${overhaulDue.length - 10} lainnya</i>`);
    }

    if ((skpi?.length || 0) + (maint?.length || 0) + (down?.length || 0) + pmHoursDue.length + overhaulDue.length === 0) {
      lines.push(`\n✅ <b>Semua aman.</b> Tidak ada SKPI expired, maintenance due (tanggal/jam), overhaul, atau equipment Down hari ini.`);
    }

    lines.push(`\n🔗 <a href="${APP_URL}">Buka eRAMHoist</a>`);

    await sendTelegram(lines.join("\n"));

    // Log ke alert_log
    await sb.from("alert_log").insert({
      alert_type: "daily-check",
      message: `Daily alert: ${skpi?.length || 0} SKPI, ${maint?.length || 0} maintenance, ${down?.length || 0} down, ${pmHoursDue.length} PM-jam, ${overhaulDue.length} overhaul`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({
      ok: true,
      counts: { skpi: skpi?.length || 0, maintenance: maint?.length || 0, down: down?.length || 0, pmHours: pmHoursDue.length, overhaul: overhaulDue.length }
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});