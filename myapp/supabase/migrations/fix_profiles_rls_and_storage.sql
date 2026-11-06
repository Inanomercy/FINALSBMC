-- =============================================================================
-- Migration: Fix Infinite Recursion in Profiles RLS & Supabase Storage 503 Error
-- Target project: bjpybpumzhdesyzucexq
-- =============================================================================

-- 1. Ensure helper function is_admin is SECURITY DEFINER with public search path
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(
        (SELECT role = 'admin' FROM public.profiles WHERE id = p_user_id),
        false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Fix public.profiles RLS policies (breaks infinite recursion loop)
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

-- 3. Fix storage.objects RLS policies
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
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Admins can update category images" ON storage.objects;
CREATE POLICY "Admins can update category images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'category-images' AND 
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Admins can delete category images" ON storage.objects;
CREATE POLICY "Admins can delete category images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'category-images' AND 
        public.is_admin(auth.uid())
    );

-- 4. Fix products policies to use is_admin function
DROP POLICY IF EXISTS "Allow viewing products" ON public.products;
CREATE POLICY "Allow viewing products"
    ON public.products FOR SELECT
    USING (
        is_active = true OR 
        public.is_admin(auth.uid())
    );

DROP POLICY IF EXISTS "Allow admins to insert products" ON public.products;
CREATE POLICY "Allow admins to insert products"
    ON public.products FOR INSERT
    WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Allow admins to update products" ON public.products;
CREATE POLICY "Allow admins to update products"
    ON public.products FOR UPDATE
    USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Allow admins to delete products" ON public.products;
CREATE POLICY "Allow admins to delete products"
    ON public.products FOR DELETE
    USING (public.is_admin(auth.uid()));
