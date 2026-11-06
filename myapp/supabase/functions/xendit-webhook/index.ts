import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-callback-token",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

function normalizeStatus(value: string | null | undefined) {
  return String(value ?? "").trim().toUpperCase();
}

export function isPaymentPaid(status: string) {
  const value = normalizeStatus(status);
  return ["PAID", "SETTLED", "SUCCEEDED", "SUCCESS", "CAPTURED", "COMPLETED"].includes(value);
}

export function isPaymentFailed(status: string) {
  const value = normalizeStatus(status);
  return ["FAILED", "DECLINED", "REJECTED"].includes(value);
}

export function isPaymentExpired(status: string) {
  const value = normalizeStatus(status);
  return ["EXPIRED", "CANCELLED", "VOIDED"].includes(value);
}

function extractPaymentStatus(payload: Record<string, any>) {
  const candidates = [
    payload.status,
    payload.data?.status,
    payload.data?.data?.status,
    payload.event,
    payload.data?.event,
    payload.data?.data?.event,
  ];

  for (const candidate of candidates) {
    if (candidate == null) continue;
    const value = normalizeStatus(String(candidate));
    const eventStatus = value.split(/[._]/).pop() ?? value;
    if (isPaymentPaid(value) || ["PAID", "SUCCEEDED", "SUCCESS", "CAPTURED", "COMPLETED"].includes(eventStatus)) return "PAID";
    if (isPaymentFailed(value) || ["FAILED", "FAILURE", "DECLINED", "REJECTED"].includes(eventStatus)) return "FAILED";
    if (isPaymentExpired(value) || ["EXPIRED", "CANCELLED", "VOIDED"].includes(eventStatus)) return "EXPIRED";
  }

  return normalizeStatus(String(candidates.find((candidate) => candidate != null) ?? ""));
}

Deno.serve(async (req) => {
  if (req.method === "GET") {
    const requestUrl = new URL(req.url);
    const returnPage = requestUrl.pathname.endsWith("/payment-success")
      ? "payment-success"
      : requestUrl.pathname.endsWith("/payment-failed")
        ? "payment-failed"
        : null;

    if (returnPage) {
      const orderId = requestUrl.searchParams.get("order_id") ?? "";
      if (!/^[a-zA-Z0-9-]{1,80}$/.test(orderId)) {
        return new Response("Missing or invalid order_id.", { status: 400 });
      }

      const appLink = new URL(`oceancart://${returnPage}`);
      appLink.searchParams.set("order_id", orderId);
      const deepLink = appLink.toString();
      return new Response(null, {
        status: 302,
        headers: { Location: deepLink },
      });
    }

    return new Response(
      JSON.stringify({ status: "active", message: "OceanCart Xendit webhook is active." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const xenditCallbackToken = Deno.env.get("XENDIT_CALLBACK_TOKEN") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase configuration." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!xenditCallbackToken) {
      return new Response(
        JSON.stringify({ error: "Missing XENDIT_CALLBACK_TOKEN secret." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const callbackToken = req.headers.get("x-callback-token") ?? "";
    if (!callbackToken) {
      return new Response(
        JSON.stringify({ error: "Missing Xendit callback token." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (callbackToken !== xenditCallbackToken) {
      return new Response(
        JSON.stringify({ error: "Unauthorized callback token." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let payload: Record<string, any> = {};
    try {
      payload = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON payload." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const status = extractPaymentStatus(payload);
    const invoiceId = String(payload.id ?? payload.data?.id ?? payload.data?.data?.id ?? payload.invoice_id ?? payload.data?.invoice_id ?? payload.payment_id ?? payload.data?.payment_id ?? "").trim();
    const externalId = String(payload.external_id ?? payload.data?.external_id ?? payload.data?.data?.external_id ?? payload.reference_id ?? payload.data?.reference_id ?? payload.data?.data?.reference_id ?? "").trim();
    const paidAmount = Number(payload.paid_amount ?? payload.paidAmount ?? payload.amount ?? payload.data?.paid_amount ?? payload.data?.amount ?? payload.data?.data?.paid_amount ?? 0);
    const paymentMethod = String(payload.payment_method ?? payload.paymentMethod ?? payload.payment_channel ?? payload.paymentChannel ?? payload.data?.payment_method ?? payload.data?.payment_channel ?? payload.bank_code ?? "xendit").trim() || "xendit";
    const now = new Date().toISOString();

    if (!status) {
      return new Response(
        JSON.stringify({ success: true, message: "Webhook acknowledged; status not provided." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    let order: any = null;

    if (externalId) {
      const { data, error } = await supabase
        .from("orders")
        .select("*, order_items(*)")
        .eq("order_number", externalId)
        .maybeSingle();

      if (!error) {
        order = data;
      }
    }

    if (!order && invoiceId) {
      const { data, error } = await supabase
        .from("payments")
        .select("id, order_id, payment_reference, status, amount, order:orders(*)")
        .eq("payment_reference", invoiceId)
        .maybeSingle();

      if (!error && data && data.order) {
        order = data.order;
      }
    }

    if (!order) {
      return new Response(
        JSON.stringify({ error: "No matching order found for Xendit callback." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: latestPayment, error: paymentLookupError } = await supabase
      .from("payments")
      .select("id, status, payment_reference, amount")
      .eq("order_id", order.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (paymentLookupError && paymentLookupError.code !== "PGRST116") {
      throw paymentLookupError;
    }

    const normalizedExistingStatus = normalizeStatus(latestPayment?.status ?? order.payment_status ?? "");

    if (isPaymentPaid(status)) {
      if (["PAID", "SETTLED", "SUCCEEDED", "SUCCESS", "CAPTURED", "COMPLETED"].includes(normalizedExistingStatus)) {
        return new Response(
          JSON.stringify({ success: true, message: "Order already paid; duplicate webhook ignored." }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: updatedOrder, error: orderUpdateError } = await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          order_status: "pending_confirmation",
          updated_at: now,
        })
        .eq("id", order.id)
        .select("id")
        .maybeSingle();
      if (orderUpdateError || !updatedOrder) {
        throw orderUpdateError ?? new Error("Order payment status was not updated.");
      }

      const { error: inventoryError } = await supabase.rpc(
        "deduct_inventory_after_payment",
        { p_order_id: order.id }
      );
      if (inventoryError) throw inventoryError;
      const { error: paymentWriteError } = await supabase.from("payments").upsert(
        {
          order_id: order.id,
          customer_id: order.customer_id,
          provider: "xendit",
          payment_reference: invoiceId || latestPayment?.payment_reference || `xnd_${order.order_number}`,
          payment_method: paymentMethod,
          amount: Number(order.total_amount ?? latestPayment?.amount ?? paidAmount ?? 0),
          status: "paid",
          paid_at: now,
          checkout_url: order.checkout_url ?? null,
        },
        { onConflict: "order_id" }
      );
      if (paymentWriteError) throw paymentWriteError;

      await supabase.from("order_status_history").insert({
        order_id: order.id,
        status: "pending_confirmation",
        changed_by: order.customer_id,
        notes: `Payment confirmed via Xendit (${paymentMethod}).`,
        created_at: now,
      });

      return new Response(
        JSON.stringify({ success: true, message: `Order #${order.order_number} marked as paid.` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (isPaymentFailed(status) || isPaymentExpired(status)) {
      const nextStatus = isPaymentFailed(status) ? "failed" : "expired";
      if (normalizeStatus(latestPayment?.status ?? order.payment_status ?? "") === nextStatus.toUpperCase()) {
        return new Response(
          JSON.stringify({ success: true, message: `Order already marked as ${nextStatus}.` }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: updatedOrder, error: orderUpdateError } = await supabase
        .from("orders")
        .update({
          payment_status: nextStatus,
          order_status: "payment_failed",
          updated_at: now,
        })
        .eq("id", order.id)
        .select("id")
        .maybeSingle();
      if (orderUpdateError || !updatedOrder) {
        throw orderUpdateError ?? new Error("Order payment status was not updated.");
      }

const { error: paymentWriteError } = await supabase.from("payments").upsert(
        {
          order_id: order.id,
          customer_id: order.customer_id,
          provider: "xendit",
          payment_reference: invoiceId || latestPayment?.payment_reference || `xnd_${order.order_number}`,
          payment_method: paymentMethod,
          amount: Number(order.total_amount ?? latestPayment?.amount ?? 0),
          status: nextStatus,
          checkout_url: order.checkout_url ?? null,
        },
        { onConflict: "order_id" }
      );
      if (paymentWriteError) throw paymentWriteError;

      return new Response(
        JSON.stringify({ success: true, message: `Order #${order.order_number} marked as ${nextStatus}.` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "Webhook acknowledged; no status change required." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Webhook processing failed.";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
