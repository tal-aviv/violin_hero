// Supabase Edge Function: violin-events-ingest
// Receives payload:
// { "events": [ { ...event fields... } ] }
// and upserts into public.violin_user_events by id.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type IncomingEvent = {
  id: string;
  timestampMs: number;
  username: string;
  sessionId: string;
  type: string;
  outcome?: boolean | null;
  starsDelta?: number;
  noteId?: string | null;
  stringIndex?: number | null;
  songId?: string | null;
  byHeartMode?: boolean | null;
  hintUsed?: boolean | null;
  accuracy?: number | null;
  metadata?: Record<string, unknown> | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Optional hardening: if INGEST_API_KEY is set, require x-api-key match.
  const requiredApiKey = Deno.env.get("INGEST_API_KEY") ?? "";
  if (requiredApiKey.length > 0) {
    const provided = req.headers.get("x-api-key") ?? "";
    if (provided !== requiredApiKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  let body: { events?: IncomingEvent[] } = {};
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const events = Array.isArray(body.events) ? body.events : [];
  if (events.length === 0) {
    return new Response(JSON.stringify({ inserted: 0, skipped: 0 }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRole) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRole);

  const rows = events
    .filter((e) => e?.id && e?.username && e?.sessionId && e?.type)
    .map((e) => ({
      id: e.id,
      timestamp_ms: Number(e.timestampMs) || Date.now(),
      username: String(e.username),
      session_id: String(e.sessionId),
      type: String(e.type),
      outcome: e.outcome ?? null,
      stars_delta: Number(e.starsDelta ?? 0),
      note_id: e.noteId ?? null,
      string_index: e.stringIndex ?? null,
      song_id: e.songId ?? null,
      by_heart_mode: e.byHeartMode ?? null,
      hint_used: e.hintUsed ?? null,
      accuracy: e.accuracy ?? null,
      metadata: e.metadata ?? {},
    }));

  if (rows.length === 0) {
    return new Response(JSON.stringify({ inserted: 0, skipped: events.length }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error } = await supabase
    .from("violin_user_events")
    .upsert(rows, { onConflict: "id", ignoreDuplicates: true });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      inserted: rows.length,
      skipped: events.length - rows.length,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});

