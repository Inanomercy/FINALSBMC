import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Missing backend configuration." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Authorization required." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseCaller = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: callerUser }, error: callerError } = await supabaseCaller.auth.getUser();

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Unauthorized user." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: adminProfile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", callerUser.id)
      .single();

    if (adminProfile?.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Only administrators can assign deliveries." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { order_id, rider_id } = body;

    if (!order_id || !rider_id) {
      return new Response(
        JSON.stringify({ error: "order_id and rider_id are required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify order
    const { data: order, error: orderErr } = await supabaseAdmin
      .from("orders")
      .select("id, order_number, order_status, payment_status, customer_id")
      .eq("id", order_id)
      .single();

    if (orderErr || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify rider
    const { data: rider, error: riderErr } = await supabaseAdmin
      .from("profiles")
      .select("id, full_name, is_active, role")
      .eq("id", rider_id)
      .single();

    if (riderErr || !rider || rider.role !== "rider" || !rider.is_active) {
      return new Response(
        JSON.stringify({ error: "Selected rider is inactive or invalid." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const now = new Date().toISOString();

    // Update order
    await supabaseAdmin
      .from("orders")
      .update({
        rider_id: rider.id,
        order_status: "assigned_to_rider",
        assigned_at: now,
        updated_at: now,
      })
      .eq("id", order.id);

    // Insert into rider_assignments
    await supabaseAdmin.from("rider_assignments").insert({
      order_id: order.id,
      rider_id: rider.id,
      status: "pending",
      assigned_at: now,
    });

    // History log
    await supabaseAdmin.from("order_status_history").insert({
      order_id: order.id,
      status: "assigned_to_rider",
      changed_by: callerUser.id,
      notes: `Order assigned to rider: ${rider.full_name}`,
      created_at: now,
    });

    // Notify Rider
    await supabaseAdmin.from("notifications").insert({
      user_id: rider.id,
      title: "New Delivery Assigned 🛵",
      message: `You have been assigned Order #${order.order_number}. Please check and accept the delivery.`,
      type: "rider",
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: `Order assigned to ${rider.full_name}`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const error = err as Error;
    return new Response(
      JSON.stringify({ error: error.message || "Failed to assign rider." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
