-- ELITEGRAM database schema (Supabase / PostgreSQL)
-- Run once in Supabase SQL Editor. Uses Supabase Auth; never put service_role keys in frontend.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 60),
  avatar_url text,
  bio text not null default '' check (char_length(bio) <= 160),
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('direct','group')),
  title text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  joined_at timestamptz not null default now(),
  primary key (conversation_id,user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 10000),
  attachment_path text,
  attachment_name text,
  attachment_mime text,
  created_at timestamptz not null default now(),
  check (char_length(body) > 0 or attachment_path is not null)
);

create index if not exists messages_conversation_created_idx
  on public.messages(conversation_id,created_at desc);

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  username text unique check (username is null or username ~ '^[a-z0-9_]{3,32}$'),
  description text not null default '' check (char_length(description) <= 500),
  avatar_url text,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.channel_members (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'subscriber' check (role in ('owner','admin','subscriber')),
  joined_at timestamptz not null default now(),
  primary key(channel_id,user_id)
);

create table if not exists public.channel_posts (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 10000),
  attachment_path text,
  attachment_name text,
  created_at timestamptz not null default now(),
  check (char_length(body) > 0 or attachment_path is not null)
);

create or replace function public.is_conversation_member(cid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=auth.uid()); $$;

create or replace function public.is_channel_member(cid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.channel_members where channel_id=cid and user_id=auth.uid()); $$;

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.channels enable row level security;
alter table public.channel_members enable row level security;
alter table public.channel_posts enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (true);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id=auth.uid());
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists conversations_read_member on public.conversations;
create policy conversations_read_member on public.conversations for select to authenticated using (public.is_conversation_member(id));
drop policy if exists conversations_create_own on public.conversations;
create policy conversations_create_own on public.conversations for insert to authenticated with check (created_by=auth.uid());

drop policy if exists members_read_same_conversation on public.conversation_members;
create policy members_read_same_conversation on public.conversation_members for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists members_add_self on public.conversation_members;
create policy members_add_self on public.conversation_members for insert to authenticated with check (user_id=auth.uid());

drop policy if exists messages_read_member on public.messages;
create policy messages_read_member on public.messages for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists messages_insert_member on public.messages;
create policy messages_insert_member on public.messages for insert to authenticated with check (sender_id=auth.uid() and public.is_conversation_member(conversation_id));

drop policy if exists channels_read_public_or_member on public.channels;
create policy channels_read_public_or_member on public.channels for select to authenticated using (is_public or owner_id=auth.uid() or public.is_channel_member(id));
drop policy if exists channels_create_owner on public.channels;
create policy channels_create_owner on public.channels for insert to authenticated with check (owner_id=auth.uid());
drop policy if exists channels_update_owner on public.channels;
create policy channels_update_owner on public.channels for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());

drop policy if exists channel_members_read on public.channel_members;
create policy channel_members_read on public.channel_members for select to authenticated using (public.is_channel_member(channel_id) or exists(select 1 from public.channels c where c.id=channel_id and c.is_public));
drop policy if exists channel_members_join_self on public.channel_members;
create policy channel_members_join_self on public.channel_members for insert to authenticated with check (user_id=auth.uid());

drop policy if exists channel_posts_read on public.channel_posts;
create policy channel_posts_read on public.channel_posts for select to authenticated using (
  exists(select 1 from public.channels c where c.id=channel_id and (c.is_public or c.owner_id=auth.uid() or public.is_channel_member(c.id)))
);
drop policy if exists channel_posts_owner_insert on public.channel_posts;
create policy channel_posts_owner_insert on public.channel_posts for insert to authenticated with check (
  author_id=auth.uid() and exists(select 1 from public.channels c where c.id=channel_id and c.owner_id=auth.uid())
);

-- Realtime: enable messages and channel_posts in Database -> Replication.
-- Storage: create a private bucket named "chat-files"; apply owner/member-aware policies before production use.
