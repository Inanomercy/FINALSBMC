# OceanCart - Production Setup & Deployment Guide

This guide details the complete configuration, database deployment, Edge Functions setup, Xendit payment gateway integration, and testing instructions for **OceanCart**.

---

## 1. Environment & Architecture Overview

OceanCart is built with:
- **Frontend**: Flutter (Material 3, Provider, GoRouter) supporting Customer, Admin, and Rider roles in a unified app.
- **Backend**: Supabase (PostgreSQL, Row Level Security, Auth, Storage, Edge Functions).
- **Payment Gateway**: Xendit API & Webhooks.

---

## 2. Supabase Database Migration

All database tables, constraints, triggers, functions, and RLS policies are organized in `supabase/migrations/`:

| Migration File | Description |
|---|---|
| `20241031000001_create_schema.sql` | Core tables (`profiles`, `categories`, `products`, `product_images`, `cart_items`, `orders`, `order_items`, `payments`, `rider_assignments`, `order_status_history`, `notifications`) |
| `20241031000002_functions_and_triggers.sql` | `handle_new_user` auth trigger, inventory deduction/restoration, rider assignment, delivery acceptance |
| `20241031000003_storage_and_rls.sql` | Storage buckets (`product-images`, `category-images`, `avatars`) and comprehensive RLS policies |
| `20241031000004_seed_data.sql` | Initial seafood categories and fresh seafood catalog |
| `all_migrations_combined.sql` | Complete script combining all 4 migrations for 1-click execution |

### Applying Migrations to Supabase:
1. Open the [Supabase Dashboard](https://supabase.com/dashboard/project/bjpybpumzhdesyzucexq).
2. Go to **SQL Editor** from the left navigation menu.
3. Open `supabase/migrations/all_migrations_combined.sql` in your editor, copy the contents, paste them into the SQL Editor, and click **Run**.
4. All tables, functions, triggers, and seed products will be created immediately.

---

## 3. Supabase Edge Functions Deployment

The project includes 6 serverless backend functions in `supabase/functions/`:

1. **`create-rider`**: Admin-only endpoint to securely provision rider credentials via `auth.admin.createUser`.
2. **`checkout`**: Server-side validation of cart items, stock checks, PHP subtotal calculation, Xendit invoice creation, and atomic stock deduction.
3. **`create-payment`**: Re-initiates or fetches Xendit invoice for existing unpaid orders.
4. **`xendit-webhook`**: Webhook endpoint to receive payment callbacks (`PAID`, `EXPIRED`), verify token, update order status, and log order history.
5. **`assign-rider`**: Assigns an eligible order to an active rider and sends real-time in-app notification.
6. **`accept-delivery`**: Concurrency-safe delivery acceptance or rejection by assigned riders.

### Deploying Edge Functions:
Run the following commands using the Supabase CLI:

```bash
# Login to Supabase CLI
npx supabase login

# Link your project
npx supabase link --project-ref bjpybpumzhdesyzucexq

# Set required secrets for Edge Functions
npx supabase secrets set XENDIT_SECRET_KEY="xnd_development_bDcrZdYMJashHCYsKshovf6B2KByWB8hY4enL9WyAdosnncnyCVimWJIDm9x"
npx supabase secrets set XENDIT_WEBHOOK_VERIFICATION_TOKEN="your_webhook_token_here"

# Deploy all 6 functions
npx supabase functions deploy create-rider --no-verify-jwt
npx supabase functions deploy checkout
npx supabase functions deploy create-payment
npx supabase functions deploy xendit-webhook --no-verify-jwt
npx supabase functions deploy assign-rider
npx supabase functions deploy accept-delivery
```

---

## 4. Xendit Payment Gateway Configuration

1. Log into your [Xendit Dashboard](https://dashboard.xendit.co/).
2. Navigate to **Settings** > **Developers** > **API Keys**:
   - Ensure your Secret Key matches `OceanCart` / `XENDIT_SECRET_KEY`.
3. Navigate to **Settings** > **Developers** > **Webhooks**:
   - Set the Invoice Paid Webhook URL to:
     ```
     https://bjpybpumzhdesyzucexq.supabase.co/functions/v1/xendit-webhook
     ```
   - Copy the **Webhook Verification Token** and set it in Supabase secrets as `XENDIT_WEBHOOK_VERIFICATION_TOKEN`.
   - Test the webhook using Xendit's "Test Webhook" button.

---

## 5. Flutter Application Setup & Execution

### 1. Configure Configuration Constants:
File: `lib/core/constants/app_constants.dart`
```dart
static const String supabaseUrl = 'https://bjpybpumzhdesyzucexq.supabase.co';
static const String supabaseAnonKey = 'sb_publishable_tumTQnd97CGHtzkooSfGQw_6JTmnSt3';
```

### 2. Install Dependencies:
```bash
flutter pub get
```

### 3. Run Flutter Analyze:
```bash
flutter analyze
```

### 4. Run the Application:
```bash
# Run on connected Android / iOS device or emulator
flutter run

# Run on Chrome for web preview
flutter run -d chrome
```

---

## 6. Testing Instructions & Test Accounts

### A. Customer Workflow Testing:
1. Open the application.
2. Click **Register** on the Login screen.
3. Fill in Full Name, Email, Password, Contact Number, and Delivery Address.
4. Browse seafood categories and products on the Home screen.
5. Tap a product (e.g., *Norwegian Atlantic Salmon Fillet*) to open the details page.
6. Select quantity and click **Add to Cart**.
7. Go to **Cart**, review subtotal, delivery fee, and click **Proceed to Checkout**.
8. Select GCash / Maya payment method and click **Place Order & Pay**.
9. The secure Xendit checkout will open. Upon payment, order status updates to `Pending Confirmation`.

### B. Admin Workflow Testing:
To promote a user to Administrator, run this in Supabase SQL Editor:
```sql
UPDATE public.profiles 
SET role = 'admin' 
WHERE email = 'admin@oceancart.com';
```
1. Log in with the admin account.
2. The Admin Dashboard displays live metrics: Total Products, Orders, Revenue, and Riders.
3. Go to **Products** to add, edit, or toggle seafood items.
4. Go to **Riders** to view active riders and click `+` to add a new rider.
5. Go to **Orders** to see incoming paid orders, click an order, and tap **Assign Rider**.

### C. Rider Workflow Testing:
1. Log in with the rider account created by the Admin.
2. The Rider Dashboard shows assigned jobs.
3. Tap the assigned delivery card to open **Delivery Details**.
4. Click **Accept Delivery Job** (order updates to `Rider Accepted`).
5. Click **Confirm Picked Up from Store** (order updates to `Picked Up`).
6. Click **Start Delivery** (order updates to `Out for Delivery`).
7. Customer can track live status in their **Orders** timeline.
8. Click **Mark as Delivered to Customer** once completed.
