part of 'main.dart';

enum FeedbackState { idle, correct, wrong }

enum StageMode { learnSingleString, mixedStrings }

/// Standard note durations supported by the rhythm engine.
///
/// Each value covers a rhythmic *slot* — either a sounding pitch or a
/// silence (rest) of the same length. Rest variants are suffixed with
/// `Rest` and carry [NoteDurationSpec.isRest] = true. The song-learning
/// screen uses that flag to:
///   • render a rest glyph instead of a note head,
///   • skip audio playback for the slot,
///   • auto-advance after the elapsed silence (no tap required).
///
/// To add a new rhythm (sixteenth, dotted eighth, triplet, …):
///   1. Add a value to this enum (and its rest counterpart if it can be
///      a rest).
///   2. Add a [NoteDurationSpec] entry to [kNoteDurationSpecs] describing
///      its rhythmic value and how it should be drawn on the staff.
///   3. Add a branch to [noteDurationMs] mapping it to playback ms.
///
/// Everything else (audio playback, staff rendering, beat counting) reads
/// from those tables, so a new rhythm requires no scattered `if` updates.
enum NoteDuration {
  sixteenth,
  eighth,
  dottedEighth,
  quarter,
  dottedQuarter,
  half,
  dottedHalf,
  whole,
  // Rests — sit silently for the corresponding duration. The song
  // engine auto-advances through them, so the student isn't asked to
  // tap during silence.
  sixteenthRest,
  eighthRest,
  quarterRest,
  dottedQuarterRest,
  halfRest,
  dottedHalfRest,
  wholeRest,
}

/// Visual + rhythmic properties of a [NoteDuration]. The renderer queries
/// these flags so each duration can be drawn correctly on the staff
/// without bespoke per-duration code paths.
class NoteDurationSpec {
  const NoteDurationSpec({
    required this.beatUnits,
    required this.hasOpenHead,
    required this.hasStem,
    required this.flagCount,
    required this.isDotted,
    this.isRest = false,
    this.restGlyph,
  });

  /// Length of the slot expressed in quarter-note beats.
  final double beatUnits;

  /// `true` for half / dotted-half / whole — drawn as an outlined oval.
  /// Ignored for rests.
  final bool hasOpenHead;

  /// `false` only for whole notes (no stem). Ignored for rests.
  final bool hasStem;

  /// 0 = none, 1 = eighth flag, 2 = sixteenth (reserved for future use).
  /// Ignored for rests.
  final int flagCount;

  /// `true` for dotted rhythms — the painter renders an augmentation dot
  /// after the note head (or rest glyph).
  final bool isDotted;

  /// `true` for rest slots. The painter draws [restGlyph] instead of a
  /// pitched note, the audio engine plays nothing, and the song-learning
  /// screen ignores tap input until the rest elapses.
  final bool isRest;

  /// Unicode glyph used to render the rest on the staff. Only meaningful
  /// when [isRest] is true. Drawn via TextPainter, same way the treble
  /// clef glyph is drawn.
  final String? restGlyph;
}

const Map<NoteDuration, NoteDurationSpec> kNoteDurationSpecs = {
  NoteDuration.sixteenth: NoteDurationSpec(
    beatUnits: 0.25,
    hasOpenHead: false,
    hasStem: true,
    flagCount: 2,
    isDotted: false,
  ),
  NoteDuration.eighth: NoteDurationSpec(
    beatUnits: 0.5,
    hasOpenHead: false,
    hasStem: true,
    flagCount: 1,
    isDotted: false,
  ),
  NoteDuration.dottedEighth: NoteDurationSpec(
    beatUnits: 0.75,
    hasOpenHead: false,
    hasStem: true,
    flagCount: 1,
    isDotted: true,
  ),
  NoteDuration.quarter: NoteDurationSpec(
    beatUnits: 1.0,
    hasOpenHead: false,
    hasStem: true,
    flagCount: 0,
    isDotted: false,
  ),
  NoteDuration.dottedQuarter: NoteDurationSpec(
    beatUnits: 1.5,
    hasOpenHead: false,
    hasStem: true,
    flagCount: 0,
    isDotted: true,
  ),
  NoteDuration.half: NoteDurationSpec(
    beatUnits: 2.0,
    hasOpenHead: true,
    hasStem: true,
    flagCount: 0,
    isDotted: false,
  ),
  NoteDuration.dottedHalf: NoteDurationSpec(
    beatUnits: 3.0,
    hasOpenHead: true,
    hasStem: true,
    flagCount: 0,
    isDotted: true,
  ),
  NoteDuration.whole: NoteDurationSpec(
    beatUnits: 4.0,
    hasOpenHead: true,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
  ),
  // Rest slots. `restGlyph` uses the SMuFL/Unicode musical-symbol code
  // points so the painter can render them with the same TextPainter
  // pipeline used for the treble clef. Dotted rests reuse the base
  // glyph and add an augmentation dot via the existing `isDotted`
  // rendering branch.
  NoteDuration.sixteenthRest: NoteDurationSpec(
    beatUnits: 0.25,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
    isRest: true,
    restGlyph: '\u{1D13F}', // 𝄿 sixteenth rest
  ),
  NoteDuration.eighthRest: NoteDurationSpec(
    beatUnits: 0.5,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
    isRest: true,
    restGlyph: '\u{1D13E}', // 𝄾 eighth rest
  ),
  NoteDuration.quarterRest: NoteDurationSpec(
    beatUnits: 1.0,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
    isRest: true,
    restGlyph: '\u{1D13D}', // 𝄽 quarter rest
  ),
  NoteDuration.dottedQuarterRest: NoteDurationSpec(
    beatUnits: 1.5,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: true,
    isRest: true,
    restGlyph: '\u{1D13D}', // 𝄽 quarter rest + augmentation dot
  ),
  NoteDuration.halfRest: NoteDurationSpec(
    beatUnits: 2.0,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
    isRest: true,
    restGlyph: '\u{1D13C}', // 𝄼 half rest
  ),
  NoteDuration.dottedHalfRest: NoteDurationSpec(
    beatUnits: 3.0,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: true,
    isRest: true,
    restGlyph: '\u{1D13C}', // 𝄼 half rest + augmentation dot
  ),
  NoteDuration.wholeRest: NoteDurationSpec(
    beatUnits: 4.0,
    hasOpenHead: false,
    hasStem: false,
    flagCount: 0,
    isDotted: false,
    isRest: true,
    restGlyph: '\u{1D13B}', // 𝄻 whole rest
  ),
};

extension NoteDurationStyle on NoteDuration {
  NoteDurationSpec get spec => kNoteDurationSpecs[this]!;
}

/// Base millisecond durations used by [noteDurationMs]. Tuned for a
/// learning experience that gives kids time to react on shorter notes,
/// so these aren't strict 2:1 ratios — each step up roughly doubles
/// minus ~10–15%, which keeps shorter values from feeling punishingly
/// fast.
const int kSixteenthNoteMs = 200;
const int kEighthNoteMs = 340;
const int kQuarterNoteMs = 620;
const int kHalfNoteMs = 1120;
const int kWholeNoteMs = 2200;

/// Playback (or silent-wait, for rests) duration in ms for each
/// [NoteDuration]. Dotted values are derived additively (dotted quarter
/// = quarter + eighth, dotted half = half + quarter, dotted eighth =
/// eighth + sixteenth) which keeps the existing "feel" of the game
/// while still being musically correct.
int noteDurationMs(NoteDuration duration) {
  switch (duration) {
    case NoteDuration.sixteenth:
    case NoteDuration.sixteenthRest:
      return kSixteenthNoteMs;
    case NoteDuration.eighth:
    case NoteDuration.eighthRest:
      return kEighthNoteMs;
    case NoteDuration.dottedEighth:
      return kEighthNoteMs + kSixteenthNoteMs;
    case NoteDuration.quarter:
    case NoteDuration.quarterRest:
      return kQuarterNoteMs;
    case NoteDuration.dottedQuarter:
    case NoteDuration.dottedQuarterRest:
      return kQuarterNoteMs + kEighthNoteMs;
    case NoteDuration.half:
    case NoteDuration.halfRest:
      return kHalfNoteMs;
    case NoteDuration.dottedHalf:
    case NoteDuration.dottedHalfRest:
      return kHalfNoteMs + kQuarterNoteMs;
    case NoteDuration.whole:
    case NoteDuration.wholeRest:
      return kWholeNoteMs;
  }
}

class LearningStage {
  const LearningStage({
    required this.title,
    required this.activeStringIndices,
    required this.mode,
  });

  final String title;
  final List<int> activeStringIndices;
  final StageMode mode;
}

/// Controls who can see a song in the song-selection list.
///
/// `public` — visible to every signed-in user. The default for legacy
/// songs and any song that's been promoted out of the draft library.
///
/// `admin` — visible only to accounts whose username appears in
/// [kAdminUsernames]. Used as a staging library where new songs (e.g.
/// the rest of Suzuki Book 1) can be authored, played, and verified
/// before being released to the general player base.
enum SongVisibility { public, admin }

/// Lowercased usernames that can see admin-only ([SongVisibility.admin])
/// songs. Edit this set to grant additional accounts access to the
/// staging library.
///
/// This is *not* a security boundary — the list ships in the client
/// bundle and anyone inspecting the JS could read it. Its purpose is
/// purely product-level: hide draft / unfinished songs from the regular
/// player base while we iterate.
const Set<String> kAdminUsernames = {'admin'};

bool isAdminUser(UserSession? session) {
  if (session == null) return false;
  return kAdminUsernames.contains(session.username.trim().toLowerCase());
}

class SongDefinition {
  const SongDefinition({
    required this.id,
    required this.title,
    required this.noteIds,
    required this.noteDurations,
    this.icon = Icons.music_note_rounded,
    this.color = const Color(0xFF4FB38E),
    this.visibility = SongVisibility.public,
  });

  final String id;
  final String title;

  /// Parallel to [noteDurations]. For *rest* slots (where the matching
  /// duration's `spec.isRest` is true), the entry is the empty string —
  /// no pitch is associated with the slot. The runtime never looks up a
  /// note by an empty id; instead it routes rest slots through the
  /// silent auto-advance path.
  final List<String> noteIds;

  /// Per-slot rhythmic value — single source of truth for both audio
  /// playback and the visual representation on the staff. Rest slots
  /// use the rest variants from [NoteDuration].
  final List<NoteDuration> noteDurations;

  /// Icon shown on the song-selection card. Each song can have its own
  /// visual identity without the selection screen needing per-song
  /// hardcoding.
  final IconData icon;

  /// Accent color for the song-selection card and the progress stars.
  final Color color;

  /// Whether the song is shown to every player or only to admin
  /// accounts. See [SongVisibility].
  final SongVisibility visibility;
}

class UserSession {
  const UserSession({
    required this.username,
    required this.avatarId,
  });

  final String username;
  final String avatarId;
}

/// Persisted per-note adaptive learning state. Shared across the
/// Learn Notes and Learn Songs modules so a note mastered in one
/// module starts at the same level in the other.
///
/// Only the *level* state persists — transient counters (consecutive
/// correct streaks, mistake counts inside a level) reset on each
/// fresh session, which matches the natural feeling that closing the
/// app ends the current attempt streak while preserving mastery.
class NoteAdaptiveState {
  const NoteAdaptiveState({
    required this.mastered,
    required this.hideHint,
    required this.nameMastered,
    required this.hideName,
  });

  /// Sticky: once `true`, stays `true`. Drives the lower re-master
  /// threshold for the Level 1 ↔ 2 transition.
  final bool mastered;

  /// Currently hiding the color hint (Level 2+). Flips back to false
  /// when too many mistakes accumulate at Level 2.
  final bool hideHint;

  /// Sticky: once `true`, stays `true`. Drives the lower re-master
  /// threshold for the Level 2 ↔ 3 transition.
  final bool nameMastered;

  /// Currently hiding the solfège card (Level 3). Flips back to false
  /// when too many mistakes accumulate at Level 3.
  final bool hideName;

  static const NoteAdaptiveState fresh = NoteAdaptiveState(
    mastered: false,
    hideHint: false,
    nameMastered: false,
    hideName: false,
  );

  bool get isFresh =>
      !mastered && !hideHint && !nameMastered && !hideName;

  NoteAdaptiveState copyWith({
    bool? mastered,
    bool? hideHint,
    bool? nameMastered,
    bool? hideName,
  }) {
    return NoteAdaptiveState(
      mastered: mastered ?? this.mastered,
      hideHint: hideHint ?? this.hideHint,
      nameMastered: nameMastered ?? this.nameMastered,
      hideName: hideName ?? this.hideName,
    );
  }

  Map<String, dynamic> toJson() => {
        if (mastered) 'm': true,
        if (hideHint) 'hh': true,
        if (nameMastered) 'nm': true,
        if (hideName) 'hn': true,
      };

  static NoteAdaptiveState fromJson(Object? raw) {
    if (raw is! Map) return fresh;
    return NoteAdaptiveState(
      mastered: raw['m'] == true,
      hideHint: raw['hh'] == true,
      nameMastered: raw['nm'] == true,
      hideName: raw['hn'] == true,
    );
  }

  /// Per-flag max — preserves the more-progressed state across two
  /// snapshots (e.g. local + remote). Sticky bits never regress; the
  /// transient hide flags also take the more-progressed value, since
  /// hiding a hint represents *more* mastery than showing it.
  NoteAdaptiveState mergeWith(NoteAdaptiveState other) {
    return NoteAdaptiveState(
      mastered: mastered || other.mastered,
      hideHint: hideHint || other.hideHint,
      nameMastered: nameMastered || other.nameMastered,
      hideName: hideName || other.hideName,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoteAdaptiveState &&
      other.mastered == mastered &&
      other.hideHint == hideHint &&
      other.nameMastered == nameMastered &&
      other.hideName == hideName;

  @override
  int get hashCode =>
      Object.hash(mastered, hideHint, nameMastered, hideName);
}

class HeroProgress {
  const HeroProgress({
    required this.stars,
    required this.streakDays,
    required this.lastActiveDayEpoch,
    required this.weekId,
    required this.activeDaysThisWeek,
    required this.streakShieldUsedWeekId,
    required this.weeklyBonusAwardedWeekId,
    required this.stringSectionStars,
    required this.songSectionStars,
    required this.noteAdaptiveStates,
  });

  static const HeroProgress initial = HeroProgress(
    stars: 0,
    streakDays: 0,
    lastActiveDayEpoch: null,
    weekId: 0,
    activeDaysThisWeek: 0,
    streakShieldUsedWeekId: -1,
    weeklyBonusAwardedWeekId: -1,
    stringSectionStars: {},
    songSectionStars: {},
    noteAdaptiveStates: {},
  );

  final int stars;
  final int streakDays;
  final int? lastActiveDayEpoch;
  final int weekId;
  final int activeDaysThisWeek;
  final int streakShieldUsedWeekId;
  final int weeklyBonusAwardedWeekId;
  final Map<int, int> stringSectionStars;
  final Map<String, int> songSectionStars;

  /// Per-note adaptive learning levels, keyed by [GameNote.id]
  /// (e.g. `'D5_A'`). Notes not present here are treated as fresh
  /// (Level 1, all flags false).
  final Map<String, NoteAdaptiveState> noteAdaptiveStates;

  HeroProgress copyWith({
    int? stars,
    int? streakDays,
    int? lastActiveDayEpoch,
    bool clearLastActiveDay = false,
    int? weekId,
    int? activeDaysThisWeek,
    int? streakShieldUsedWeekId,
    int? weeklyBonusAwardedWeekId,
    Map<int, int>? stringSectionStars,
    Map<String, int>? songSectionStars,
    Map<String, NoteAdaptiveState>? noteAdaptiveStates,
  }) {
    return HeroProgress(
      stars: stars ?? this.stars,
      streakDays: streakDays ?? this.streakDays,
      lastActiveDayEpoch: clearLastActiveDay
          ? null
          : (lastActiveDayEpoch ?? this.lastActiveDayEpoch),
      weekId: weekId ?? this.weekId,
      activeDaysThisWeek: activeDaysThisWeek ?? this.activeDaysThisWeek,
      streakShieldUsedWeekId:
          streakShieldUsedWeekId ?? this.streakShieldUsedWeekId,
      weeklyBonusAwardedWeekId:
          weeklyBonusAwardedWeekId ?? this.weeklyBonusAwardedWeekId,
      stringSectionStars: stringSectionStars ?? this.stringSectionStars,
      songSectionStars: songSectionStars ?? this.songSectionStars,
      noteAdaptiveStates: noteAdaptiveStates ?? this.noteAdaptiveStates,
    );
  }
}

class _ProgressAward {
  const _ProgressAward({
    required this.earnedStars,
    required this.usedStreakShield,
    required this.triggeredWeeklyBonus,
  });

  final int earnedStars;
  final bool usedStreakShield;
  final bool triggeredWeeklyBonus;
}

