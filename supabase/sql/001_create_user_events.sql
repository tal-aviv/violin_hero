-- Violin Hero global event log table
create table if not exists public.violin_user_events (
  id text primary key,
  timestamp_ms bigint not null,
  created_at timestamptz not null default now(),
  username text not null,
  session_id text not null,
  type text not null,
  outcome boolean,
  stars_delta integer not null default 0,
  note_id text,
  string_index integer,
  song_id text,
  by_heart_mode boolean,
  hint_used boolean,
  accuracy double precision,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_violin_user_events_username
  on public.violin_user_events (username);

create index if not exists idx_violin_user_events_session
  on public.violin_user_events (session_id);

create index if not exists idx_violin_user_events_type
  on public.violin_user_events (type);

create index if not exists idx_violin_user_events_timestamp
  on public.violin_user_events (timestamp_ms desc);

-- Optional: easy daily rollups
create or replace view public.violin_user_events_daily as
select
  username,
  to_timestamp(timestamp_ms / 1000.0)::date as event_date,
  count(*) as events_count,
  sum(stars_delta) as stars_delta_sum
from public.violin_user_events
group by 1, 2;

