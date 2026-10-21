# Books, Wishes & Serendipity

Next.js 15 + React 19 + Tailwind CSS 4, Supabase PostgreSQL/Auth and Resend.

繁體中文設定清單：[本機與服務設定](docs/SETUP.zh-TW.md)。

## Local development

Use Node.js 22 or 24. From `/workspace/Book-Club`:

```sh
npm ci --cache /tmp/book-club-npm
test -f .env.local || cp .env.example .env.local
npm run dev
```

The landing page and form can render without credentials. Registration, edits and organizer features require a real Supabase project; no sample registration is silently stored in browser storage. Only the successful registration's private edit link is remembered in session storage.

1. Create a Supabase project and execute `supabase/schema.sql` once in its SQL editor. It creates server-only tables, transactional registration/edit/matching RPCs, and a sample event. Update the event's venue, capacity, fee and dates before opening registration. Sample fee is NT$0, capacity 50; these are defaults, not confirmed event details.
2. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and server-only `SUPABASE_SERVICE_ROLE_KEY` in `.env.local` or secure deployment settings. Never expose the service role key in client code.
3. Create the organizer in Supabase Authentication (email/password); disable public signups for the project. Set `ADMIN_EMAIL` to that exact organizer email. Server routes independently verify the Supabase user and this allowlist.
4. Verify your sending domain in Resend. Set `RESEND_API_KEY` and `EMAIL_FROM` to an approved sender. Set `APP_URL` to the actual HTTPS deployment origin for edit links (local testing: http://localhost:3000).
5. Restart Next.js after changing variables. Sign in at `/admin/login`.

No credentials should be pasted into chat or committed. The public anon key is intended for browser authentication; all event/participant/match data access is performed server-side. RLS has no public data policies and RPC execution is restricted to service_role.

## Routes and workflow

- `/`: event information, invitation and Secret Wish explanation.
- `/register`: three-step form. Required identity, email, phone and book validation; 300-character introduction; first wish required for Secret Wish.
- `/success`: confirmation and private edit link; explicitly reports unsuccessful confirmation email delivery.
- `/edit/[token]`: bearer-link editing using 256-bit random tokens. Treat links as private. Participation is locked after generation.
- `/admin`: live registration, wishlist and delivery counts.
- `/admin/participants`: search, filters and participant details.
- `/admin/secret-wish`: confirm generation, preview full matches, then separately confirm notification delivery. Failed/unsent messages can be retried; sent messages are skipped. Resend idempotency keys also protect provider retries within its retention window.

Add bidirectional exclusions directly in `match_restrictions` via Supabase SQL editor before generating. Circular shuffle uses cryptographic randomness and retries up to 1000 times. Generation is transactional and cannot overwrite existing matches. Registration and editing coordinate with matching through an event row lock, preventing capacity races and participation changes after matching. Duplicate emails are rejected per event.

## Validation

```sh
npm test
npm run build
npm start
```

Database tests run the actual SQL schema in an ephemeral PGlite PostgreSQL engine without credentials; they cover registration, edits, capacity/deadline limits, atomic matching, participation locks and RPC privileges.

Matching tests cover unique givers/receivers, no self-match, two-person input, invalid input, bidirectional restrictions, and impossible restrictions. Full registration/Auth/email integration requires the external services above. Test with two owned inboxes; confirm edits and wishlist details, generate once, verify locked participation and separate send confirmation, then inspect actual inbox delivery. Do not send test messages to other people without authorization.

## Deployment

Import into Vercel, configure the same variables and production `APP_URL`, then deploy. No payment handling or public accounts are included. Single-event MVP: routes select the first configured event; keep exactly one event in this version. Organizer tooling intentionally does not regenerate matches or edit event settings/restrictions. Apply appropriate hosted rate limiting/bot protection before a public launch; private tokens should be kept out of analytics/logging. Confirmation delivery failures currently surface to the registrant with their saved edit link; there is no confirmation-email retry dashboard yet.
