part of 'main.dart';

class _HeroProgressStore {
  static const String _starsKey = 'hero_stars';
  static const String _streakDaysKey = 'hero_streak_days';
  static const String _lastActiveDayEpochKey = 'hero_last_active_day_epoch';
  static const String _weekIdKey = 'hero_week_id';
  static const String _activeDaysThisWeekKey = 'hero_active_days_week';
  static const String _shieldUsedWeekIdKey = 'hero_shield_used_week_id';
  static const String _weeklyBonusWeekIdKey = 'hero_weekly_bonus_week_id';
  static const String _stringSectionStarsKey = 'hero_string_section_rank_stars_v2';
  static const String _songSectionStarsKey = 'hero_song_section_rank_stars_v2';
  static const String _noteAdaptiveStatesKey = 'hero_note_adaptive_states_v1';
  static const List<int> _streakMilestones = [2, 3, 5, 7, 14, 21, 30];

  static const String _authEndpoint = String.fromEnvironment(
    'VH_AUTH_ENDPOINT',
    defaultValue: '',
  );

  static String get _progressEndpoint {
    if (_authEndpoint.isEmpty) return '';
    final i = _authEndpoint.lastIndexOf('/');
    if (i < 0) return '';
    return '${_authEndpoint.substring(0, i)}/violin-progress';
  }

  static final ValueNotifier<HeroProgress> progressListenable =
      ValueNotifier<HeroProgress>(HeroProgress.initial);
  static bool _loaded = false;
  static final Set<int> _awardedStringThisSession = <int>{};
  static final Set<String> _awardedSongThisSession = <String>{};
  static Timer? _remoteSyncTimer;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static int _weekIdForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    final monday = normalized.subtract(Duration(days: normalized.weekday - 1));
    return monday.millisecondsSinceEpoch;
  }

  static int _dayEpoch(DateTime day) =>
      DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

  static Future<void> _persist(HeroProgress progress) async {
    final prefs = await _prefs();
    await prefs.setInt(_starsKey, progress.stars);
    await prefs.setInt(_streakDaysKey, progress.streakDays);
    if (progress.lastActiveDayEpoch == null) {
      await prefs.remove(_lastActiveDayEpochKey);
    } else {
      await prefs.setInt(_lastActiveDayEpochKey, progress.lastActiveDayEpoch!);
    }
    await prefs.setInt(_weekIdKey, progress.weekId);
    await prefs.setInt(_activeDaysThisWeekKey, progress.activeDaysThisWeek);
    await prefs.setInt(_shieldUsedWeekIdKey, progress.streakShieldUsedWeekId);
    await prefs.setInt(
      _weeklyBonusWeekIdKey,
      progress.weeklyBonusAwardedWeekId,
    );
    await prefs.setString(
      _stringSectionStarsKey,
      jsonEncode({
        for (final entry in progress.stringSectionStars.entries)
          '${entry.key}': entry.value,
      }),
    );
    await prefs.setString(
      _songSectionStarsKey,
      jsonEncode(progress.songSectionStars),
    );
    await prefs.setString(
      _noteAdaptiveStatesKey,
      jsonEncode(_encodeNoteAdaptiveStates(progress.noteAdaptiveStates)),
    );
    _scheduleRemoteSync();
  }

  /// Strips notes that are entirely fresh (all flags false) from the
  /// serialized payload — they're indistinguishable from "missing" on
  /// load, so omitting them keeps the column lean.
  static Map<String, dynamic> _encodeNoteAdaptiveStates(
    Map<String, NoteAdaptiveState> states,
  ) {
    final out = <String, dynamic>{};
    for (final entry in states.entries) {
      if (entry.value.isFresh) continue;
      out[entry.key] = entry.value.toJson();
    }
    return out;
  }

  static Map<String, NoteAdaptiveState> _decodeNoteAdaptiveStates(Object? raw) {
    if (raw == null) return {};
    Map<String, dynamic>? decoded;
    if (raw is String) {
      if (raw.isEmpty) return {};
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          decoded = parsed.map((k, v) => MapEntry('$k', v));
        }
      } catch (_) {
        return {};
      }
    } else if (raw is Map) {
      decoded = raw.map((k, v) => MapEntry('$k', v));
    }
    if (decoded == null) return {};
    final result = <String, NoteAdaptiveState>{};
    for (final entry in decoded.entries) {
      final state = NoteAdaptiveState.fromJson(entry.value);
      if (state.isFresh) continue;
      result[entry.key] = state;
    }
    return result;
  }

  static void _scheduleRemoteSync() {
    if (_progressEndpoint.isEmpty) return;
    _remoteSyncTimer?.cancel();
    _remoteSyncTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_syncProgressToRemote());
    });
  }

  static Future<void> _syncProgressToRemote() async {
    if (_progressEndpoint.isEmpty) return;
    try {
      final prefs = await _prefs();
      final username = prefs.getString('auth_username');
      if (username == null || username.isEmpty) return;
      final progress = progressListenable.value;
      final uri = Uri.parse(_progressEndpoint);
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'save',
              'username': username,
              'progress': {
                'stars': progress.stars,
                'streak_days': progress.streakDays,
                'last_active_day_epoch': progress.lastActiveDayEpoch,
                'week_id': progress.weekId,
                'active_days_this_week': progress.activeDaysThisWeek,
                'streak_shield_used_week_id': progress.streakShieldUsedWeekId,
                'weekly_bonus_awarded_week_id':
                    progress.weeklyBonusAwardedWeekId,
                'string_section_stars': {
                  for (final e in progress.stringSectionStars.entries)
                    '${e.key}': e.value,
                },
                'song_section_stars': progress.songSectionStars,
                'note_adaptive_states':
                    _encodeNoteAdaptiveStates(progress.noteAdaptiveStates),
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Remote sync is best-effort; local data is always authoritative.
    }
  }

  static Future<HeroProgress?> loadFromRemote(String username) async {
    if (_progressEndpoint.isEmpty) return null;
    try {
      final uri = Uri.parse(_progressEndpoint);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'load', 'username': username}),
          )
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['found'] != true) return null;
      final p = data['progress'] as Map<String, dynamic>;
      return HeroProgress(
        stars: max(0, (p['stars'] as num?)?.toInt() ?? 0),
        streakDays: max(0, (p['streak_days'] as num?)?.toInt() ?? 0),
        lastActiveDayEpoch: (p['last_active_day_epoch'] as num?)?.toInt(),
        weekId: (p['week_id'] as num?)?.toInt() ?? 0,
        activeDaysThisWeek:
            max(0, (p['active_days_this_week'] as num?)?.toInt() ?? 0),
        streakShieldUsedWeekId:
            (p['streak_shield_used_week_id'] as num?)?.toInt() ?? -1,
        weeklyBonusAwardedWeekId:
            (p['weekly_bonus_awarded_week_id'] as num?)?.toInt() ?? -1,
        stringSectionStars:
            _decodeStringStars(jsonEncode(p['string_section_stars'] ?? {})),
        songSectionStars:
            _decodeSongStars(jsonEncode(p['song_section_stars'] ?? {})),
        noteAdaptiveStates:
            _decodeNoteAdaptiveStates(p['note_adaptive_states']),
      );
    } catch (_) {
      return null;
    }
  }

  static HeroProgress mergeProgress(HeroProgress local, HeroProgress remote) {
    final useRemoteActivity =
        (remote.lastActiveDayEpoch ?? 0) > (local.lastActiveDayEpoch ?? 0);
    final activity = useRemoteActivity ? remote : local;
    final mergedStringStars = Map<int, int>.from(local.stringSectionStars);
    for (final e in remote.stringSectionStars.entries) {
      mergedStringStars[e.key] =
          max(mergedStringStars[e.key] ?? 0, e.value);
    }
    final mergedSongStars = Map<String, int>.from(local.songSectionStars);
    for (final e in remote.songSectionStars.entries) {
      mergedSongStars[e.key] = max(mergedSongStars[e.key] ?? 0, e.value);
    }
    final mergedAdaptive =
        Map<String, NoteAdaptiveState>.from(local.noteAdaptiveStates);
    for (final e in remote.noteAdaptiveStates.entries) {
      final existing = mergedAdaptive[e.key];
      mergedAdaptive[e.key] =
          existing == null ? e.value : existing.mergeWith(e.value);
    }
    return HeroProgress(
      stars: max(local.stars, remote.stars),
      streakDays: activity.streakDays,
      lastActiveDayEpoch: activity.lastActiveDayEpoch,
      weekId: activity.weekId,
      activeDaysThisWeek: activity.activeDaysThisWeek,
      streakShieldUsedWeekId:
          max(local.streakShieldUsedWeekId, remote.streakShieldUsedWeekId),
      weeklyBonusAwardedWeekId:
          max(local.weeklyBonusAwardedWeekId, remote.weeklyBonusAwardedWeekId),
      stringSectionStars: mergedStringStars,
      songSectionStars: mergedSongStars,
      noteAdaptiveStates: mergedAdaptive,
    );
  }

  static Future<void> loadAndMergeRemote(String username) async {
    final remote = await loadFromRemote(username);
    if (remote == null) return;
    await load();
    final local = progressListenable.value;
    final merged = mergeProgress(local, remote);
    progressListenable.value = merged;
    await _persist(merged);
  }

  static Map<int, int> _decodeStringStars(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <int, int>{};
      for (final entry in decoded.entries) {
        final key = int.tryParse('${entry.key}');
        final value = entry.value;
        if (key != null && value is num) {
          result[key] = value.toInt().clamp(0, 5);
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _decodeSongStars(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, int>{};
      for (final entry in decoded.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is num) {
          result[key] = value.toInt().clamp(0, 5);
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await _prefs();
    progressListenable.value = HeroProgress(
      stars: max(0, prefs.getInt(_starsKey) ?? 0),
      streakDays: max(0, prefs.getInt(_streakDaysKey) ?? 0),
      lastActiveDayEpoch: prefs.getInt(_lastActiveDayEpochKey),
      weekId: prefs.getInt(_weekIdKey) ?? 0,
      activeDaysThisWeek: max(0, prefs.getInt(_activeDaysThisWeekKey) ?? 0),
      streakShieldUsedWeekId: prefs.getInt(_shieldUsedWeekIdKey) ?? -1,
      weeklyBonusAwardedWeekId: prefs.getInt(_weeklyBonusWeekIdKey) ?? -1,
      stringSectionStars: _decodeStringStars(prefs.getString(_stringSectionStarsKey)),
      songSectionStars: _decodeSongStars(prefs.getString(_songSectionStarsKey)),
      noteAdaptiveStates:
          _decodeNoteAdaptiveStates(prefs.getString(_noteAdaptiveStatesKey)),
    );
    _loaded = true;
  }

  static Future<void> resetForNewAccount() async {
    _loaded = true;
    _awardedStringThisSession.clear();
    _awardedSongThisSession.clear();
    progressListenable.value = HeroProgress.initial;
    await _persist(HeroProgress.initial);
  }

  static Future<_ProgressAward> awardStars(int delta, {String? username}) async {
    await load();
    var progress = progressListenable.value;
    var totalDelta = delta;
    var usedShield = false;
    var triggeredWeeklyBonus = false;
    var streakDayAdded = false;
    var milestoneReached = 0;
    final now = DateTime.now();
    final todayEpoch = _dayEpoch(now);
    final todayWeekId = _weekIdForDay(now);
    final wasActiveToday = progress.lastActiveDayEpoch == todayEpoch;

    if (!wasActiveToday) {
      var streakDays = progress.streakDays;
      var shieldUsedWeekId = progress.streakShieldUsedWeekId;
      final lastEpoch = progress.lastActiveDayEpoch;
      final lastDay =
          lastEpoch == null ? null : DateTime.fromMillisecondsSinceEpoch(lastEpoch);

      if (lastDay == null) {
        streakDays = 1;
        streakDayAdded = true;
      } else {
        final deltaDays = now.difference(lastDay).inDays;
        if (deltaDays == 1) {
          streakDays++;
          streakDayAdded = true;
        } else if (deltaDays == 2 && shieldUsedWeekId != todayWeekId) {
          streakDays++;
          shieldUsedWeekId = todayWeekId;
          usedShield = true;
          streakDayAdded = true;
        } else if (deltaDays > 1) {
          streakDays = 1;
          streakDayAdded = true;
        }
      }
      if (_streakMilestones.contains(streakDays)) {
        milestoneReached = streakDays;
      }

      var activeDaysThisWeek = progress.weekId == todayWeekId
          ? progress.activeDaysThisWeek
          : 0;
      activeDaysThisWeek = min(7, activeDaysThisWeek + 1);

      if (streakDays >= 2) {
        totalDelta += 5;
      }
      var weeklyBonusWeekId = progress.weeklyBonusAwardedWeekId;
      if (activeDaysThisWeek >= 5 && weeklyBonusWeekId != todayWeekId) {
        totalDelta += 20;
        weeklyBonusWeekId = todayWeekId;
        triggeredWeeklyBonus = true;
      }

      progress = progress.copyWith(
        streakDays: streakDays,
        lastActiveDayEpoch: todayEpoch,
        weekId: todayWeekId,
        activeDaysThisWeek: activeDaysThisWeek,
        streakShieldUsedWeekId: shieldUsedWeekId,
        weeklyBonusAwardedWeekId: weeklyBonusWeekId,
      );
    }

    final nextStars = max(0, progress.stars + totalDelta);
    progress = progress.copyWith(stars: nextStars);
    progressListenable.value = progress;
    await _persist(progress);

    if (username != null && streakDayAdded) {
      unawaited(
        UserEventLogStore.log(
          username: username,
          type: UserEventType.streakDayAdded,
          outcome: true,
          starsDelta: 0,
          metadata: {
            'streakDays': progress.streakDays,
          },
        ),
      );
    }
    if (username != null && triggeredWeeklyBonus) {
      unawaited(
        UserEventLogStore.log(
          username: username,
          type: UserEventType.streakWeeklyBonusAwarded,
          outcome: true,
          starsDelta: 20,
          metadata: {
            'weekId': progress.weekId,
            'activeDaysThisWeek': progress.activeDaysThisWeek,
          },
        ),
      );
    }
    if (username != null && milestoneReached > 0) {
      unawaited(
        UserEventLogStore.log(
          username: username,
          type: UserEventType.streakMilestoneReached,
          outcome: true,
          starsDelta: 0,
          metadata: {
            'milestoneDays': milestoneReached,
            'streakDays': progress.streakDays,
          },
        ),
      );
    }

    return _ProgressAward(
      earnedStars: totalDelta,
      usedStreakShield: usedShield,
      triggeredWeeklyBonus: triggeredWeeklyBonus,
    );
  }

  static Future<bool> awardStringSectionStarForSession(int stringIndex) async {
    await load();
    if (_awardedStringThisSession.contains(stringIndex)) return false;
    final progress = progressListenable.value;
    final map = Map<int, int>.from(progress.stringSectionStars);
    final current = map[stringIndex] ?? 0;
    if (current >= 5) return false;
    map[stringIndex] = (current + 1).clamp(0, 5);
    final updated = progress.copyWith(stringSectionStars: map);
    _awardedStringThisSession.add(stringIndex);
    progressListenable.value = updated;
    await _persist(updated);
    return true;
  }

  static Future<bool> awardSongSectionStarForSession(String songId) async {
    await load();
    if (_awardedSongThisSession.contains(songId)) return false;
    final progress = progressListenable.value;
    final map = Map<String, int>.from(progress.songSectionStars);
    final current = map[songId] ?? 0;
    if (current >= 5) return false;
    map[songId] = (current + 1).clamp(0, 5);
    final updated = progress.copyWith(songSectionStars: map);
    _awardedSongThisSession.add(songId);
    progressListenable.value = updated;
    await _persist(updated);
    return true;
  }

  /// Returns the persisted adaptive state for [noteId], or
  /// [NoteAdaptiveState.fresh] if the note has never been progressed.
  /// Synchronous — relies on the listenable already being populated;
  /// call [load] first if you're reading from a fresh app launch.
  static NoteAdaptiveState noteAdaptiveStateFor(String noteId) {
    return progressListenable.value.noteAdaptiveStates[noteId] ??
        NoteAdaptiveState.fresh;
  }

  /// Writes [state] for [noteId] into the persisted progress map and
  /// triggers the standard local-then-debounced-remote sync. Skips
  /// the round-trip when the value is unchanged so that idempotent
  /// re-asserts (e.g. the per-play "still mastered" calls in
  /// [_onFingerPlacement]) don't churn the I/O path.
  static Future<void> saveNoteAdaptiveState(
    String noteId,
    NoteAdaptiveState state,
  ) async {
    await load();
    final progress = progressListenable.value;
    final existing = progress.noteAdaptiveStates[noteId];
    if (existing == state) return;
    final next = Map<String, NoteAdaptiveState>.from(progress.noteAdaptiveStates);
    if (state.isFresh) {
      next.remove(noteId);
    } else {
      next[noteId] = state;
    }
    final updated = progress.copyWith(noteAdaptiveStates: next);
    progressListenable.value = updated;
    await _persist(updated);
  }
}

enum UserEventType {
  appLaunched,
  accountCreated,
  loginAttempt,
  loginSuccess,
  sessionStarted,
  sessionEnded,
  logout,
  avatarChanged,
  learnNoteAttempt,
  streakDayAdded,
  streakWeeklyBonusAwarded,
  streakMilestoneReached,
  learnStringRankStarAwarded,
  songNoteAttempt,
  songCompleted,
  songRankStarAwarded,
}

class UserEventLog {
  const UserEventLog({
    required this.id,
    required this.timestampMs,
    required this.username,
    required this.sessionId,
    required this.type,
    this.outcome,
    this.starsDelta = 0,
    this.noteId,
    this.stringIndex,
    this.songId,
    this.byHeartMode,
    this.hintUsed,
    this.accuracy,
    this.metadata = const {},
  });

  final String id;
  final int timestampMs;
  final String username;
  final String sessionId;
  final UserEventType type;
  final bool? outcome;
  final int starsDelta;
  final String? noteId;
  final int? stringIndex;
  final String? songId;
  final bool? byHeartMode;
  final bool? hintUsed;
  final double? accuracy;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'timestampMs': timestampMs,
      'username': username,
      'sessionId': sessionId,
      'type': type.name,
      'outcome': outcome,
      'starsDelta': starsDelta,
      'noteId': noteId,
      'stringIndex': stringIndex,
      'songId': songId,
      'byHeartMode': byHeartMode,
      'hintUsed': hintUsed,
      'accuracy': accuracy,
      'metadata': metadata,
    };
  }

  static UserEventLog fromJson(Map<String, dynamic> json) {
    final typeRaw = '${json['type'] ?? ''}';
    final type = UserEventType.values.firstWhere(
      (value) => value.name == typeRaw,
      orElse: () => UserEventType.learnNoteAttempt,
    );
    final metadataRaw = json['metadata'];
    return UserEventLog(
      id: '${json['id'] ?? ''}',
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      username: '${json['username'] ?? ''}',
      sessionId: '${json['sessionId'] ?? ''}',
      type: type,
      outcome: json['outcome'] is bool ? json['outcome'] as bool : null,
      starsDelta: (json['starsDelta'] as num?)?.toInt() ?? 0,
      noteId: json['noteId'] == null ? null : '${json['noteId']}',
      stringIndex: (json['stringIndex'] as num?)?.toInt(),
      songId: json['songId'] == null ? null : '${json['songId']}',
      byHeartMode: json['byHeartMode'] is bool ? json['byHeartMode'] as bool : null,
      hintUsed: json['hintUsed'] is bool ? json['hintUsed'] as bool : null,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      metadata: metadataRaw is Map<String, dynamic>
          ? metadataRaw
          : const <String, Object?>{},
    );
  }
}

class UserEventLogFilter {
  const UserEventLogFilter({
    this.username,
    this.types,
    this.from,
    this.to,
    this.outcome,
    this.songId,
    this.stringIndex,
    this.sessionId,
    this.minStarsDelta,
    this.maxStarsDelta,
  });

  final String? username;
  final Set<UserEventType>? types;
  final DateTime? from;
  final DateTime? to;
  final bool? outcome;
  final String? songId;
  final int? stringIndex;
  final String? sessionId;
  final int? minStarsDelta;
  final int? maxStarsDelta;

  bool matches(UserEventLog event) {
    if (username != null && event.username != username) return false;
    if (types != null && !types!.contains(event.type)) return false;
    if (from != null && event.timestampMs < from!.millisecondsSinceEpoch) return false;
    if (to != null && event.timestampMs > to!.millisecondsSinceEpoch) return false;
    if (outcome != null && event.outcome != outcome) return false;
    if (songId != null && event.songId != songId) return false;
    if (stringIndex != null && event.stringIndex != stringIndex) return false;
    if (sessionId != null && event.sessionId != sessionId) return false;
    if (minStarsDelta != null && event.starsDelta < minStarsDelta!) return false;
    if (maxStarsDelta != null && event.starsDelta > maxStarsDelta!) return false;
    return true;
  }
}

class UserEventLogStore {
  static const String _logsKey = 'hero_user_event_logs_v1';
  static const String _activeSessionIdKey = 'hero_active_session_id_v1';
  static const String _lastUploadedEventIdKey = 'hero_last_uploaded_event_id_v1';
  static const int _maxEvents = 5000;
  static const int _uploadBatchSize = 120;
  static const Duration _uploadRetryDelay = Duration(seconds: 3);
  static const Duration _flushDelay = Duration(milliseconds: 800);
  static const String _remoteEndpoint = String.fromEnvironment(
    'VH_LOG_ENDPOINT',
    defaultValue: '',
  );
  static const String _remoteApiKey = String.fromEnvironment(
    'VH_LOG_API_KEY',
    defaultValue: '',
  );
  static List<UserEventLog> _cache = [];
  static bool _cacheLoaded = false;
  static Timer? _flushTimer;
  static Timer? _uploadTimer;
  static bool _uploadInFlight = false;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static String _newId() {
    final randomPart = Random().nextInt(1 << 30).toRadixString(36);
    return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  static String _newSessionId(String username) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final token = Random().nextInt(1 << 28).toRadixString(36);
    return '${username}_${stamp}_$token';
  }

  static Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    final prefs = await _prefs();
    final raw = prefs.getString(_logsKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      _cacheLoaded = true;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cache = [];
        _cacheLoaded = true;
        return;
      }
      _cache = decoded
          .whereType<Map>()
          .map((entry) => entry.map((k, v) => MapEntry('$k', v)))
          .map(UserEventLog.fromJson)
          .toList(growable: true);
      _cacheLoaded = true;
    } catch (_) {
      _cache = [];
      _cacheLoaded = true;
    }
  }

  static Future<List<UserEventLog>> _readAll() async {
    await _ensureCacheLoaded();
    return List<UserEventLog>.from(_cache);
  }

  static Future<void> _flushNow() async {
    await _ensureCacheLoaded();
    final prefs = await _prefs();
    await prefs.setString(
      _logsKey,
      jsonEncode(_cache.map((event) => event.toJson()).toList(growable: false)),
    );
  }

  static void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () {
      unawaited(_flushNow());
    });
  }

  static int _indexOfEventId(String id) {
    for (int i = 0; i < _cache.length; i++) {
      if (_cache[i].id == id) return i;
    }
    return -1;
  }

  static void _scheduleRemoteUpload({Duration delay = const Duration(milliseconds: 250)}) {
    if (_remoteEndpoint.isEmpty) return;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(delay, () {
      unawaited(_uploadPendingEvents());
    });
  }

  static Future<void> _uploadPendingEvents() async {
    if (_remoteEndpoint.isEmpty || _uploadInFlight) return;
    _uploadInFlight = true;
    var shouldRetry = false;
    var shouldContinue = false;
    try {
      await _ensureCacheLoaded();
      final prefs = await _prefs();
      final lastUploadedId = prefs.getString(_lastUploadedEventIdKey);
      final startIndex = lastUploadedId == null ? 0 : (_indexOfEventId(lastUploadedId) + 1);
      if (startIndex < 0 || startIndex >= _cache.length) {
        _uploadInFlight = false;
        return;
      }
      final endIndex = min(startIndex + _uploadBatchSize, _cache.length);
      final batch = _cache.sublist(startIndex, endIndex);
      if (batch.isEmpty) {
        _uploadInFlight = false;
        return;
      }

      final uri = Uri.tryParse(_remoteEndpoint);
      if (uri == null) {
        _uploadInFlight = false;
        return;
      }
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (_remoteApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_remoteApiKey';
        headers['x-api-key'] = _remoteApiKey;
      }
      final payload = jsonEncode({
        'events': batch.map((event) => event.toJson()).toList(growable: false),
      });
      final response = await http
          .post(uri, headers: headers, body: payload)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(_lastUploadedEventIdKey, batch.last.id);
        shouldContinue = endIndex < _cache.length;
      } else {
        shouldRetry = true;
      }
    } catch (_) {
      shouldRetry = true;
    } finally {
      _uploadInFlight = false;
    }
    if (shouldContinue) {
      _scheduleRemoteUpload(delay: const Duration(milliseconds: 40));
    } else if (shouldRetry) {
      _scheduleRemoteUpload(delay: _uploadRetryDelay);
    }
  }

  static Future<String> startSessionForUser(String username) async {
    final prefs = await _prefs();
    final sessionId = _newSessionId(username);
    await prefs.setString(_activeSessionIdKey, sessionId);
    return sessionId;
  }

  static Future<void> endCurrentSession() async {
    final prefs = await _prefs();
    await prefs.remove(_activeSessionIdKey);
    _scheduleRemoteUpload();
  }

  static Future<String> _currentSessionId({required String username}) async {
    final prefs = await _prefs();
    final existing = prefs.getString(_activeSessionIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newSessionId(username);
    await prefs.setString(_activeSessionIdKey, created);
    return created;
  }

  static Future<void> log({
    required String username,
    required UserEventType type,
    bool? outcome,
    int starsDelta = 0,
    String? noteId,
    int? stringIndex,
    String? songId,
    bool? byHeartMode,
    bool? hintUsed,
    double? accuracy,
    Map<String, Object?> metadata = const {},
  }) async {
    await _ensureCacheLoaded();
    final sessionId = await _currentSessionId(username: username);
    _cache.add(
      UserEventLog(
        id: _newId(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        username: username,
        sessionId: sessionId,
        type: type,
        outcome: outcome,
        starsDelta: starsDelta,
        noteId: noteId,
        stringIndex: stringIndex,
        songId: songId,
        byHeartMode: byHeartMode,
        hintUsed: hintUsed,
        accuracy: accuracy,
        metadata: metadata,
      ),
    );
    if (_cache.length > _maxEvents) {
      _cache = _cache.sublist(_cache.length - _maxEvents);
    }
    _scheduleFlush();
    _scheduleRemoteUpload();
  }

  static Future<List<UserEventLog>> query({
    required String username,
    UserEventLogFilter filter = const UserEventLogFilter(),
    int? limit,
  }) async {
    final all = await _readAll();
    final effective = UserEventLogFilter(
      username: username,
      types: filter.types,
      from: filter.from,
      to: filter.to,
      outcome: filter.outcome,
      songId: filter.songId,
      stringIndex: filter.stringIndex,
      sessionId: filter.sessionId,
      minStarsDelta: filter.minStarsDelta,
      maxStarsDelta: filter.maxStarsDelta,
    );
    final filtered = all.where(effective.matches).toList(growable: false)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    if (limit == null || limit >= filtered.length) return filtered;
    return filtered.sublist(filtered.length - limit);
  }

  static Future<List<UserEventLog>> queryAll({
    UserEventLogFilter filter = const UserEventLogFilter(),
    int? limit,
  }) async {
    final all = await _readAll();
    final filtered = all.where(filter.matches).toList(growable: false)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    if (limit == null || limit >= filtered.length) return filtered;
    return filtered.sublist(filtered.length - limit);
  }

  static Future<Set<String>> distinctUsers() async {
    final all = await _readAll();
    return all.map((event) => event.username).toSet();
  }

  static Future<List<String>> sessionsForUser(String username) async {
    final events = await query(username: username);
    final ids = <String>[];
    for (final event in events) {
      if (!ids.contains(event.sessionId)) {
        ids.add(event.sessionId);
      }
    }
    return ids;
  }

  static Future<List<UserEventLog>> querySession({
    required String username,
    required String sessionId,
    UserEventLogFilter filter = const UserEventLogFilter(),
  }) async {
    return query(
      username: username,
      filter: UserEventLogFilter(
        username: username,
        types: filter.types,
        from: filter.from,
        to: filter.to,
        outcome: filter.outcome,
        songId: filter.songId,
        stringIndex: filter.stringIndex,
        sessionId: sessionId,
        minStarsDelta: filter.minStarsDelta,
        maxStarsDelta: filter.maxStarsDelta,
      ),
    );
  }

  static Future<String> exportJson({
    required String username,
    UserEventLogFilter filter = const UserEventLogFilter(),
    bool pretty = true,
  }) async {
    final events = await query(username: username, filter: filter);
    final list = events.map((event) => event.toJson()).toList(growable: false);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(list)
        : jsonEncode(list);
  }

  static Future<String> exportCsv({
    required String username,
    UserEventLogFilter filter = const UserEventLogFilter(),
  }) async {
    final events = await query(username: username, filter: filter);
    String esc(Object? value) {
      final raw = value?.toString() ?? '';
      final safe = raw.replaceAll('"', '""');
      return '"$safe"';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'timestampMs,username,sessionId,type,outcome,starsDelta,noteId,stringIndex,songId,byHeartMode,hintUsed,accuracy,metadataJson',
    );
    for (final event in events) {
      buffer.writeln([
        event.timestampMs,
        esc(event.username),
        esc(event.sessionId),
        esc(event.type.name),
        esc(event.outcome),
        event.starsDelta,
        esc(event.noteId),
        event.stringIndex ?? '',
        esc(event.songId),
        esc(event.byHeartMode),
        esc(event.hintUsed),
        event.accuracy?.toStringAsFixed(4) ?? '',
        esc(jsonEncode(event.metadata)),
      ].join(','));
    }
    return buffer.toString();
  }

  static Future<String> exportToLocalFile({
    required String username,
    UserEventLogFilter filter = const UserEventLogFilter(),
    String format = 'json',
  }) async {
    await _flushNow();
    final normalized = format.toLowerCase() == 'csv' ? 'csv' : 'json';
    return normalized == 'csv'
        ? await exportCsv(username: username, filter: filter)
        : await exportJson(username: username, filter: filter);
  }

  static Future<String> exportAllToLocalFile({
    UserEventLogFilter filter = const UserEventLogFilter(),
    String format = 'json',
  }) async {
    await _flushNow();
    final normalized = format.toLowerCase() == 'csv' ? 'csv' : 'json';
    final events = await queryAll(filter: filter);
    return switch (normalized) {
      'csv' => _toCsv(events),
      _ => const JsonEncoder.withIndent('  ').convert(
          events.map((event) => event.toJson()).toList(growable: false),
        ),
    };
  }

  static Future<Map<String, String>> exportAllLiveNow() async {
    await _flushNow();
    final events = await queryAll();
    return {
      'json': const JsonEncoder.withIndent('  ').convert(
        events.map((event) => event.toJson()).toList(growable: false),
      ),
      'csv': _toCsv(events),
    };
  }

  static String _toCsv(List<UserEventLog> events) {
    String esc(Object? value) {
      final raw = value?.toString() ?? '';
      final safe = raw.replaceAll('"', '""');
      return '"$safe"';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'timestampMs,username,sessionId,type,outcome,starsDelta,noteId,stringIndex,songId,byHeartMode,hintUsed,accuracy,metadataJson',
    );
    for (final event in events) {
      buffer.writeln([
        event.timestampMs,
        esc(event.username),
        esc(event.sessionId),
        esc(event.type.name),
        esc(event.outcome),
        event.starsDelta,
        esc(event.noteId),
        event.stringIndex ?? '',
        esc(event.songId),
        esc(event.byHeartMode),
        esc(event.hintUsed),
        event.accuracy?.toStringAsFixed(4) ?? '',
        esc(jsonEncode(event.metadata)),
      ].join(','));
    }
    return buffer.toString();
  }
}

