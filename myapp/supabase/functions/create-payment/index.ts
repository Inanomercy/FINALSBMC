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
    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY") ?? Deno.env.get("OceanCart") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Missing backend configuration." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body = await req.json();
    const { order_id, payment_method } = body;

    if (!order_id) {
      return new Response(
        JSON.stringify({ error: "order_id is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch order
    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("*, customer:profiles!orders_customer_id_fkey(full_name, email)")
      .eq("id", order_id)
      .single();

    if (orderErr || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (order.payment_status === "paid") {
      return new Response(
        JSON.stringify({ error: "Order is already paid." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!xenditSecretKey || !xenditSecretKey.startsWith("xnd_")) {
      return new Response(
        JSON.stringify({ error: "XENDIT_SECRET_KEY is not configured. Real invoice creation is disabled." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let checkoutUrl = "";
    let paymentRef = "";

    try {
      const basicAuth = btoa(`${xenditSecretKey}:`);
      const res = await fetch("https://api.xendit.co/v2/invoices", {
        method: "POST",
        headers: {
          "Authorization": `Basic ${basicAuth}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          external_id: order.order_number,
          amount: order.total_amount,
          description: `Payment for Order #${order.order_number}`,
          payer_email: order.customer?.email,
          currency: "PHP",
        }),
      });

      if (!res.ok) {
        const responseText = await res.text();
        console.error("Xendit invoice creation failed:", responseText);
        throw new Error(`Xendit invoice request failed with status ${res.status}.`);
      }

      const inv = await res.json();
      checkoutUrl = inv.invoice_url ?? "";
      paymentRef = inv.id ?? "";
    } catch (e) {
      console.error("Xendit Invoice creation error:", e);
      return new Response(
        JSON.stringify({ error: e instanceof Error ? e.message : "Failed to create Xendit invoice." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!checkoutUrl || !paymentRef) {
      return new Response(
        JSON.stringify({ error: "Xendit invoice creation did not return a valid checkout URL." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Upsert payment record
    await supabase.from("payments").insert({
      order_id: order.id,
      customer_id: order.customer_id,
      provider: "xendit",
      payment_reference: paymentRef,
      payment_method: payment_method || "xendit",
      amount: order.total_amount,
      status: "pending",
      checkout_url: checkoutUrl,
    });

    return new Response(
      JSON.stringify({
        success: true,
        checkout_url: checkoutUrl,
        payment_reference: paymentRef,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const error = err as Error;
    return new Response(
      JSON.stringify({ error: error.message || "Payment initiation failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
