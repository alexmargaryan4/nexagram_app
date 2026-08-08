# NexaGram

A premium, cross-platform messenger built with Flutter and Supabase —
Telegram-inspired functionality with an original "Liquid Glass" visual
identity (iOS 26-style glassmorphism, blur, and translucency throughout).

Runs on **iOS** and **Android** from a single Dart codebase.

---

## Features

- **Auth** — email/password sign-up & sign-in, password reset, session
  persistence
- **Profiles** — avatar, name, username, bio, phone number; live
  online/offline presence and "last seen"
- **Contacts** — search users by username/name, add/remove contacts
- **Chats** — real-time private & group messaging, typing indicators,
  read/delivery receipts, emoji reactions, replies, edit, soft-delete,
  pin/mute
- **Media** — image and file attachments with camera/gallery capture,
  upload progress, voice messages
- **Push notifications** — local notifications for new messages while the
  app is open or backgrounded, delivered over a live Supabase Realtime
  connection (see `docs/SUPABASE_SETUP.md` § 8 for what this does and
  doesn't cover)
- **Settings** — light/dark/system theme, notification & privacy toggles

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3 + Cupertino accents), `go_router` |
| State | `provider` (`ChangeNotifier`) |
| Backend | Supabase: Auth, Postgres + Row Level Security, Realtime, Storage |
| Fonts | SF Pro Display (bundled) with an automatic Google Fonts "Inter" fallback |

Everything — accounts, the chat/message database, live updates, and file
storage — runs on a single free-tier Supabase project. No other backend
service is involved.

---

## Getting started

1. **Install dependencies**

   ```bash
   flutter pub get
   ```

2. **Set up Supabase** — this repo does not ship real credentials
   (`lib/supabase_options.dart` reads them from `--dart-define` at build
   time; nothing sensitive is hand-edited or committed). Follow
   **[`docs/SUPABASE_SETUP.md`](docs/SUPABASE_SETUP.md)** end-to-end
   before running the app — it covers project creation, running
   `supabase_schema.sql` (tables + Row Level Security + RPCs) and
   `supabase_storage_policy.sql` (the media bucket) from the dashboard's
   SQL Editor, enabling email/password sign-in, and what push
   notifications do and don't cover on this backend. Building via
   `.github/workflows/build.yml` (GitHub Actions) needs no local setup at
   all beyond adding two repository secrets.

3. **Run**

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJ...
   ```

---

## Project structure

```
lib/
├── core/
│   ├── constants/       # AppConstants, SupabaseTables, SupabaseRpc, StoragePaths
│   ├── errors/          # AppException hierarchy (AuthException, DatabaseException, ...)
│   ├── router/          # go_router config (app_router.dart) + route table (app_routes.dart)
│   └── utils/           # Validators, DateFormatter
├── models/              # Immutable, Equatable data classes mirroring Postgres rows
├── services/            # Thin wrappers around the Supabase client — the only layer
│                         # that talks to Supabase directly
├── providers/           # ChangeNotifier state, one per feature area
├── screens/              # One folder per feature (auth/, chat/, chats/, contacts/, ...)
├── widgets/
│   ├── common/           # GlassContainer, UserAvatar, GlassTextField/AppTextField, PrimaryButton
│   ├── chats/             # ChatListTile
│   ├── chat/               # MessageBubble, MessageInputBar, ReactionPicker
│   └── navigation/        # CustomNavigationBar
├── theme/                # AppColors, AppDimens, AppTypography, AppTheme (barrel: theme.dart)
├── supabase_options.dart # Reads SUPABASE_URL / SUPABASE_ANON_KEY from --dart-define
└── main.dart
```

**Layering rule:** screens depend on providers, providers depend on
services, services depend on the Supabase client SDK. Screens and
providers never import `supabase_flutter` directly — that keeps Supabase
entirely behind the `services/` boundary, so swapping backends later
only touches that one layer.

### Data flow example (sending a message)

```
ChatScreen (widgets/chat/message_input_bar.dart)
  → ChatProvider.sendMessage()
    → ChatService.sendMessage()
      → Supabase RPC send_message(): atomically inserts into public.messages
                                       + updates public.chats
                                         (last_message*, unread_counts)
```

The RPC (defined in `supabase_schema.sql`) is what makes that a single
atomic round trip instead of two separate client writes — the same
guarantee the old Firestore `WriteBatch` gave.

---

## Design system

Colors, spacing, and type are centralized in `lib/theme/` and match the
product spec exactly:

| Token | Light | Dark |
|---|---|---|
| Background | `#F2F2F7` | `#000000` |
| Surface / cards | `#FFFFFF` | `#1C1C1E` |
| Outgoing bubble | `#2AABEE` | `#2AABEE` |
| Incoming bubble | `#FFFFFF` | `#2C2C2E` |
| Accent | `#0A84FF` | `#0A84FF` |
| Text | `#000000` | `#FFFFFF` |
| Secondary text | `#6D6D72` | `#9A9A9E` |

The glass effect (`GlassContainer`, `LiquidGlassBackground` in
`lib/widgets/common/glass_container.dart`) is a single reusable
`BackdropFilter` + gradient-bordered panel, reused for the nav bar, app
bars, message composer, and auth screens rather than re-implemented per
screen.

---

## Backend security

`supabase_schema.sql` and `supabase_storage_policy.sql` at the project
root define every table and Row Level Security policy, scoped to match
exactly what each `services/*.dart` method reads and writes — see the
comments in each file, and `docs/SUPABASE_SETUP.md` for how to apply
them. RLS is Postgres's equivalent of the old `firestore.rules`: policies
run server-side on every query regardless of what the client sends, so a
compromised or modified client still can't read or write data it
shouldn't.

---

## Testing

```bash
flutter test
```

`test/widget_test.dart` is the default Flutter smoke test; grow this
directory alongside features (`AuthService`/`ChatService` are constructed
with an injectable `SupabaseClient` specifically to make them mockable
with `mockito`, already in `dev_dependencies`).
