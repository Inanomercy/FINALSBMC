import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

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
        JSON.stringify({ error: "Missing Supabase configuration." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body = await req.json();
    const { customer_id, delivery_address, customer_phone, payment_method, items } = body;

    if (!customer_id || !delivery_address || !customer_phone || !items || !Array.isArray(items) || items.length === 0) {
      return new Response(
        JSON.stringify({ error: "Incomplete checkout parameters." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch customer details
    const { data: customer, error: custErr } = await supabase
      .from("profiles")
      .select("id, full_name, email")
      .eq("id", customer_id)
      .single();

    if (custErr || !customer) {
      return new Response(
        JSON.stringify({ error: "Customer profile not found." }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch products and calculate server-side subtotal
    const productIds = items.map((i: any) => i.product_id);
    const { data: products, error: prodErr } = await supabase
      .from("products")
      .select("id, name, price, stock, is_active")
      .in("id", productIds);

    if (prodErr || !products || products.length === 0) {
      return new Response(
        JSON.stringify({ error: "Failed to load product details." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prodMap = new Map<string, any>(products.map((p: any) => [p.id, p]));
    let subtotal = 0;
    const orderItemsToInsert: any[] = [];

    for (const item of items) {
      const prod = prodMap.get(item.product_id);
      if (!prod) {
        return new Response(
          JSON.stringify({ error: `Product not found: ${item.product_id}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (!prod.is_active) {
        return new Response(
          JSON.stringify({ error: `Product is currently unavailable: ${prod.name}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (prod.stock < item.quantity) {
        return new Response(
          JSON.stringify({ error: `Insufficient stock for ${prod.name}. Available: ${prod.stock}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const itemPrice = Number(prod.price);
      const itemSubtotal = itemPrice * Number(item.quantity);
      subtotal += itemSubtotal;

      orderItemsToInsert.push({
        product_id: prod.id,
        product_name: prod.name,
        product_price: itemPrice,
        quantity: item.quantity,
        subtotal: itemSubtotal,
      });
    }

    const deliveryFee = 50.0;
    const totalAmount = subtotal + deliveryFee;

    // 3. Generate unique order number (e.g. OC-YYYYMMDD-XXXX)
    const timestamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const randomHex = Math.floor(1000 + Math.random() * 9000).toString();
    const orderNumber = `OC-${timestamp}-${randomHex}`;

    // 4. Create Xendit Invoice if API key is present
    let checkoutUrl = "";
    let paymentRef = "";

    if (!xenditSecretKey || !xenditSecretKey.startsWith("xnd_")) {
      return new Response(
        JSON.stringify({ error: "XENDIT_SECRET_KEY is not configured. Real invoice creation is disabled." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      const basicAuth = btoa(`${xenditSecretKey}:`);
      const xenditRes = await fetch("https://api.xendit.co/v2/invoices", {
        method: "POST",
        headers: {
          "Authorization": `Basic ${basicAuth}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          external_id: orderNumber,
          amount: totalAmount,
          description: `OceanCart Seafood Order #${orderNumber}`,
          payer_email: customer.email,
          customer: {
            given_names: customer.full_name,
            mobile_number: customer_phone,
          },
          items: orderItemsToInsert.map((item) => ({
            name: item.product_name,
            quantity: item.quantity,
            price: item.product_price,
          })),
          fees: [
            {
              type: "Delivery Fee",
              value: deliveryFee,
            },
          ],
          success_redirect_url: `oceancart://payment-success?order_number=${orderNumber}`,
          failure_redirect_url: `oceancart://payment-failed?order_number=${orderNumber}`,
          currency: "PHP",
        }),
      });

      if (!xenditRes.ok) {
        const responseText = await xenditRes.text();
        console.error("Xendit API returned non-200:", responseText);
        throw new Error(`Xendit invoice request failed with status ${xenditRes.status}.`);
      }

      const xenditData = await xenditRes.json();
      checkoutUrl = xenditData.invoice_url ?? "";
      paymentRef = xenditData.id ?? "";
    } catch (err) {
      console.error("Xendit Invoice creation error:", err);
      throw err;
    }

    if (!checkoutUrl || !paymentRef) {
      throw new Error("Xendit invoice creation did not return a valid checkout URL.");
    }

    // 5. Insert order into DB
    const { data: newOrder, error: orderErr } = await supabase
      .from("orders")
      .insert({
        order_number: orderNumber,
        customer_id: customer_id,
        subtotal: subtotal,
        delivery_fee: deliveryFee,
        total_amount: totalAmount,
        payment_status: "pending",
        order_status: "pending_payment",
        delivery_address: delivery_address.trim(),
        customer_phone: customer_phone.trim(),
      })
      .select()
      .single();

    if (orderErr || !newOrder) {
      return new Response(
        JSON.stringify({ error: "Failed to persist order: " + orderErr?.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Insert order items
    const itemsWithOrderId = orderItemsToInsert.map((item) => ({
      ...item,
      order_id: newOrder.id,
    }));
    await supabase.from("order_items").insert(itemsWithOrderId);

    // 7. Insert payment record
    await supabase.from("payments").insert({
      order_id: newOrder.id,
      customer_id: customer_id,
      provider: "xendit",
      payment_reference: paymentRef,
      payment_method: payment_method || "xendit",
      amount: totalAmount,
      status: "pending",
      checkout_url: checkoutUrl,
    });

    // 8. Log order status history
    await supabase.from("order_status_history").insert({
      order_id: newOrder.id,
      status: "pending_payment",
      changed_by: customer_id,
      notes: "Customer checked out and created order.",
    });


    // 9. Clean customer's cart
    await supabase.from("cart_items").delete().eq("customer_id", customer_id);

    return new Response(
      JSON.stringify({
        success: true,
        order_id: newOrder.id,
        order_number: orderNumber,
        checkout_url: checkoutUrl,
        total_amount: totalAmount,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const error = err as Error;
    return new Response(
      JSON.stringify({ error: error.message || "Checkout failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
