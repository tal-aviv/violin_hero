import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const action = String(body.action ?? "");
  if (!["save", "load"].includes(action)) {
    return jsonResponse({ error: "Unknown action" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) {
    return jsonResponse(
      { error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
      500,
    );
  }
  const supabase = createClient(supabaseUrl, serviceRole);

  const username = String(body.username ?? "").trim().toLowerCase();
  if (!username) return jsonResponse({ error: "Missing username" }, 400);

  // --- load ---
  if (action === "load") {
    const { data, error } = await supabase
      .from("violin_user_progress")
      .select("*")
      .eq("username", username)
      .maybeSingle();

    if (error) return jsonResponse({ error: error.message }, 500);
    if (!data) return jsonResponse({ found: false });

    return jsonResponse({
      found: true,
      progress: {
        stars: data.stars,
        streak_days: data.streak_days,
        last_active_day_epoch: data.last_active_day_epoch,
        week_id: data.week_id,
        active_days_this_week: data.active_days_this_week,
        streak_shield_used_week_id: data.streak_shield_used_week_id,
        weekly_bonus_awarded_week_id: data.weekly_bonus_awarded_week_id,
        string_section_stars: data.string_section_stars,
        song_section_stars: data.song_section_stars,
      },
    });
  }

  // --- save ---
  if (action === "save") {
    const progress = body.progress as Record<string, unknown> | undefined;
    if (!progress) return jsonResponse({ error: "Missing progress" }, 400);

    const row = {
      username,
      stars: Number(progress.stars ?? 0),
      streak_days: Number(progress.streak_days ?? 0),
      last_active_day_epoch: progress.last_active_day_epoch != null
        ? Number(progress.last_active_day_epoch)
        : null,
      week_id: Number(progress.week_id ?? 0),
      active_days_this_week: Number(progress.active_days_this_week ?? 0),
      streak_shield_used_week_id: Number(
        progress.streak_shield_used_week_id ?? -1,
      ),
      weekly_bonus_awarded_week_id: Number(
        progress.weekly_bonus_awarded_week_id ?? -1,
      ),
      string_section_stars: progress.string_section_stars ?? {},
      song_section_stars: progress.song_section_stars ?? {},
      updated_at: new Date().toISOString(),
    };

    const { error } = await supabase
      .from("violin_user_progress")
      .upsert(row, { onConflict: "username" });

    if (error) return jsonResponse({ error: error.message }, 500);
    return jsonResponse({ ok: true });
  }

  return jsonResponse({ error: "Unknown action" }, 400);
});
