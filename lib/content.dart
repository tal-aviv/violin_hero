part of 'main.dart';

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.animal,
    required this.primaryColor,
    required this.detailColor,
    required this.backgroundColor,
  });

  final String id;
  final AnimalAvatar animal;
  final Color primaryColor;
  final Color detailColor;
  final Color backgroundColor;
}

enum AnimalAvatar { frog, dog, bear, rabbit, goldfish, panda }

const List<AvatarOption> kAvatarOptions = [
  AvatarOption(
    id: 'avatar_frog',
    animal: AnimalAvatar.frog,
    primaryColor: Color(0xFF43A047),
    detailColor: Color(0xFFC8E6C9),
    backgroundColor: Color(0xFFE8F5E9),
  ),
  AvatarOption(
    id: 'avatar_dog',
    animal: AnimalAvatar.dog,
    primaryColor: Color(0xFF42A5F5),
    detailColor: Color(0xFFE3F2FD),
    backgroundColor: Color(0xFFE3F2FD),
  ),
  AvatarOption(
    id: 'avatar_bear',
    animal: AnimalAvatar.bear,
    primaryColor: Color(0xFF8D6E63),
    detailColor: Color(0xFFEFEBE9),
    backgroundColor: Color(0xFFEFEBE9),
  ),
  AvatarOption(
    id: 'avatar_rabbit',
    animal: AnimalAvatar.rabbit,
    primaryColor: Color(0xFFAB47BC),
    detailColor: Color(0xFFF3E5F5),
    backgroundColor: Color(0xFFF3E5F5),
  ),
  AvatarOption(
    id: 'avatar_goldfish',
    animal: AnimalAvatar.goldfish,
    primaryColor: Color(0xFFFFB300),
    detailColor: Color(0xFFFFE082),
    backgroundColor: Color(0xFFFFF8E1),
  ),
  AvatarOption(
    id: 'avatar_panda',
    animal: AnimalAvatar.panda,
    primaryColor: Color(0xFF455A64),
    detailColor: Color(0xFFECEFF1),
    backgroundColor: Color(0xFFECEFF1),
  ),
];

AvatarOption avatarOptionById(String id) {
  final normalizedId = id == 'avatar_duck' ? 'avatar_goldfish' : id;
  return kAvatarOptions.firstWhere(
    (o) => o.id == normalizedId,
    orElse: () => kAvatarOptions.first,
  );
}

const List<SongDefinition> kSongLibrary = [
  SongDefinition(
    id: 'twinkle_la',
    title: 'Twinkle Twinkle Little Star',
    icon: Icons.star_rounded,
    color: Color(0xFF4FB38E),
    noteIds: [
      'A4_A',
      'A4_A',
      'E5_E',
      'E5_E',
      'F#5_E',
      'F#5_E',
      'E5_E',
      'D5_A',
      'D5_A',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
      'E5_E',
      'E5_E',
      'D5_A',
      'D5_A',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'E5_E',
      'E5_E',
      'D5_A',
      'D5_A',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'A4_A',
      'A4_A',
      'E5_E',
      'E5_E',
      'F#5_E',
      'F#5_E',
      'E5_E',
      'D5_A',
      'D5_A',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
    ],
    noteDurations: [
      // Each phrase ends on a half note ("...how I wonder what you are").
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'twinkle_harmony_vln2',
    title: 'Twinkle Harmony',
    icon: Icons.stars_rounded,
    color: Color(0xFF5D8BFF),
    noteIds: [
      'A4_A',
      'A4_A',
      'C#5_A',
      'C#5_A',
      'D5_A',
      'D5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
      'A4_A',
      'E4_D',
      'E4_D',
      'A4_A',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
      'A4_A',
      'E4_D',
      'C#5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
      'A4_A',
      'E4_D',
      'A4_A',
      'A4_A',
      'C#5_A',
      'C#5_A',
      'D5_A',
      'D5_A',
      'C#5_A',
      'B4_A',
      'B4_A',
      'A4_A',
      'A4_A',
      'E4_D',
      'E4_D',
      'A4_A',
    ],
    noteDurations: [
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'frere_jacques',
    title: 'Frère Jacques',
    icon: Icons.notifications_rounded,
    color: Color(0xFFFFB300),
    noteIds: [
      // Frere Jacques, Frere Jacques
      'A4_A', 'B4_A', 'C#5_A', 'A4_A',
      'A4_A', 'B4_A', 'C#5_A', 'A4_A',
      // Dormez-vous? Dormez-vous?
      'C#5_A', 'D5_A', 'E5_E',
      'C#5_A', 'D5_A', 'E5_E',
      // Sonnez les matines, sonnez les matines
      'E5_E', 'F#5_E', 'E5_E', 'D5_A', 'C#5_A', 'A4_A',
      'E5_E', 'F#5_E', 'E5_E', 'D5_A', 'C#5_A', 'A4_A',
      // Ding ding dong, ding ding dong
      'A4_A', 'E4_D', 'A4_A',
      'A4_A', 'E4_D', 'A4_A',
    ],
    noteDurations: [
      // "Frère Jacques, Frère Jacques" — 8 quarters
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // "Dormez-vous? Dormez-vous?" — q q h, twice
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      // "Sonnez les matines, sonnez les matines" — 4 eighths + 2 quarters, twice
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // "Ding ding dong, ding ding dong" — q q h, twice
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'lightly_row',
    title: 'Yonatan Hakatan',
    icon: Icons.park_rounded,
    color: Color(0xFFE091E8),
    noteIds: [
      // Part A
      // "Yonatan hakatan" (melody same as Lightly Row)
      'E5_E', 'C#5_A', 'C#5_A',
      'D5_A', 'B4_A', 'B4_A',
      'A4_A', 'B4_A', 'C#5_A', 'D5_A',
      'E5_E', 'E5_E', 'E5_E',
      // "Smoothly glide, smoothly glide, on the silent tide"
      'E5_E', 'C#5_A', 'C#5_A',
      'D5_A', 'B4_A', 'B4_A',
      'A4_A', 'C#5_A', 'E5_E', 'E5_E',
      'A4_A',
      // Part B
      // "Let the winds and waters be mingled with our melody"
      'B4_A', 'B4_A', 'B4_A', 'B4_A',
      'B4_A', 'C#5_A', 'D5_A',
      'C#5_A', 'C#5_A', 'C#5_A', 'C#5_A',
      'C#5_A', 'D5_A', 'E5_E',
      // "Sing and float, sing and float, in our little boat"
      'E5_E', 'C#5_A', 'C#5_A',
      'D5_A', 'B4_A', 'B4_A',
      'A4_A', 'C#5_A', 'E5_E', 'E5_E',
      'A4_A',
    ],
    noteDurations: [
      // Part A
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
      // Part B
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'song_of_the_wind',
    title: 'Song of the Wind',
    icon: Icons.air_rounded,
    color: Color(0xFF5DADE2),
    // Suzuki Book 1 #3, A major, 2/4 time. Pitches recovered via
    // Audiveris OMR (see tools/test_fixtures/songofthewind.musicxml),
    // rhythm dictated by hand because Audiveris consistently misread
    // straight beam-groups as triplets and dropped the quarter-rest
    // cadence on the half-bars (M4 / M6). Plays through once — the
    // overarching ‖: ... :‖ that would loop the whole tune back to
    // the start is dropped, but every internal echo (M5–M6 echoing
    // M3–M4, M11–M13 echoing M7–M9) is preserved exactly as written.
    // 14 bars of 2/4 = 28 beats = 49 slots:
    //   • M1–M4:   12 eighths + Q + QR        (first phrase)
    //   • M5–M6:   4 eighths  + Q + QR        (= echo of M3 + M4)
    //   • M7–M10:  14 eighths + Q             (second phrase)
    //   • M11–M14: 12 eighths + Q + QR        (= echo of M7–M10
    //                                          cadencing on A4)
    noteIds: [
      // ── M1 ── A B C# D, all eighths on the A string
      'A4_A', 'B4_A', 'C#5_A', 'D5_A',
      // ── M2 ── E E E E
      'E5_E', 'E5_E', 'E5_E', 'E5_E',
      // ── M3 ── F# D A F#
      'F#5_E', 'D5_A', 'A5_E', 'F#5_E',
      // ── M4 ── E (quarter) + quarter rest
      'E5_E', '',
      // ── M5 ── F# D A F#  (= M3)
      'F#5_E', 'D5_A', 'A5_E', 'F#5_E',
      // ── M6 ── E (quarter) + quarter rest  (= M4)
      'E5_E', '',
      // ── M7 ── E D D D
      'E5_E', 'D5_A', 'D5_A', 'D5_A',
      // ── M8 ── D C# C# C#
      'D5_A', 'C#5_A', 'C#5_A', 'C#5_A',
      // ── M9 ── C# B B B
      'C#5_A', 'B4_A', 'B4_A', 'B4_A',
      // ── M10 ── A C# (eighths) + E (quarter)
      'A4_A', 'C#5_A', 'E5_E',
      // ── M11 ── E D D D  (= M7)
      'E5_E', 'D5_A', 'D5_A', 'D5_A',
      // ── M12 ── D C# C# C#  (= M8)
      'D5_A', 'C#5_A', 'C#5_A', 'C#5_A',
      // ── M13 ── C# B B B  (= M9)
      'C#5_A', 'B4_A', 'B4_A', 'B4_A',
      // ── M14 ── A (quarter) + quarter rest
      'A4_A', '',
    ],
    noteDurations: [
      // M1: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M2: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M3: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M4: Q + QR
      NoteDuration.quarter, NoteDuration.quarterRest,
      // M5: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M6: Q + QR
      NoteDuration.quarter, NoteDuration.quarterRest,
      // M7: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M8: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M9: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M10: 2 eighths + Q
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter,
      // M11: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M12: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M13: 4 eighths
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M14: Q + QR
      NoteDuration.quarter, NoteDuration.quarterRest,
    ],
  ),
  SongDefinition(
    id: 'ode_to_joy',
    title: 'Ode to Joy',
    icon: Icons.celebration_rounded,
    color: Color(0xFFEF6C6C),
    // Arranged in G major so the melody starts on B (Si) — the 1st finger
    // on the A string. Transposed up a perfect 4th from the canonical
    // D-major version, so each phrase sits comfortably on the D and A
    // strings using fingers 0–3.
    noteIds: [
      // Line 1 (measures 1-4)
      'B4_A', 'B4_A', 'C5_A', 'D5_A',
      'D5_A', 'C5_A', 'B4_A', 'A4_A',
      'G4_D', 'G4_D', 'A4_A', 'B4_A',
      'B4_A', 'A4_A', 'A4_A',
      // Line 2 (measures 5-8)
      'B4_A', 'B4_A', 'C5_A', 'D5_A',
      'D5_A', 'C5_A', 'B4_A', 'A4_A',
      'G4_D', 'G4_D', 'A4_A', 'B4_A',
      'A4_A', 'G4_D', 'G4_D',
    ],
    // Faithful 4/4 rhythm: each line ends with dotted-quarter + eighth +
    // half, the classic Ode to Joy cadence.
    noteDurations: [
      // M1: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M2: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M3: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M4: ♩. ♪ 𝅗𝅥
      NoteDuration.dottedQuarter, NoteDuration.eighth,
      NoteDuration.half,
      // M5: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M6: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M7: ♩ ♩ ♩ ♩
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M8: ♩. ♪ 𝅗𝅥
      NoteDuration.dottedQuarter, NoteDuration.eighth,
      NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'mississippi_reel',
    title: 'Mississippi Reel',
    // Stacked horizontal wavy lines — reads as a flowing river rather
    // than the cresting `waves_rounded` (which feels more ocean-like).
    icon: Icons.water_rounded,
    color: Color(0xFF8D6E63),
    // American fiddle reel in D major, 4/4. Two parts so far:
    //
    //   Part A — measures 1–4 — string-position study. M1–M3 each
    //   open with three descending four-note sixteenth-note scale
    //   fragments and resolve to a beamed eighth-note pair. M4 has
    //   one sixteenth fragment followed by a six-eighth cadence that
    //   outlines the D-major arpeggio. The descending run walks
    //   through different fingering positions:
    //     • M1 (= M3): A-string descent  D5–C#5–B4–A4   (3-2-1-0)
    //     • M2:        D-string descent  G4–F#4–E4–D4   (3-2-1-0)
    //     • M4:        D-string turn     E4–G4–F#4–E4   (1-3-2-1)
    //
    //   Part B — measures 5–8 — bariolage study. Each beat alternates
    //   a fingered note on the D string with the open A — a classic
    //   fiddle texture that drills clean string crossings. The
    //   D-string note descends G → F# → E across each measure pair
    //   and the section closes on a held D:
    //     • M5: [G–A]×4 [F#–A]×4              (16 sixteenths)
    //     • M6: [E–A]×4  D F# B A             (8 sixteenths + 4 eighths)
    //     • M7: repeat of M5
    //     • M8: [E–A]×4  D D  D-quarter       (cadence on open D)
    //
    // Range: D4 → F#5, spans all three upper strings (D / A / E).
    // No low-2 needed.
    noteIds: [
      // ── M1 ── A-string descending sixteenth-note scale × 3,
      //          then octave drop D5 (A) → D4 (D) in eighths
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'D4_D',
      // ── M2 ── D-string descending sixteenth-note scale × 3,
      //          then two open-A eighths
      'G4_D', 'F#4_D', 'E4_D', 'D4_D',
      'G4_D', 'F#4_D', 'E4_D', 'D4_D',
      'G4_D', 'F#4_D', 'E4_D', 'D4_D',
      'A4_A', 'A4_A',
      // ── M3 ── exact repeat of M1
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      'D5_A', 'D4_D',
      // ── M4 ── one D-string turn (E G F# E) in sixteenths, then
      //          six eighths: two open-A pickups, a D-string D-F#-D
      //          arpeggio figure, and a final landing on open A
      'E4_D', 'G4_D', 'F#4_D', 'E4_D',
      'A4_A', 'A4_A',
      'D4_D', 'F#4_D',
      'D4_D', 'A4_A',
      // ── M5 ── bariolage: [G(D)–A(A)]×4 then [F#(D)–A(A)]×4
      //          (16 sixteenths, all string crossings)
      'G4_D', 'A4_A', 'G4_D', 'A4_A',
      'G4_D', 'A4_A', 'G4_D', 'A4_A',
      'F#4_D', 'A4_A', 'F#4_D', 'A4_A',
      'F#4_D', 'A4_A', 'F#4_D', 'A4_A',
      // ── M6 ── [E(D)–A(A)]×4 in sixteenths, then a four-eighth
      //          cadence  D(open)  F#(D)  B(A)  A(open)
      'E4_D', 'A4_A', 'E4_D', 'A4_A',
      'E4_D', 'A4_A', 'E4_D', 'A4_A',
      'D4_D', 'F#4_D', 'B4_A', 'A4_A',
      // ── M7 ── repeat of M5
      'G4_D', 'A4_A', 'G4_D', 'A4_A',
      'G4_D', 'A4_A', 'G4_D', 'A4_A',
      'F#4_D', 'A4_A', 'F#4_D', 'A4_A',
      'F#4_D', 'A4_A', 'F#4_D', 'A4_A',
      // ── M8 ── [E(D)–A(A)]×4 sixteenths, then two open-D eighths
      //          and a final open-D quarter — full stop on the
      //          tonic to close Part B
      'E4_D', 'A4_A', 'E4_D', 'A4_A',
      'E4_D', 'A4_A', 'E4_D', 'A4_A',
      'D4_D', 'D4_D',
      'D4_D',
    ],
    noteDurations: [
      // M1: 12 sixteenths + 2 eighths
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M2: 12 sixteenths + 2 eighths
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M3: 12 sixteenths + 2 eighths (same shape as M1)
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M4: 4 sixteenths + 6 eighths (cadence)
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M5: 16 sixteenths (bariolage)
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      // M6: 8 sixteenths + 4 eighths
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.eighth,
      // M7: 16 sixteenths (repeat of M5)
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      // M8: 8 sixteenths + 2 eighths + 1 quarter (final cadence)
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.sixteenth, NoteDuration.sixteenth,
      NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter,
    ],
  ),
  // ─────────────────────────────────────────────────────────────────
  // ADMIN-ONLY DRAFT LIBRARY
  // ─────────────────────────────────────────────────────────────────
  // Songs with `visibility: SongVisibility.admin` are hidden from
  // regular users and only appear for accounts in `kAdminUsernames`.
  // Use this section to author / verify new songs (e.g. the rest of
  // Suzuki Book 1) before promoting them to `SongVisibility.public`.
  //
  // To promote a song to the public library: change its `visibility`
  // to `SongVisibility.public` (or just remove the field — public is
  // the default). No other code changes needed.
  SongDefinition(
    id: 'go_tell_aunt_rhody',
    title: 'Go Tell Aunt Rhody',
    // "Go tell…" — a speaking/telling icon (person with voice waves).
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFF66BB6A),
    visibility: SongVisibility.admin,
    // Traditional American folk tune in A major, 4/4. Transcribed via
    // Audiveris OMR (tools/test_fixtures/gotellauntrhody.musicxml.mxl)
    // — this score read cleanly (every bar resolves to 4 beats), and
    // the pitches were verified by hand. Form is A–B–A across 12 bars,
    // all on the A and E strings (range A4 → F#5):
    //   • A  (M1–M4):  opening phrase, cadences on A
    //   • B  (M5–M8):  rises to F#5, cadences on E
    //   • A  (M9–M12): exact repeat of M1–M4
    noteIds: [
      // ── A section ──
      // M1: C# C# B A A
      'C#5_A', 'C#5_A', 'B4_A', 'A4_A', 'A4_A',
      // M2: B B C# B A
      'B4_A', 'B4_A', 'C#5_A', 'B4_A', 'A4_A',
      // M3: E E D C# C#
      'E5_E', 'E5_E', 'D5_A', 'C#5_A', 'C#5_A',
      // M4: B A B C# A(half)
      'B4_A', 'A4_A', 'B4_A', 'C#5_A', 'A4_A',
      // ── B section ──
      // M5: C# C# D E E
      'C#5_A', 'C#5_A', 'D5_A', 'E5_E', 'E5_E',
      // M6: F# F# E D C#
      'F#5_E', 'F#5_E', 'E5_E', 'D5_A', 'C#5_A',
      // M7: C# C# D E E
      'C#5_A', 'C#5_A', 'D5_A', 'E5_E', 'E5_E',
      // M8: F# F# E(half)
      'F#5_E', 'F#5_E', 'E5_E',
      // ── A section (repeat of M1–M4) ──
      // M9: C# C# B A A
      'C#5_A', 'C#5_A', 'B4_A', 'A4_A', 'A4_A',
      // M10: B B C# B A
      'B4_A', 'B4_A', 'C#5_A', 'B4_A', 'A4_A',
      // M11: E E D C# C#
      'E5_E', 'E5_E', 'D5_A', 'C#5_A', 'C#5_A',
      // M12: B A B C# A(half)
      'B4_A', 'A4_A', 'B4_A', 'C#5_A', 'A4_A',
    ],
    noteDurations: [
      // M1: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M2: q q e e q
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter,
      // M3: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M4: e e e e half
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.half,
      // M5: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M6: q q e e q
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter,
      // M7: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M8: q q half
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      // M9: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M10: q q e e q
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter,
      // M11: q e e q q
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.quarter,
      // M12: e e e e half
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'o_come_little_children',
    title: 'O Come Little Children',
    // A gentle Christmas carol — children gathering at the manger.
    icon: Icons.child_care_rounded,
    color: Color(0xFFE57373),
    visibility: SongVisibility.admin,
    // Christmas carol (J.A.P. Schulz, "Ihr Kinderlein, kommet") in A major,
    // 2/4. Transcribed via Audiveris OMR
    // (tools/test_fixtures/ocomelittlechildren.musicxml.mxl). Audiveris put a
    // spurious *bass* clef on the first line (M1–M4) and only switched to the
    // correct treble clef at M5, so the first line's pitches were reinterpreted
    // up by an octave-and-a-sixth. The proof it's right: after the fix, line 1
    // (M1–M4) becomes identical to line 2 (M5–M8) — exactly as the carol is
    // written (same tune, two verses of words). Each 2/4 bar = quarter + two
    // eighths; opens with an eighth-note pickup and ends on a dotted quarter.
    // Range A4 → A5, all on the A and E strings.
    noteIds: [
      // pickup
      'E5_E',
      // ── Line 1 (A): "O come, little children…" ──
      // M1: E C# E
      'E5_E', 'C#5_A', 'E5_E',
      // M2: E C# E
      'E5_E', 'C#5_A', 'E5_E',
      // M3: D B B
      'D5_A', 'B4_A', 'B4_A',
      // M4: C# (rest) E
      'C#5_A', '', 'E5_E',
      // ── Line 2 (A): "to Bethlehem haste…" ──
      // M5: E C# E
      'E5_E', 'C#5_A', 'E5_E',
      // M6: E C# E
      'E5_E', 'C#5_A', 'E5_E',
      // M7: D B B
      'D5_A', 'B4_A', 'B4_A',
      // M8: C# (rest) C#
      'C#5_A', '', 'C#5_A',
      // ── Line 3 (B) ──
      // M9: B B B
      'B4_A', 'B4_A', 'B4_A',
      // M10: D D D
      'D5_A', 'D5_A', 'D5_A',
      // M11: C# C# C#
      'C#5_A', 'C#5_A', 'C#5_A',
      // M12: F# (rest) F#
      'F#5_E', '', 'F#5_E',
      // M13: E E E  (open E string)
      'E5_E', 'E5_E', 'E5_E',
      // M14: A E C#  (A on the open E string, the high point)
      'A5_E', 'E5_E', 'C#5_A',
      // M15: D B B
      'D5_A', 'B4_A', 'B4_A',
      // M16: A (dotted quarter, final)
      'A4_A',
    ],
    noteDurations: [
      // pickup
      NoteDuration.eighth,
      // M1: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M2: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M3: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M4: q eRest e
      NoteDuration.quarter, NoteDuration.eighthRest, NoteDuration.eighth,
      // M5: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M6: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M7: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M8: q eRest e
      NoteDuration.quarter, NoteDuration.eighthRest, NoteDuration.eighth,
      // M9: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M10: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M11: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M12: q eRest e
      NoteDuration.quarter, NoteDuration.eighthRest, NoteDuration.eighth,
      // M13: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M14: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M15: q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M16: dotted quarter
      NoteDuration.dottedQuarter,
    ],
  ),
  SongDefinition(
    id: 'allegro',
    title: 'Allegro',
    // Brisk and energetic — a lightning bolt for the lively tempo.
    icon: Icons.bolt_rounded,
    color: Color(0xFFFFA726),
    visibility: SongVisibility.admin,
    // Suzuki Book 1 (Suzuki), A major, 4/4. Transcribed via Audiveris OMR
    // (tools/test_fixtures/allegro.musicxml.mvt1.mxl). The scan read cleanly
    // except M7, where straight quarter notes were mis-tagged as a triplet
    // (the parallel bar M3 proves it's four quarters). Full form: M1-M8 are the
    // A-theme stated twice (M1-M4 = M5-M8); M9-M12 are the contrasting middle
    // strain (M9 = M10); M13-M16 restate the opening line (= M1-M4). The E in
    // M12 is notated on the A string (4th finger) with a fermata; the app has
    // no 4th-finger position or fermata glyph, so it plays as the open E string
    // held for a half note. Range A4 -> A5 across the A and E strings.
    noteIds: [
      // M1: A A E E
      'A5_E', 'A5_E', 'E5_E', 'E5_E',
      // M2: F# G# A F# | E E
      'F#5_E', 'G#5_E', 'A5_E', 'F#5_E', 'E5_E', 'E5_E',
      // M3: D D C# C#
      'D5_A', 'D5_A', 'C#5_A', 'C#5_A',
      // M4: B A B C# | A(half)
      'B4_A', 'A4_A', 'B4_A', 'C#5_A', 'A4_A',
      // M5: A A E E
      'A5_E', 'A5_E', 'E5_E', 'E5_E',
      // M6: F# G# A F# | E E
      'F#5_E', 'G#5_E', 'A5_E', 'F#5_E', 'E5_E', 'E5_E',
      // M7: D D C# C#  (fixed from bogus triplets)
      'D5_A', 'D5_A', 'C#5_A', 'C#5_A',
      // M8: B A B C# | A(half)
      'B4_A', 'A4_A', 'B4_A', 'C#5_A', 'A4_A',
      // M9: F# F# E A(open)  [E string, drops to open A]
      'F#5_E', 'F#5_E', 'E5_E', 'A4_A',
      // M10: F# F# E A(open)  (repeat of M9)
      'F#5_E', 'F#5_E', 'E5_E', 'A4_A',
      // M11: F# G# A F#
      'F#5_E', 'G#5_E', 'A5_E', 'F#5_E',
      // M12: E C# B(half)  [E notated on A string; fermata on B]
      'E5_E', 'C#5_A', 'B4_A',
      // M13: A A E E  (= M1)
      'A5_E', 'A5_E', 'E5_E', 'E5_E',
      // M14: F# G# A F# | E E  (= M2)
      'F#5_E', 'G#5_E', 'A5_E', 'F#5_E', 'E5_E', 'E5_E',
      // M15: D D C# C#  (= M3)
      'D5_A', 'D5_A', 'C#5_A', 'C#5_A',
      // M16: B A B C# | A(half)  (= M4)
      'B4_A', 'A4_A', 'B4_A', 'C#5_A', 'A4_A',
    ],
    noteDurations: [
      // M1: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M2: e e e e q q
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter, NoteDuration.quarter,
      // M3: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M4: e e e e half
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.half,
      // M5: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M6: e e e e q q
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter, NoteDuration.quarter,
      // M7: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M8: e e e e half
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.half,
      // M9: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M10: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M11: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M12: q q half
      NoteDuration.quarter, NoteDuration.quarter, NoteDuration.half,
      // M13: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M14: e e e e q q
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.quarter, NoteDuration.quarter,
      // M15: q q q q
      NoteDuration.quarter, NoteDuration.quarter,
      NoteDuration.quarter, NoteDuration.quarter,
      // M16: e e e e half
      NoteDuration.eighth, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.eighth, NoteDuration.half,
    ],
  ),
  SongDefinition(
    id: 'long_long_ago',
    title: 'Long Long Ago',
    // A nostalgic tune of old tales — an open storybook.
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF8D6E63),
    visibility: SongVisibility.admin,
    // T.H. Bayly, "Long, Long Ago" (Suzuki Book 1), A major, 4/4. Transcribed
    // via Audiveris OMR (tools/test_fixtures/longlongago.musicxml.mvt1.mxl).
    // Pitches read cleanly; the rhythm needed light repair (Audiveris misread
    // one eighth as a 16th in M1 and a run as triplets in M5 — both resolve to
    // the plain "quarter + two eighths" figure the parallel bars use). Full
    // 16-bar form: bars 1-8 are the opening strain (two near-identical phrases);
    // bars 9-12 are the contrasting strain (a 2-bar phrase stated twice, dipping
    // to a low E on the D string); bars 13-16 restate the closing cadence
    // (identical to bars 5-8). Range E4 -> E5 across the D, A and E strings.
    noteIds: [
      // M1: A A B C# C# D
      'A4_A', 'A4_A', 'B4_A', 'C#5_A', 'C#5_A', 'D5_A',
      // M2: E F# E C#(half)
      'E5_E', 'F#5_E', 'E5_E', 'C#5_A',
      // M3: E D C# B(half)
      'E5_E', 'D5_A', 'C#5_A', 'B4_A',
      // M4: D C# B A(half)
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      // M5: A A B C# C# D
      'A4_A', 'A4_A', 'B4_A', 'C#5_A', 'C#5_A', 'D5_A',
      // M6: E F# E C#(half)
      'E5_E', 'F#5_E', 'E5_E', 'C#5_A',
      // M7: E D C# B | C# B
      'E5_E', 'D5_A', 'C#5_A', 'B4_A', 'C#5_A', 'B4_A',
      // M8: A(half)
      'A4_A',
      // M9: E D C# B | E(D string) E
      'E5_E', 'D5_A', 'C#5_A', 'B4_A', 'E4_D', 'E4_D',
      // M10: D C# B A(half)
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      // M11: E D C# B | E(D string) E  (repeat of M9)
      'E5_E', 'D5_A', 'C#5_A', 'B4_A', 'E4_D', 'E4_D',
      // M12: D C# B A(half)  (repeat of M10)
      'D5_A', 'C#5_A', 'B4_A', 'A4_A',
      // M13: A A B C# C# D  (= M5)
      'A4_A', 'A4_A', 'B4_A', 'C#5_A', 'C#5_A', 'D5_A',
      // M14: E F# E C#(half)  (= M6)
      'E5_E', 'F#5_E', 'E5_E', 'C#5_A',
      // M15: E D C# B | C# B  (= M7)
      'E5_E', 'D5_A', 'C#5_A', 'B4_A', 'C#5_A', 'B4_A',
      // M16: A(half)  (= M8)
      'A4_A',
    ],
    noteDurations: [
      // M1: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M2: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M3: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M4: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M5: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M6: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M7: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M8: half
      NoteDuration.half,
      // M9: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M10: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M11: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M12: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M13: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M14: q e e half
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.half,
      // M15: q e e q e e
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      NoteDuration.quarter, NoteDuration.eighth, NoteDuration.eighth,
      // M16: half
      NoteDuration.half,
    ],
  ),
];

class GameNote {
  const GameNote({
    required this.id,
    required this.letterLabel,
    required this.solfegeLabel,
    required this.staffStep,
    required this.fingerNumber,
    required this.stringIndex,
    required this.frequencyHz,
    required this.hintColor,
    this.lowSecondFinger = false,
  });

  final String id;
  final String letterLabel;
  final String solfegeLabel;
  final int staffStep;
  final int fingerNumber;
  final int stringIndex;
  final double frequencyHz;
  final Color hintColor;

  /// `true` for notes that need the 2nd finger placed close to the 1st
  /// finger (a half-step lower than its "normal" position) — e.g. C
  /// natural on the A string in keys like G major. The touch UI splits
  /// the finger-2 region in half: upper sub-zone = low 2, lower sub-zone
  /// = high 2.
  ///
  /// For backward compatibility, the strictness only kicks in when the
  /// target note is itself a low-2 note. High-2 targets (C#, F#)
  /// continue to accept either sub-zone, so existing D-major songs are
  /// unaffected.
  final bool lowSecondFinger;
}

/// The single source of truth for every playable note in the app. Both
/// learning screens derive their working pools from this list rather than
/// each carrying a hand-maintained copy (which previously drifted out of
/// sync). Order matters: the free-play fallback returns the first entry,
/// so the D string stays first.
///
///  * Learn Notes (free play) uses every note **except** `C5_A` — the
///    low-2 C natural only appears in song material.
///  * Learn Songs uses every note **except** the G-string notes, which no
///    current song reaches.
///
/// Keeping both as `.where(...)` views over this list means a note is
/// defined exactly once, so the two screens can never disagree again.
const List<GameNote> kGameNotePool = [
  // D / Re string (D string index: 1)
  GameNote(
    id: 'D4_D',
    letterLabel: 'D',
    solfegeLabel: 'Re',
    staffStep: -1,
    fingerNumber: 0,
    stringIndex: 1,
    frequencyHz: 293.66,
    hintColor: Color(0xFF58A6FF),
  ),
  GameNote(
    id: 'E4_D',
    letterLabel: 'E',
    solfegeLabel: 'Mi',
    staffStep: 0,
    fingerNumber: 1,
    stringIndex: 1,
    frequencyHz: 329.63,
    hintColor: Color(0xFF8F7CFF),
  ),
  GameNote(
    id: 'F#4_D',
    letterLabel: 'F#',
    solfegeLabel: 'Fa',
    staffStep: 1,
    fingerNumber: 2,
    stringIndex: 1,
    frequencyHz: 369.99,
    hintColor: Color(0xFFFF8A80),
  ),
  GameNote(
    id: 'G4_D',
    letterLabel: 'G',
    solfegeLabel: 'Sol',
    staffStep: 2,
    fingerNumber: 3,
    stringIndex: 1,
    frequencyHz: 392.00,
    hintColor: Color(0xFF50D6A5),
  ),
  // A / La string (A string index: 2)
  GameNote(
    id: 'A4_A',
    letterLabel: 'A',
    solfegeLabel: 'La',
    staffStep: 3,
    fingerNumber: 0,
    stringIndex: 2,
    frequencyHz: 440.00,
    hintColor: Color(0xFFFFA726),
  ),
  GameNote(
    id: 'B4_A',
    letterLabel: 'B',
    solfegeLabel: 'Si',
    staffStep: 4,
    fingerNumber: 1,
    stringIndex: 2,
    frequencyHz: 493.88,
    hintColor: Color(0xFF7E57C2),
  ),
  // C natural on the A string. Same staff position as C#5 (no
  // accidental), but the 2nd finger lands a half-step closer to the
  // 1st finger — like on a real violin. The `lowSecondFinger: true`
  // flag tells the touch UI to enforce that physical position.
  GameNote(
    id: 'C5_A',
    letterLabel: 'C',
    solfegeLabel: 'Do',
    staffStep: 5,
    fingerNumber: 2,
    stringIndex: 2,
    frequencyHz: 523.25,
    hintColor: Color(0xFFFFD54F),
    lowSecondFinger: true,
  ),
  GameNote(
    id: 'C#5_A',
    letterLabel: 'C#',
    solfegeLabel: 'Do#',
    staffStep: 5,
    fingerNumber: 2,
    stringIndex: 2,
    frequencyHz: 554.37,
    hintColor: Color(0xFF26A69A),
  ),
  GameNote(
    id: 'D5_A',
    letterLabel: 'D',
    solfegeLabel: 'Re',
    staffStep: 6,
    fingerNumber: 3,
    stringIndex: 2,
    frequencyHz: 587.33,
    hintColor: Color(0xFF42A5F5),
  ),
  // E / Mi string (E string index: 3)
  GameNote(
    id: 'E5_E',
    letterLabel: 'E',
    solfegeLabel: 'Mi',
    staffStep: 7,
    fingerNumber: 0,
    stringIndex: 3,
    frequencyHz: 659.25,
    hintColor: Color(0xFFEC407A),
  ),
  GameNote(
    id: 'F#5_E',
    letterLabel: 'F#',
    solfegeLabel: 'Fa#',
    staffStep: 8,
    fingerNumber: 1,
    stringIndex: 3,
    frequencyHz: 739.99,
    hintColor: Color(0xFFFF7043),
  ),
  // G# / A on the E string — needed for any A-major piece (e.g.
  // Suzuki "Song of the Wind"). G# is the high-2 finger position on
  // the E string, A is the 3rd finger.
  GameNote(
    id: 'G#5_E',
    letterLabel: 'G#',
    solfegeLabel: 'Sol#',
    staffStep: 9,
    fingerNumber: 2,
    stringIndex: 3,
    frequencyHz: 830.61,
    hintColor: Color(0xFFAB47BC),
  ),
  GameNote(
    id: 'A5_E',
    letterLabel: 'A',
    solfegeLabel: 'La',
    staffStep: 10,
    fingerNumber: 3,
    stringIndex: 3,
    frequencyHz: 880.00,
    hintColor: Color(0xFFFFB300),
  ),
  // G / Sol string (G string index: 0)
  GameNote(
    id: 'G3_G',
    letterLabel: 'G',
    solfegeLabel: 'Sol',
    staffStep: -5,
    fingerNumber: 0,
    stringIndex: 0,
    frequencyHz: 196.00,
    hintColor: Color(0xFF66BB6A),
  ),
  GameNote(
    id: 'A3_G',
    letterLabel: 'A',
    solfegeLabel: 'La',
    staffStep: -4,
    fingerNumber: 1,
    stringIndex: 0,
    frequencyHz: 220.00,
    hintColor: Color(0xFFFFCA28),
  ),
  GameNote(
    id: 'B3_G',
    letterLabel: 'B',
    solfegeLabel: 'Si',
    staffStep: -3,
    fingerNumber: 2,
    stringIndex: 0,
    frequencyHz: 246.94,
    hintColor: Color(0xFF7E57C2),
  ),
  GameNote(
    id: 'C4_G',
    letterLabel: 'C',
    solfegeLabel: 'Do',
    staffStep: -2,
    fingerNumber: 3,
    stringIndex: 0,
    frequencyHz: 261.63,
    hintColor: Color(0xFF26C6DA),
  ),
];

/// Shared three-level adaptive-hint bookkeeping used by both the Learn
/// Notes (free play) and Learn Songs screens. Each concrete screen supplies
/// its working [adaptiveNotePool]; the *triggers* that promote or demote a
/// note between levels stay in each screen's play handlers (they legitimately
/// differ — free play tracks per-string stats, songs track by-heart mode),
/// but the per-note state maps and the hydration from / persistence to
/// [_HeroProgressStore] are identical and live here once, so the two modules
/// can never disagree about a note's mastery.
mixin _AdaptiveNoteLearning<T extends StatefulWidget> on State<T> {
  /// The notes this screen tracks adaptive state for.
  List<GameNote> get adaptiveNotePool;

  late final Map<String, int> _consecutiveCorrect = {
    for (final note in adaptiveNotePool) note.id: 0,
  };
  // Counts only those consecutive correct plays where the note was
  // already at Level 2 (color hidden) at the start of the play. This is
  // what gates the Level 2 → 3 transition — a fresh player who gets 3
  // correct in a row at Level 1 graduates to Level 2 but still needs 3
  // *more* correct plays *at Level 2* before the name hides. Reset on any
  // mistake or whenever the hint comes back.
  late final Map<String, int> _consecutiveCorrectAtLevel2 = {
    for (final note in adaptiveNotePool) note.id: 0,
  };
  late final Map<String, bool> _mastered = {
    for (final note in adaptiveNotePool) note.id: false,
  };
  late final Map<String, bool> _hideHintForNote = {
    for (final note in adaptiveNotePool) note.id: false,
  };
  late final Map<String, int> _mistakesWithoutHint = {
    for (final note in adaptiveNotePool) note.id: 0,
  };
  // Sticky: once a note has reached Level 3, [_nameMastered] stays true
  // forever even if the name comes back due to mistakes — that way
  // Level 2.5 → 3 re-mastery uses the lower threshold.
  late final Map<String, bool> _nameMastered = {
    for (final note in adaptiveNotePool) note.id: false,
  };
  late final Map<String, bool> _hideNoteNameForNote = {
    for (final note in adaptiveNotePool) note.id: false,
  };
  late final Map<String, int> _mistakesWithoutNoteName = {
    for (final note in adaptiveNotePool) note.id: 0,
  };

  /// Pulls each note's persisted [NoteAdaptiveState] (mastery + hide flags)
  /// from [_HeroProgressStore] into the local working maps so progress
  /// carries across screen entries, modules, and sessions. The store is
  /// loaded synchronously at app launch, so this usually returns instantly;
  /// the async branch guards against entering a screen before that load
  /// completes.
  Future<void> _hydrateAdaptiveStatesFromStore() async {
    await _HeroProgressStore.load();
    if (!mounted) return;
    var dirty = false;
    for (final note in adaptiveNotePool) {
      final state = _HeroProgressStore.noteAdaptiveStateFor(note.id);
      if (_mastered[note.id] != state.mastered) {
        _mastered[note.id] = state.mastered;
        dirty = true;
      }
      if (_hideHintForNote[note.id] != state.hideHint) {
        _hideHintForNote[note.id] = state.hideHint;
        dirty = true;
      }
      if (_nameMastered[note.id] != state.nameMastered) {
        _nameMastered[note.id] = state.nameMastered;
        dirty = true;
      }
      if (_hideNoteNameForNote[note.id] != state.hideName) {
        _hideNoteNameForNote[note.id] = state.hideName;
        dirty = true;
      }
    }
    if (dirty) setState(() {});
  }

  /// Writes the four-flag adaptive state back to the shared store. Called
  /// after every level transition (correct or wrong) so the next screen
  /// entry — same module or different — picks up exactly where the player
  /// left off. The store call is idempotent and debounces remote sync, so
  /// calling on every play is cheap.
  void _persistAdaptiveStateForNote(String noteId) {
    final state = NoteAdaptiveState(
      mastered: _mastered[noteId] ?? false,
      hideHint: _hideHintForNote[noteId] ?? false,
      nameMastered: _nameMastered[noteId] ?? false,
      hideName: _hideNoteNameForNote[noteId] ?? false,
    );
    unawaited(_HeroProgressStore.saveNoteAdaptiveState(noteId, state));
  }
}

