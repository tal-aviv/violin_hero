---
name: score-to-song
description: Transcribes a music score (image, PDF, or MusicXML) into a SongDefinition entry for the kSongLibrary list in lib/main.dart. Use when the user asks to add a new song to violin_hero, transcribe sheet music, convert a score image to song data, create a song from a music score, or extract notes and rhythm from sheet music.
---

# Score → Song

Convert a music score into a `SongDefinition` block ready to paste into `kSongLibrary` in `lib/main.dart`.

## When to use this

The user has a score (image, PDF, MusicXML, or notes from memory) and wants to add it as a playable song in the violin_hero app.

## Image-reading limits — read this first

This agent **cannot reliably read low-resolution score images** (phone photos, screenshots from sheet music apps). Pixelated ledger lines, blurred accidentals, and ambiguous beam grouping cause incorrect transcription. Past songs (Mississippi Reel, Song of the Wind) required several rounds of corrections when transcribed directly from images.

Choose the OMR path (Path A) whenever the score quality is anything less than a clean, high-DPI PDF or scan. Use the dictation path (Path B) only for short songs the user is willing to dictate, or when OMR isn't available.

Never silently fall back to "guess from the image" — if both paths are blocked, ask the user to choose.

## Path A — OMR (preferred)

Optical Music Recognition tools convert score images to MusicXML, which this agent can parse perfectly.

1. Tell the user to install **Audiveris** from <https://github.com/Audiveris/audiveris/releases> (Java-based, ~50 MB, free, open source).
2. Have them open the score image or PDF in Audiveris and let it auto-process. Audiveris can also import scores directly from PDFs.
3. Have them export as MusicXML: `File → Export → MusicXML`. The output is a `.musicxml` or `.xml` file.
4. Run the converter on that file:
   ```bash
   python3 tools/musicxml_to_song.py path/to/score.musicxml \
     --id new_song_id --title "Display Title"
   ```
   Add `--admin` to mark the song `SongVisibility.admin` for staging.
5. The converter prints a `SongDefinition(...)` block on stdout and any transcription issues on stderr (out-of-range pitches, beat-count mismatches, unrecognized rhythms).
6. Paste the printed Dart block into `kSongLibrary` in `lib/main.dart`. Adjust `icon` and `color` to fit the song's vibe.
7. Run the verification checklist below.

## Path B — Structured dictation

When OMR isn't viable (very short song, user prefers to dictate, no Audiveris install), gather information measure-by-measure in this exact format:

```
Title: Mississippi Reel
Key: D major
Time: 4/4

M1: D5(A) C#5(A) B4(A) A4(A)            | sixteenths
    D5(A) D4(D)                          | eighths
M2: G4(D) F#4(D) E4(D) D4(D)            | sixteenths × 3 groups, then
    A4(A) A4(A)                          | eighths
...
```

Required fields:
- **Title**.
- **Key signature** — determines whether F is F or F#, whether C is C or C#.
- **Time signature** — drives beat-count verification.
- **Per measure**: pitches with octave, string in parentheses, then rhythm. Group consecutive same-rhythm notes.

When in doubt about any pitch or string assignment, ask the user. Do not guess.

## Pitch + string → noteId

Format: `<Letter><Accidental?><Octave>_<String>` where `String` is one of `G`, `D`, `A`, `E`.

The complete pool (must stay in sync with `_songNotePool` and `_allNotes` in `lib/main.dart`):

| MIDI | Pitch | noteId       | String | Notes                                    |
|------|-------|--------------|--------|------------------------------------------|
| 55   | G3    | `G3_G`       | G      | open G                                   |
| 57   | A3    | `A3_G`       | G      | finger 1                                 |
| 59   | B3    | `B3_G`       | G      | finger 2 high                            |
| 60   | C4    | `C4_G`       | G      | finger 3                                 |
| 62   | D4    | `D4_D`       | D      | open D                                   |
| 64   | E4    | `E4_D`       | D      | finger 1                                 |
| 66   | F#4   | `F#4_D`      | D      | finger 2 high                            |
| 67   | G4    | `G4_D`       | D      | finger 3                                 |
| 69   | A4    | `A4_A`       | A      | open A                                   |
| 71   | B4    | `B4_A`       | A      | finger 1                                 |
| 72   | C5    | `C5_A`       | A      | finger 2 **low** (use for D-minor / G-major) |
| 73   | C#5   | `C#5_A`      | A      | finger 2 **high** (use for D-major / A-major) |
| 74   | D5    | `D5_A`       | A      | finger 3                                 |
| 76   | E5    | `E5_E`       | E      | open E                                   |
| 78   | F#5   | `F#5_E`      | E      | finger 1                                 |
| 80   | G#5   | `G#5_E`      | E      | finger 2 high (A-major)                  |
| 81   | A5    | `A5_E`       | E      | finger 3                                 |

Every pitch in the pool is uniquely identified by MIDI number — there's no string-choice ambiguity given the current pool. The converter assigns the noteId from pitch alone.

**Pitches outside the pool** (F natural in any octave, D# / Eb, G natural at G5, anything below G3 or above A5) require either expanding the pool in `lib/main.dart` first or transposing the song. The converter reports these on stderr.

## Rhythm → NoteDuration

Available pitched durations:
- `NoteDuration.sixteenth`, `NoteDuration.eighth`, `NoteDuration.dottedEighth`
- `NoteDuration.quarter`, `NoteDuration.dottedQuarter`
- `NoteDuration.half`, `NoteDuration.dottedHalf`
- `NoteDuration.whole`

Rests (use empty string `''` as the noteId):
- `NoteDuration.sixteenthRest`, `NoteDuration.eighthRest`
- `NoteDuration.quarterRest`, `NoteDuration.dottedQuarterRest`
- `NoteDuration.halfRest`, `NoteDuration.dottedHalfRest`
- `NoteDuration.wholeRest`

The converter handles MusicXML duration math automatically using the score's `<divisions>` value. New rhythm needs (32nd notes, triplets, ties across barlines) require extending `NoteDuration` in `lib/main.dart` first — see the comment block above the enum at line ~36.

## Output template

```dart
SongDefinition(
  id: 'song_id_here',                    // snake_case, unique within kSongLibrary
  title: 'Display Title',
  icon: Icons.music_note_rounded,        // pick a thematic Material icon
  color: Color(0xFF4FB38E),              // accent color for the card
  noteIds: [
    'A4_A', 'A4_A', 'E5_E',
    // ...
  ],
  noteDurations: [
    NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
    // ...
  ],
),
```

For staging (admin-only) songs, add `visibility: SongVisibility.admin,` after `color`. Remove (or change to `SongVisibility.public`) when the song ships to all users.

## Verification checklist

Before considering a new song done:

- [ ] `noteIds.length == noteDurations.length`
- [ ] Every `noteId` exists in the pool table above (and in `_songNotePool` / `_allNotes` in `lib/main.dart`)
- [ ] Every `noteDuration` is a valid `NoteDuration` enum value
- [ ] Beats per measure match the time signature: sum `beatUnits` per measure (see `kNoteDurationSpecs` in `lib/main.dart`) — e.g., a 4/4 measure must total 4.0 beats
- [ ] Key signature is internally consistent (don't mix `C5_A` and `C#5_A` in the same A-major piece unless there's a chromatic passage)
- [ ] Test in the app: navigate to **Learn Songs → \<new song\>**, play through one full pass, listen for off-pitch notes or wrong rhythms

## Common pitfalls

1. **F natural vs F# / C natural vs C#** — Determined by the key signature, not the visual position on the staff. Confirm the key first; the pool only includes F# and both C variants — F natural is unsupported.
2. **Beam-group misreading** — Two beamed notes can be "two eighths" or "dotted eighth + sixteenth". The OMR converter reads this from `<duration>`, but if dictating, ask the user to spell out the rhythm.
3. **Octaves above the staff** — Notes above the top staff line use ledger lines that are easy to miscount. Always confirm octave when above the top line.
4. **Ties vs slurs** — Ties combine durations, slurs do not. The converter currently treats every notated note head as a separate slot. Tied notes need to be manually merged into a single longer duration in the output.
5. **Repeats** — `:|` and `|:` are not auto-expanded. Either expand them manually in dictation, or duplicate the relevant note ranges in the output. The converter expands them only when MusicXML uses the explicit `<repeat>` element with `<barline>` markers.
6. **Multi-voice / chord scores** — The converter only reads the first part and the principal note of each chord. Multi-violin parts or piano accompaniments need the file edited down to a single melodic line first.

## Adding the song to kSongLibrary

After pasting the `SongDefinition` into `kSongLibrary` in `lib/main.dart`:

1. Update the comment block above `kSongLibrary` (around line 1679) if the new song uses any rhythm or pitch that's worth flagging.
2. If the song uses pitches outside the existing pool, extend `_songNotePool` and `_allNotes` in `lib/main.dart` first — both lists must include any noteId referenced by a song.
3. Hot-reload (`r` in `flutter run`) and verify the song shows up on the song-selection screen.

## Reference: existing songs

For canonical examples to mirror, see in `lib/main.dart`:
- `twinkle_la` — simplest example, only quarter + half notes
- `mississippi_reel` — full rhythm vocabulary including sixteenths, dotted-eighths, and string-crossing bariolage
