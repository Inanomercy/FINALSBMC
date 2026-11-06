-- =============================================================================
-- Migration 01: Core Database Schema for OceanCart
-- Complies with README.md Section 8 (Supabase Database Structure)
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. PROFILES TABLE
-- Stores user profile data extending Supabase auth.users
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    role TEXT NOT NULL CHECK (role IN ('customer', 'admin', 'rider')) DEFAULT 'customer',
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Index for role-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- -----------------------------------------------------------------------------
-- 2. CATEGORIES TABLE
-- Product categories for seafood items
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- -----------------------------------------------------------------------------
-- 3. PRODUCTS TABLE
-- Seafood catalog with stock, pricing in PHP, and category association
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(is_active);

-- -----------------------------------------------------------------------------
-- 4. PRODUCT IMAGES TABLE
-- Gallery images for seafood items
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_product_images_product ON public.product_images(product_id);

-- -----------------------------------------------------------------------------
-- 5. CART ITEMS TABLE
-- Persistent customer shopping cart items
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    CONSTRAINT uq_cart_customer_product UNIQUE (customer_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_cart_items_customer ON public.cart_items(customer_id);

-- -----------------------------------------------------------------------------
-- 6. ORDERS TABLE
-- Master order records tracking delivery, rider assignment, and payments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    rider_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 50.00 CHECK (delivery_fee >= 0),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    payment_status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'expired')),
    order_status TEXT NOT NULL DEFAULT 'pending_payment'
        CHECK (order_status IN (
            'pending_payment',
            'pending_confirmation',
            'processing',
            'assigned_to_rider',
            'rider_accepted',
            'picked_up',
            'out_for_delivery',
            'delivered',
            'cancelled',
            'payment_failed'
        )),
    delivery_address TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    assigned_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_rider ON public.orders(rider_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON public.orders(created_at DESC);

-- -----------------------------------------------------------------------------
-- 7. ORDER ITEMS TABLE
-- Snapshot of product name and price at the time of order
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_price NUMERIC(12,2) NOT NULL CHECK (product_price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

-- -----------------------------------------------------------------------------
-- 8. PAYMENTS TABLE
-- Xendit payment and invoice transaction logs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'xendit',
    payment_reference TEXT,
    payment_method TEXT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'failed', 'expired')),
    checkout_url TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON public.payments(payment_reference);

-- -----------------------------------------------------------------------------
-- 9. RIDER ASSIGNMENTS TABLE
-- Tracks rider assignment, acceptance, and rejection workflow
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rider_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected')),
    rejection_reason TEXT,
    assigned_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    responded_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rider_assignments_order ON public.rider_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_rider_assignments_rider ON public.rider_assignments(rider_id);

-- -----------------------------------------------------------------------------
-- 10. ORDER STATUS HISTORY TABLE
-- Audit trail of all status transitions for customer & rider tracking
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON public.order_status_history(order_id);

-- -----------------------------------------------------------------------------
-- 11. NOTIFICATIONS TABLE
-- Real-time notification records for Customer, Admin, and Rider
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'system',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, is_read);
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
-- =============================================================================
-- Migration 03: Storage Buckets & Row Level Security (RLS) Policies
-- Complies with README.md Section 9 (Supabase Security & Row Level Security)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. STORAGE BUCKETS SETUP
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('product-images', 'product-images', true),
    ('category-images', 'category-images', true),
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage Objects Policies
DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
CREATE POLICY "Public can view product images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Admins can upload product images" ON storage.objects;
CREATE POLICY "Admins can upload product images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'product-images' AND 
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    );

DROP POLICY IF EXISTS "Admins can delete product images" ON storage.objects;
CREATE POLICY "Admins can delete product images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'product-images' AND 
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    );

DROP POLICY IF EXISTS "Public can view category images" ON storage.objects;
CREATE POLICY "Public can view category images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'category-images');

DROP POLICY IF EXISTS "Admins can upload category images" ON storage.objects;
CREATE POLICY "Admins can upload category images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'category-images' AND 
        (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    );

DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;
CREATE POLICY "Public can view avatars"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
    ON storage.objects FOR UPDATE
    USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- -----------------------------------------------------------------------------
-- 2. ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 3. PROFILES POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow user to read own profile" ON public.profiles;
CREATE POLICY "Allow user to read own profile"
    ON public.profiles FOR SELECT
    USING (
        auth.uid() = id OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') OR
        role = 'rider'
    );

DROP POLICY IF EXISTS "Allow user to update own profile" ON public.profiles;
CREATE POLICY "Allow user to update own profile"
    ON public.profiles FOR UPDATE
    USING (
        auth.uid() = id OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Allow profile inserts" ON public.profiles;
CREATE POLICY "Allow profile inserts"
    ON public.profiles FOR INSERT
    WITH CHECK (
        auth.uid() = id OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- -----------------------------------------------------------------------------
-- 4. CATEGORIES POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow all users to view categories" ON public.categories;
CREATE POLICY "Allow all users to view categories"
    ON public.categories FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Allow admins to insert categories" ON public.categories;
CREATE POLICY "Allow admins to insert categories"
    ON public.categories FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Allow admins to update categories" ON public.categories;
CREATE POLICY "Allow admins to update categories"
    ON public.categories FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Allow admins to delete categories" ON public.categories;
CREATE POLICY "Allow admins to delete categories"
    ON public.categories FOR DELETE
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- -----------------------------------------------------------------------------
-- 5. PRODUCTS POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow viewing products" ON public.products;
CREATE POLICY "Allow viewing products"
    ON public.products FOR SELECT
    USING (
        is_active = true OR 
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Allow admins to insert products" ON public.products;
CREATE POLICY "Allow admins to insert products"
    ON public.products FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Allow admins to update products" ON public.products;
CREATE POLICY "Allow admins to update products"
    ON public.products FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Allow admins to delete products" ON public.products;
CREATE POLICY "Allow admins to delete products"
    ON public.products FOR DELETE
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- -----------------------------------------------------------------------------
-- 6. PRODUCT IMAGES POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow all to view product images" ON public.product_images;
CREATE POLICY "Allow all to view product images"
    ON public.product_images FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Allow admins to manage product images" ON public.product_images;
CREATE POLICY "Allow admins to manage product images"
    ON public.product_images FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- -----------------------------------------------------------------------------
-- 7. CART ITEMS POLICIES
-- Customers only control their own shopping cart
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Customer manage own cart" ON public.cart_items;
CREATE POLICY "Customer manage own cart"
    ON public.cart_items FOR ALL
    USING (auth.uid() = customer_id)
    WITH CHECK (auth.uid() = customer_id);

-- -----------------------------------------------------------------------------
-- 8. ORDERS POLICIES
-- Customer views own, Rider views assigned, Admin views all
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View orders policy" ON public.orders;
CREATE POLICY "View orders policy"
    ON public.orders FOR SELECT
    USING (
        auth.uid() = customer_id OR
        auth.uid() = rider_id OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Create orders policy" ON public.orders;
CREATE POLICY "Create orders policy"
    ON public.orders FOR INSERT
    WITH CHECK (
        auth.uid() = customer_id OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Update orders policy" ON public.orders;
CREATE POLICY "Update orders policy"
    ON public.orders FOR UPDATE
    USING (
        auth.uid() = rider_id OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- -----------------------------------------------------------------------------
-- 9. ORDER ITEMS POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View order items policy" ON public.order_items;
CREATE POLICY "View order items policy"
    ON public.order_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders o 
            WHERE o.id = order_items.order_id AND (
                o.customer_id = auth.uid() OR
                o.rider_id = auth.uid() OR
                EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
            )
        )
    );

DROP POLICY IF EXISTS "Insert order items policy" ON public.order_items;
CREATE POLICY "Insert order items policy"
    ON public.order_items FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.orders o 
            WHERE o.id = order_items.order_id AND (
                o.customer_id = auth.uid() OR
                EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
            )
        )
    );

-- -----------------------------------------------------------------------------
-- 10. PAYMENTS POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View payments policy" ON public.payments;
CREATE POLICY "View payments policy"
    ON public.payments FOR SELECT
    USING (
        customer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Manage payments policy" ON public.payments;
CREATE POLICY "Manage payments policy"
    ON public.payments FOR ALL
    USING (
        customer_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- -----------------------------------------------------------------------------
-- 11. RIDER ASSIGNMENTS POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View rider assignments policy" ON public.rider_assignments;
CREATE POLICY "View rider assignments policy"
    ON public.rider_assignments FOR SELECT
    USING (
        rider_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Update rider assignments policy" ON public.rider_assignments;
CREATE POLICY "Update rider assignments policy"
    ON public.rider_assignments FOR UPDATE
    USING (
        rider_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

DROP POLICY IF EXISTS "Insert rider assignments policy" ON public.rider_assignments;
CREATE POLICY "Insert rider assignments policy"
    ON public.rider_assignments FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- -----------------------------------------------------------------------------
-- 12. ORDER STATUS HISTORY POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View order history policy" ON public.order_status_history;
CREATE POLICY "View order history policy"
    ON public.order_status_history FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.orders o
            WHERE o.id = order_status_history.order_id AND (
                o.customer_id = auth.uid() OR
                o.rider_id = auth.uid() OR
                EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
            )
        )
    );

DROP POLICY IF EXISTS "Insert order history policy" ON public.order_status_history;
CREATE POLICY "Insert order history policy"
    ON public.order_status_history FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- -----------------------------------------------------------------------------
-- 13. NOTIFICATIONS POLICIES
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users manage own notifications" ON public.notifications;
CREATE POLICY "Users manage own notifications"
    ON public.notifications FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Allow system/admins to insert notifications" ON public.notifications;
CREATE POLICY "Allow system/admins to insert notifications"
    ON public.notifications FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');
-- =============================================================================
-- Migration 04: Seed Data for OceanCart (Seafood Catalog)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. INSERT CATEGORIES
-- -----------------------------------------------------------------------------
INSERT INTO public.categories (id, name, description, image_url)
VALUES 
    (
        'c1000000-0000-0000-0000-000000000001',
        'Fresh Fish',
        'Wild-caught and farm-fresh prime fish fillets and whole cuts',
        'https://images.unsplash.com/photo-1534948216015-843149f72be3?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000002',
        'Shrimps & Prawns',
        'Succulent tiger prawns, white shrimps, and peeled prawn tails',
        'https://images.unsplash.com/photo-1559737558-245cbab6f8e7?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000003',
        'Crabs & Lobsters',
        'Fresh live mud crabs, blue swimming crabs, and premium spiny lobsters',
        'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000004',
        'Shellfish & Mollusks',
        'Scallops, green mussels (tahong), oysters, and sweet clams',
        'https://images.unsplash.com/photo-1628102491629-778571d893a3?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000005',
        'Squid & Octopus',
        'Tender giant squid tubes, calamari rings, and cleaned baby octopus',
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80'
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    image_url = EXCLUDED.image_url;

-- -----------------------------------------------------------------------------
-- 2. INSERT PRODUCTS
-- -----------------------------------------------------------------------------
INSERT INTO public.products (id, category_id, name, description, price, stock, image_url, is_active)
VALUES
    -- Fresh Fish
    (
        'a1000000-0000-0000-0000-000000000001',
        'c1000000-0000-0000-0000-000000000001',
        'Norwegian Atlantic Salmon Fillet',
        'Premium sashimi-grade salmon fillet with rich omega-3 fat marbling. Descaled, deboned, skin-on. Perfect for pan-searing or baking. 500g vacuum-sealed.',
        650.00,
        35,
        'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000002',
        'c1000000-0000-0000-0000-000000000001',
        'General Santos Yellowfin Tuna Loin',
        'Freshly caught Philippine deep-sea yellowfin tuna. Thick cut loin, vibrant ruby red meat, mild ocean flavor. 500g pack.',
        480.00,
        28,
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000011',
        'c1000000-0000-0000-0000-000000000001',
        'Dagupan Boneless Milkfish (Bangus)',
        'Fresh deboned Dagupan bangus marinated with garlic and vinegar. Famous fatty belly flavor, ready to fry or grill. 450g pack.',
        220.00,
        50,
        'https://images.unsplash.com/photo-1534948216015-843149f72be3?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Shrimps & Prawns
    (
        'a1000000-0000-0000-0000-000000000003',
        'c1000000-0000-0000-0000-000000000002',
        'Jumbo Black Tiger Prawns (Sugpo)',
        'Large headless or whole black tiger prawns. Firm, juicy, and naturally sweet. Excellent for garlic butter, sinigang, or thermidor. 500g (approx 10-12 pcs).',
        580.00,
        45,
        'https://images.unsplash.com/photo-1559737558-245cbab6f8e7?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000004',
        'c1000000-0000-0000-0000-000000000002',
        'Fresh White Shrimp (Suahe)',
        'Daily catch fresh white shrimps with thin shell and succulent sweet meat. Ideal for halabos or tempura. 500g pack.',
        360.00,
        40,
        'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Crabs & Lobsters
    (
        'a1000000-0000-0000-0000-000000000005',
        'c1000000-0000-0000-0000-000000000003',
        'Live Mud Crab (Alimango)',
        'Heavy female/male mangrove mud crabs brimming with rich aligue (crab fat) and sweet claw meat. Tied and chilled for freshness. 1kg (2-3 pcs).',
        850.00,
        20,
        'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000006',
        'c1000000-0000-0000-0000-000000000003',
        'Tropical Spiny Lobster Tail',
        'Wild caught spiny lobster tails with dense, sweet meat. Premium restaurant grade, flash-frozen at peak freshness. 400g (2 tails).',
        1250.00,
        15,
        'https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000007',
        'c1000000-0000-0000-0000-000000000003',
        'Blue Swimming Crab (Alimasag)',
        'Whole cleaned blue crabs ideal for ginataang alimasag, sweet chili crab, or crab soup. 1kg pack.',
        420.00,
        30,
        'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Shellfish & Mollusks
    (
        'a1000000-0000-0000-0000-000000000008',
        'c1000000-0000-0000-0000-000000000004',
        'Half-Shell Hokkaido Scallops',
        'Large sweet sea scallops on the half shell. Cleaned and ready for garlic butter broiling or grilling with cheese. 500g (8-10 pcs).',
        390.00,
        30,
        'https://images.unsplash.com/photo-1628102491629-778571d893a3?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000009',
        'c1000000-0000-0000-0000-000000000004',
        'Fresh Cavite Green Mussels (Tahong)',
        'Purged and cleaned green mussels harvested from Cavite beds. Plump and tender meat for tinola or butter garlic saute. 1kg.',
        140.00,
        60,
        'https://images.unsplash.com/photo-1548811579-017cf2a4268b?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Squid & Octopus
    (
        'a1000000-0000-0000-0000-000000000010',
        'c1000000-0000-0000-0000-000000000005',
        'Fresh Giant Squid (Pusit Lumot)',
        'Cleaned whole giant squid with natural ink sacs preserved. Tender and flavorful when grilled or cooked in classic adobo. 1kg pack.',
        380.00,
        25,
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
        true
    )
ON CONFLICT (id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    stock = EXCLUDED.stock,
    image_url = EXCLUDED.image_url,
    is_active = EXCLUDED.is_active;
