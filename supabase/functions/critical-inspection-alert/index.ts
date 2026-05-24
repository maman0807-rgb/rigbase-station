// Edge Function: critical-inspection-alert
// Dipanggil oleh DB trigger (pg_net) saat ada INSERT di inspection_findings.
// Kalau category = 'Critical', kirim alert real-time ke Telegram.
// Menangkap SEMUA jalur insert (form manual, import PDF/Excel, SQL langsung).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID")!;
const APP_URL = Deno.env.get("APP_URL") || "https://eramhoist.vercel.app";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SECRET_KEYS")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

// Escape karakter yang bisa merusak parse_mode HTML Telegram
function esc(s: unknown): string {
  return String(s ?? "—").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    // Payload dari DB webhook/trigger: { type, table, record } — atau record langsung
    const rec = body.record || body;

    // Hanya proses temuan Critical
    if (!rec || rec.category !== "Critical") {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const sb = createClient(SB_URL, SB_SERVICE_KEY);

    // Resolve siklus + rig dari inspection_id
    let inspectionCode = "—";
    let rigName = "—";
    if (rec.inspection_id) {
      const { data: insp } = await sb.from("inspections")
        .select("inspection_code, parent_units(name)")
        .eq("id", rec.inspection_id)
        .single();
      if (insp) {
        inspectionCode = insp.inspection_code || "—";
        // deno-lint-ignore no-explicit-any
        rigName = (insp as any).parent_units?.name || "—";
      }
    }

    // Resolve nama pembuat (opsional)
    let byName = "";
    if (rec.created_by) {
      const { data: prof } = await sb.from("profiles")
        .select("full_name, email")
        .eq("id", rec.created_by)
        .single();
      if (prof) byName = prof.full_name || prof.email || "";
    }

    const msg =
      `🚨 <b>CRITICAL FINDING</b>\n` +
      `Siklus: <b>${esc(inspectionCode)}</b>\n` +
      `Rig: ${esc(rigName)}\n` +
      `Equipment: <b>${esc(rec.equipment_name_snapshot)}</b>${rec.bagian ? " (" + esc(rec.bagian) + ")" : ""}\n` +
      `📝 ${esc(rec.finding)}\n` +
      (rec.recommendation ? `💡 ${esc(rec.recommendation)}\n` : "") +
      (byName ? `👤 ${esc(byName)}\n` : "") +
      `\n🔗 <a href="${APP_URL}">Buka Rigbase Station</a>`;

    await sendTelegram(msg);

    // Catat ke alert_log
    await sb.from("alert_log").insert({
      alert_type: "critical-finding",
      equipment_id: rec.equipment_id || null,
      message: `Critical: ${rec.equipment_name_snapshot} @ ${rigName} (${inspectionCode})`,
      sent_to: CHAT_ID,
      status: "sent",
    });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
