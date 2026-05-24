// Edge Function: daily-alert-check
// Cek SKPI expired + maintenance due + status Down → kirim summary ke Telegram
// Dijadwal tiap pagi 08:00 WIB via pg_cron

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID")!;
const APP_URL = Deno.env.get("APP_URL") || "https://maman0807-rgb.github.io/rigbase-station";
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

    // Build message
    const lines: string[] = [`🛢️ <b>Rigbase Daily Alert</b>\n<i>${now.toLocaleDateString("id-ID", { weekday: "long", day: "2-digit", month: "long", year: "numeric" })}</i>`];

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

    if ((skpi?.length || 0) + (maint?.length || 0) + (down?.length || 0) === 0) {
      lines.push(`\n✅ <b>Semua aman.</b> Tidak ada SKPI expired, maintenance due, atau equipment Down hari ini.`);
    }

    lines.push(`\n🔗 <a href="${APP_URL}">Buka Rigbase Station</a>`);

    await sendTelegram(lines.join("\n"));

    // Log ke alert_log
    await sb.from("alert_log").insert({
      alert_type: "daily-check",
      message: `Daily alert: ${skpi?.length || 0} SKPI, ${maint?.length || 0} maintenance, ${down?.length || 0} down`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({
      ok: true,
      counts: { skpi: skpi?.length || 0, maintenance: maint?.length || 0, down: down?.length || 0 }
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});