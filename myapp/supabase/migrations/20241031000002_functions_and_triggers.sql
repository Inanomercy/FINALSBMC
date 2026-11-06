-- =============================================================================
-- Migration 02: Functions, Triggers, and Stored Procedures for OceanCart
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. AUTOMATIC PROFILE CREATION TRIGGER
-- When a user registers via Supabase auth, create their profile automatically
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        phone,
        address,
        role,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'address',
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
        TRUE,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = COALESCE(EXCLUDED.phone, profiles.phone),
        address = COALESCE(EXCLUDED.address, profiles.address),
        updated_at = TIMEZONE('utc', NOW());

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 2. UPDATED_AT TIMESTAMP TRIGGER
-- Automatically updates updated_at whenever a record changes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON public.products;
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_cart_items_updated_at ON public.cart_items;
CREATE TRIGGER trg_cart_items_updated_at
    BEFORE UPDATE ON public.cart_items
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON public.orders;
CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 3. ROLE HELPER FUNCTIONS
-- Secure server-side role verification for RLS policies
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.profiles WHERE id = p_user_id;
    RETURN COALESCE(v_role, 'customer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (SELECT role = 'admin' FROM public.profiles WHERE id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_rider(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (SELECT role = 'rider' FROM public.profiles WHERE id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. ATOMIC INVENTORY DEDUCTION PROCEDURE
-- Deducts stock when order is placed and prevents overselling
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.deduct_inventory(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT product_id, quantity FROM public.order_items WHERE order_id = p_order_id) LOOP
        -- Check and lock row for update
        UPDATE public.products
        SET stock = stock - r.quantity
        WHERE id = r.product_id AND stock >= r.quantity;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Insufficient stock for product ID: %', r.product_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. ATOMIC INVENTORY RESTORATION PROCEDURE
-- Restores stock if an order or payment expires/fails
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.restore_inventory(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT product_id, quantity FROM public.order_items WHERE order_id = p_order_id) LOOP
        UPDATE public.products
        SET stock = stock + r.quantity
        WHERE id = r.product_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 6. ATOMIC RIDER ASSIGNMENT FUNCTION
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_rider_to_order(
    p_order_id UUID,
    p_rider_id UUID,
    p_admin_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_order_status TEXT;
    v_rider_active BOOLEAN;
    v_now TIMESTAMPTZ := TIMEZONE('utc', NOW());
BEGIN
    -- Verify rider is active
    SELECT is_active INTO v_rider_active FROM public.profiles 
    WHERE id = p_rider_id AND role = 'rider';

    IF v_rider_active IS NOT TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', 'Selected rider is not active or not found.');
    END IF;

    -- Update order
    UPDATE public.orders
    SET rider_id = p_rider_id,
        order_status = 'assigned_to_rider',
        assigned_at = v_now,
        updated_at = v_now
    WHERE id = p_order_id;

    -- Create assignment record
    INSERT INTO public.rider_assignments (order_id, rider_id, status, assigned_at)
    VALUES (p_order_id, p_rider_id, 'pending', v_now);

    -- Log status history
    INSERT INTO public.order_status_history (order_id, status, changed_by, notes, created_at)
    VALUES (p_order_id, 'assigned_to_rider', p_admin_id, 'Assigned to rider by admin', v_now);

    -- Notify rider
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        p_rider_id,
        'New Delivery Assigned!',
        'You have been assigned a new delivery order. Open your deliveries to accept.',
        'rider'
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 7. ATOMIC RIDER ACCEPT / REJECT FUNCTION
-- Prevents race conditions if multiple riders were assigned
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_delivery_assignment(
    p_assignment_id UUID,
    p_order_id UUID,
    p_rider_id UUID,
    p_accepted BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_current_rider UUID;
    v_order_num TEXT;
    v_customer_id UUID;
    v_now TIMESTAMPTZ := TIMEZONE('utc', NOW());
BEGIN
    -- Verify order and assigned rider
    SELECT rider_id, order_number, customer_id 
    INTO v_current_rider, v_order_num, v_customer_id
    FROM public.orders WHERE id = p_order_id;

    IF v_current_rider <> p_rider_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'This delivery is no longer assigned to you.');
    END IF;

    IF p_accepted THEN
        -- Accept assignment
        UPDATE public.rider_assignments
        SET status = 'accepted', responded_at = v_now
        WHERE id = p_assignment_id AND rider_id = p_rider_id;

        UPDATE public.orders
        SET order_status = 'rider_accepted',
            accepted_at = v_now,
            updated_at = v_now
        WHERE id = p_order_id;

        -- Record history
        INSERT INTO public.order_status_history (order_id, status, changed_by, notes)
        VALUES (p_order_id, 'rider_accepted', p_rider_id, 'Rider accepted delivery job');

        -- Notify customer
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_customer_id,
            'Rider Accepted Delivery',
            'Your seafood order #' || v_order_num || ' was accepted by rider and is preparing for pickup.',
            'order'
        );

        RETURN jsonb_build_object('success', true, 'status', 'rider_accepted');
    ELSE
        -- Reject assignment
        UPDATE public.rider_assignments
        SET status = 'rejected',
            rejection_reason = p_rejection_reason,
            responded_at = v_now
        WHERE id = p_assignment_id AND rider_id = p_rider_id;

        -- Return order to pending queue
        UPDATE public.orders
        SET rider_id = NULL,
            order_status = 'pending_confirmation',
            updated_at = v_now
        WHERE id = p_order_id;

        -- Record history
        INSERT INTO public.order_status_history (order_id, status, changed_by, notes)
        VALUES (p_order_id, 'pending_confirmation', p_rider_id, 'Rider rejected delivery: ' || COALESCE(p_rejection_reason, 'No reason given'));

        -- Notify admins
        INSERT INTO public.notifications (user_id, title, message, type)
        SELECT id, 'Delivery Rejected by Rider', 'Rider rejected delivery for order #' || v_order_num || '. Needs reassignment.', 'admin'
        FROM public.profiles WHERE role = 'admin';

        RETURN jsonb_build_object('success', true, 'status', 'rejected');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
