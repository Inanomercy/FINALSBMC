# OceanCart Xendit Integration Diagnostic Report

Date: 2026-10-31

This report is based on static inspection and executed local checks only. No production deployment was performed, and no secrets were exposed.

## Executed checks
- `deno check supabase/functions/create-xendit-invoice/index.ts`
- `deno check supabase/functions/xendit-webhook/index.ts`
- `flutter analyze`
- `flutter test test/xendit_payment_integration_test.dart`
- `npx supabase functions list` (failed because the local Supabase CLI is not authenticated)

## Summary table

| Item | Status | Details |
|---|---|---|
| Invoice Function | PASS | `deno check` on `supabase/functions/create-xendit-invoice/index.ts` completed successfully with no TypeScript errors. The function validates bearer auth, ownership, amount, and calls Xendit server-side. |
| Webhook Function | PASS | `deno check` on `supabase/functions/xendit-webhook/index.ts` completed successfully with no TypeScript errors. The function validates `x-callback-token`, maps payment status, and handles duplicate idempotent updates. |
| Xendit API | FAIL | Not live-validated against the real Xendit API in this environment. Local static validation passed, but no remote API call was executed here. |
| Supabase Database | PASS | Static inspection of `supabase/migrations/20241031000001_create_schema.sql` and related migrations confirms the expected tables and columns for `orders`, `order_items`, and `payments` are present. |
| Authentication | PASS | Static review confirms the invoice function uses `Authorization: Bearer <session>` and calls `auth.getUser()`. The webhook checks the callback token header. |
| Flutter Checkout | PASS | `flutter analyze` reported no issues, and the checkout flow is wired to the secure Edge Function URL with bearer-token authentication. |
| Tests | PASS | `flutter test test/xendit_payment_integration_test.dart` completed successfully: `All tests passed!` |

## Actual errors

### 1) Supabase CLI is not authenticated for remote function checks
- Exact error message: `Access token not provided. Supply an access token by running supabase login or setting the SUPABASE_ACCESS_TOKEN environment variable.`
- File path: `N/A (Supabase CLI environment, not a source file)`
- Line number: `N/A`
- Root cause: The local environment is not logged into Supabase; therefore, remote function configuration checks cannot run.
- Recommended fix: Run `supabase login` or configure `SUPABASE_ACCESS_TOKEN` before running remote Supabase CLI commands.

### 2) Local environment uses mismatched Supabase/Xendit variable names
- Exact error message: `None from the compiler; this is a configuration mismatch discovered during code inspection.`
- File path: `myapp/.env`
- Line number: `8-10`
- Root cause: The webhook function reads `XENDIT_WEBHOOK_TOKEN` (or `XENDIT_WEBHOOK_VERIFICATION_TOKEN`), but the project `.env` uses `WEBHOOK_SECRET_KEY`. Also, `APP_BASE_URL` points to a Supabase function endpoint instead of a public app callback origin.
- Recommended fix: Use the exact names expected by the Edge Functions:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `XENDIT_SECRET_KEY`
  - `XENDIT_WEBHOOK_TOKEN`
  - `APP_BASE_URL`

### 3) Legacy Edge Functions still contain mock/insecure fallback logic
- Exact error message: `No compiler error; logic issue found during review.`
- File path: `myapp/supabase/functions/create-payment/index.ts` and `myapp/supabase/functions/checkout/index.ts`
- Line number: `17`, `91`; `18`, `166`
- Root cause: Both legacy files use `Deno.env.get("OceanCart")` and fall back to a mock Xendit URL:
  - `https://checkout.xendit.co/web/mock-invoice/...`
  This allows a non-production payment path that bypasses the secure invoice flow when the env is missing or stale.
- Recommended fix: Remove or disable these legacy mock fallback paths and ensure checkout is routed exclusively through the secure `create-xendit-invoice` function.

### 4) `supabase/config.toml` is not present in the workspace
- Exact error message: `Unable to resolve nonexistent file 'c:\Users\Laptop Supplier PH\Desktop\seafood_finals\myapp\supabase\config.toml'`
- File path: `myapp/supabase/config.toml`
- Line number: `N/A`
- Root cause: The project does not currently contain a `supabase/config.toml` file, so local Supabase project-level config was not present for inspection.
- Recommended fix: Add the proper project config if this repo is meant to use a local Supabase project setup, or rely on the actual deployed Supabase project configuration.

## Warnings

### 1) Legacy UI/Flutter fallback logic still checks for mock URLs
- Exact warning: `mock-invoice` string detection in checkout logic
- File path: `myapp/lib/features/customer/checkout/checkout_screen.dart`
- Line number: `97`, `127`
- Root cause: The app explicitly treats mock Xendit URLs as a fallback condition. This is a defensive guard, but it is not a production payment path.
- Recommended fix: Keep the guard only for local testing; do not allow mock URLs in production checkout.

### 2) Payment service also recognizes mock fallback URLs
- Exact warning: `checkoutUrl.contains('xendit.co/web/mock-invoice')`
- File path: `myapp/lib/features/payments/services/payment_service.dart`
- Line number: `43`
- Root cause: The client still has a mock fallback branch and could interpret a non-production URL as acceptable behavior.
- Recommended fix: Restrict or remove mock detection outside controlled non-production environments.

### 3) `APP_BASE_URL` is not a valid public callback origin for a real checkout flow
- Exact warning: `APP_BASE_URL=https://bjpybpumzhdesyzucexq.supabase.co/functions/v1/websocket-server`
- File path: `myapp/.env`
- Line number: `10`
- Root cause: This is a function endpoint, not an app or frontend origin, and it is the wrong target for Xendit redirect callbacks.
- Recommended fix: Set `APP_BASE_URL` to the public domain of the frontend app or the correct callback host, not a websocket function route.

## Key findings by area

### Invoice Function
- Status: PASS for static compilation and logic validation.
- Evidence: `deno check supabase/functions/create-xendit-invoice/index.ts` succeeded.
- Findings:
  - Validates `Authorization: Bearer` and `auth.getUser()`
  - Validates `customer_id`/`order_id` ownership
  - Verifies order total against server-side product prices
  - Uses `Basic ${btoa(`${xenditSecretKey}:`)}` with the Xendit invoice API
  - Stores payment record with `status: "pending"`
- No compile errors were reported by the executed Deno check.

### Webhook Function
- Status: PASS for static compilation and logic validation.
- Evidence: `deno check supabase/functions/xendit-webhook/index.ts` succeeded.
- Findings:
  - Validates `x-callback-token` against `XENDIT_WEBHOOK_TOKEN`
  - Handles `PAID`, `FAILED`, and `EXPIRED` states
  - Uses an idempotent duplicate detection path when `order.payment_status === "paid"`
  - Looks up order by `external_id` or payment reference and updates payment/order records server-side
- No compile errors were reported by the executed Deno check.

### Xendit API
- Status: FAIL (not live-validated here)
- Evidence: No live Xendit API call was performed in this environment.
- Findings:
  - The code is valid structurally and correctly sets basic auth headers.
  - However, real-world API readiness still depends on live credentials and Xendit dashboard configuration.
- Recommended next step: Perform a sandbox validation with the real remote project after proper secret setup.

### Supabase Database
- Status: PASS (static schema validation)
- Evidence: `supabase/migrations/20241031000001_create_schema.sql` includes `orders`, `order_items`, `payments`, and `order_status_history` with the required fields and constraints.
- Findings:
  - `orders.payment_status` accepts `pending`, `paid`, `failed`, and `expired`
  - `orders.order_status` accepts the relevant app states
  - `payments` stores `amount`, `status`, `checkout_url`, `payment_reference`
  - `order_status_history` gives an audit trail for updates
- No schema mismatch was found in the inspected migrations.

### Authentication
- Status: PASS
- Evidence: The invoice function obtains the user from `auth.getUser()` using the bearer token passed from the Flutter client. The webhook function validates the callback token from the request header.
- Findings:
  - The app passes `Authorization: Bearer <accessToken>` from the current session
  - The invoice function verifies the authenticated user owns the order
  - The webhook verifies `x-callback-token` before processing

### Flutter Checkout
- Status: PASS
- Evidence: `flutter analyze` produced `No issues found!` and the checkout flow correctly calls the secure Edge Function.
- Findings:
  - `myapp/lib/features/customer/checkout/checkout_screen.dart` posts to `${AppConstants.supabaseUrl}/functions/v1/create-xendit-invoice`
  - The function is called with the signed-in user’s access token
  - If the secure function fails, the app falls back to direct order creation in a local fallback path, which is not a secure production flow and should be considered a warning

### Tests
- Status: PASS
- Evidence: `flutter test test/xendit_payment_integration_test.dart` returned `All tests passed!`
- Findings:
  - Local automated tests covering payment/integration logic are green.
  - This validates code-level behavior in the workspace, not live remote deployment.

## Final conclusion
The current workspace shows no TypeScript or Flutter analyzer errors in the secure Xendit flow, and the relevant tests passed. The main remaining issue is environment and deployment configuration rather than code-level correctness. The repo must still be configured with live Supabase/Xendit secrets and a valid public callback URL before any real payment flow is considered production-ready.
