import 'package:flutter_test/flutter_test.dart';

import 'package:violin_hero/main.dart';

List<String> _songIdsFor(UserSession session) =>
    practiceSongsForSession(session).map((song) => song.id).toList();

UserSession _session(String username, SkillLevel level) =>
    UserSession(username: username, avatarId: 'avatar_frog', level: level);

void main() {
  group('resolveSkillLevel', () {
    test('override map beats the level chosen at signup', () {
      expect(resolveSkillLevel('tal', SkillLevel.beginner), SkillLevel.advanced);
      expect(
        resolveSkillLevel('  Gelila Q ', null),
        SkillLevel.advanced,
      );
      expect(resolveSkillLevel('אלנה', null), SkillLevel.intermediate);
    });

    test('falls back to the signup choice, then beginner', () {
      expect(
        resolveSkillLevel('someone_new', SkillLevel.intermediate),
        SkillLevel.intermediate,
      );
      expect(resolveSkillLevel('someone_new', null), SkillLevel.beginner);
    });
  });

  group('practiceSongsForSession', () {
    test('beginner has no songs', () {
      expect(_songIdsFor(_session('kid', SkillLevel.beginner)), isEmpty);
    });

    test('intermediate gets the four starter songs in order', () {
      expect(_songIdsFor(_session('kid', SkillLevel.intermediate)), [
        'twinkle_la',
        'twinkle_harmony_vln2',
        'frere_jacques',
        'lightly_row',
      ]);
    });

    test('advanced gets intermediate songs plus five more, in order', () {
      expect(_songIdsFor(_session('kid', SkillLevel.advanced)), [
        'twinkle_la',
        'twinkle_harmony_vln2',
        'frere_jacques',
        'lightly_row',
        'song_of_the_wind',
        'go_tell_aunt_rhody',
        'o_come_little_children',
        'ode_to_joy',
        'mississippi_reel',
      ]);
    });

    test('admin sees the whole library regardless of level', () {
      expect(
        _songIdsFor(_session('admin', SkillLevel.beginner)),
        kSongLibrary.map((song) => song.id).toList(),
      );
    });

    test('every listed song ID exists in the library', () {
      final libraryIds = kSongLibrary.map((song) => song.id).toSet();
      for (final ids in [
        ...kLevelSongs.values,
        ...kLevelNewSongs.values,
        kAdminNewSongs,
      ]) {
        expect(libraryIds, containsAll(ids));
      }
    });
  });

  test('beginners only get Practice Notes; other levels and admin get song modules', () {
    expect(hasSongModules(_session('kid', SkillLevel.beginner)), isFalse);
    expect(hasSongModules(_session('kid', SkillLevel.intermediate)), isTrue);
    expect(hasSongModules(_session('kid', SkillLevel.advanced)), isTrue);
    expect(hasSongModules(_session('admin', SkillLevel.beginner)), isTrue);
  });

  test('every song is well-formed', () {
    final noteIds = kGameNotePool.map((note) => note.id).toSet();
    for (final song in kSongLibrary) {
      expect(song.noteIds.length, song.noteDurations.length, reason: song.id);
      for (var i = 0; i < song.noteIds.length; i++) {
        final isRest = song.noteDurations[i].spec.isRest;
        expect(
          isRest ? song.noteIds[i].isEmpty : noteIds.contains(song.noteIds[i]),
          isTrue,
          reason: '${song.id} slot $i',
        );
      }
    }
  });

  test('G# on the D string is a high-3 G# (415.30 Hz)', () {
    final gSharp = kGameNotePool.firstWhere((note) => note.id == 'G#4_D');
    expect(gSharp.frequencyHz, 415.30);
    expect(gSharp.fingerNumber, 3);
    expect(gSharp.highThirdFinger, isTrue);
    expect(
      kGameNotePool.firstWhere((note) => note.id == 'G4_D').highThirdFinger,
      isFalse,
    );
  });

  test('Song of the Wind Harmony is 14 bars of 2/4', () {
    final song =
        kSongLibrary.firstWhere((s) => s.id == 'song_of_the_wind_harmony');
    final beats = song.noteDurations
        .fold<double>(0, (sum, d) => sum + d.spec.beatUnits);
    expect(beats, 28);
    expect(song.visibility, SongVisibility.admin);
  });

  test('Yonatan Hakatan Harmony is 16 bars of 4 beats', () {
    final song = kSongLibrary.firstWhere((s) => s.id == 'lightly_row_harmony');
    final beats = song.noteDurations
        .fold<double>(0, (sum, d) => sum + d.spec.beatUnits);
    expect(beats, 64);
    expect(song.visibility, SongVisibility.admin);
  });

  group('newSongsForSession', () {
    List<String> newIdsFor(UserSession session) =>
        newSongsForSession(session).map((song) => song.id).toList();

    test('each level gets its own new songs', () {
      expect(newIdsFor(_session('kid', SkillLevel.beginner)), isEmpty);
      expect(
        newIdsFor(_session('kid', SkillLevel.intermediate)),
        ['song_of_the_wind'],
      );
      expect(newIdsFor(_session('kid', SkillLevel.advanced)), ['allegro']);
    });

    test('new songs stay out of the same level\'s practice songs', () {
      for (final level in SkillLevel.values) {
        final session = _session('kid', level);
        expect(
          _songIdsFor(session).toSet().intersection(newIdsFor(session).toSet()),
          isEmpty,
        );
      }
    });

    test('admin has no new songs', () {
      expect(newIdsFor(_session('admin', SkillLevel.advanced)), isEmpty);
    });
  });
}
