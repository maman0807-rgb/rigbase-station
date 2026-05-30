// Edge Function: morning-briefing-alert
// FASE 2 — Briefing pagi 06:30 WIB
// Hanya kirim CRITICAL ONLY: OVERDUE maintenance (sisa<0) + Down equipment aktif.
// Format pendek (scannable, baca sambil ngopi).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID")!;
const APP_URL = Deno.env.get("APP_URL") || "https://eramhoist.vercel.app";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEYS")!;

const corsHeaders = { "Access-Control-Allow-Origin": "*" };

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

    // Get parent unit names
    const { data: units } = await sb.from("parent_units").select("id, name");
    const unitName: Record<number, string> = {};
    (units || []).forEach((u) => unitName[u.id] = u.name);

    // Fetch active snoozes (kalau ada equipment yg di-snooze, skip di alert)
    const { data: snoozes } = await sb.from("alert_snooze")
      .select("equipment_id, alert_kind")
      .gt("snooze_until", new Date().toISOString());
    const snoozeKey = (id: string | null, kind: string) => `${id || "*"}::${kind}`;
    const snoozedSet = new Set<string>();
    (snoozes || []).forEach((s) => {
      snoozedSet.add(snoozeKey(s.equipment_id, s.alert_kind));
      snoozedSet.add(snoozeKey(s.equipment_id, "all"));
    });
    const isSnoozed = (eqId: string, kind: string) =>
      snoozedSet.has(snoozeKey(eqId, kind)) || snoozedSet.has(snoozeKey(eqId, "all"));

    // Fetch equipment dgn HM > 0 utk hitung overdue
    const { data: hmEq } = await sb.from("equipment")
      .select("id, tag_number, nama_equipment, assigned_unit_id, running_hours, last_pm_hours, pm_interval_hours, toh_interval_hours, goh_interval_hours, last_toh_hours, last_goh_hours")
      .gt("running_hours", 0);

    // OVERDUE = sisa < THRESHOLD (sudah lewat threshold significantly, bukan baru lewat 1 jam)
    // Threshold filter biar tidak spam: OVERDUE diperhitungkan kalau lewat >50 jam (untuk PM) atau >100 jam (TOH/GOH)
    const overdue: any[] = [];
    (hmEq || []).forEach((e) => {
      const rh = Number(e.running_hours) || 0;
      // PM overdue (threshold: lewat >50 jam)
      const pmInt = Number(e.pm_interval_hours) || 0;
      if (pmInt > 0 && !isSnoozed(e.id, "PM")) {
        const rem = pmInt - (rh - (Number(e.last_pm_hours) || 0));
        if (rem < -50) overdue.push({ ...e, _kind: "PM", _rem: rem });
      }
      // TOH overdue (threshold: lewat >100 jam)
      const tohInt = Number(e.toh_interval_hours) || 0;
      if (tohInt > 0 && !isSnoozed(e.id, "TOH")) {
        const base = Number(e.last_toh_hours ?? e.last_goh_hours ?? 0) || 0;
        const rem = tohInt - (rh - base);
        if (rem < -100) overdue.push({ ...e, _kind: "TOH", _rem: rem });
      }
      // GOH overdue (threshold: lewat >100 jam)
      const gohInt = Number(e.goh_interval_hours) || 0;
      if (gohInt > 0 && !isSnoozed(e.id, "GOH")) {
        const base = Number(e.last_goh_hours) || 0;
        const rem = gohInt - (rh - base);
        if (rem < -100) overdue.push({ ...e, _kind: "GOH", _rem: rem });
      }
    });
    overdue.sort((a, b) => a._rem - b._rem); // urutan: paling parah dulu

    // Equipment Down aktif
    const { data: down } = await sb.from("equipment")
      .select("tag_number, nama_equipment, assigned_unit_id")
      .eq("status_operasi", "Down")
      .order("tag_number");

    // Downtime events ongoing (end_at = null)
    const { data: ongoingDt } = await sb.from("downtime_events")
      .select("equipment_tag, equipment_name, unit_name, category, start_at, notes")
      .is("end_at", null)
      .in("category", ["breakdown", "troubleshoot"])
      .order("start_at", { ascending: true });

    // Skip alert kalau tidak ada apa-apa
    const total = overdue.length + (down?.length || 0) + (ongoingDt?.length || 0);
    if (total === 0) {
      return new Response(JSON.stringify({ ok: true, skipped: "no critical items" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // Build short message
    const lines: string[] = [];
    lines.push(`☀️ <b>SELAMAT PAGI</b> · ${now.toLocaleDateString("id-ID", { weekday: "short", day: "2-digit", month: "long" })}`);
    lines.push(`<i>Briefing critical · 06:30 WIB</i>`);

    if (overdue.length > 0) {
      lines.push(`\n🔴 <b>OVERDUE MAINTENANCE (${overdue.length})</b>`);
      overdue.slice(0, 10).forEach((e) => {
        const unit = unitName[e.assigned_unit_id] || "—";
        lines.push(`• <b>${e.tag_number}</b> @ ${unit} — ${e._kind} lewat ${Math.round(-e._rem)}j`);
      });
      if (overdue.length > 10) lines.push(`<i>...dan ${overdue.length - 10} lainnya</i>`);
    }

    if (ongoingDt && ongoingDt.length > 0) {
      lines.push(`\n💥 <b>DOWNTIME AKTIF (${ongoingDt.length})</b>`);
      ongoingDt.slice(0, 5).forEach((d) => {
        const hSince = Math.round((Date.now() - new Date(d.start_at).getTime()) / 3600000);
        const tipe = d.category === "breakdown" ? "BD" : "TS";
        lines.push(`• <b>${d.equipment_tag}</b> [${tipe}] sejak ${hSince}j lalu — ${(d.notes || "-").slice(0, 50)}`);
      });
      if (ongoingDt.length > 5) lines.push(`<i>...dan ${ongoingDt.length - 5} lainnya</i>`);
    }

    if (down && down.length > 0) {
      lines.push(`\n🛑 <b>STATUS DOWN (${down.length})</b>`);
      down.slice(0, 5).forEach((e) => {
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"}`);
      });
      if (down.length > 5) lines.push(`<i>...dan ${down.length - 5} lainnya</i>`);
    }

    lines.push(`\n→ <a href="${APP_URL}/#kelayakan">Buka Maintenance Due Soon panel</a>`);

    await sendTelegram(lines.join("\n"));

    // Log ke alert_log
    await sb.from("alert_log").insert({
      alert_type: "morning-briefing",
      message: `Briefing pagi: ${overdue.length} overdue, ${ongoingDt?.length || 0} ongoing downtime, ${down?.length || 0} status Down`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({
      ok: true,
      counts: { overdue: overdue.length, ongoingDt: ongoingDt?.length || 0, down: down?.length || 0 }
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
