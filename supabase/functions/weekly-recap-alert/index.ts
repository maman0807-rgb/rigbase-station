// Edge Function: weekly-recap-alert
// FASE 4 — Weekly Strategic Recap setiap Senin 07:00 WIB
// Executive summary: recap minggu lalu + plan minggu ini + NEAR EOL replacement watchlist
// Format: aggregate level, bukan per-equipment detail (itu sudah di daily)

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
    const weekAgo = new Date(now.getTime() - 7 * 86400000);
    const monthAgo = new Date(now.getTime() - 30 * 86400000);

    // Get parent unit names
    const { data: units } = await sb.from("parent_units").select("id, name");
    const unitName: Record<number, string> = {};
    (units || []).forEach((u) => unitName[u.id] = u.name);

    // 1. Maintenance log minggu lalu (PM/CM done)
    const { data: maintLog } = await sb.from("daily_logs")
      .select("log_date, maintenance_type, equipment_name, total")
      .gte("log_date", weekAgo.toISOString().slice(0, 10))
      .lte("log_date", now.toISOString().slice(0, 10))
      .not("maintenance_type", "is", null);

    // 2. Downtime events minggu lalu (closed)
    const { data: dtClosed } = await sb.from("downtime_events")
      .select("equipment_tag, category, start_at, end_at, duration_hours")
      .gte("start_at", weekAgo.toISOString())
      .not("end_at", "is", null);

    // 3. Downtime events sekarang yg masih ongoing
    const { data: dtOngoing } = await sb.from("downtime_events")
      .select("equipment_tag, category, start_at, unit_name")
      .is("end_at", null)
      .in("category", ["breakdown", "troubleshoot"]);

    // 4. Gejala minggu lalu (early warning trend)
    const { data: gejala } = await sb.from("downtime_events")
      .select("equipment_tag, start_at, end_at")
      .eq("category", "gejala")
      .gte("start_at", weekAgo.toISOString());

    // 5. Mutasi minggu lalu (perpindahan equipment)
    const { data: mutasi } = await sb.from("mutation_log")
      .select("equipment_id, from_unit_id, to_unit_id, reason, mutation_date")
      .gte("created_at", weekAgo.toISOString());

    // 6. NEAR EOL units (replacement watchlist)
    const { data: hmEq } = await sb.from("equipment")
      .select("tag_number, nama_equipment, assigned_unit_id, running_hours, economic_life_hours")
      .gt("running_hours", 0)
      .not("economic_life_hours", "is", null);
    const nearEOL: any[] = [];
    (hmEq || []).forEach((e) => {
      const rh = Number(e.running_hours) || 0;
      const eco = Number(e.economic_life_hours) || 0;
      if (eco > 0) {
        const pct = (rh / eco) * 100;
        if (pct >= 80) nearEOL.push({ ...e, _pct: pct, _sisaEco: eco - rh });
      }
    });
    nearEOL.sort((a, b) => b._pct - a._pct);

    // 7. PERLU PLAN minggu ini (sisa < threshold)
    const { data: hmEqPlan } = await sb.from("equipment")
      .select("tag_number, assigned_unit_id, running_hours, last_pm_hours, pm_interval_hours, toh_interval_hours, goh_interval_hours, last_toh_hours, last_goh_hours");
    const planThisWeek: any[] = [];
    (hmEqPlan || []).forEach((e) => {
      const rh = Number(e.running_hours) || 0;
      if (rh <= 0) return;
      const pmInt = Number(e.pm_interval_hours) || 0;
      if (pmInt > 0) {
        const rem = pmInt - (rh - (Number(e.last_pm_hours) || 0));
        if (rem >= 0 && rem <= 200) planThisWeek.push({ tag: e.tag_number, unit: e.assigned_unit_id, kind: "PM", rem });
      }
      const tohInt = Number(e.toh_interval_hours) || 0;
      if (tohInt > 0) {
        const base = Number(e.last_toh_hours ?? e.last_goh_hours ?? 0) || 0;
        const rem = tohInt - (rh - base);
        if (rem >= 0 && rem <= 500) planThisWeek.push({ tag: e.tag_number, unit: e.assigned_unit_id, kind: "TOH", rem });
      }
      const gohInt = Number(e.goh_interval_hours) || 0;
      if (gohInt > 0) {
        const base = Number(e.last_goh_hours) || 0;
        const rem = gohInt - (rh - base);
        if (rem >= 0 && rem <= 1000) planThisWeek.push({ tag: e.tag_number, unit: e.assigned_unit_id, kind: "GOH", rem });
      }
    });
    planThisWeek.sort((a, b) => a.rem - b.rem);

    // Aggregate stats
    const pmDoneCnt = (maintLog || []).filter((l) => l.maintenance_type === "PM").length;
    const cmDoneCnt = (maintLog || []).filter((l) => l.maintenance_type === "CM").length;
    const totalCost = (maintLog || []).reduce((sum, l) => sum + (Number(l.total) || 0), 0);
    const dtClosedCnt = dtClosed?.length || 0;
    const dtTotalH = (dtClosed || []).reduce((s, d) => s + (Number(d.duration_hours) || 0), 0);
    const fmtH = (h: number) => h < 24 ? `${h.toFixed(1)}j` : `${(h / 24).toFixed(1)} hari`;
    const fmtRp = (n: number) => "Rp " + n.toLocaleString("id-ID");

    // Build message
    const lines: string[] = [];
    lines.push(`📊 <b>RECAP MINGGUAN · ${now.toLocaleDateString("id-ID", { day: "2-digit", month: "long", year: "numeric" })}</b>`);
    lines.push(`<i>Senin 07:00 WIB · Executive Summary</i>`);

    lines.push(`\n✅ <b>Done Minggu Lalu</b>`);
    lines.push(`• <b>${pmDoneCnt}</b> Preventive Maintenance`);
    lines.push(`• <b>${cmDoneCnt}</b> Corrective / Repair`);
    if (totalCost > 0) lines.push(`• Total biaya: <b>${fmtRp(totalCost)}</b>`);
    lines.push(`• <b>${dtClosedCnt}</b> downtime selesai (total ${fmtH(dtTotalH)})`);
    if (mutasi && mutasi.length > 0) lines.push(`• <b>${mutasi.length}</b> mutasi equipment`);
    if (gejala && gejala.length > 0) lines.push(`• <b>${gejala.length}</b> gejala tercatat (early warning)`);

    if (dtOngoing && dtOngoing.length > 0) {
      lines.push(`\n💥 <b>Downtime Aktif Sekarang (${dtOngoing.length})</b>`);
      dtOngoing.slice(0, 5).forEach((d) => {
        const days = Math.round((Date.now() - new Date(d.start_at).getTime()) / 86400000);
        const cat = d.category === "breakdown" ? "BD" : "TS";
        lines.push(`• <b>${d.equipment_tag}</b> @ ${d.unit_name || "—"} [${cat}] — ${days}h jalan`);
      });
      if (dtOngoing.length > 5) lines.push(`<i>...dan ${dtOngoing.length - 5} lainnya</i>`);
    }

    if (planThisWeek.length > 0) {
      lines.push(`\n⏳ <b>Plan Minggu Ini — Maintenance Soon (${planThisWeek.length})</b>`);
      planThisWeek.slice(0, 10).forEach((p) => {
        lines.push(`• <b>${p.tag}</b> @ ${unitName[p.unit] || "—"} — ${p.kind} dlm ${Math.round(p.rem)}j`);
      });
      if (planThisWeek.length > 10) lines.push(`<i>...dan ${planThisWeek.length - 10} lainnya</i>`);
    }

    if (nearEOL.length > 0) {
      lines.push(`\n⚫ <b>Near Economic Life — CAPEX Watchlist (${nearEOL.length})</b>`);
      nearEOL.slice(0, 5).forEach((e) => {
        lines.push(`• <b>${e.tag_number}</b> @ ${unitName[e.assigned_unit_id] || "—"} — ${e._pct.toFixed(0)}% umur (sisa ${Math.round(e._sisaEco)}j)`);
      });
      if (nearEOL.length > 5) lines.push(`<i>...dan ${nearEOL.length - 5} lainnya</i>`);
      lines.push(`<i>💡 Saatnya review: rebuild lagi vs replace dgn unit baru?</i>`);
    }

    lines.push(`\n📈 <b>Selamat bekerja minggu ini!</b>`);
    lines.push(`→ <a href="${APP_URL}">eRAMHoist Dashboard</a>`);

    await sendTelegram(lines.join("\n"));

    await sb.from("alert_log").insert({
      alert_type: "weekly-recap",
      message: `Weekly recap: ${pmDoneCnt} PM, ${cmDoneCnt} CM, ${dtClosedCnt} dt-closed, ${planThisWeek.length} plan, ${nearEOL.length} near-EOL`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({
      ok: true,
      counts: { pmDone: pmDoneCnt, cmDone: cmDoneCnt, dtClosed: dtClosedCnt, dtOngoing: dtOngoing?.length || 0, planThisWeek: planThisWeek.length, nearEOL: nearEOL.length, totalCost }
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
