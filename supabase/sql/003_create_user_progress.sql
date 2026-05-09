-- Violin Hero per-user progress table (synced from client)
create table if not exists public.violin_user_progress (
  username text primary key references public.violin_users(username),
  stars integer not null default 0,
  streak_days integer not null default 0,
  last_active_day_epoch bigint,
  week_id bigint not null default 0,
  active_days_this_week integer not null default 0,
  streak_shield_used_week_id bigint not null default -1,
  weekly_bonus_awarded_week_id bigint not null default -1,
  string_section_stars jsonb not null default '{}'::jsonb,
  song_section_stars jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
