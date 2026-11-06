# Xendit Setup for OceanCart

This project keeps the Xendit secret key and webhook token on the Supabase backend only. Flutter must never receive or store them.

## Required Supabase secrets

Set these in Supabase Edge Function secrets:

- `XENDIT_SECRET_KEY`
- `XENDIT_CALLBACK_TOKEN`
- `APP_BASE_URL`

The project also uses:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`

## Deployment commands

From the app directory:

```bash
cd myapp
npx supabase login
npx supabase link --project-ref bjpybpumzhdesyzucexq
npx supabase secrets set XENDIT_SECRET_KEY="<your_xendit_secret_key>" XENDIT_CALLBACK_TOKEN="<your_webhook_token>" APP_BASE_URL="https://your-app-domain.com"
npx supabase functions deploy create-xendit-invoice
npx supabase functions deploy xendit-webhook --no-verify-jwt
```

## Webhook URL

The exact webhook endpoint is:

```text
https://bjpybpumzhdesyzucexq.supabase.co/functions/v1/xendit-webhook
```

Configure this URL in the Xendit dashboard under webhook settings.

## Xendit webhook setup

1. In the Xendit Dashboard, open Settings > Webhooks.
2. Set the webhook URL to the Supabase function URL above.
3. Set the callback token to the same value configured as `XENDIT_CALLBACK_TOKEN` in Supabase.
4. Enable webhook events for invoice status changes such as `PAID`, `FAILED`, and `EXPIRED`.
5. Verify that the request includes the `x-callback-token` header.

## Test mode instructions

Use Xendit test mode during development:

- Use the development secret key from the Xendit dashboard.
- Test invoice creation in sandbox.
- Trigger webhook events manually from the Xendit Dashboard or from invoice test flows.
- Confirm that the `payment_status` in `orders` changes to `paid`, `failed`, or `expired` only from the server-side webhook.

## Payment testing checklist

- [ ] Customer order creates a valid invoice.
- [ ] `orders.payment_status` remains `pending` until webhook confirmation.
- [ ] Duplicate payment requests for same order are ignored.
- [ ] Unauthorized user cannot access another customer order.
- [ ] Webhook with invalid token is rejected with `401`.
- [ ] Duplicate webhook does not double-process the payment.
- [ ] Failed or expired invoice updates the order correctly.
- [ ] Customer sees pending, paid, failed, and expired states in the app after refresh.

## Notes

- Never hardcode `XENDIT_SECRET_KEY` in Flutter code.
- Never trust the app redirect alone as proof of payment.
- Always process payment success via the server-side webhook and update the order record from Supabase.
