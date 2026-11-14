# VYLOOP SOCIAL

Cloudflare Pages frontend for VYLOOP SOCIAL.

## Authentication and 18+ access

- Email/password login and registration use Supabase Auth.
- Signup requires a date of birth selected with the browser's date picker.
- The browser validates strict calendar dates, rejects future dates, and calculates completed age by comparing year/month/day (not elapsed seconds).
- The database auth trigger is authoritative: it rejects missing, malformed, impossible, future and under-18 dates.
- Date of birth is stored only in `private.user_birth_dates`. The trigger removes the temporary `date_of_birth` signup metadata from `auth.users.raw_user_meta_data` immediately after storing it.
- The public `profiles` table has no DOB column; the private schema is not exposed to anon/authenticated clients and the birth-date table has a deny-client RLS policy.
- Signup does not grant admin privileges. Existing admin assignments are left unchanged.

The browser uses the Supabase publishable key only. Never place a service-role or secret key in frontend code.

## Regression tests

Run `supabase/tests/18_plus_birth_date_validation.sql` against the linked project. It tests the private server-side validator without creating test Auth users or changing application data.

## Deployment

This repository is a static Cloudflare Pages site. Upload the repository root as Pages assets or connect the repository to Cloudflare Pages. The root contains `index.html`, `chat.js`, `_headers` and `_redirects`.

Before public launch, test a real signup with an adult test email, confirm the email flow, sign in, and verify the deployed Pages domain and Auth redirect URLs in Supabase.
