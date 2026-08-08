-- ============================================================================
-- NexaGram — Supabase Postgres schema
-- ============================================================================
-- Replaces the old Firestore data model 1:1:
--   users/{uid}                          -> public.users
--   usernames/{usernameLower}            -> public.users.username_lower (unique index)
--   chats/{chatId}                       -> public.chats
--   chats/{chatId}/messages/{messageId}  -> public.messages (chat_id FK, on delete cascade)
--   chats/{chatId}/typing/{uid}          -> public.typing_status (composite PK)
--   users/{ownerUid}/contacts/{uid}      -> public.contacts (composite PK)
--
-- How to run this:
--   Supabase dashboard -> SQL Editor -> paste this whole file -> Run.
--   (No CLI needed — this works entirely from a browser, including on
--   the iPhone Safari app.)
--
-- This script is idempotent — safe to re-run.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. users
-- ----------------------------------------------------------------------------
-- `id` is the Supabase Auth uid (auth.users.id) — the profile row is
-- provisioned client-side right after sign-up (see AuthService.register),
-- mirroring the old Firestore users/{uid} document.

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null default '',
  username_lower text not null default '',
  name text not null default '',
  email text not null default '',
  bio text not null default '',
  phone_number text not null default '',
  avatar_url text,
  is_online boolean not null default false,
  last_seen timestamptz,
  created_at timestamptz not null default now(),
  fcm_tokens text[] not null default '{}',
  blocked_user_ids text[] not null default '{}'
);

-- Enforces the same "one account per username" guarantee the old
-- usernames/{usernameLower} reservation collection gave, but as a single
-- unique index instead of a second write.
create unique index if not exists users_username_lower_key
  on public.users (username_lower);

alter table public.users enable row level security;

drop policy if exists "users: anyone signed in can read profiles" on public.users;
create policy "users: anyone signed in can read profiles"
  on public.users for select
  to authenticated
  using (true);

drop policy if exists "users: users insert their own profile" on public.users;
create policy "users: users insert their own profile"
  on public.users for insert
  to authenticated
  with check (id = auth.uid());

drop policy if exists "users: users update their own profile" on public.users;
create policy "users: users update their own profile"
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "users: users delete their own profile" on public.users;
create policy "users: users delete their own profile"
  on public.users for delete
  to authenticated
  using (id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. chats
-- ----------------------------------------------------------------------------
-- `id` is `text`, not a generated uuid: 1:1 chats use the deterministic
-- "sortedUidA_sortedUidB" scheme (ChatModel.privateChatId) so opening an
-- existing conversation can never create a duplicate row, and group chats
-- get a client-generated id (ChatService._newGroupId). Both are assigned by
-- the app, so there's no database default here.

create table if not exists public.chats (
  id text primary key,
  type text not null default 'private' check (type in ('private', 'group')),
  participant_ids text[] not null default '{}',
  group_name text,
  group_avatar_url text,
  group_admin_ids text[] not null default '{}',
  last_message text,
  last_message_sender_id text,
  last_message_type text,
  last_message_at timestamptz,
  unread_counts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  created_by text,
  muted_by text[] not null default '{}',
  pinned_by text[] not null default '{}'
);

create index if not exists chats_participant_ids_idx
  on public.chats using gin (participant_ids);

alter table public.chats enable row level security;

drop policy if exists "chats: participants can read" on public.chats;
create policy "chats: participants can read"
  on public.chats for select
  to authenticated
  using (auth.uid()::text = any (participant_ids));

drop policy if exists "chats: participants can create" on public.chats;
create policy "chats: participants can create"
  on public.chats for insert
  to authenticated
  with check (auth.uid()::text = any (participant_ids));

drop policy if exists "chats: participants can update" on public.chats;
create policy "chats: participants can update"
  on public.chats for update
  to authenticated
  using (auth.uid()::text = any (participant_ids))
  with check (auth.uid()::text = any (participant_ids));

drop policy if exists "chats: participants can delete" on public.chats;
create policy "chats: participants can delete"
  on public.chats for delete
  to authenticated
  using (auth.uid()::text = any (participant_ids));

-- ----------------------------------------------------------------------------
-- 3. messages
-- ----------------------------------------------------------------------------

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id text not null references public.chats (id) on delete cascade,
  sender_id text not null,
  type text not null default 'text'
    check (type in ('text', 'image', 'file', 'voice', 'system')),
  text text not null default '',
  media_url text,
  media_thumb_url text,
  file_name text,
  file_size_bytes bigint,
  voice_duration_ms integer,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  read_by text[] not null default '{}',
  delivered_to text[] not null default '{}',
  reactions jsonb not null default '{}'::jsonb,
  reply_to_message_id uuid,
  reply_to_preview text,
  reply_to_sender_name text,
  is_deleted boolean not null default false
);

create index if not exists messages_chat_id_created_at_idx
  on public.messages (chat_id, created_at desc);

alter table public.messages enable row level security;

-- Membership is checked by looking the sender's uid up in the parent
-- chat's participant_ids — the Postgres equivalent of the old Firestore
-- rule that read get(/databases/.../chats/$(chatId)).data.participantIds.

drop policy if exists "messages: participants can read" on public.messages;
create policy "messages: participants can read"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and auth.uid()::text = any (c.participant_ids)
    )
  );

drop policy if exists "messages: participants can send" on public.messages;
create policy "messages: participants can send"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()::text
    and exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and auth.uid()::text = any (c.participant_ids)
    )
  );

-- Any participant (not just the sender) needs update access here:
-- markAsDelivered/markChatAsRead are written by the *recipient* appending
-- their own uid to delivered_to/read_by. This mirrors the trust boundary
-- the old Firestore rules used for this collection — enforcing "only the
-- sender may edit text/is_deleted" would need column-level security or
-- moving edit/delete through a security-definer RPC (the way send_message
-- and toggle_reaction already work), which is a reasonable follow-up if
-- you want tighter guarantees than the client-side checks in
-- ChatService.editMessage/deleteMessage currently give.
drop policy if exists "messages: participants can update" on public.messages;
create policy "messages: participants can update"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and auth.uid()::text = any (c.participant_ids)
    )
  );

-- ----------------------------------------------------------------------------
-- 4. typing_status
-- ----------------------------------------------------------------------------
-- Composite primary key (chat_id, user_id) — same shape as the old
-- chats/{chatId}/typing/{uid} sub-collection. Rows are ephemeral: written on
-- every keystroke (debounced client-side) and deleted when typing stops.

create table if not exists public.typing_status (
  chat_id text not null references public.chats (id) on delete cascade,
  user_id text not null,
  is_typing boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

alter table public.typing_status enable row level security;

drop policy if exists "typing_status: participants can read" on public.typing_status;
create policy "typing_status: participants can read"
  on public.typing_status for select
  to authenticated
  using (
    exists (
      select 1 from public.chats c
      where c.id = typing_status.chat_id
        and auth.uid()::text = any (c.participant_ids)
    )
  );

drop policy if exists "typing_status: users manage their own row" on public.typing_status;
create policy "typing_status: users manage their own row"
  on public.typing_status for all
  to authenticated
  using (user_id = auth.uid()::text)
  with check (user_id = auth.uid()::text);

-- ----------------------------------------------------------------------------
-- 5. contacts
-- ----------------------------------------------------------------------------
-- Composite primary key (owner_uid, contact_uid) — same shape as the old
-- users/{ownerUid}/contacts/{contactUid} sub-collection. One-directional by
-- design (see ContactService doc comment).

create table if not exists public.contacts (
  owner_uid text not null,
  contact_uid text not null,
  username text not null default '',
  name text not null default '',
  avatar_url text,
  added_at timestamptz not null default now(),
  primary key (owner_uid, contact_uid)
);

alter table public.contacts enable row level security;

drop policy if exists "contacts: owners manage their own contacts" on public.contacts;
create policy "contacts: owners manage their own contacts"
  on public.contacts for all
  to authenticated
  using (owner_uid = auth.uid()::text)
  with check (owner_uid = auth.uid()::text);

-- ----------------------------------------------------------------------------
-- 6. reports
-- ----------------------------------------------------------------------------
-- Reserved for user/message reporting (see SupabaseTables.reports). Not
-- wired up in the app yet — created here so the table exists with a safe
-- default policy (insert-only, own reports only) ahead of that feature.

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_uid text not null,
  reported_uid text,
  reported_message_id uuid,
  reason text not null default '',
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

drop policy if exists "reports: users can file their own reports" on public.reports;
create policy "reports: users can file their own reports"
  on public.reports for insert
  to authenticated
  with check (reporter_uid = auth.uid()::text);

drop policy if exists "reports: users can read their own reports" on public.reports;
create policy "reports: users can read their own reports"
  on public.reports for select
  to authenticated
  using (reporter_uid = auth.uid()::text);

-- ============================================================================
-- 7. RPC functions
-- ============================================================================
-- Postgres equivalents of the old Firestore WriteBatch / FieldValue.increment
-- / FieldValue.arrayUnion calls — each runs as a single atomic transaction
-- server-side instead of several round trips from the client.

-- ----------------------------------------------------------------------------
-- send_message: inserts the message row and updates the parent chat's
-- preview fields + per-participant unread counters in one transaction.
-- ----------------------------------------------------------------------------
create or replace function public.send_message(
  p_chat_id text,
  p_sender_id text,
  p_type text,
  p_text text default '',
  p_media_url text default null,
  p_media_thumb_url text default null,
  p_file_name text default null,
  p_file_size_bytes bigint default null,
  p_voice_duration_ms integer default null,
  p_reply_to_message_id uuid default null,
  p_reply_to_preview text default null,
  p_reply_to_sender_name text default null,
  p_preview_text text default ''
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message public.messages;
  v_participant_ids text[];
  v_new_unread jsonb;
begin
  select participant_ids into v_participant_ids
  from public.chats
  where id = p_chat_id;

  if v_participant_ids is null then
    raise exception 'Chat % not found', p_chat_id;
  end if;

  if not (p_sender_id = any (v_participant_ids)) then
    raise exception 'Sender is not a participant of this chat';
  end if;

  insert into public.messages (
    chat_id, sender_id, type, text, media_url, media_thumb_url,
    file_name, file_size_bytes, voice_duration_ms,
    reply_to_message_id, reply_to_preview, reply_to_sender_name
  ) values (
    p_chat_id, p_sender_id, p_type, p_text, p_media_url, p_media_thumb_url,
    p_file_name, p_file_size_bytes, p_voice_duration_ms,
    p_reply_to_message_id, p_reply_to_preview, p_reply_to_sender_name
  )
  returning * into v_message;

  select coalesce(
    jsonb_object_agg(
      uid,
      case
        when uid = p_sender_id then 0
        else coalesce((c.unread_counts ->> uid)::int, 0) + 1
      end
    ),
    '{}'::jsonb
  )
  into v_new_unread
  from public.chats c, unnest(v_participant_ids) as uid
  where c.id = p_chat_id;

  update public.chats
  set last_message = p_preview_text,
      last_message_sender_id = p_sender_id,
      last_message_type = p_type,
      last_message_at = v_message.created_at,
      unread_counts = v_new_unread
  where id = p_chat_id;

  return v_message;
end;
$$;

-- ----------------------------------------------------------------------------
-- mark_chat_as_read: marks every unread message in the recent window as
-- read by p_uid and resets that participant's unread counter.
-- ----------------------------------------------------------------------------
create or replace function public.mark_chat_as_read(
  p_chat_id text,
  p_uid text,
  p_recent_window integer default 200
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.messages
  set read_by = array_append(read_by, p_uid)
  where id in (
    select id from public.messages
    where chat_id = p_chat_id
      and not (p_uid = any (read_by))
      and sender_id <> p_uid
    order by created_at desc
    limit p_recent_window
  );

  update public.chats
  set unread_counts = jsonb_set(
    coalesce(unread_counts, '{}'::jsonb),
    array[p_uid],
    '0'::jsonb
  )
  where id = p_chat_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- toggle_reaction: adds or removes p_uid from the reaction-users array for
-- a given emoji on a message, replacing the old
-- FieldValue.arrayUnion/arrayRemove pair.
-- ----------------------------------------------------------------------------
create or replace function public.toggle_reaction(
  p_message_id uuid,
  p_emoji text,
  p_uid text,
  p_add boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_users jsonb;
  v_updated jsonb;
begin
  select coalesce(reactions -> p_emoji, '[]'::jsonb)
  into v_users
  from public.messages
  where id = p_message_id;

  if v_users is null then
    return;
  end if;

  if p_add then
    if not (v_users ? p_uid) then
      v_updated := v_users || to_jsonb(p_uid);
    else
      v_updated := v_users;
    end if;
  else
    select coalesce(jsonb_agg(elem), '[]'::jsonb)
    into v_updated
    from jsonb_array_elements_text(v_users) as elem
    where elem <> p_uid;
  end if;

  update public.messages
  set reactions = jsonb_set(
    coalesce(reactions, '{}'::jsonb),
    array[p_emoji],
    v_updated
  )
  where id = p_message_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- search_users: case-insensitive prefix search across username and display
-- name, replacing the old two-query Firestore range-scan trick.
-- ----------------------------------------------------------------------------
create or replace function public.search_users(
  p_query text,
  p_exclude_uid text default null,
  p_limit integer default 20
)
returns setof public.users
language sql
security definer
set search_path = public
stable
as $$
  select *
  from public.users
  where (
    username_lower like lower(p_query) || '%'
    or lower(name) like lower(p_query) || '%'
  )
  and (p_exclude_uid is null or id <> p_exclude_uid::uuid)
  order by username_lower
  limit p_limit;
$$;

-- ============================================================================
-- 8. Realtime
-- ============================================================================
-- Powers both live UI updates (chat list, messages, typing indicators) and
-- foreground/backgrounded push notifications via NotificationService.
--
-- Wrapped in a check against pg_publication_tables so re-running this
-- script never fails with "relation is already member of publication"
-- (a plain `alter publication ... add table` is not idempotent on its own).

do $$
declare
  t text;
begin
  foreach t in array array['users', 'chats', 'messages', 'typing_status', 'contacts']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
