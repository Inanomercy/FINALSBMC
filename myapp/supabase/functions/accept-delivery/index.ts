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

    const body = await req.json();
    const { order_id, assignment_id, action, rejection_reason } = body;

    if (!order_id || !action || !["accept", "reject"].includes(action)) {
      return new Response(
        JSON.stringify({ error: "order_id and valid action ('accept' or 'reject') required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify order
    const { data: order, error: orderErr } = await supabaseAdmin
      .from("orders")
      .select("id, order_number, rider_id, customer_id, order_status")
      .eq("id", order_id)
      .single();

    if (orderErr || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (order.rider_id !== callerUser.id) {
      return new Response(
        JSON.stringify({ error: "This delivery job is not assigned to you." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const now = new Date().toISOString();

    if (action === "accept") {
      // 1. Update assignment
      if (assignment_id) {
        await supabaseAdmin
          .from("rider_assignments")
          .update({ status: "accepted", responded_at: now })
          .eq("id", assignment_id);
      } else {
        await supabaseAdmin
          .from("rider_assignments")
          .update({ status: "accepted", responded_at: now })
          .eq("order_id", order.id)
          .eq("rider_id", callerUser.id);
      }

      // 2. Update order
      await supabaseAdmin
        .from("orders")
        .update({
          order_status: "rider_accepted",
          accepted_at: now,
          updated_at: now,
        })
        .eq("id", order.id);

      // 3. Log history
      await supabaseAdmin.from("order_status_history").insert({
        order_id: order.id,
        status: "rider_accepted",
        changed_by: callerUser.id,
        notes: "Rider accepted delivery job.",
        created_at: now,
      });

      // 4. Notify Customer
      await supabaseAdmin.from("notifications").insert({
        user_id: order.customer_id,
        title: "Rider Accepted Delivery",
        message: `Your seafood order #${order.order_number} has been accepted by our rider and will be picked up soon.`,
        type: "order",
      });

      return new Response(
        JSON.stringify({ success: true, message: "Delivery accepted.", status: "rider_accepted" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } else {
      // Reject action
      if (assignment_id) {
        await supabaseAdmin
          .from("rider_assignments")
          .update({
            status: "rejected",
            rejection_reason: rejection_reason || "Rider unavailable",
            responded_at: now,
          })
          .eq("id", assignment_id);
      } else {
        await supabaseAdmin
          .from("rider_assignments")
          .update({
            status: "rejected",
            rejection_reason: rejection_reason || "Rider unavailable",
            responded_at: now,
          })
          .eq("order_id", order.id)
          .eq("rider_id", callerUser.id);
      }

      // Return order to pending confirmation queue
      await supabaseAdmin
        .from("orders")
        .update({
          rider_id: null,
          order_status: "pending_confirmation",
          updated_at: now,
        })
        .eq("id", order.id);

      // Log history
      await supabaseAdmin.from("order_status_history").insert({
        order_id: order.id,
        status: "pending_confirmation",
        changed_by: callerUser.id,
        notes: `Rider rejected delivery: ${rejection_reason || "No reason given"}`,
        created_at: now,
      });

      // Notify Admins
      const { data: admins } = await supabaseAdmin
        .from("profiles")
        .select("id")
        .eq("role", "admin");

      if (admins) {
        const notifs = admins.map((a: any) => ({
          user_id: a.id,
          title: "Delivery Rejected",
          message: `Order #${order.order_number} was rejected by rider. Needs reassignment.`,
          type: "rider",
        }));
        await supabaseAdmin.from("notifications").insert(notifs);
      }

      return new Response(
        JSON.stringify({ success: true, message: "Delivery rejected.", status: "rejected" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  } catch (err: unknown) {
    const error = err as Error;
    return new Response(
      JSON.stringify({ error: error.message || "Failed to update delivery response." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
