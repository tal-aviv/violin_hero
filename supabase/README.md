# Supabase Backend Setup

This folder contains the backend for Violin Hero: **event logging**, **user accounts** (cross-device login with unique usernames), and **progress sync** (stars, streaks, and mastery data persist across devices).

---

## 1) Create the tables

Run all SQL files in your Supabase SQL editor (Dashboard → SQL Editor → New query):

1. `supabase/sql/001_create_user_events.sql` — event log table
2. `supabase/sql/002_create_users.sql` — user accounts table (unique username primary key)
3. `supabase/sql/003_create_user_progress.sql` — per-user progress table (stars, streaks, section mastery)

## 2) Deploy the Edge Functions

There are three functions:

| Function | Source | Purpose |
|---|---|---|
| `violin-events-ingest` | `supabase/functions/violin-events-ingest/index.ts` | Batched event log uploads |
| `violin-auth` | `supabase/functions/violin-auth/index.ts` | Signup, login, username check |
| `violin-progress` | `supabase/functions/violin-progress/index.ts` | Save / load progress per user |

Deploy all (from the project root with `supabase` CLI linked):

```bash
supabase functions deploy violin-events-ingest --no-verify-jwt
supabase functions deploy violin-auth --no-verify-jwt
supabase functions deploy violin-progress --no-verify-jwt
```

## 3) Configure environment & deploy

Copy the example env file and fill in your Supabase values:

```bash
cp .env.example .env
# Edit .env with your project ref and anon key
```

Then deploy with one command:

```bash
./deploy.sh
```

This builds Flutter web with the correct `--dart-define` flags and pushes to GitHub Pages.

### Manual build (if you prefer)

```bash
flutter build web --base-href "/violin_hero/" \
  --dart-define=VH_LOG_ENDPOINT=https://<project-ref>.supabase.co/functions/v1/violin-events-ingest \
  --dart-define=VH_LOG_API_KEY=<your-supabase-anon-public-key> \
  --dart-define=VH_AUTH_ENDPOINT=https://<project-ref>.supabase.co/functions/v1/violin-auth

npx gh-pages -d build/web
```

## 4) How it works

**Signup flow:**
1. User picks avatar, enters username + password
2. App checks username availability in real-time (green check / red X)
3. On submit, app calls the `violin-auth` function with `action: "signup"`
4. Server checks uniqueness, hashes password with SHA-256, inserts row
5. Credentials are also cached locally for offline access

**Login flow:**
1. User enters username + password on any device
2. App calls `violin-auth` with `action: "login"`
3. Server validates credentials and returns avatar
4. Credentials cached locally; if offline, falls back to local cache
5. Remote progress is fetched and merged with any local progress (takes the best of both)

**Progress sync:**
- Every time progress changes (stars earned, streak updated, section mastery), it is saved locally AND synced to Supabase (debounced, best-effort)
- On login / app startup, remote progress is fetched and merged with local data
- Merge strategy: per-field max for stars and section mastery; activity-tracking fields follow whichever copy is more recent

## 5) Query data in Supabase

### Users

```sql
select * from public.violin_users order by created_at desc;
```

### Progress

```sql
select * from public.violin_user_progress order by updated_at desc;
```

### Event logs

```sql
-- Recent events
select * from public.violin_user_events
order by timestamp_ms desc limit 200;

-- Per-user summary
select username, count(*) as events, sum(stars_delta) as net_stars
from public.violin_user_events
group by username order by events desc;
```

## Notes

- Usernames are stored lowercase; duplicates are prevented by the primary key.
- The ingest function upserts on `id` to avoid duplicate event inserts.
- If `VH_AUTH_ENDPOINT` is not set, auth works locally only (single-device).
- If `VH_LOG_ENDPOINT` is not set, event logging stays local only.
- The progress endpoint is auto-derived from `VH_AUTH_ENDPOINT` — no extra flag needed.
