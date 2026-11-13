# VYLOOP SOCIAL

Cloudflare Pages starter package for the VYLOOP SOCIAL frontend.

## Deploy the ZIP
1. Download `VYLOOP-SOCIAL-CLOUDFLARE.zip` from the ChatGPT conversation.
2. Open Cloudflare Dashboard → Workers & Pages → Create → Pages → Upload assets.
3. Upload the ZIP (its root contains `index.html`, `_headers`, and `_redirects`).
4. Name the project `vyloop-social` and deploy.

## Included in this first frontend build
- Responsive dark-purple VYLOOP interface
- Supabase email/password authentication
- 18+ signup sending date of birth as auth metadata for server-side database validation
- Public text feed and authenticated text-post publishing

The browser uses the Supabase publishable key only. Never place a service-role/secret key in frontend code.

## Current scope
This is an initial deployable frontend foundation, not the complete social platform. Messaging, media uploads, comments, reactions, notifications, profile editing, admin dashboard, moderation tools and additional production hardening remain to be built. Test registration, email confirmation, login and posting before public launch.