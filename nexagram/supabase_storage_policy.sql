-- ============================================================================
-- NexaGram — Supabase Storage bucket + RLS policies
-- ============================================================================
-- Mirrors the old Firebase storage.rules (removed — file storage moved to
-- Supabase because Firebase Storage now requires a linked billing account
-- even for free-tier usage). Same paths, same size/type limits, same trust
-- boundary as before.
--
-- How to run this:
--   Supabase dashboard → SQL Editor → paste this whole file → Run.
--   (No CLI needed — this works entirely from a browser, including on
--   the iPhone Safari app.)
--
-- Paths (must match StoragePaths in lib/core/constants/app_constants.dart):
--   avatars/{uid}.jpg
--   chats/{chatId}/images/{fileName}
--   chats/{chatId}/files/{fileName}
--   chats/{chatId}/voice/{fileName}
-- ============================================================================

-- 1. Create the bucket (public: files are reachable by URL once you know
--    the path, same trust model the old Firebase rules used — a stranger
--    who doesn't know a chat's random id can't guess a file path inside
--    it). Skip this step in the dashboard if you already created the
--    "nexagram" bucket by hand under Storage → New bucket.
insert into storage.buckets (id, name, public)
values ('nexagram', 'nexagram', true)
on conflict (id) do nothing;

-- 2. Anyone signed in can read any object in this bucket — mirrors the
--    old `allow read: if isSignedIn()` rule on every path.
create policy "nexagram: signed-in users can read"
on storage.objects for select
to authenticated
using (bucket_id = 'nexagram');

-- 3. Avatars: only the owning user can upload/overwrite/delete
--    avatars/{their-own-uid}.jpg.
create policy "nexagram: users manage their own avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'nexagram'
  and (storage.foldername(name))[1] = 'avatars'
  and name = 'avatars/' || auth.uid()::text || '.jpg'
);

create policy "nexagram: users update their own avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'nexagram'
  and name = 'avatars/' || auth.uid()::text || '.jpg'
);

create policy "nexagram: users delete their own avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'nexagram'
  and name = 'avatars/' || auth.uid()::text || '.jpg'
);

-- 4. Chat media (images/files/voice): any signed-in user can upload or
--    delete — same as the old Firebase rules, which couldn't check chat
--    membership from Storage rules either and relied on chat ids being
--    unguessable. If you want real per-chat access control later, move
--    chat membership into a Postgres table and reference it here.
create policy "nexagram: signed-in users can upload chat media"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'nexagram'
  and (storage.foldername(name))[1] = 'chats'
);

create policy "nexagram: signed-in users can delete chat media"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'nexagram'
  and (storage.foldername(name))[1] = 'chats'
);

-- Notes on limits that Firebase's storage.rules used to enforce
-- server-side (max file size, content-type checks): Postgres RLS can't
-- inspect the upload payload the way Firebase's `request.resource` could.
-- StorageService already enforces the same size limits client-side
-- (AppConstants.maxImageSizeBytes / maxFileSizeBytes) before it uploads —
-- that's the enforcement point now. If you later want a hard server-side
-- cap too, set "File size limit" on the bucket in the dashboard (Storage →
-- nexagram → bucket settings), which applies regardless of client code.
