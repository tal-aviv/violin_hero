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

async function sha256(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
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
  if (!["signup", "login", "check_username"].includes(action)) {
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

  // --- check_username ---
  if (action === "check_username") {
    const username = String(body.username ?? "").trim().toLowerCase();
    if (!username) return jsonResponse({ error: "Missing username" }, 400);

    const { data } = await supabase
      .from("violin_users")
      .select("username")
      .eq("username", username)
      .maybeSingle();

    return jsonResponse({ available: data === null });
  }

  // --- signup ---
  if (action === "signup") {
    const username = String(body.username ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const avatarId = String(body.avatar_id ?? "avatar_frog");

    if (!username || username.length < 2) {
      return jsonResponse({ error: "Username must be at least 2 characters" }, 400);
    }
    if (!password || password.length < 3) {
      return jsonResponse({ error: "Password must be at least 3 characters" }, 400);
    }

    const { data: existing } = await supabase
      .from("violin_users")
      .select("username")
      .eq("username", username)
      .maybeSingle();

    if (existing) {
      return jsonResponse({ error: "Username already taken" }, 409);
    }

    const passwordHash = await sha256(password);

    const { error } = await supabase.from("violin_users").insert({
      username,
      password_hash: passwordHash,
      avatar_id: avatarId,
    });

    if (error) {
      if (error.code === "23505") {
        return jsonResponse({ error: "Username already taken" }, 409);
      }
      return jsonResponse({ error: error.message }, 500);
    }

    return jsonResponse({ ok: true, username, avatar_id: avatarId });
  }

  // --- login ---
  if (action === "login") {
    const username = String(body.username ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");

    if (!username || !password) {
      return jsonResponse({ error: "Missing username or password" }, 400);
    }

    const { data: user, error } = await supabase
      .from("violin_users")
      .select("username, password_hash, avatar_id")
      .eq("username", username)
      .maybeSingle();

    if (error) return jsonResponse({ error: error.message }, 500);

    if (!user) {
      return jsonResponse({ error: "Invalid username or password" }, 401);
    }

    const passwordHash = await sha256(password);
    if (user.password_hash !== passwordHash) {
      return jsonResponse({ error: "Invalid username or password" }, 401);
    }

    return jsonResponse({
      ok: true,
      username: user.username,
      avatar_id: user.avatar_id,
    });
  }

  return jsonResponse({ error: "Unknown action" }, 400);
});
