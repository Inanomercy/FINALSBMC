-- =============================================================================
-- SQL Script: Create or Update Admin Account in Supabase
-- Target Email: admin@gmail.com
-- Password: Admin@123
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$
DECLARE
    v_user_id UUID;
    v_email TEXT := 'admin@gmail.com';
    v_password TEXT := 'Admin@123';
    v_encrypted_password TEXT;
BEGIN
    -- Encrypt password using bcrypt
    v_encrypted_password := crypt(v_password, gen_salt('bf'));

    -- Check if the user already exists in auth.users
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

    IF v_user_id IS NULL THEN
        -- Generate user ID
        v_user_id := gen_random_uuid();

        -- 1. Insert into auth.users (email pre-confirmed)
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            recovery_token,
            email_change_token_new,
            email_change
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_email,
            v_encrypted_password,
            NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"full_name":"System Administrator","role":"admin"}'::jsonb,
            NOW(),
            NOW(),
            '',
            '',
            '',
            ''
        );
    ELSE
        -- Update password and confirmation if already exists
        UPDATE auth.users
        SET 
            encrypted_password = v_encrypted_password,
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            raw_user_meta_data = jsonb_set(
                COALESCE(raw_user_meta_data, '{}'::jsonb),
                '{role}',
                '"admin"'
            ),
            updated_at = NOW()
        WHERE id = v_user_id;
    END IF;

    -- 2. Insert or update public.profiles with role = 'admin'
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        role,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        'System Administrator',
        v_email,
        'admin',
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        role = 'admin',
        is_active = TRUE,
        full_name = 'System Administrator',
        updated_at = NOW();

    RAISE NOTICE 'Admin user created/updated successfully with ID: %', v_user_id;
END $$;
