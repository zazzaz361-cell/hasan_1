// Read-only Loyverse connectivity check: GET /merchant/ only.
// Required secret: LOYVERSE_ACCESS_TOKEN (never logged or returned).
import { createClient } from "jsr:@supabase/supabase-js@2";

const LOYVERSE_BASE_URL = "https://api.loyverse.com/v1.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ ok: false, code: "method_not_allowed" }, 405);

  // Only active DARI staff may trigger the test.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );
  const { data: isStaff, error: staffError } = await supabase.rpc("is_staff");
  if (staffError || isStaff !== true) {
    return reply({ ok: false, code: "forbidden" }, 403);
  }

  const token = Deno.env.get("LOYVERSE_ACCESS_TOKEN");
  if (!token) return reply({ ok: false, code: "token_not_configured" });

  let requestedBase = "";
  try {
    const body = await req.json();
    if (typeof body?.baseUrl === "string") requestedBase = body.baseUrl.trim();
  } catch (_) { /* empty body is fine */ }

  // The token is only ever sent to the official Loyverse API host.
  const base = requestedBase.replace(/\/+$/, "");
  if (base !== "" && base.toLowerCase() !== LOYVERSE_BASE_URL) {
    return reply({ ok: false, code: "invalid_base_url" });
  }

  try {
    const response = await fetch(`${LOYVERSE_BASE_URL}/merchant/`, {
      method: "GET",
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      signal: AbortSignal.timeout(10000),
    });
    if (response.status === 401 || response.status === 403) {
      await response.body?.cancel();
      return reply({ ok: false, code: "unauthorized" });
    }
    if (response.status === 429) {
      await response.body?.cancel();
      return reply({ ok: false, code: "rate_limited" });
    }
    if (response.status !== 200) {
      await response.body?.cancel();
      return reply({ ok: false, code: "loyverse_error", status: response.status });
    }
    const merchant = await response.json();
    const name = typeof merchant?.business_name === "string"
      ? merchant.business_name
      : null;
    return reply({ ok: true, code: "connected", merchant_name: name });
  } catch (_) {
    return reply({ ok: false, code: "network_error" });
  }
});
