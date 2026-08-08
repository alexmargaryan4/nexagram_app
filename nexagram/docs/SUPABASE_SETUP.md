# NexaGram — Supabase Setup

This guide takes you from an empty Supabase project to a working NexaGram
backend: Authentication, the Postgres schema (chats, messages, users,
contacts, typing indicators), Row Level Security, Storage, and Realtime
(which also powers foreground/background push notifications). Everything
here works from a phone browser — no terminal required, and no billing
account needed at any tier used by this app.

---

## 1. Prerequisites

- A free [Supabase](https://supabase.com) account
- The Flutter SDK already set up for this project (`flutter doctor`)

No CLI installs are required — this app talks to Supabase purely over
its client library (`supabase_flutter`), and setup is done entirely from
the Supabase dashboard.

---

## 2. Create the Supabase project

1. Go to the [Supabase dashboard](https://supabase.com/dashboard) → **New project**.
2. Name it (e.g. `nexagram-app`), pick a region close to your users, and
   set a database password (you won't need it day-to-day — the app only
   ever uses the anon key).
3. Wait for provisioning to finish (~2 minutes).

---

## 3. Run the database schema

1. Open **SQL Editor** in the left sidebar.
2. Open `supabase_schema.sql` from the project root, copy the whole file,
   paste it into the editor, and click **Run**.

This creates every table (`users`, `chats`, `messages`, `typing_status`,
`contacts`), all Row Level Security policies, the Realtime publication,
and four RPC functions (`send_message`, `mark_chat_as_read`,
`toggle_reaction`, `search_users`) that the app calls for operations that
need to happen atomically (the equivalent of the old Firestore
`WriteBatch` / `FieldValue.increment` calls).

The script is idempotent — safe to re-run if you ever need to.

---

## 4. Run the Storage policy

1. Still in **SQL Editor**, open a new query.
2. Copy the contents of `supabase_storage_policy.sql` from the project
   root and run it.

This creates the `nexagram` Storage bucket (public — reachable by URL,
same trust model the old Firebase Storage rules used) and the policies
that let signed-in users upload/read/delete avatars and chat media.

---

## 5. Enable email/password sign-in

1. Go to **Authentication → Providers**.
2. Confirm **Email** is enabled (it is by default).
3. Optional but recommended for a real launch: **Authentication →
   Settings** → turn *off* "Confirm email" only if you want frictionless
   sign-up during development; leave it *on* for production so
   `register()` behaves the way users expect (they'll get a confirmation
   email before they can sign in).
4. Optional: customize the email templates under **Authentication →
   Email Templates** to match NexaGram's branding.

### Redirect URLs (required — without this, confirmation links open a dead `localhost` page)

By default, Supabase sends the user back to your project's **Site URL**
after they tap the confirmation/password-reset link in the email — which
is a placeholder like `http://localhost:3000` and does nothing on a
phone. The app instead asks Supabase to redirect to the custom deep link
`nexagram://login-callback` (see `kEmailRedirectTo` in
`lib/services/auth_service.dart`), which opens the app directly. For
Supabase to honor that, the URL must be allow-listed:

1. Go to **Authentication → URL Configuration**.
2. Under **Redirect URLs**, add:
   ```
   nexagram://login-callback
   ```
3. Save.

If this step is skipped, GoTrue silently falls back to the Site URL and
confirmation/reset links keep landing on `localhost` exactly as before —
this is a dashboard setting, not something the app can configure itself.

---

## 6. Get your project credentials

Go to **Project Settings → API**. You need two values:

- **Project URL** — looks like `https://xxxxxxxxxxxx.supabase.co`
- **anon / public key** — a long JWT starting with `eyJ...`

These are safe to embed in the client (they're what Supabase's own docs
tell you to ship in mobile apps) — access control is enforced server-side
by the RLS policies from step 3, not by keeping this key secret.

---

## 7. Configure the app

Values are read from `--dart-define` at build time, so nothing sensitive
needs to be hand-edited or committed:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

For day-to-day local development, it's easiest to create a
`.vscode/launch.json` entry or an Android Studio run configuration with
these two `--dart-define` flags baked in, so you don't have to retype
them every run.

### GitHub Actions builds

`.github/workflows/build.yml` passes these automatically from repository
secrets — set them once under **Settings → Secrets and variables →
Actions** in your GitHub repo:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

No local setup is needed to build via CI beyond that.

---

## 8. Push notifications (foreground & background)

NexaGram shows notifications for new messages via **Supabase Realtime**
instead of Firebase Cloud Messaging:

- While the app is **open or backgrounded** (still running, socket
  alive), `NotificationService` keeps a Realtime subscription on
  `public.messages` and shows a local notification for any message that
  arrives in a chat you're part of, sent by someone else.
- This requires no extra setup beyond steps 3–7 above — Realtime is
  already enabled on the `messages` table by `supabase_schema.sql`, and
  local-notification permissions are requested automatically on first
  launch (`NotificationService.initialize()`).

**What this does *not* cover:** notifications while the app is fully
closed/killed. Supabase has no built-in push-delivery service equivalent
to FCM for that case — Realtime only delivers events to a live
connection. If you need "app fully closed" push later, the common
Supabase-native pattern is a Postgres trigger (or an extension of the
`send_message` RPC) that calls a Supabase Edge Function on new-message
insert, which then calls the FCM HTTP v1 API or APNs directly using a
service-account credential kept server-side — the client never needs the
full Firebase SDK for that, only the small Edge Function. This is left as
a deliberate follow-up rather than pulling Firebase back into the client.

---

## 9. Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

---

## Troubleshooting

- **"This username is already taken" on the very first sign-up** — make
  sure step 3 ran successfully; `username_lower` has a unique index, so
  an incomplete schema run can leave the table in a state where lookups
  fail oddly. Re-run `supabase_schema.sql`.
- **Realtime updates not arriving (chat list / messages don't live-update)**
  — double check step 3 completed the `alter publication supabase_realtime
  add table ...` block at the bottom of `supabase_schema.sql` without
  errors; re-run the script if unsure, it's idempotent.
- **Uploads fail with a policy error** — re-run
  `supabase_storage_policy.sql` (step 4); confirm the bucket is named
  exactly `nexagram` (Storage → check the bucket list).
- **`SupabaseConfig.isConfigured` is false / app can't connect** — you
  forgot the `--dart-define` flags in step 7, or pasted the service-role
  key instead of the anon key by mistake.
