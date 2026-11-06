ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS inventory_deducted_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.deduct_inventory_after_payment(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_status TEXT;
  v_inventory_deducted_at TIMESTAMPTZ;
  r RECORD;
BEGIN
  SELECT payment_status, inventory_deducted_at
    INTO v_payment_status, v_inventory_deducted_at
    FROM public.orders
   WHERE id = p_order_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_payment_status <> 'paid' THEN
    RAISE EXCEPTION 'Cannot deduct inventory before payment is confirmed for order %', p_order_id;
  END IF;

  IF v_inventory_deducted_at IS NOT NULL THEN
    RETURN FALSE;
  END IF;

  FOR r IN
    SELECT product_id, quantity
      FROM public.order_items
     WHERE order_id = p_order_id
  LOOP
    UPDATE public.products
       SET stock = stock - r.quantity
     WHERE id = r.product_id
       AND stock >= r.quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient stock for product ID: %', r.product_id;
    END IF;
  END LOOP;

  UPDATE public.orders
     SET inventory_deducted_at = NOW()
   WHERE id = p_order_id;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.deduct_inventory_after_payment(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.deduct_inventory_after_payment(UUID) TO service_role;