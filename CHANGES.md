# What was fixed, and where each file goes

## 1. Files that were corrupted by the upload (extension mangled to `.txt`)

Your zip had three screens saved as `.txt` next to either an empty or
missing `.dart` file of the same name. Fixed by renaming/replacing:

| Broken state | Fixed |
|---|---|
| `lib/screens/auth/login_screen.dart` — **missing entirely** | Restored from `login_screen.dart.txt` |
| `lib/screens/auth/register_screen.dart` — **1-byte empty stub** | Real content restored from `register_screen.dart.txt` |
| `lib/screens/splash/splash_screen.dart` — **1-byte empty stub** | Real content restored from `splash_screen.dart.txt` |

## 2. File in the wrong folder

`lib/screens/chats_screen.dart` used `../../` imports and was itself
imported by `main_shell.dart` as `chats/chats_screen.dart` — but the file
was sitting directly in `screens/`, one level too shallow. Moved to:

```
lib/screens/chats/chats_screen.dart
```

## 3. The 5 files from `NexaGram.zip` — where they go

| File you provided | Destination | Why |
|---|---|---|
| `glass_container.dart` | `lib/widgets/common/glass_container.dart` | Replaces the existing file — identical except the relative import path (`../theme/theme.dart` → `../../theme/theme.dart`), which is the *correct* depth for this widget's actual folder location. |
| `user_avatar.dart` | `lib/widgets/common/user_avatar.dart` | Same situation — replaces existing file, same import-depth fix. |
| `glass_text_field.dart` | `lib/widgets/common/glass_text_field.dart` | **New file.** Referenced by `login_screen`, `register_screen`, `edit_profile_screen`, `new_group_screen` but never existed in the project. |
| `primary_button.dart` | `lib/widgets/common/primary_button.dart` | **New file.** Same situation — referenced everywhere, never existed. |
| `chat_list_tile.dart` | `lib/widgets/chats/chat_list_tile.dart` (new folder) | **New file.** Required by `chats_screen.dart`'s import of `../../widgets/chats/chat_list_tile.dart`. |

I verified every constructor parameter these 5 widgets expose against
every call site across the whole app (profile screens, contacts screens,
chat screen, settings screen, chats screen) — all match exactly, so
nothing else needed to change to accommodate them.

## 4. Small bugs fixed while verifying

- **`lib/main.dart`** — used `AppConstants.appName` without importing
  `core/constants/app_constants.dart`. Added the import.
- **`lib/main.dart`** — `NotificationService().initialize()` (which sets
  up the local-notification plugin, Android channel, and FCM foreground/
  background listeners) was never called anywhere in the app, including
  here. Added the call before `runApp`.
- **`android/app/src/main/AndroidManifest.xml`** — missing every runtime
  permission the app's own dependencies need: camera, gallery/media,
  microphone (voice messages), and Android 13+'s `POST_NOTIFICATIONS`.
  Added them.
- **`ios/Runner/Info.plist`** — missing the `NS*UsageDescription` strings
  iOS requires before it will even show the camera/photo library/
  microphone permission prompt (without these, calling those APIs
  crashes the app on a real device). Added camera, photo library, photo
  library add, and microphone descriptions, plus `UIBackgroundModes` for
  remote notifications.
- **`.gitignore`** — didn't exclude `google-services.json`,
  `GoogleService-Info.plist`, or `firebase_options.dart`. Added them so
  real Firebase credentials can never be committed by accident.

## 5. Genuinely missing pieces (referenced in code comments, never written)

Both `chat_service.dart` and `storage_service.dart` had doc comments
pointing at files that didn't exist yet:

- **`firestore.rules`** (project root) — full security rules matching
  every read/write pattern in `services/*.dart`, field-scoped so a
  participant can only ever touch the fields their specific action needs
  (e.g. updating `unreadCounts` on someone else's behalf when sending a
  message, but never touching their `groupAdminIds`).
- **`storage.rules`** (project root) — matches `StoragePaths` exactly,
  with the same 10 MB / 50 MB limits `StorageService` enforces
  client-side, re-enforced server-side.
- **`firestore.indexes.json`** — the one composite index the app's
  queries actually require (`participantIds arrayContains` +
  `lastMessageAt orderBy`).
- **`firebase.json`** — ties the above together plus emulator ports.
- **`docs/FIREBASE_SETUP.md`** — end-to-end setup: project creation,
  `flutterfire configure`, enabling each product, deploying rules, and
  the two Cloud Functions the client-side code assumes exist
  (recursive message cleanup on chat delete; sending the actual push
  notification on new message — `NotificationService` only handles
  *displaying* a push, not originating one).
- **`README.md`** (both root and `nexagram/`) — were Flutter/GitHub
  boilerplate; rewritten with real architecture, setup, and design-token
  documentation.

## If you're merging this into your own working copy instead of using the zip

1. Copy `lib/screens/auth/login_screen.dart`,
   `lib/screens/auth/register_screen.dart`,
   `lib/screens/splash/splash_screen.dart` over your broken versions.
2. Move your `chats_screen.dart` into `lib/screens/chats/`.
3. Drop the 5 widget files into the destinations in the table above.
4. Apply the `main.dart` / manifest / `.gitignore` edits in section 4.
5. Copy `firestore.rules`, `storage.rules`, `firestore.indexes.json`,
   `firebase.json`, and `docs/FIREBASE_SETUP.md` into your project root.
