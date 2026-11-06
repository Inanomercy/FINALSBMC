import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type OrderItemInput = {
  product_id: string;
  quantity: number;
};

type CheckoutPayload = {
  customer_id?: string;
  order_id?: string;
  delivery_address?: string;
  customer_phone?: string;
  payment_method?: string;
  items?: OrderItemInput[];
};

function normalizeStatus(value: string | null | undefined) {
  return String(value ?? "").trim().toLowerCase();
}

export function isOrderOwnerAllowed(userId: string, orderCustomerId: string) {
  return Boolean(userId) && userId === orderCustomerId;
}

export function hasDuplicateInvoicePayment(payment: { status?: string; checkout_url?: string | null } | null | undefined) {
  if (!payment) return false;
  const status = normalizeStatus(payment.status);
  const hasCheckoutUrl = Boolean(payment.checkout_url && payment.checkout_url.trim().length > 0);
  return status === "paid" || status === "pending" || hasCheckoutUrl;
}

function getRequestJson(req: Request): Promise<Record<string, any>> {
  return req.json().catch(() => ({}));
}

async function ensureCustomerOwnership(
  supabase: any,
  userId: string,
  orderId: string
) {
  const { data: order, error } = await supabase
    .from("orders")
    .select("id, customer_id")
    .eq("id", orderId)
    .maybeSingle();

  if (error || !order) {
    throw new Error("Order not found.");
  }

  if (order.customer_id !== userId) {
    throw new Error("Unauthorized order access.");
  }

  return order;
}

async function findExistingPayment(supabase: any, orderId: string) {
  const { data, error } = await supabase
    .from("payments")
    .select("id, order_id, payment_reference, payment_method, status, checkout_url, amount")
    .eq("order_id", orderId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error && error.code !== "PGRST116") {
    throw error;
  }

  return data;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY") ?? "";
    const appBaseUrl = Deno.env.get("APP_BASE_URL") ?? "oceancart://";

    if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase server configuration." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing bearer token." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const { data: authData, error: authError } = await authClient.auth.getUser();
    if (authError || !authData.user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized. Please sign in again." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = authData.user.id;
    const body = (await getRequestJson(req)) as CheckoutPayload;

    if (!body.customer_id && !body.order_id) {
      return new Response(
        JSON.stringify({ error: "customer_id or order_id is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    let order: Record<string, any> | null = null;
    let newOrderCreated = false;

    if (body.order_id) {
      const { data, error } = await supabase
        .from("orders")
        .select("*, order_items(*), customer:profiles!orders_customer_id_fkey(id, email, full_name, phone)")
        .eq("id", body.order_id)
        .maybeSingle();

      if (error || !data) {
        return new Response(
          JSON.stringify({ error: "Order not found." }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      order = data;
    } else {
      const customerId = body.customer_id;
      const deliveryAddress = (body.delivery_address ?? "").trim();
      const customerPhone = (body.customer_phone ?? "").trim();
      const items = body.items ?? [];

      if (!customerId || !deliveryAddress || !customerPhone || !Array.isArray(items) || items.length === 0) {
        return new Response(
          JSON.stringify({ error: "Incomplete checkout parameters." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: customer, error: customerError } = await supabase
        .from("profiles")
        .select("id, full_name, email")
        .eq("id", customerId)
        .maybeSingle();

      if (customerError || !customer) {
        return new Response(
          JSON.stringify({ error: "Customer profile not found." }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const productIds = [...new Set(items.map((item) => item.product_id))];
      const { data: products, error: productError } = await supabase
        .from("products")
        .select("id, name, price, stock, is_active")
        .in("id", productIds);

      if (productError || !products || products.length === 0) {
        return new Response(
          JSON.stringify({ error: "Failed to load product details for checkout." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const productMap = new Map((products as any[]).map((product) => [product.id, product]));
      let subtotal = 0;
      const orderItems: any[] = [];

      for (const item of items) {
        const product = productMap.get(item.product_id);
        if (!product) {
          return new Response(
            JSON.stringify({ error: `Product not found: ${item.product_id}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        if (!product.is_active) {
          return new Response(
            JSON.stringify({ error: `Product is currently unavailable: ${product.name}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const quantity = Number(item.quantity ?? 0);
        if (!Number.isFinite(quantity) || quantity <= 0) {
          return new Response(
            JSON.stringify({ error: `Invalid quantity for ${product.name}.` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        if (Number(product.stock) < quantity) {
          return new Response(
            JSON.stringify({ error: `Insufficient stock for ${product.name}. Available: ${product.stock}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const unitPrice = Number(product.price);
        const lineSubtotal = unitPrice * quantity;
        subtotal += lineSubtotal;

        orderItems.push({
          product_id: product.id,
          product_name: product.name,
          product_price: unitPrice,
          quantity,
          subtotal: lineSubtotal,
        });
      }

      const deliveryFee = 50;
      const totalAmount = subtotal + deliveryFee;
      const timestamp = new Date().toISOString().slice(0, 10).replace(/-/g, "");
      const randomSuffix = Math.floor(1000 + Math.random() * 9000).toString();
      const orderNumber = `OC-${timestamp}-${randomSuffix}`;

      const { data: createdOrder, error: orderInsertError } = await supabase
        .from("orders")
        .insert({
          order_number: orderNumber,
          customer_id: customerId,
          subtotal,
          delivery_fee: deliveryFee,
          total_amount: totalAmount,
          payment_status: "pending",
          order_status: "pending_payment",
          delivery_address: deliveryAddress,
          customer_phone: customerPhone,
        })
        .select("*, order_items(*), customer:profiles!orders_customer_id_fkey(id, email, full_name, phone)")
        .single();

      if (orderInsertError || !createdOrder) {
        return new Response(
          JSON.stringify({ error: "Failed to create order: " + (orderInsertError?.message ?? "unknown error") }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const orderItemsWithOrderId = orderItems.map((item) => ({
        ...item,
        order_id: createdOrder.id,
      }));

      const { error: itemInsertError } = await supabase.from("order_items").insert(orderItemsWithOrderId);
      if (itemInsertError) {
        return new Response(
          JSON.stringify({ error: "Failed to save order items: " + itemInsertError.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      order = { ...createdOrder, order_items: orderItemsWithOrderId };
      newOrderCreated = true;
    }

    if (!order) {
      return new Response(
        JSON.stringify({ error: "Order data is missing." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (order.customer_id !== userId) {
      return new Response(
        JSON.stringify({ error: "Unauthorized order access." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const existingPayment = await findExistingPayment(supabase, order.id);
    if (existingPayment && existingPayment.checkout_url) {
      return new Response(
        JSON.stringify({
          success: true,
          order_id: order.id,
          order_number: order.order_number,
          checkout_url: existingPayment.checkout_url,
          payment_reference: existingPayment.payment_reference,
          status: existingPayment.status,
          duplicate: true,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const productIds = [...new Set((order.order_items ?? []).map((item: any) => item.product_id))];
    const { data: currentProducts, error: currentProductsError } = await supabase
      .from("products")
      .select("id, price")
      .in("id", productIds);

    if (currentProductsError || !currentProducts) {
      return new Response(
        JSON.stringify({ error: "Unable to verify the order total." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const productPriceMap = new Map((currentProducts as any[]).map((product) => [product.id, Number(product.price)]));
    let serverSubtotal = 0;
    for (const item of order.order_items ?? []) {
      const itemProductPrice = productPriceMap.get(item.product_id) ?? Number(item.product_price ?? 0);
      serverSubtotal += itemProductPrice * Number(item.quantity ?? 0);
    }

    const deliveryFee = Number(order.delivery_fee ?? 50);
    const expectedTotal = Number(serverSubtotal + deliveryFee);
    const actualTotal = Number(order.total_amount ?? 0);

    if (Math.abs(expectedTotal - actualTotal) > 0.01) {
      return new Response(
        JSON.stringify({ error: "Order amount mismatch. Please refresh the cart and try again." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const paymentMethod = (body.payment_method ?? "xendit").trim() || "xendit";
    const invoiceDescription = `OceanCart Order #${order.order_number}`;

    let checkoutUrl = "";
    let paymentReference = "";

    if (!xenditSecretKey || !xenditSecretKey.startsWith("xnd_")) {
      return new Response(
        JSON.stringify({ error: "XENDIT_SECRET_KEY is not configured for invoice creation." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          external_id: order.order_number,
          amount: expectedTotal,
          description: invoiceDescription,
          currency: "PHP",
          payer_email: order.customer?.email ?? authData.user.email,
          customer: {
            given_names: order.customer?.full_name ?? authData.user.email,
            mobile_number: order.customer_phone ?? order.customer?.phone ?? "",
          },
          success_redirect_url: `${appBaseUrl}/payment-success?order_id=${order.id}`,
          failure_redirect_url: `${appBaseUrl}/payment-failed?order_id=${order.id}`,
          items: (order.order_items ?? []).map((item: any) => ({
            name: item.product_name,
            quantity: Number(item.quantity),
            price: Number(item.product_price ?? 0),
          })),
          fees: [
            {
              type: "Delivery Fee",
              value: Number(deliveryFee),
            },
          ],
        }),
      });

      if (xenditResponse.ok) {
        const invoiceData = await xenditResponse.json();
        checkoutUrl = invoiceData.invoice_url ?? "";
        paymentReference = invoiceData.id ?? "";
      } else {
        const text = await xenditResponse.text();
        console.warn("Xendit invoice creation failed:", text);
        throw new Error(`Xendit invoice request failed with status ${xenditResponse.status}.`);
      }
    } catch (error) {
      console.error("Failed to create Xendit invoice:", error);
      throw error;
    }

    if (!checkoutUrl || !paymentReference) {
      throw new Error("Xendit invoice creation did not return a valid checkout URL.");
    }

    const paymentRecord = {
      order_id: order.id,
      customer_id: order.customer_id,
      provider: "xendit",
      payment_reference: paymentReference,
      payment_method: paymentMethod,
      amount: expectedTotal,
      status: "pending",
      checkout_url: checkoutUrl,
      created_at: new Date().toISOString(),
    };

    if (existingPayment) {
      await supabase.from("payments").update(paymentRecord).eq("id", existingPayment.id);
    } else {
      await supabase.from("payments").insert(paymentRecord);
    }

    if (newOrderCreated) {
      await supabase.from("order_status_history").insert({
        order_id: order.id,
        status: "pending_payment",
        changed_by: userId,
        notes: "Customer created and confirmed checkout request.",
        created_at: new Date().toISOString(),
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        order_id: order.id,
        order_number: order.order_number,
        payment_reference: paymentReference,
        checkout_url: checkoutUrl,
        status: "pending",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Checkout failed.";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
