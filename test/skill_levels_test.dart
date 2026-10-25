import 'package:flutter_test/flutter_test.dart';

import 'package:violin_hero/main.dart';

List<String> _songIdsFor(UserSession session) =>
    songsForSession(session).map((song) => song.id).toList();

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

  group('songsForSession', () {
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
      for (final ids in kLevelSongs.values) {
        expect(libraryIds, containsAll(ids));
      }
    });
  });
}
