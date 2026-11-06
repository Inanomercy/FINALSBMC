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
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Admins can update product images" ON storage.objects;
CREATE POLICY "Admins can update product images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'product-images' AND 
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Admins can delete product images" ON storage.objects;
CREATE POLICY "Admins can delete product images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'product-images' AND 
        public.is_admin(auth.uid())
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
        public.is_admin(auth.uid()) OR
        role = 'rider'
    );

DROP POLICY IF EXISTS "Allow user to update own profile" ON public.profiles;
CREATE POLICY "Allow user to update own profile"
    ON public.profiles FOR UPDATE
    USING (
        auth.uid() = id OR 
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Allow profile inserts" ON public.profiles;
CREATE POLICY "Allow profile inserts"
    ON public.profiles FOR INSERT
    WITH CHECK (
        auth.uid() = id OR
        public.is_admin(auth.uid())
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
