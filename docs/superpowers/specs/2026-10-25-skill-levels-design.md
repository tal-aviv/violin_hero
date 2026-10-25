# Skill Levels (Beginner / Intermediate / Advanced) — Design

## Goal

Group users into three skill levels. Each level unlocks its own set of songs
(possibly none). Unlocks are expanded over time by editing app code and
redeploying.

## Data model

- `enum SkillLevel { beginner, intermediate, advanced }` in `lib/models.dart`.
- `kLevelSongs: Map<SkillLevel, List<String>>` in `lib/content.dart` — explicit
  song-ID list per level. Lists are independent (not cumulative); a song
  unlocked for two levels appears in both lists.
- `kUserLevels: Map<String, SkillLevel>` in `lib/models.dart` — lowercase
  username → level override, same style as `kAdminUsernames`.
- `UserSession` gains a `level` field.

### Initial song lists

| Level | Songs |
|---|---|
| beginner | *(none)* |
| intermediate | `twinkle_la`, `twinkle_harmony_vln2`, `frere_jacques`, `lightly_row` |
| advanced | intermediate songs + `song_of_the_wind`, `go_tell_aunt_rhody`, `o_come_little_children`, `ode_to_joy`, `mississippi_reel` |

Songs are shown in the order they appear in the level's list.

### Initial user assignments

| Username | Level |
|---|---|
| `tal` | advanced |
| `gelila q` | advanced |
| `gelilaq` | advanced |
| `דלינה` | intermediate |
| `dbora` | intermediate |
| `pricilla` | intermediate |
| `אלנה` | intermediate |
| `raman` | intermediate |
| `אביגיל` | intermediate |
| `merbl` | intermediate |
| `567` | intermediate |
| `מגדה` | intermediate |
| `abigail` | intermediate |
| `raman_thecoolest` | intermediate |
| `elane` | intermediate |
| `cristal` | intermediate |
| `מירבל` | intermediate |
| `prisilla` | intermediate |
| `hili` | intermediate |
| `pricilla6767` | intermediate |
| `prisilla 6767` | intermediate |
| `tal2` | intermediate |

Keys are matched against the trimmed, lowercased username, so `gelila q`
keeps its inner space. Every other existing account resolves to beginner.

## Level resolution

A user's effective level is resolved in this order:

1. `kUserLevels[username]` if present.
2. The level chosen at signup (stored with the account).
3. `SkillLevel.beginner`.

## Signup

- The create-account screen adds a required Beginner / Intermediate / Advanced
  picker alongside the avatar picker.
- The choice is persisted locally under `auth_level` and sent to the remote
  signup endpoint as `level`. On remote login, a `level` field in the response
  is used if present; otherwise the locally stored value (same device) applies.
- Users cannot change their level after signup.

## Song list

- Non-admin users see only songs whose ID is in `kLevelSongs[effectiveLevel]`
  **and** whose `visibility` is `public`, in list order. Everything else is
  hidden.
- Admin accounts (`isAdminUser`) sit outside the level system entirely: their
  level is ignored and they see every song, including drafts, as today.
  `kAdminUsernames` and the admin draft badge are unchanged.
- A beginner (empty list) sees an empty song screen with a short friendly
  message instead of a blank page.

## Known limitations

- The `violin-auth` function stores `level` in `violin_users.level`
  (migration `005_add_user_level.sql`) and returns it at login, so a
  self-selected level follows the user across devices.
- Existing accounts default to beginner, which currently has no songs, so they
  must be added to `kUserLevels` before release to keep access.
- Like `kAdminUsernames`, this is not a security boundary.

## Testing

- Unit tests for level resolution (override beats signup choice beats default).
- Unit tests for song filtering per level, and for admin seeing everything.
- Widget check that signup requires a level and the beginner empty state renders.
