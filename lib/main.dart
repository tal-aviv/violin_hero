import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ViolinHeroApp());
}

enum FeedbackState { idle, correct, wrong }

enum StageMode { learnSingleString, mixedStrings }

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

class SongDefinition {
  const SongDefinition({
    required this.id,
    required this.title,
    required this.noteIds,
    this.noteBeats,
    this.eighthNoteIndices,
  });

  final String id;
  final String title;
  final List<String> noteIds;
  final List<int>? noteBeats;
  final Set<int>? eighthNoteIndices;
}

class UserSession {
  const UserSession({
    required this.username,
    required this.avatarId,
  });

  final String username;
  final String avatarId;
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
  static const List<int> _streakMilestones = [2, 3, 5, 7, 14, 21, 30];

  static final ValueNotifier<HeroProgress> progressListenable =
      ValueNotifier<HeroProgress>(HeroProgress.initial);
  static bool _loaded = false;
  static final Set<int> _awardedStringThisSession = <int>{};
  static final Set<String> _awardedSongThisSession = <String>{};

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
    noteBeats: [
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
    ],
  ),
  SongDefinition(
    id: 'twinkle_harmony_vln2',
    title: 'Twinkle Harmony',
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
    noteBeats: [
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
      1, 1, 1, 1, 1, 1, 2,
    ],
  ),
  SongDefinition(
    id: 'frere_jacques',
    title: 'Frère Jacques',
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
    noteBeats: [
      1, 1, 1, 1,
      1, 1, 1, 1,
      1, 1, 2,
      1, 1, 2,
      1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1,
      1, 1, 2,
      1, 1, 2,
    ],
    // The two "sonnez les matines" groups begin with four eighth notes each.
    eighthNoteIndices: {14, 15, 16, 17, 20, 21, 22, 23},
  ),
  SongDefinition(
    id: 'lightly_row',
    title: 'Lightly Row',
    noteIds: [
      // Part A
      // "Lightly row, lightly row, o'er the glassy waves we go"
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
    noteBeats: [
      // Part A
      1, 1, 2,
      1, 1, 2,
      1, 1, 1, 1,
      1, 1, 2,
      1, 1, 2,
      1, 1, 2,
      1, 1, 1, 1,
      4,
      // Part B
      1, 1, 1, 1,
      1, 1, 2,
      1, 1, 1, 1,
      1, 1, 2,
      1, 1, 2,
      1, 1, 2,
      1, 1, 1, 1,
      4,
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
  });

  final String id;
  final String letterLabel;
  final String solfegeLabel;
  final int staffStep;
  final int fingerNumber;
  final int stringIndex;
  final double frequencyHz;
  final Color hintColor;

}

class _AuthResult {
  const _AuthResult({this.ok = false, this.error, this.session});
  final bool ok;
  final String? error;
  final UserSession? session;
}

class _LocalAuthStore {
  static const String _usernameKey = 'auth_username';
  static const String _passwordKey = 'auth_password';
  static const String _avatarKey = 'auth_avatar_id';
  static const String _loggedInKey = 'auth_logged_in';
  static const String _authEndpoint = String.fromEnvironment(
    'VH_AUTH_ENDPOINT',
    defaultValue: '',
  );

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static bool get _hasRemote => _authEndpoint.isNotEmpty;

  static Future<Map<String, dynamic>?> _remotePost(
    Map<String, dynamic> body,
  ) async {
    if (!_hasRemote) return null;
    try {
      final uri = Uri.parse(_authEndpoint);
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasAccount() async {
    final prefs = await _prefs();
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);
    return username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _prefs();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<void> logout() async {
    final prefs = await _prefs();
    await prefs.setBool(_loggedInKey, false);
  }

  /// Returns true if available, false if taken, null if network unavailable.
  static Future<bool?> checkUsernameAvailable(String username) async {
    final result = await _remotePost({
      'action': 'check_username',
      'username': username.trim().toLowerCase(),
    });
    if (result == null) return null;
    return result['available'] == true;
  }

  static Future<_AuthResult> createAccount({
    required String username,
    required String password,
    required String avatarId,
  }) async {
    final normalized = username.trim().toLowerCase();

    final result = await _remotePost({
      'action': 'signup',
      'username': normalized,
      'password': password,
      'avatar_id': avatarId,
    });

    if (result != null) {
      if (result['ok'] == true) {
        final prefs = await _prefs();
        await prefs.setString(_usernameKey, normalized);
        await prefs.setString(_passwordKey, password);
        await prefs.setString(_avatarKey, avatarId);
        await prefs.setBool(_loggedInKey, true);
        return _AuthResult(
          ok: true,
          session: UserSession(username: normalized, avatarId: avatarId),
        );
      }
      return _AuthResult(
        error: result['error'] as String? ?? 'Signup failed',
      );
    }

    final prefs = await _prefs();
    await prefs.setString(_usernameKey, normalized);
    await prefs.setString(_passwordKey, password);
    await prefs.setString(_avatarKey, avatarId);
    await prefs.setBool(_loggedInKey, true);
    return _AuthResult(
      ok: true,
      session: UserSession(username: normalized, avatarId: avatarId),
    );
  }

  static Future<_AuthResult> login({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();

    final result = await _remotePost({
      'action': 'login',
      'username': normalized,
      'password': password,
    });

    if (result != null) {
      if (result['ok'] == true) {
        final avatarId =
            result['avatar_id'] as String? ?? kAvatarOptions.first.id;
        final prefs = await _prefs();
        await prefs.setString(_usernameKey, normalized);
        await prefs.setString(_passwordKey, password);
        await prefs.setString(_avatarKey, avatarId);
        await prefs.setBool(_loggedInKey, true);
        return _AuthResult(
          ok: true,
          session: UserSession(username: normalized, avatarId: avatarId),
        );
      }
      return _AuthResult(
        error: result['error'] as String? ?? 'Login failed',
      );
    }

    final prefs = await _prefs();
    final savedUsername = prefs.getString(_usernameKey);
    final savedPassword = prefs.getString(_passwordKey);
    if (savedUsername == normalized && savedPassword == password) {
      await prefs.setBool(_loggedInKey, true);
      final avatarId = prefs.getString(_avatarKey) ?? kAvatarOptions.first.id;
      return _AuthResult(
        ok: true,
        session: UserSession(username: normalized, avatarId: avatarId),
      );
    }
    return const _AuthResult(error: 'Invalid username or password');
  }

  static Future<UserSession?> currentProfile() async {
    final prefs = await _prefs();
    final username = prefs.getString(_usernameKey);
    if (username == null || username.isEmpty) return null;
    final avatarId = prefs.getString(_avatarKey) ?? kAvatarOptions.first.id;
    return UserSession(username: username, avatarId: avatarId);
  }

  static Future<UserSession?> updateAvatar(String avatarId) async {
    final prefs = await _prefs();
    await prefs.setString(_avatarKey, avatarId);
    return currentProfile();
  }
}

class ViolinHeroApp extends StatefulWidget {
  const ViolinHeroApp({super.key});

  @override
  State<ViolinHeroApp> createState() => _ViolinHeroAppState();
}

class _ViolinHeroAppState extends State<ViolinHeroApp> {
  bool? _isLoggedIn;
  UserSession? _session;

  @override
  void initState() {
    super.initState();
    _loadLoginState();
  }

  Future<void> _loadLoginState() async {
    final loggedIn = await _LocalAuthStore.isLoggedIn();
    await _HeroProgressStore.load();
    final session = loggedIn ? await _LocalAuthStore.currentProfile() : null;
    if (!mounted || !context.mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _session = session;
    });
  }

  Future<void> _handleLoginSuccess() async {
    await _HeroProgressStore.load();
    final session = await _LocalAuthStore.currentProfile();
    if (session != null) {
      final sessionId = await UserEventLogStore.startSessionForUser(session.username);
      await UserEventLogStore.log(
        username: session.username,
        type: UserEventType.sessionStarted,
        outcome: true,
        metadata: {'sessionId': sessionId, 'source': 'login'},
      );
      await UserEventLogStore.log(
        username: session.username,
        type: UserEventType.loginSuccess,
        outcome: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    final username = _session?.username;
    if (username != null) {
      await UserEventLogStore.log(
        username: username,
        type: UserEventType.sessionEnded,
        outcome: true,
        metadata: {'source': 'logout'},
      );
      await UserEventLogStore.log(
        username: username,
        type: UserEventType.logout,
        outcome: true,
      );
      await UserEventLogStore.endCurrentSession();
    }
    await _LocalAuthStore.logout();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _session = null;
    });
  }

  void _handleProfileUpdated(UserSession session) {
    setState(() {
      _session = session;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FF),
      ),
      home: switch (_isLoggedIn) {
        null => const Scaffold(body: Center(child: CircularProgressIndicator())),
        true => ModuleSelectionScreen(
            onLogout: _handleLogout,
            session: _session ?? const UserSession(username: 'Player', avatarId: 'avatar_frog'),
            onProfileUpdated: _handleProfileUpdated,
          ),
        false => LoginScreen(onLoginSuccess: _handleLoginSuccess),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final Future<void> Function() onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Enter username and password.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    final result =
        await _LocalAuthStore.login(username: username, password: password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.ok) {
      await UserEventLogStore.log(
        username: username,
        type: UserEventType.loginAttempt,
        outcome: true,
      );
      await widget.onLoginSuccess();
    } else {
      await UserEventLogStore.log(
        username: username,
        type: UserEventType.loginAttempt,
        outcome: false,
      );
      setState(() {
        _errorText = result.error ?? 'Invalid username or password.';
      });
    }
  }

  Future<void> _openSignup() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Violin Hero')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E7BFF).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF6E7BFF)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Login',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter your username and password',
                    style: TextStyle(color: Color(0xFF5C6485), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _submitLogin,
                    child: Text(_loading ? 'Logging in...' : 'Login'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _openSignup,
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String _selectedAvatarId = kAvatarOptions.first.id;
  String? _errorText;
  bool _creating = false;
  String? _usernameStatus;
  Timer? _usernameCheckTimer;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameCheckTimer?.cancel();
    final text = _usernameController.text.trim();
    if (text.length < 2) {
      setState(() => _usernameStatus = null);
      return;
    }
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
      final available = await _LocalAuthStore.checkUsernameAvailable(text);
      if (!mounted) return;
      if (_usernameController.text.trim().toLowerCase() !=
          text.toLowerCase()) {
        return;
      }
      setState(() {
        if (available == null) {
          _usernameStatus = null;
        } else if (available) {
          _usernameStatus = 'available';
        } else {
          _usernameStatus = 'taken';
        }
      });
    });
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter username and password.');
      return;
    }
    if (username.length < 2) {
      setState(() => _errorText = 'Username must be at least 2 characters.');
      return;
    }
    if (password.length < 3) {
      setState(() => _errorText = 'Password must be at least 3 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }
    setState(() {
      _creating = true;
      _errorText = null;
    });
    final result = await _LocalAuthStore.createAccount(
      username: username,
      password: password,
      avatarId: _selectedAvatarId,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _creating = false;
        _errorText = result.error ?? 'Signup failed.';
      });
      return;
    }
    await _HeroProgressStore.resetForNewAccount();
    final sessionId = await UserEventLogStore.startSessionForUser(username);
    await UserEventLogStore.log(
      username: username,
      type: UserEventType.sessionStarted,
      outcome: true,
      metadata: {'sessionId': sessionId, 'source': 'signup'},
    );
    await UserEventLogStore.log(
      username: username,
      type: UserEventType.accountCreated,
      outcome: true,
      metadata: {'avatarId': _selectedAvatarId},
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FB38E).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4FB38E)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Create account',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose avatar',
                    style: TextStyle(color: Color(0xFF5C6485), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: 360,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 1,
                        ),
                        itemCount: kAvatarOptions.length,
                        itemBuilder: (context, index) {
                          final option = kAvatarOptions[index];
                          return Center(
                            child: InkResponse(
                              radius: 64,
                              onTap: () {
                                setState(() {
                                  _selectedAvatarId = option.id;
                                });
                              },
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                scale: _selectedAvatarId == option.id ? 1.08 : 1,
                                child: AnimatedInstrumentAvatar(
                                  option: option,
                                  size: 96,
                                  animate: _selectedAvatarId == option.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: const OutlineInputBorder(),
                      suffixIcon: _usernameStatus == 'available'
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF4FB38E), size: 22)
                          : _usernameStatus == 'taken'
                              ? const Icon(Icons.cancel,
                                  color: Colors.redAccent, size: 22)
                              : null,
                      helperText: _usernameStatus == 'taken'
                          ? 'Username already taken'
                          : null,
                      helperStyle: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    onSubmitted: (_) => _createAccount(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _creating ? null : _createAccount,
                    child:
                        Text(_creating ? 'Creating...' : 'Create'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModuleSelectionScreen extends StatelessWidget {
  const ModuleSelectionScreen({
    super.key,
    required this.onLogout,
    required this.session,
    required this.onProfileUpdated,
  });

  final Future<void> Function() onLogout;
  final UserSession session;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        actions: [
          ProfileCornerAction(
            session: session,
            onLogout: onLogout,
            onProfileUpdated: onProfileUpdated,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModuleCard(
              title: 'Learn Notes',
              icon: Icons.music_note_rounded,
              color: const Color(0xFF6E7BFF),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LearnNotesStringSelectionScreen(
                      session: session,
                      onLogout: onLogout,
                      onProfileUpdated: onProfileUpdated,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ModuleCard(
              title: 'Learn Songs',
              icon: Icons.piano_rounded,
              color: const Color(0xFF4FB38E),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SongSelectionScreen(
                      session: session,
                      onLogout: onLogout,
                      onProfileUpdated: onProfileUpdated,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
    this.footer,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 6),
                      footer!,
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

int _displayStarsFromSectionTotal(int totalSectionStars) {
  return totalSectionStars.clamp(0, 5);
}

class _ProgressStarsRow extends StatelessWidget {
  const _ProgressStarsRow({
    required this.filledCount,
    required this.color,
  });

  final int filledCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1.5),
            child: Icon(
              i < filledCount
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 16,
              color: i < filledCount
                  ? color
                  : const Color(0xFFAEB7D7),
            ),
          ),
      ],
    );
  }
}

class _ProgressStarsColumn extends StatelessWidget {
  const _ProgressStarsColumn({
    required this.filledCount,
    required this.color,
    this.size = 10,
  });

  final int filledCount;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 1.5),
            child: Icon(
              i < filledCount
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: size,
              color: i < filledCount ? color : const Color(0xFFAEB7D7),
            ),
          ),
      ],
    );
  }
}

class AnimatedInstrumentAvatar extends StatefulWidget {
  const AnimatedInstrumentAvatar({
    super.key,
    required this.option,
    this.size = 28,
    this.animate = true,
  });

  final AvatarOption option;
  final double size;
  final bool animate;

  @override
  State<AnimatedInstrumentAvatar> createState() => _AnimatedInstrumentAvatarState();
}

class _AnimatedInstrumentAvatarState extends State<AnimatedInstrumentAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;
        final bob = widget.animate ? sin(t) * widget.size * 0.05 : 0.0;
        final tilt = widget.animate ? sin(t) * 0.06 : 0.0;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _AnimalAvatarPainter(option: widget.option),
        ),
      ),
    );
  }
}

class _AnimalAvatarPainter extends CustomPainter {
  _AnimalAvatarPainter({required this.option});

  final AvatarOption option;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(tile, Paint()..color = option.backgroundColor);

    final center = Offset(size.width / 2, size.height / 2);
    final headRadius = size.width * 0.24;
    final headPaint = Paint()..color = option.primaryColor;
    final detailPaint = Paint()..color = option.detailColor.withValues(alpha: 0.9);

    void drawEyesAndMouth({
      required Color eyeColor,
      required Color mouthColor,
      double yOffset = 0,
    }) {
      final eyePaint = Paint()..color = eyeColor;
      final eyeY = center.dy - headRadius * 0.12 + yOffset;
      final eyeDx = headRadius * 0.38;
      canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), headRadius * 0.12, eyePaint);
      canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), headRadius * 0.12, eyePaint);
      final mouth = Path()
        ..moveTo(center.dx - headRadius * 0.28, center.dy + headRadius * 0.25 + yOffset)
        ..quadraticBezierTo(
          center.dx,
          center.dy + headRadius * 0.40 + yOffset,
          center.dx + headRadius * 0.28,
          center.dy + headRadius * 0.25 + yOffset,
        );
      canvas.drawPath(
        mouth,
        Paint()
          ..color = mouthColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, size.width * 0.035)
          ..strokeCap = StrokeCap.round,
      );
    }

    switch (option.animal) {
      case AnimalAvatar.frog:
        canvas.drawCircle(
          center.translate(-headRadius * 0.55, -headRadius * 0.85),
          headRadius * 0.30,
          headPaint,
        );
        canvas.drawCircle(
          center.translate(headRadius * 0.55, -headRadius * 0.85),
          headRadius * 0.30,
          headPaint,
        );
        canvas.drawCircle(center, headRadius, headPaint);
        canvas.drawCircle(
          center.translate(-headRadius * 0.55, -headRadius * 0.85),
          headRadius * 0.14,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          center.translate(headRadius * 0.55, -headRadius * 0.85),
          headRadius * 0.14,
          Paint()..color = Colors.white,
        );
        final frogSmile = Path()
          ..moveTo(center.dx - headRadius * 0.30, center.dy + headRadius * 0.18)
          ..quadraticBezierTo(
            center.dx,
            center.dy + headRadius * 0.40,
            center.dx + headRadius * 0.30,
            center.dy + headRadius * 0.18,
          );
        canvas.drawPath(
          frogSmile,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, size.width * 0.035)
            ..strokeCap = StrokeCap.round,
        );
      case AnimalAvatar.dog:
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(-headRadius * 0.9, -headRadius * 0.05),
            width: headRadius * 0.7,
            height: headRadius * 1.1,
          ),
          headPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(headRadius * 0.9, -headRadius * 0.05),
            width: headRadius * 0.7,
            height: headRadius * 1.1,
          ),
          headPaint,
        );
        canvas.drawCircle(center, headRadius, headPaint);
        drawEyesAndMouth(eyeColor: Colors.white, mouthColor: Colors.white);
      case AnimalAvatar.bear:
        canvas.drawCircle(
          center.translate(-headRadius * 0.65, -headRadius * 0.75),
          headRadius * 0.38,
          headPaint,
        );
        canvas.drawCircle(
          center.translate(headRadius * 0.65, -headRadius * 0.75),
          headRadius * 0.38,
          headPaint,
        );
        canvas.drawCircle(center, headRadius, headPaint);
        drawEyesAndMouth(eyeColor: Colors.white, mouthColor: Colors.white);
      case AnimalAvatar.rabbit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center.translate(-headRadius * 0.35, -headRadius * 1.2),
              width: headRadius * 0.42,
              height: headRadius * 1.15,
            ),
            Radius.circular(headRadius * 0.20),
          ),
          headPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center.translate(headRadius * 0.35, -headRadius * 1.2),
              width: headRadius * 0.42,
              height: headRadius * 1.15,
            ),
            Radius.circular(headRadius * 0.20),
          ),
          headPaint,
        );
        canvas.drawCircle(center, headRadius, headPaint);
        drawEyesAndMouth(eyeColor: Colors.white, mouthColor: Colors.white);
      case AnimalAvatar.goldfish:
        final fishBody = Rect.fromCenter(
          center: center.translate(-headRadius * 0.12, 0),
          width: headRadius * 1.95,
          height: headRadius * 1.25,
        );
        canvas.drawOval(fishBody, headPaint);
        final tail = Path()
          ..moveTo(center.dx + headRadius * 0.72, center.dy)
          ..lineTo(center.dx + headRadius * 1.35, center.dy - headRadius * 0.52)
          ..lineTo(center.dx + headRadius * 1.35, center.dy + headRadius * 0.52)
          ..close();
        canvas.drawPath(tail, headPaint);
        canvas.drawCircle(
          center.translate(-headRadius * 0.58, -headRadius * 0.12),
          headRadius * 0.12,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          center.translate(-headRadius * 0.58, -headRadius * 0.12),
          headRadius * 0.055,
          headPaint,
        );
      case AnimalAvatar.panda:
        canvas.drawCircle(center, headRadius, Paint()..color = Colors.white);
        canvas.drawCircle(
          center.translate(-headRadius * 0.65, -headRadius * 0.75),
          headRadius * 0.34,
          headPaint,
        );
        canvas.drawCircle(
          center.translate(headRadius * 0.65, -headRadius * 0.75),
          headRadius * 0.34,
          headPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(-headRadius * 0.38, -headRadius * 0.08),
            width: headRadius * 0.55,
            height: headRadius * 0.40,
          ),
          headPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(headRadius * 0.38, -headRadius * 0.08),
            width: headRadius * 0.55,
            height: headRadius * 0.40,
          ),
          headPaint,
        );
        canvas.drawCircle(
          center.translate(0, headRadius * 0.20),
          headRadius * 0.20,
          detailPaint,
        );
        drawEyesAndMouth(eyeColor: Colors.white, mouthColor: option.primaryColor);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimalAvatarPainter oldDelegate) {
    return oldDelegate.option.id != option.id;
  }
}

class ProfileCornerAction extends StatefulWidget {
  const ProfileCornerAction({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final UserSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  State<ProfileCornerAction> createState() => _ProfileCornerActionState();
}

class _ProfileCornerActionState extends State<ProfileCornerAction> {
  late UserSession _session;
  late HeroProgress _progress;
  late final VoidCallback _progressListener;
  bool _readyForStreakCelebrations = false;
  double _starsScale = 1;
  double _streakScale = 1;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _progress = _HeroProgressStore.progressListenable.value;
    _progressListener = () {
      if (!mounted) return;
      final latest = _HeroProgressStore.progressListenable.value;
      final previous = _progress;
      setState(() {
        _progress = latest;
      });
      if (!_readyForStreakCelebrations) return;
      if (latest.stars > previous.stars) {
        _pulseStars();
      }
      if (latest.streakDays > previous.streakDays) {
        _pulseStreak();
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1400),
            content: Text(
              '⚡ Streak +1! ${latest.streakDays} day${latest.streakDays == 1 ? '' : 's'} in a row.',
            ),
          ),
        );
      }
    };
    _HeroProgressStore.progressListenable.addListener(_progressListener);
    unawaited(
      _HeroProgressStore.load().then((_) {
        if (!mounted) return;
        setState(() {
          _progress = _HeroProgressStore.progressListenable.value;
          _readyForStreakCelebrations = true;
        });
      }),
    );
  }

  @override
  void didUpdateWidget(covariant ProfileCornerAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.username != widget.session.username ||
        oldWidget.session.avatarId != widget.session.avatarId) {
      _session = widget.session;
    }
  }

  @override
  void dispose() {
    _HeroProgressStore.progressListenable.removeListener(_progressListener);
    super.dispose();
  }

  void _pulseStars() {
    setState(() {
      _starsScale = 1.16;
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        if (!mounted) return;
        setState(() {
          _starsScale = 1;
        });
      }),
    );
  }

  void _pulseStreak() {
    setState(() {
      _streakScale = 1.16;
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        if (!mounted) return;
        setState(() {
          _streakScale = 1;
        });
      }),
    );
  }

  Future<void> _showMenu() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.face_retouching_natural_rounded),
                title: const Text('Change profile icon'),
                onTap: () => Navigator.of(context).pop('change_icon'),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () => Navigator.of(context).pop('logout'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;

    if (option == 'logout') {
      await widget.onLogout();
      return;
    }
    if (option == 'change_icon') {
      final selectedId = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Choose profile icon',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (final avatar in kAvatarOptions)
                        InkResponse(
                          radius: 64,
                          onTap: () => Navigator.of(context).pop(avatar.id),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            scale: avatar.id == _session.avatarId ? 1.08 : 1,
                            child: AnimatedInstrumentAvatar(
                              option: avatar,
                              size: 96,
                              animate: avatar.id == _session.avatarId,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (selectedId != null) {
        final updated = await _LocalAuthStore.updateAvatar(selectedId);
        if (updated != null) {
          await UserEventLogStore.log(
            username: updated.username,
            type: UserEventType.avatarChanged,
            outcome: true,
            metadata: {'avatarId': selectedId},
          );
          if (mounted) {
            setState(() {
              _session = updated;
            });
          }
          widget.onProfileUpdated(updated);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarOptionById(_session.avatarId);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _showMenu,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedInstrumentAvatar(option: avatar, size: 68),
            SizedBox(
              width: 136,
              child: Text(
                _session.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF545C7A),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 136,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _starsScale,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4C4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFF59F00),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_progress.stars}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A5A00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedScale(
                    scale: _streakScale,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFF4F6BFF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_progress.streakDays}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E45B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearnNotesStringSelectionScreen extends StatefulWidget {
  const LearnNotesStringSelectionScreen({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final UserSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  State<LearnNotesStringSelectionScreen> createState() =>
      _LearnNotesStringSelectionScreenState();
}

class _LearnNotesStringSelectionScreenState
    extends State<LearnNotesStringSelectionScreen> {
  final Set<int> _selectedStringIndices = <int>{};

  static const List<({int index, String label, Color color})> _strings = [
    (index: 0, label: 'Sol', color: Color(0xFF66BB6A)),
    (index: 1, label: 'Re', color: Color(0xFF58A6FF)),
    (index: 2, label: 'La', color: Color(0xFFFFA726)),
    (index: 3, label: 'Mi', color: Color(0xFFEC407A)),
  ];

  void _toggleString(int index) {
    setState(() {
      if (_selectedStringIndices.contains(index)) {
        _selectedStringIndices.remove(index);
      } else {
        _selectedStringIndices.add(index);
      }
    });
  }

  void _startPractice() {
    if (_selectedStringIndices.isEmpty) return;
    final selected = _selectedStringIndices.toList()..sort();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViolinGameScreen(
          activeStringIndices: selected,
          session: widget.session,
          onLogout: widget.onLogout,
          onProfileUpdated: widget.onProfileUpdated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        actions: [
          ProfileCornerAction(
            session: widget.session,
            onLogout: widget.onLogout,
            onProfileUpdated: widget.onProfileUpdated,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<HeroProgress>(
          valueListenable: _HeroProgressStore.progressListenable,
          builder: (context, progress, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose Strings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _StringSelectionNeckPreview(
                  selectedStringIndices: _selectedStringIndices,
                  strings: _strings,
                  stringSectionStars: progress.stringSectionStars,
                  onToggleString: _toggleString,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF19A857),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                    ),
                    onPressed: _selectedStringIndices.isEmpty ? null : _startPractice,
                    child: const Icon(Icons.play_arrow_rounded),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StringSelectionNeckPreview extends StatelessWidget {
  const _StringSelectionNeckPreview({
    required this.selectedStringIndices,
    required this.strings,
    required this.stringSectionStars,
    required this.onToggleString,
  });

  final Set<int> selectedStringIndices;
  final List<({int index, String label, Color color})> strings;
  final Map<int, int> stringSectionStars;
  final ValueChanged<int> onToggleString;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 410,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final stringsXs = _ViolinFingerGeometry.stringXs(size);
          final openY = min(
            _ViolinFingerGeometry.yForFingerOnScreen(fingerNumber: 0, size: size),
            size.height - 156,
          );
          final labelY = min(size.height - 96, openY + 34);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StringSelectionNeckPainter(
                    selectedStringIndices: selectedStringIndices,
                  ),
                ),
              ),
              for (int i = 0; i < strings.length; i++)
                Positioned(
                  left: stringsXs[i] - 31,
                  top: labelY,
                  width: 62,
                  height: 108,
                  child: Column(
                    children: [
                      Material(
                        color: selectedStringIndices.contains(strings[i].index)
                            ? strings[i].color.withValues(alpha: 0.22)
                            : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onToggleString(strings[i].index),
                          child: Container(
                            width: 50,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedStringIndices.contains(strings[i].index)
                                    ? strings[i].color
                                    : const Color(0x669FA7C6),
                                width: 1.4,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                strings[i].label,
                                style: TextStyle(
                                  color: selectedStringIndices.contains(strings[i].index)
                                      ? strings[i].color
                                      : const Color(0xFF9FA7C6),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ProgressStarsColumn(
                        filledCount: _displayStarsFromSectionTotal(
                          stringSectionStars[strings[i].index] ?? 0,
                        ),
                        color: strings[i].color,
                        size: 9.5,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StringSelectionNeckPainter extends CustomPainter {
  _StringSelectionNeckPainter({required this.selectedStringIndices});

  final Set<int> selectedStringIndices;
  static const List<double> _stringStrokeByIndex = [3.6, 2.7, 2.1, 1.4];
  static const List<Color> _stringColors = [
    Color(0xFF66BB6A), // Sol
    Color(0xFF58A6FF), // Re
    Color(0xFFFFA726), // La
    Color(0xFFEC407A), // Mi
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 8, size.width - 20, size.height - 16),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFF121417));

    final strings = _ViolinFingerGeometry.stringXs(size);
    final top = bodyRect.outerRect.top + 1;
    final openY = min(
      _ViolinFingerGeometry.yForFingerOnScreen(fingerNumber: 0, size: size),
      size.height - 156,
    );
    final bottom = openY;

    for (int i = 0; i < strings.length; i++) {
      final selected = selectedStringIndices.contains(i);
      final color = selected ? _stringColors[i] : const Color(0x66F4F6FF);
      canvas.drawLine(
        Offset(strings[i], top),
        Offset(strings[i], bottom),
        Paint()
          ..color = color
          ..strokeWidth = _stringStrokeByIndex[i],
      );
    }

    for (int i = 0; i < strings.length; i++) {
      final selected = selectedStringIndices.contains(i);
      final spot = Offset(strings[i], openY);
      canvas.drawCircle(
        spot,
        selected ? 9 : 7,
        Paint()..color = selected ? _stringColors[i].withValues(alpha: 0.35) : const Color(0x45FFFFFF),
      );
      canvas.drawCircle(
        spot,
        selected ? 9 : 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.4 : 1.6
          ..color = selected ? _stringColors[i] : const Color(0xFF9FA7C6),
      );
    }

  }

  @override
  bool shouldRepaint(covariant _StringSelectionNeckPainter oldDelegate) {
    return oldDelegate.selectedStringIndices.length != selectedStringIndices.length ||
        !oldDelegate.selectedStringIndices.containsAll(selectedStringIndices);
  }
}

class SongSelectionScreen extends StatelessWidget {
  const SongSelectionScreen({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final UserSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    final primarySong = kSongLibrary.first;
    final harmonySong = kSongLibrary[1];
    final frereSong = kSongLibrary[2];
    final lightlyRowSong = kSongLibrary[3];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        actions: [
          ProfileCornerAction(
            session: session,
            onLogout: onLogout,
            onProfileUpdated: onProfileUpdated,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<HeroProgress>(
          valueListenable: _HeroProgressStore.progressListenable,
          builder: (context, progress, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModuleCard(
                  title: primarySong.title,
                  icon: Icons.star_rounded,
                  color: const Color(0xFF4FB38E),
                  footer: _ProgressStarsRow(
                    filledCount: _displayStarsFromSectionTotal(
                      progress.songSectionStars[primarySong.id] ?? 0,
                    ),
                    color: const Color(0xFF4FB38E),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongLearningScreen(
                          song: primarySong,
                          session: session,
                          onLogout: onLogout,
                          onProfileUpdated: onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ModuleCard(
                  title: harmonySong.title,
                  icon: Icons.stars_rounded,
                  color: const Color(0xFF5D8BFF),
                  footer: _ProgressStarsRow(
                    filledCount: _displayStarsFromSectionTotal(
                      progress.songSectionStars[harmonySong.id] ?? 0,
                    ),
                    color: const Color(0xFF5D8BFF),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongLearningScreen(
                          song: harmonySong,
                          session: session,
                          onLogout: onLogout,
                          onProfileUpdated: onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ModuleCard(
                  title: frereSong.title,
                  icon: Icons.notifications_rounded,
                  color: const Color(0xFFFFB300),
                  footer: _ProgressStarsRow(
                    filledCount: _displayStarsFromSectionTotal(
                      progress.songSectionStars[frereSong.id] ?? 0,
                    ),
                    color: const Color(0xFFFFB300),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongLearningScreen(
                          song: frereSong,
                          session: session,
                          onLogout: onLogout,
                          onProfileUpdated: onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ModuleCard(
                  title: lightlyRowSong.title,
                  icon: Icons.water_rounded,
                  color: const Color(0xFFE091E8),
                  footer: _ProgressStarsRow(
                    filledCount: _displayStarsFromSectionTotal(
                      progress.songSectionStars[lightlyRowSong.id] ?? 0,
                    ),
                    color: const Color(0xFFE091E8),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongLearningScreen(
                          song: lightlyRowSong,
                          session: session,
                          onLogout: onLogout,
                          onProfileUpdated: onProfileUpdated,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ViolinGameScreen extends StatefulWidget {
  const ViolinGameScreen({
    super.key,
    required this.activeStringIndices,
    required this.session,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final List<int> activeStringIndices;
  final UserSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  State<ViolinGameScreen> createState() => _ViolinGameScreenState();
}

class _ViolinGameScreenState extends State<ViolinGameScreen> {
  final Random _random = Random();

  static const List<GameNote> _allNotes = [
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

  final Map<String, int> _consecutiveCorrect = {
    for (final note in _allNotes) note.id: 0,
  };
  final Map<String, bool> _mastered = {for (final note in _allNotes) note.id: false};
  final Map<String, bool> _hideHintForNote = {
    for (final note in _allNotes) note.id: false,
  };
  final Map<String, int> _mistakesWithoutHint = {
    for (final note in _allNotes) note.id: 0,
  };
  static const int _mistakesBeforeHintReturns = 2;
  static const int _relearnCorrectToHideHintAgain = 2;
  int _neckShakeTrigger = 0;
  late final AudioPlayer _audioPlayer;
  final Map<String, Uint8List> _toneCache = {};
  static const double _sectionStarAccuracyThreshold = 0.85;

  late GameNote _currentNote;
  late final List<int> _activeStringIndices;
  FeedbackState _feedbackState = FeedbackState.idle;
  bool _isTransitioning = false;
  bool _mistakeChargedForCurrentNote = false;
  final Map<int, int> _stringAttempts = {for (int i = 0; i < 4; i++) i: 0};
  final Map<int, int> _stringCorrect = {for (int i = 0; i < 4; i++) i: 0};
  final Map<int, Set<String>> _stringNoHintCorrectNoteIds = {
    for (int i = 0; i < 4; i++) i: <String>{},
  };

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    unawaited(_audioPlayer.setPlayerMode(PlayerMode.lowLatency));
    _activeStringIndices = widget.activeStringIndices.toSet().toList()..sort();
    _currentNote = _pickRandomNoteFromSelection();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<GameNote> get _activeNotesForSelection => _allNotes
      .where((note) => _activeStringIndices.contains(note.stringIndex))
      .toList();

  GameNote _pickRandomNoteFromSelection({GameNote? excluding}) {
    final activeNotes = _activeNotesForSelection;
    if (activeNotes.isEmpty) return _allNotes.first;
    final options = excluding == null
        ? activeNotes
        : activeNotes.where((note) => note.id != excluding.id).toList();
    if (options.isEmpty) return activeNotes.first;
    return options[_random.nextInt(options.length)];
  }

  List<GameNote> _notesForString(int stringIndex) =>
      _allNotes.where((note) => note.stringIndex == stringIndex).toList();

  Future<bool> _maybeAwardStringRankStar(int stringIndex) async {
    if (!_activeStringIndices.contains(stringIndex)) return false;
    final needed = _notesForString(stringIndex).length;
    if ((_stringNoHintCorrectNoteIds[stringIndex]?.length ?? 0) < needed) return false;
    final attempts = _stringAttempts[stringIndex] ?? 0;
    if (attempts <= 0) return false;
    final accuracy = (_stringCorrect[stringIndex] ?? 0) / attempts;
    if (accuracy < _sectionStarAccuracyThreshold) return false;
    return _HeroProgressStore.awardStringSectionStarForSession(stringIndex);
  }

  Future<void> _onFingerPlacement(_FingerPlacement placement) async {
    if (_isTransitioning) return;
    final noteId = _currentNote.id;
    final hintWasHidden = (_mastered[noteId] ?? false) && (_hideHintForNote[noteId] ?? false);
    final alreadyMastered = _mastered[noteId] ?? false;

    final isCorrect =
        placement.stringIndex == _currentNote.stringIndex &&
        placement.fingerNumber == _currentNote.fingerNumber;
    final stringIndex = _currentNote.stringIndex;
    _stringAttempts[stringIndex] = (_stringAttempts[stringIndex] ?? 0) + 1;

    if (isCorrect) {
      var justMastered = false;
      setState(() {
        _feedbackState = FeedbackState.correct;
        _consecutiveCorrect[noteId] = (_consecutiveCorrect[noteId] ?? 0) + 1;

        if ((_consecutiveCorrect[noteId] ?? 0) >= 3) {
          justMastered = !alreadyMastered;
          _mastered[noteId] = true;
          _hideHintForNote[noteId] = true;
          _mistakesWithoutHint[noteId] = 0;
        } else if ((_mastered[noteId] ?? false) &&
            !hintWasHidden &&
            (_consecutiveCorrect[noteId] ?? 0) >= _relearnCorrectToHideHintAgain) {
          _hideHintForNote[noteId] = true;
          _mistakesWithoutHint[noteId] = 0;
        } else if (hintWasHidden) {
          _mistakesWithoutHint[noteId] = 0;
        }
        _isTransitioning = true;
        _mistakeChargedForCurrentNote = false;
      });

      var starsEarned = hintWasHidden ? 2 : 1;
      if (justMastered) {
        starsEarned += 8;
      }
      unawaited(
        _HeroProgressStore.awardStars(
          starsEarned,
          username: widget.session.username,
        ),
      );
      _stringCorrect[stringIndex] = (_stringCorrect[stringIndex] ?? 0) + 1;
      if (hintWasHidden) {
        _stringNoHintCorrectNoteIds[stringIndex]?.add(noteId);
      }
      final awardedStringRank = await _maybeAwardStringRankStar(stringIndex);
      if (awardedStringRank) {
        unawaited(
          UserEventLogStore.log(
            username: widget.session.username,
            type: UserEventType.learnStringRankStarAwarded,
            outcome: true,
            stringIndex: stringIndex,
            metadata: {
              'requiredNoHintNotes': _notesForString(stringIndex).length,
              'accuracy': (_stringCorrect[stringIndex] ?? 0) /
                  max(1, (_stringAttempts[stringIndex] ?? 1)),
            },
          ),
        );
      }
      unawaited(
        UserEventLogStore.log(
          username: widget.session.username,
          type: UserEventType.learnNoteAttempt,
          outcome: true,
          starsDelta: starsEarned,
          noteId: noteId,
          stringIndex: stringIndex,
          hintUsed: !hintWasHidden,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': _currentNote.fingerNumber,
          },
        ),
      );

      await _playNoteTone(_currentNote);
      await Future<void>.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;
      setState(() {
        _currentNote = _pickRandomNoteFromSelection(excluding: _currentNote);
        _feedbackState = FeedbackState.idle;
        _isTransitioning = false;
      });
    } else {
      setState(() {
        _feedbackState = FeedbackState.wrong;
        _consecutiveCorrect[noteId] = 0;
        if (hintWasHidden) {
          final nextMistakeCount = (_mistakesWithoutHint[noteId] ?? 0) + 1;
          _mistakesWithoutHint[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeHintReturns) {
            _hideHintForNote[noteId] = false;
            _mistakesWithoutHint[noteId] = 0;
          }
        }
        _neckShakeTrigger++;
      });
      final chargedNow = !_mistakeChargedForCurrentNote;
      if (chargedNow) {
        _mistakeChargedForCurrentNote = true;
        unawaited(
          _HeroProgressStore.awardStars(
            -1,
            username: widget.session.username,
          ),
        );
      }
      final starsDelta = chargedNow ? -1 : 0;
      unawaited(
        UserEventLogStore.log(
          username: widget.session.username,
          type: UserEventType.learnNoteAttempt,
          outcome: false,
          starsDelta: starsDelta,
          noteId: noteId,
          stringIndex: stringIndex,
          hintUsed: !hintWasHidden,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': _currentNote.fingerNumber,
          },
        ),
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _feedbackState != FeedbackState.wrong) return;
          setState(() {
            _feedbackState = FeedbackState.idle;
          });
        }),
      );
    }
  }

  bool get _showHintColors {
    final noteId = _currentNote.id;
    final isMastered = _mastered[noteId] ?? false;
    final hideHint = _hideHintForNote[noteId] ?? false;
    return !isMastered || !hideHint;
  }

  Future<void> _playNoteTone(GameNote note) async {
    final toneBytes =
        _toneCache.putIfAbsent(note.id, () => _buildViolinLikeWav(note.frequencyHz));
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        BytesSource(toneBytes, mimeType: 'audio/wav'),
        volume: 0.85,
      );
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Uint8List _buildViolinLikeWav(double frequencyHz) {
    const sampleRate = 44100;
    const durationMs = 620;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = sampleCount * blockAlign;
    final fileSize = 36 + dataSize;

    final bytes = BytesBuilder();
    void writeString(String value) => bytes.add(value.codeUnits);
    void writeU32(int value) {
      final b = ByteData(4)..setUint32(0, value, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    void writeU16(int value) {
      final b = ByteData(2)..setUint16(0, value, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    writeString('RIFF');
    writeU32(fileSize);
    writeString('WAVE');
    writeString('fmt ');
    writeU32(16);
    writeU16(1);
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeString('data');
    writeU32(dataSize);

    const amplitude = 0.38;
    const attackSamples = 5200;
    const releaseSamples = 6800;
    const lowPassMix1 = 0.955;
    const lowPassMix2 = 0.92;
    const bowNoiseAmount = 0.0012;
    const formant1Hz = 1450.0;
    const formant2Hz = 2150.0;
    var lowPassState = 0.0;
    var lowPassState2 = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      var env = 1.0;
      if (i < attackSamples) {
        env = i / attackSamples;
      } else if (i > sampleCount - releaseSamples) {
        env = (sampleCount - i) / releaseSamples;
      }
      final baseFreq = frequencyHz;
      final harmonic = sin(2 * pi * baseFreq * t) * 0.68 +
          sin(2 * pi * baseFreq * 2 * t) * 0.10 +
          sin(2 * pi * baseFreq * 3 * t) * 0.035 +
          sin(2 * pi * baseFreq * 4 * t) * 0.012 +
          sin(2 * pi * baseFreq * 5 * t) * 0.006;

      final formant = sin(2 * pi * formant1Hz * t) * 0.005 +
          sin(2 * pi * formant2Hz * t) * 0.0026;

      final bowNoise = sin(2 * pi * 1137.0 * t);
      final raw = harmonic + formant + bowNoise * bowNoiseAmount * env;

      // Two-stage smoothing for a cleaner, less buzzy violin tone on speakers.
      lowPassState = lowPassState * lowPassMix1 + raw * (1 - lowPassMix1);
      lowPassState2 = lowPassState2 * lowPassMix2 + lowPassState * (1 - lowPassMix2);
      final drive = lowPassState2 * 1.05;
      final softClipped = drive / (1 + drive.abs());
      final sample = softClipped * amplitude * env;
      final pcm = (sample * 32767).round().clamp(-32768, 32767);
      final b = ByteData(2)..setInt16(0, pcm, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    return bytes.toBytes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        leading: const BackButton(),
        title: const Text('Learn Notes'),
        actions: [
          ProfileCornerAction(
            session: widget.session,
            onLogout: widget.onLogout,
            onProfileUpdated: widget.onProfileUpdated,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final neckWidth = _ViolinFingerGeometry.mmToLogicalPx(
              _ViolinFingerGeometry.neckVisualWidthMm,
            );
            final neckViewportWidth = min(neckWidth + 20, constraints.maxWidth * 0.84);
            final fullScaleNeckHeight = _ViolinFingerGeometry.mmToLogicalPx(
              _ViolinFingerGeometry.totalNeckLengthMm,
            );
            // Leave enough vertical buffer for paddings/card chrome to prevent overflow.
            final neckHeight = min(fullScaleNeckHeight, constraints.maxHeight - 44);
            return Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 10, 16),
                    child: Column(
                      children: [
                        _MusicStaffCard(
                          note: _currentNote,
                          feedbackState: _feedbackState,
                          showHintColors: _showHintColors,
                          hintColor: _currentNote.hintColor,
                        ),
                        const SizedBox(height: 10),
                        _NoteHintCard(
                          note: _currentNote,
                          showHintColors: _showHintColors,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: neckViewportWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 0, bottom: 10),
                    child: _VerticalViolinNeckCard(
                      key: ValueKey(_currentNote.id),
                      neckHeight: neckHeight,
                      neckWidth: neckWidth,
                      targetFingerNumber: _currentNote.fingerNumber,
                      targetStringIndex: _currentNote.stringIndex,
                      showHintColors: _showHintColors,
                      hintColor: _currentNote.hintColor,
                      shakeTrigger: _neckShakeTrigger,
                      onPlacement: _onFingerPlacement,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SongLearningScreen extends StatefulWidget {
  const SongLearningScreen({
    super.key,
    required this.song,
    required this.session,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  final SongDefinition song;
  final UserSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<UserSession> onProfileUpdated;

  @override
  State<SongLearningScreen> createState() => _SongLearningScreenState();
}

class _SongLearningScreenState extends State<SongLearningScreen> {
  static const int _quarterNoteDurationMs = 620;
  static const int _halfNoteDurationMs = 1120;
  static const int _eighthNoteDurationMs = 340;
  static const double _sectionStarAccuracyThreshold = 0.85;
  static const List<GameNote> _songNotePool = [
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
  ];

  static const int _mistakesBeforeHintReturns = 2;
  static const int _relearnCorrectToHideHintAgain = 2;
  final Map<String, int> _consecutiveCorrect = {
    for (final note in _songNotePool) note.id: 0,
  };
  final Map<String, bool> _mastered = {
    for (final note in _songNotePool) note.id: false,
  };
  final Map<String, bool> _hideHintForNote = {
    for (final note in _songNotePool) note.id: false,
  };
  final Map<String, int> _mistakesWithoutHint = {
    for (final note in _songNotePool) note.id: 0,
  };

  late final AudioPlayer _audioPlayer;
  final Map<String, Uint8List> _toneCache = {};
  late SongDefinition _selectedSong;
  int _songIndex = 0;
  int _mistakesThisRun = 0;
  int _neckShakeTrigger = 0;
  bool _showSongCompleteOverlay = false;
  int _songCompleteToken = 0;
  String _songCompleteOverlayTitle = 'Song Complete!';
  String _songCompleteOverlaySubtitle = '';
  bool _songCompleteOverlayBigWin = false;
  bool _isByHeartMode = false;
  String? _byHeartHintNoteId;
  int _byHeartMistakesOnCurrentNote = 0;
  FeedbackState _feedbackState = FeedbackState.idle;
  bool _isTransitioning = false;
  bool _mistakeChargedForCurrentSongNote = false;
  int _wrongChargedNotesThisRun = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    unawaited(_audioPlayer.setPlayerMode(PlayerMode.lowLatency));
    _selectedSong = widget.song;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  GameNote _noteById(String id) {
    return _songNotePool.firstWhere((note) => note.id == id);
  }

  List<GameNote> get _songNotes =>
      _selectedSong.noteIds.map(_noteById).toList(growable: false);

  GameNote get _currentNote => _songNotes[_songIndex];
  int get _currentBeatUnits => _selectedSong.noteBeats?[_songIndex] ?? 1;
  bool get _currentIsEighthNote =>
      _selectedSong.eighthNoteIndices?.contains(_songIndex) ?? false;
  int get _currentNoteDurationMs {
    if (_currentIsEighthNote) return _eighthNoteDurationMs;
    if (_currentBeatUnits >= 2) return _halfNoteDurationMs;
    return _quarterNoteDurationMs;
  }

  bool _showHintFor(String noteId) {
    final isMastered = _mastered[noteId] ?? false;
    final hideHint = _hideHintForNote[noteId] ?? false;
    return !isMastered || !hideHint;
  }

  bool get _notesVisibleInUi =>
      !_isByHeartMode || _byHeartHintNoteId == _currentNote.id;
  bool get _showHintColors => _notesVisibleInUi && _showHintFor(_currentNote.id);

  void _togglePlayMode() {
    setState(() {
      _isByHeartMode = !_isByHeartMode;
      _songIndex = 0;
      _mistakesThisRun = 0;
      _wrongChargedNotesThisRun = 0;
      _mistakeChargedForCurrentSongNote = false;
      _feedbackState = FeedbackState.idle;
      _isTransitioning = false;
      _byHeartHintNoteId = null;
      _byHeartMistakesOnCurrentNote = 0;
    });
  }

  void _triggerSongCompleteOverlay({
    required String title,
    String subtitle = '',
    bool isBigWin = false,
  }) {
    _songCompleteToken++;
    final token = _songCompleteToken;
    setState(() {
      _songCompleteOverlayTitle = title;
      _songCompleteOverlaySubtitle = subtitle;
      _songCompleteOverlayBigWin = isBigWin;
      _showSongCompleteOverlay = true;
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1450), () {
        if (!mounted || token != _songCompleteToken) return;
        setState(() {
          _showSongCompleteOverlay = false;
        });
      }),
    );
  }

  Future<void> _onFingerPlacement(_FingerPlacement placement) async {
    if (_isTransitioning) return;
    final noteId = _currentNote.id;
    final hintWasHidden = (_mastered[noteId] ?? false) && (_hideHintForNote[noteId] ?? false);
    final noteVisibleInUi = !_isByHeartMode || _byHeartHintNoteId == noteId;
    final hintVisibleNow = noteVisibleInUi && _showHintFor(noteId);

    final isCorrect =
        placement.stringIndex == _currentNote.stringIndex &&
        placement.fingerNumber == _currentNote.fingerNumber;

    if (isCorrect) {
      setState(() {
        _feedbackState = FeedbackState.correct;
        if (_isByHeartMode) {
          _byHeartHintNoteId = null;
          _byHeartMistakesOnCurrentNote = 0;
        }
        _consecutiveCorrect[noteId] = (_consecutiveCorrect[noteId] ?? 0) + 1;
        if ((_consecutiveCorrect[noteId] ?? 0) >= 3) {
          _mastered[noteId] = true;
          _hideHintForNote[noteId] = true;
          _mistakesWithoutHint[noteId] = 0;
        } else if ((_mastered[noteId] ?? false) &&
            !hintWasHidden &&
            (_consecutiveCorrect[noteId] ?? 0) >= _relearnCorrectToHideHintAgain) {
          _hideHintForNote[noteId] = true;
          _mistakesWithoutHint[noteId] = 0;
        } else if (hintWasHidden) {
          _mistakesWithoutHint[noteId] = 0;
        }
        _isTransitioning = true;
        _mistakeChargedForCurrentSongNote = false;
      });

      final starsForCorrect = switch (_isByHeartMode) {
        true => hintVisibleNow ? 2 : 3,
        false => hintVisibleNow ? 1 : 2,
      };
      unawaited(
        _HeroProgressStore.awardStars(
          starsForCorrect,
          username: widget.session.username,
        ),
      );
      unawaited(
        UserEventLogStore.log(
          username: widget.session.username,
          type: UserEventType.songNoteAttempt,
          outcome: true,
          starsDelta: starsForCorrect,
          noteId: noteId,
          stringIndex: _currentNote.stringIndex,
          songId: _selectedSong.id,
          byHeartMode: _isByHeartMode,
          hintUsed: hintVisibleNow,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': _currentNote.fingerNumber,
          },
        ),
      );

      final noteDurationMs = _currentNoteDurationMs;
      await _playNoteTone(_currentNote, durationMs: noteDurationMs);
      await Future<void>.delayed(Duration(milliseconds: noteDurationMs));

      if (!mounted) return;
      var songCompleted = false;
      setState(() {
        if (_songIndex >= _songNotes.length - 1) {
          _songIndex = 0;
          songCompleted = true;
        } else {
          _songIndex++;
        }
        _feedbackState = FeedbackState.idle;
        _isTransitioning = false;
      });
      if (songCompleted) {
        final noteCount = _songNotes.length;
        final correctlyPlayedCount = max<int>(
          0,
          noteCount - _wrongChargedNotesThisRun,
        );
        final accuracy = noteCount == 0 ? 0.0 : correctlyPlayedCount / noteCount;
        final accuracyBonus = switch (accuracy) {
          >= 0.95 => 15,
          >= 0.85 => 10,
          >= 0.70 => 5,
          _ => 0,
        };
        final completionBonus = 10 + (_isByHeartMode ? 10 : 0);
        final runStarsAward = completionBonus + accuracyBonus;
        final progressAward = await _HeroProgressStore.awardStars(
          runStarsAward,
          username: widget.session.username,
        );
        var awardedSongRankStar = false;
        if (accuracy >= _sectionStarAccuracyThreshold) {
          awardedSongRankStar = await _HeroProgressStore.awardSongSectionStarForSession(
            _selectedSong.id,
          );
        }
        unawaited(
          UserEventLogStore.log(
            username: widget.session.username,
            type: UserEventType.songCompleted,
            outcome: accuracy >= _sectionStarAccuracyThreshold,
            starsDelta: runStarsAward,
            songId: _selectedSong.id,
            byHeartMode: _isByHeartMode,
            accuracy: accuracy,
            metadata: {
              'noteCount': noteCount,
              'wrongChargedNotes': _wrongChargedNotesThisRun,
              'completionBonus': completionBonus,
              'accuracyBonus': accuracyBonus,
            },
          ),
        );
        if (awardedSongRankStar) {
          unawaited(
            UserEventLogStore.log(
              username: widget.session.username,
              type: UserEventType.songRankStarAwarded,
              outcome: true,
              songId: _selectedSong.id,
              byHeartMode: _isByHeartMode,
              accuracy: accuracy,
            ),
          );
        }
        if (!mounted) return;

        final completedWithoutMistakes = _mistakesThisRun == 0;
        final shouldEnterByHeart = !_isByHeartMode && completedWithoutMistakes;
        setState(() {
          _mistakesThisRun = 0;
          _wrongChargedNotesThisRun = 0;
          _mistakeChargedForCurrentSongNote = false;
          if (shouldEnterByHeart) {
            _isByHeartMode = true;
            _byHeartHintNoteId = null;
            _byHeartMistakesOnCurrentNote = 0;
          }
        });
        if (progressAward.triggeredWeeklyBonus) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Weekly streak bonus unlocked! +20 stars'),
              duration: Duration(milliseconds: 1300),
            ),
          );
        }
        if (shouldEnterByHeart) {
          _triggerSongCompleteOverlay(
            title: 'Perfect run!',
            subtitle: 'Now play by heart. +$runStarsAward stars',
            isBigWin: true,
          );
        } else {
          _triggerSongCompleteOverlay(
            title: runStarsAward >= 20 ? 'Nice work!' : 'Song Complete!',
            subtitle: '+$runStarsAward stars',
            isBigWin: runStarsAward >= 20,
          );
        }
      }
    } else {
      setState(() {
        _feedbackState = FeedbackState.wrong;
        _mistakesThisRun++;
        if (_isByHeartMode) {
          _byHeartMistakesOnCurrentNote++;
          if (_byHeartMistakesOnCurrentNote >= 2) {
            _byHeartHintNoteId = noteId;
          }
        }
        _consecutiveCorrect[noteId] = 0;
        if (hintWasHidden) {
          final nextMistakeCount = (_mistakesWithoutHint[noteId] ?? 0) + 1;
          _mistakesWithoutHint[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeHintReturns) {
            _hideHintForNote[noteId] = false;
            _mistakesWithoutHint[noteId] = 0;
          }
        }
        _neckShakeTrigger++;
      });
      final chargedNow = !_mistakeChargedForCurrentSongNote;
      if (chargedNow) {
        _mistakeChargedForCurrentSongNote = true;
        _wrongChargedNotesThisRun++;
        unawaited(
          _HeroProgressStore.awardStars(
            -1,
            username: widget.session.username,
          ),
        );
      }
      unawaited(
        UserEventLogStore.log(
          username: widget.session.username,
          type: UserEventType.songNoteAttempt,
          outcome: false,
          starsDelta: chargedNow ? -1 : 0,
          noteId: noteId,
          stringIndex: _currentNote.stringIndex,
          songId: _selectedSong.id,
          byHeartMode: _isByHeartMode,
          hintUsed: hintVisibleNow,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': _currentNote.fingerNumber,
          },
        ),
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _feedbackState != FeedbackState.wrong) return;
          setState(() {
            _feedbackState = FeedbackState.idle;
          });
        }),
      );
    }
  }

  Future<void> _playNoteTone(GameNote note, {required int durationMs}) async {
    final cacheKey = '${note.id}_$durationMs';
    final toneBytes = _toneCache.putIfAbsent(
      cacheKey,
      () => _buildViolinLikeWav(note.frequencyHz, durationMs: durationMs),
    );
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        BytesSource(toneBytes, mimeType: 'audio/wav'),
        volume: 0.85,
      );
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Uint8List _buildViolinLikeWav(double frequencyHz, {required int durationMs}) {
    const sampleRate = 44100;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = sampleCount * blockAlign;
    final fileSize = 36 + dataSize;

    final bytes = BytesBuilder();
    void writeString(String value) => bytes.add(value.codeUnits);
    void writeU32(int value) {
      final b = ByteData(4)..setUint32(0, value, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    void writeU16(int value) {
      final b = ByteData(2)..setUint16(0, value, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    writeString('RIFF');
    writeU32(fileSize);
    writeString('WAVE');
    writeString('fmt ');
    writeU32(16);
    writeU16(1);
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeString('data');
    writeU32(dataSize);

    const amplitude = 0.38;
    const attackSamples = 5200;
    const releaseSamples = 6800;
    const lowPassMix1 = 0.955;
    const lowPassMix2 = 0.92;
    const bowNoiseAmount = 0.0012;
    const formant1Hz = 1450.0;
    const formant2Hz = 2150.0;
    var lowPassState = 0.0;
    var lowPassState2 = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      var env = 1.0;
      if (i < attackSamples) {
        env = i / attackSamples;
      } else if (i > sampleCount - releaseSamples) {
        env = (sampleCount - i) / releaseSamples;
      }
      final baseFreq = frequencyHz;
      final harmonic = sin(2 * pi * baseFreq * t) * 0.68 +
          sin(2 * pi * baseFreq * 2 * t) * 0.10 +
          sin(2 * pi * baseFreq * 3 * t) * 0.035 +
          sin(2 * pi * baseFreq * 4 * t) * 0.012 +
          sin(2 * pi * baseFreq * 5 * t) * 0.006;

      final formant = sin(2 * pi * formant1Hz * t) * 0.005 +
          sin(2 * pi * formant2Hz * t) * 0.0026;

      final bowNoise = sin(2 * pi * 1137.0 * t);
      final raw = harmonic + formant + bowNoise * bowNoiseAmount * env;

      lowPassState = lowPassState * lowPassMix1 + raw * (1 - lowPassMix1);
      lowPassState2 = lowPassState2 * lowPassMix2 + lowPassState * (1 - lowPassMix2);
      final drive = lowPassState2 * 1.05;
      final softClipped = drive / (1 + drive.abs());
      final sample = softClipped * amplitude * env;
      final pcm = (sample * 32767).round().clamp(-32768, 32767);
      final b = ByteData(2)..setInt16(0, pcm, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    return bytes.toBytes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        leading: const BackButton(),
        centerTitle: false,
        titleSpacing: 2,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _selectedSong.title,
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
        ),
        actions: [
          ProfileCornerAction(
            session: widget.session,
            onLogout: widget.onLogout,
            onProfileUpdated: widget.onProfileUpdated,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final neckWidth = _ViolinFingerGeometry.mmToLogicalPx(
              _ViolinFingerGeometry.neckVisualWidthMm,
            );
            final neckViewportWidth = min(neckWidth + 20, constraints.maxWidth * 0.84);
            final fullScaleNeckHeight = _ViolinFingerGeometry.mmToLogicalPx(
              _ViolinFingerGeometry.totalNeckLengthMm,
            );
            final neckHeight = min(fullScaleNeckHeight, constraints.maxHeight - 20);
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 10, 16),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (_notesVisibleInUi) ...[
                                _MusicStaffCard(
                                  note: _currentNote,
                                  feedbackState: _feedbackState,
                                  showHintColors: _showHintColors,
                                  hintColor: _currentNote.hintColor,
                                  isHalfNote: _currentBeatUnits >= 2,
                                  isEighthNote: _currentIsEighthNote,
                                ),
                                const SizedBox(height: 8),
                                _NoteHintCard(
                                  note: _currentNote,
                                  showHintColors: _showHintColors,
                                ),
                                const SizedBox(height: 8),
                              ] else ...[
                                const SizedBox(height: 2),
                                const SizedBox(height: 8),
                              ],
                              FilledButton.tonalIcon(
                                onPressed: _togglePlayMode,
                                icon: Icon(
                                  _isByHeartMode
                                      ? Icons.music_note_rounded
                                      : Icons.favorite_rounded,
                                ),
                                label: Text(
                                  _isByHeartMode
                                      ? 'Play with notes'
                                      : 'Play by heart',
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: neckViewportWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, top: 0, bottom: 10),
                        child: _VerticalViolinNeckCard(
                          key: ValueKey('${_selectedSong.id}_${_songIndex}_${_currentNote.id}'),
                          neckHeight: neckHeight,
                          neckWidth: neckWidth,
                          targetFingerNumber: _currentNote.fingerNumber,
                          targetStringIndex: _currentNote.stringIndex,
                          showHintColors: _showHintColors,
                          hintColor: _currentNote.hintColor,
                          shakeTrigger: _neckShakeTrigger,
                          onPlacement: _onFingerPlacement,
                        ),
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  ignoring: !_showSongCompleteOverlay,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _showSongCompleteOverlay ? 1 : 0,
                    child: _SongCompleteOverlay(
                      title: _songCompleteOverlayTitle,
                      subtitle: _songCompleteOverlaySubtitle,
                      isBigWin: _songCompleteOverlayBigWin,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SongCompleteOverlay extends StatelessWidget {
  const _SongCompleteOverlay({
    required this.title,
    required this.subtitle,
    required this.isBigWin,
  });

  final String title;
  final String subtitle;
  final bool isBigWin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0x66000000),
      child: Stack(
        children: [
          if (isBigWin)
            const Positioned.fill(
              child: IgnorePointer(
                child: _StarRainToProfile(),
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBigWin ? Icons.stars_rounded : Icons.star_rounded,
                        color: isBigWin
                            ? const Color(0xFFF59F00)
                            : const Color(0xFF7A8BFF),
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F3A61),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4C587E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRainToProfile extends StatefulWidget {
  const _StarRainToProfile();

  @override
  State<_StarRainToProfile> createState() => _StarRainToProfileState();
}

class _StarRainToProfileState extends State<_StarRainToProfile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final target = Offset(width - 52, 42);
            final stars = List<Widget>.generate(12, (index) {
              final lane = index % 6;
              final row = index ~/ 6;
              final startX = width * (0.12 + lane * 0.14);
              final startY = -20.0 - row * 22;
              final fallY = height * (0.30 + (index % 3) * 0.07);
              final wobble = sin((t * 7) + index) * 10;
              late double x;
              late double y;
              if (t < 0.68) {
                final phase = t / 0.68;
                x = startX + wobble;
                y = lerpDouble(startY, fallY, Curves.easeIn.transform(phase))!;
              } else {
                final phase = (t - 0.68) / 0.32;
                final from = Offset(startX + wobble, fallY);
                final to = target.translate(
                  (index.isEven ? -1 : 1) * (6 + index * 0.8),
                  index % 2 == 0 ? 2 : -2,
                );
                x = lerpDouble(from.dx, to.dx, Curves.easeInOut.transform(phase))!;
                y = lerpDouble(from.dy, to.dy, Curves.easeInOut.transform(phase))!;
              }
              final size = 18.0 - (index % 3) * 2;
              final fade = t < 0.9 ? 1.0 : 1.0 - ((t - 0.9) / 0.1);
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: fade.clamp(0, 1),
                  child: Transform.rotate(
                    angle: t * (0.8 + index * 0.03),
                    child: Icon(
                      Icons.star_rounded,
                      size: size,
                      color: const Color(0xFFFFC533),
                    ),
                  ),
                ),
              );
            });
            return Stack(children: stars);
          },
        );
      },
    );
  }
}

class _MusicStaffCard extends StatelessWidget {
  const _MusicStaffCard({
    required this.note,
    required this.feedbackState,
    required this.showHintColors,
    required this.hintColor,
    this.isHalfNote = false,
    this.isEighthNote = false,
  });

  final GameNote note;
  final FeedbackState feedbackState;
  final bool showHintColors;
  final Color hintColor;
  final bool isHalfNote;
  final bool isEighthNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _StaffPainter(
                staffStep: note.staffStep,
                showSharp: note.letterLabel.contains('#'),
                noteColor: showHintColors ? hintColor : const Color(0xFF111111),
                isHalfNote: isHalfNote,
                isEighthNote: isEighthNote,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (feedbackState) {
              FeedbackState.correct => const Icon(
                  Icons.check_circle,
                  key: ValueKey('correct'),
                  color: Colors.green,
                  size: 34,
                ),
              FeedbackState.wrong => const Icon(
                  Icons.cancel,
                  key: ValueKey('wrong'),
                  color: Colors.redAccent,
                  size: 34,
                ),
              FeedbackState.idle => const SizedBox(
                  key: ValueKey('idle'),
                  height: 34,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _NoteHintCard extends StatelessWidget {
  const _NoteHintCard({
    required this.note,
    required this.showHintColors,
  });

  final GameNote note;
  final bool showHintColors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 108,
        height: 108,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: showHintColors ? note.hintColor.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showHintColors ? note.hintColor : const Color(0xFFDDE1F3),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          note.solfegeLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: showHintColors ? note.hintColor : const Color(0xFF1F2438),
          ),
        ),
      ),
    );
  }
}

class _FingerPlacement {
  const _FingerPlacement({required this.fingerNumber, required this.stringIndex});

  final int fingerNumber;
  final int stringIndex;
}

class _ResolvedPlacement {
  const _ResolvedPlacement({required this.placement, required this.marker});

  final _FingerPlacement placement;
  final Offset marker;
}

class _ViolinFingerGeometry {
  static const double _assumedLogicalDpi = 160;
  static const double halfSizeStringLengthMm = 285;
  static const List<int> _semitonesFromOpen = [2, 4, 5];
  static const double stoppedFingerSpacingScale = 0.72;
  static final List<double> fingerMm = [
    0,
    for (final semitone in _semitonesFromOpen) _distanceFromNutForSemitone(semitone),
  ];
  static const double topPaddingMm = -4;
  static const double bottomPaddingMm = 10;
  static const double neckVisualWidthMm = 28;
  static const double totalNeckLengthMm =
      halfSizeStringLengthMm + topPaddingMm + bottomPaddingMm;
  static const double openStringZoneMm = 40;

  static double _distanceFromNutForSemitone(int semitone) {
    return halfSizeStringLengthMm * (1 - 1 / pow(2, semitone / 12));
  }

  static double mmToLogicalPx(double mm) => mm * _assumedLogicalDpi / 25.4;
  static double get topPadding => mmToLogicalPx(topPaddingMm);
  static double get bottomPadding => mmToLogicalPx(bottomPaddingMm);

  static List<double> stringXs(Size size) {
    final left = size.width * 0.26;
    final right = size.width * 0.74;
    final spacing = (right - left) / 3;
    return [for (int i = 0; i < 4; i++) left + i * spacing];
  }

  static double mmForFinger(int fingerNumber) {
    if (fingerNumber == 0) return halfSizeStringLengthMm;
    return fingerMm[fingerNumber] * stoppedFingerSpacingScale;
  }

  static double yForFingerOnScreen({required int fingerNumber, required Size size}) {
    final top = topPadding;
    final bottom = size.height - bottomPadding;
    if (fingerNumber == 0) return bottom;
    final y = top + mmToLogicalPx(mmForFinger(fingerNumber));
    return y.clamp(top, bottom).toDouble();
  }

  static _ResolvedPlacement resolveFromTouch(Offset local, Size size) {
    final strings = stringXs(size);
    int stringIndex = 0;
    double bestDx = double.infinity;
    for (int i = 0; i < strings.length; i++) {
      final dx = (local.dx - strings[i]).abs();
      if (dx < bestDx) {
        bestDx = dx;
        stringIndex = i;
      }
    }

    final top = topPadding;
    final bottom = size.height - bottomPadding;
    final clampedY = local.dy.clamp(top, bottom).toDouble();
    final y1 = yForFingerOnScreen(fingerNumber: 1, size: size);
    final y2 = yForFingerOnScreen(fingerNumber: 2, size: size);
    final y3 = yForFingerOnScreen(fingerNumber: 3, size: size);
    final openZonePx = min(mmToLogicalPx(openStringZoneMm), (bottom - top) * 0.35);

    final int fingerNumber;
    if (clampedY >= bottom - openZonePx) {
      fingerNumber = 0;
    } else if (clampedY < (y1 + y2) / 2) {
      fingerNumber = 1;
    } else if (clampedY < (y2 + y3) / 2) {
      fingerNumber = 2;
    } else {
      fingerNumber = 3;
    }
    final snappedY = yForFingerOnScreen(fingerNumber: fingerNumber, size: size);

    return _ResolvedPlacement(
      placement: _FingerPlacement(
        fingerNumber: fingerNumber,
        stringIndex: stringIndex,
      ),
      marker: Offset(strings[stringIndex], snappedY),
    );
  }
}

class _VerticalViolinNeckCard extends StatefulWidget {
  const _VerticalViolinNeckCard({
    super.key,
    required this.neckHeight,
    required this.neckWidth,
    required this.targetFingerNumber,
    required this.targetStringIndex,
    required this.showHintColors,
    required this.hintColor,
    required this.shakeTrigger,
    required this.onPlacement,
  });

  final double neckHeight;
  final double neckWidth;
  final int targetFingerNumber;
  final int targetStringIndex;
  final bool showHintColors;
  final Color hintColor;
  final int shakeTrigger;
  final ValueChanged<_FingerPlacement> onPlacement;

  @override
  State<_VerticalViolinNeckCard> createState() => _VerticalViolinNeckCardState();
}

class _VerticalViolinNeckCardState extends State<_VerticalViolinNeckCard> {
  Offset? _marker;
  int? _selectedString;

  void _handleTap(Offset localPosition, Size size) {
    final resolved = _ViolinFingerGeometry.resolveFromTouch(localPosition, size);
    setState(() {
      _marker = resolved.marker;
      _selectedString = resolved.placement.stringIndex;
    });
    widget.onPlacement(resolved.placement);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(widget.shakeTrigger),
        duration: const Duration(milliseconds: 340),
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          final wave = sin(value * pi * 8) * (1 - value) * 10;
          return Transform.translate(offset: Offset(wave, 0), child: child);
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: widget.neckWidth,
            height: widget.neckHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _handleTap(event.localPosition, size),
                  child: CustomPaint(
                    painter: _VerticalViolinNeckPainter(
                      marker: _marker,
                      selectedString: _selectedString,
                      targetFingerNumber: widget.targetFingerNumber,
                      targetStringIndex: widget.targetStringIndex,
                      showHintColors: widget.showHintColors,
                      hintColor: widget.hintColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffPainter extends CustomPainter {
  _StaffPainter({
    required this.staffStep,
    required this.showSharp,
    required this.noteColor,
    required this.isHalfNote,
    required this.isEighthNote,
  });

  final int staffStep;
  final bool showSharp;
  final Color noteColor;
  final bool isHalfNote;
  final bool isEighthNote;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..strokeWidth = 2;
    const lines = 5;
    // Keep staff lines slightly tighter so a canonical treble clef
    // can extend above and below within the available card height.
    final spacing = min(16.0, size.height / (lines + 4.5));
    final staffTopY = (size.height - spacing * (lines - 1)) / 2;

    final staffLeftX = 20.0;
    final staffRightX = size.width - 20;

    for (int i = 0; i < lines; i++) {
      final y = staffTopY + i * spacing;
      canvas.drawLine(Offset(staffLeftX, y), Offset(staffRightX, y), linePaint);
    }

    final staffBottomY = staffTopY + (lines - 1) * spacing;

    // G line = 2nd staff line from the bottom — the treble clef's inner
    // curl must sit exactly here, matching real sheet-music engraving.
    final gLineY = staffBottomY - spacing;

    const clefStyle = TextStyle(
      color: Color(0xFF111111),
      fontSize: 100,
      fontWeight: FontWeight.w400,
    );
    final clefText = TextPainter(
      text: TextSpan(text: '𝄞', style: clefStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Scale the clef so its lower loop reaches the bottom E line.
    // The 𝄞 glyph's lower loop turns around at roughly 82 % of the
    // glyph height from the top. With the curl at 69.2 %, the loop-
    // to-curl span = 0.128 of glyph height.  We need that span to
    // equal 1 staff-space (G→E), giving totalH ≈ 1/0.128 ≈ 7.8 sp.
    final targetClefHeight = spacing * 7.8;
    final heightScale = targetClefHeight / max(1.0, clefText.height);
    final maxClefWidth = spacing * 3.5;
    final widthScale = maxClefWidth / max(1.0, clefText.width);
    final clefScale = min(heightScale, widthScale);

    // The inner curl of the 𝄞 glyph sits at this fraction from the
    // glyph's top. Derived from the standard proportions:
    //   top-overshoot 1.5 sp + staff 3 sp to G-line = 4.5 sp from top,
    //   total 6.5 sp → 4.5 / 6.5 ≈ 0.692.
    const curlFromTop = 0.692;
    final scaledH = clefText.height * clefScale;
    final clefX = staffLeftX + 2;
    final clefY = gLineY - scaledH * curlFromTop;

    canvas.save();
    canvas.translate(clefX, clefY);
    canvas.scale(clefScale, clefScale);
    clefText.paint(canvas, Offset.zero);
    canvas.restore();
    final clefRightX = clefX + clefText.width * clefScale;

    final bottomLineY = staffBottomY;
    final noteY = bottomLineY - staffStep * (spacing / 2);

    final noteFillPaint = Paint()..color = noteColor;
    final noteStrokePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.8, spacing * 0.20);
    final noteHeadWidth = spacing * 1.35;
    final noteHeadHeight = spacing * 0.95;
    final horizontalGap = spacing * 0.55;
    final noteXMax = staffRightX - noteHeadWidth * 0.52;

    final sharpWidth = showSharp ? spacing * 1.04 : 0.0;

    final noteXMin = showSharp
        ? clefRightX + horizontalGap + sharpWidth + horizontalGap + noteHeadWidth * 0.52
        : clefRightX + horizontalGap + noteHeadWidth * 0.52;
    final noteX = noteXMax < noteXMin
        ? (noteXMin + noteXMax) / 2
        : noteXMax;

    // Draw ledger lines for notes outside the 5-line staff.
    // Staff line steps: 0,2,4,6,8 (bottom -> top). Steps are in half-space units.
    final ledgerPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..strokeWidth = 2;
    final ledgerHalfLength = noteHeadWidth * 0.78;
    if (staffStep > 8) {
      final highestLedgerStep = staffStep.isEven ? staffStep : staffStep - 1;
      for (int ledgerStep = 10; ledgerStep <= highestLedgerStep; ledgerStep += 2) {
        final ledgerY = bottomLineY - ledgerStep * (spacing / 2);
        canvas.drawLine(
          Offset(noteX - ledgerHalfLength, ledgerY),
          Offset(noteX + ledgerHalfLength, ledgerY),
          ledgerPaint,
        );
      }
    } else if (staffStep < 0) {
      final lowestLedgerStep = staffStep.isEven ? staffStep : staffStep + 1;
      for (int ledgerStep = -2; ledgerStep >= lowestLedgerStep; ledgerStep -= 2) {
        final ledgerY = bottomLineY - ledgerStep * (spacing / 2);
        canvas.drawLine(
          Offset(noteX - ledgerHalfLength, ledgerY),
          Offset(noteX + ledgerHalfLength, ledgerY),
          ledgerPaint,
        );
      }
    }

    if (showSharp) {
      final sharpX = noteX - noteHeadWidth * 0.52 - horizontalGap - sharpWidth;
      final sharpHeight = spacing * 2.2;
      final sharpCenterY = noteY - spacing * 0.01;
      final stemPaint = Paint()
        ..color = noteColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.7, spacing * 0.14)
        ..strokeCap = StrokeCap.round;
      final barPaint = Paint()
        ..color = noteColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(3.2, spacing * 0.28)
        ..strokeCap = StrokeCap.round;

      final leftStemX = sharpX + sharpWidth * 0.33;
      final rightStemX = sharpX + sharpWidth * 0.69;
      final stemTilt = spacing * 0.05;
      final topY = sharpCenterY - sharpHeight * 0.5;
      final bottomY = sharpCenterY + sharpHeight * 0.5;
      canvas.drawLine(
        Offset(leftStemX, topY),
        Offset(leftStemX + stemTilt, bottomY),
        stemPaint,
      );
      canvas.drawLine(
        Offset(rightStemX, topY),
        Offset(rightStemX + stemTilt, bottomY),
        stemPaint,
      );

      final horizontalLeftX = sharpX - sharpWidth * 0.02;
      final horizontalRightX = sharpX + sharpWidth * 1.02;
      final horizontalRise = spacing * 0.11;
      final upperY = sharpCenterY - sharpHeight * 0.2;
      final lowerY = sharpCenterY + sharpHeight * 0.2;
      canvas.drawLine(
        Offset(horizontalLeftX, upperY),
        Offset(horizontalRightX, upperY - horizontalRise),
        barPaint,
      );
      canvas.drawLine(
        Offset(horizontalLeftX, lowerY),
        Offset(horizontalRightX, lowerY - horizontalRise),
        barPaint,
      );
    }

    final noteHeadRect = Rect.fromCenter(
      center: Offset(noteX, noteY),
      width: noteHeadWidth,
      height: noteHeadHeight,
    );
    if (isHalfNote) {
      canvas.drawOval(noteHeadRect, noteStrokePaint);
    } else {
      canvas.drawOval(noteHeadRect, noteFillPaint);
    }

    final stemLength = spacing * 3.5;
    final stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = max(2.0, spacing * 0.22);
    final staffMiddleY = (staffTopY + staffBottomY) / 2;
    final stemGoesDownOnLeft = noteY < staffMiddleY;
    final rx = noteHeadWidth * 0.5;
    // Half notes: attach on outer edge to keep hollow head clean.
    // Quarter notes: attach slightly inside for a smooth continuous join.
    final attachXOffset = isHalfNote ? rx : noteHeadWidth * 0.43;
    if (stemGoesDownOnLeft) {
      final stemX = noteX - attachXOffset;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY + stemLength),
        stemPaint,
      );
      if (isEighthNote) {
        final flagPaint = Paint()
          ..color = noteColor
          ..style = PaintingStyle.fill;
        final tipY = noteY + stemLength;
        // In standard engraving, eighth-note flags are drawn on the
        // right side of the stem for both stem directions.
        final flagPath = Path()
          ..moveTo(stemX, tipY)
          ..cubicTo(
            stemX + spacing * 0.16,
            tipY - spacing * 0.20,
            stemX + spacing * 0.96,
            tipY - spacing * 0.52,
            stemX + spacing * 0.70,
            tipY - spacing * 1.16,
          )
          ..cubicTo(
            stemX + spacing * 0.52,
            tipY - spacing * 0.90,
            stemX + spacing * 0.22,
            tipY - spacing * 0.56,
            stemX,
            tipY - spacing * 0.36,
          )
          ..close();
        canvas.drawPath(flagPath, flagPaint);
      }
    } else {
      final stemX = noteX + attachXOffset;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY - stemLength),
        stemPaint,
      );
      if (isEighthNote) {
        final flagPaint = Paint()
          ..color = noteColor
          ..style = PaintingStyle.fill;
        final tipY = noteY - stemLength;
        final flagPath = Path()
          ..moveTo(stemX, tipY)
          ..cubicTo(
            stemX + spacing * 0.14,
            tipY + spacing * 0.20,
            stemX + spacing * 0.98,
            tipY + spacing * 0.52,
            stemX + spacing * 0.70,
            tipY + spacing * 1.16,
          )
          ..cubicTo(
            stemX + spacing * 0.52,
            tipY + spacing * 0.90,
            stemX + spacing * 0.22,
            tipY + spacing * 0.56,
            stemX,
            tipY + spacing * 0.36,
          )
          ..close();
        canvas.drawPath(flagPath, flagPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) {
    return oldDelegate.staffStep != staffStep ||
        oldDelegate.showSharp != showSharp ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.isHalfNote != isHalfNote ||
        oldDelegate.isEighthNote != isEighthNote;
  }
}

class _VerticalViolinNeckPainter extends CustomPainter {
  _VerticalViolinNeckPainter({
    required this.marker,
    required this.selectedString,
    required this.targetFingerNumber,
    required this.targetStringIndex,
    required this.showHintColors,
    required this.hintColor,
  });

  final Offset? marker;
  final int? selectedString;
  final int targetFingerNumber;
  final int targetStringIndex;
  final bool showHintColors;
  final Color hintColor;
  // Approximate relative violin string gauges: G > D > A > E.
  static const List<double> _stringStrokeByIndex = [3.6, 2.7, 2.1, 1.4];

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 8, size.width - 20, size.height - 16),
      const Radius.circular(18),
    );
    final neckPaint = Paint()..color = const Color(0xFF121417);
    canvas.drawRRect(bodyRect, neckPaint);

    final nutY = _ViolinFingerGeometry.topPadding - 10;
    canvas.drawRect(
      Rect.fromLTWH(14, nutY, size.width - 28, 8),
      Paint()..color = const Color(0xFFE7E8F0),
    );

    final strings = _ViolinFingerGeometry.stringXs(size);
    final top = _ViolinFingerGeometry.topPadding;
    final bottom = size.height - _ViolinFingerGeometry.bottomPadding;
    for (int i = 0; i < strings.length; i++) {
      final isTargetString = i == targetStringIndex;
      canvas.drawLine(
        Offset(strings[i], top),
        Offset(strings[i], bottom),
        Paint()
          ..color = isTargetString
              ? const Color(0xFFEAF0FF)
              : const Color(0xB3F4F6FF)
          ..strokeWidth = _stringStrokeByIndex[i],
      );
    }

    final openY = _ViolinFingerGeometry.yForFingerOnScreen(fingerNumber: 0, size: size);
    for (final stringX in strings) {
      final targetSpot = Offset(stringX, openY);
      canvas.drawCircle(
        targetSpot,
        7.5,
        Paint()..color = const Color(0x55FFFFFF),
      );
      canvas.drawCircle(
        targetSpot,
        7.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFF6AA7FF),
      );
    }

    for (int finger = 1; finger <= 3; finger++) {
      final y = _ViolinFingerGeometry.yForFingerOnScreen(
        fingerNumber: finger,
        size: size,
      );
      canvas.drawLine(
        Offset(14, y),
        Offset(size.width - 14, y),
        Paint()
          ..color = const Color(0x59FFFFFF)
          ..strokeWidth = 1.8,
      );
    }

    if (showHintColors) {
      final targetY = _ViolinFingerGeometry.yForFingerOnScreen(
        fingerNumber: targetFingerNumber,
        size: size,
      );
      final targetStringX = strings[targetStringIndex];
      canvas.drawCircle(
        Offset(targetStringX, targetY),
        10,
        Paint()..color = hintColor.withValues(alpha: 0.32),
      );
      canvas.drawCircle(
        Offset(targetStringX, targetY),
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = hintColor,
      );
    }

    if (marker != null) {
      final onDString = selectedString == 1;
      final markerPaint = Paint()
        ..color = onDString ? const Color(0xFF00C853) : const Color(0xFFFF7043);
      canvas.drawCircle(marker!, 11, markerPaint);
      canvas.drawCircle(
        marker!,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalViolinNeckPainter oldDelegate) {
    return oldDelegate.marker != marker ||
        oldDelegate.selectedString != selectedString ||
        oldDelegate.targetFingerNumber != targetFingerNumber ||
        oldDelegate.targetStringIndex != targetStringIndex ||
        oldDelegate.showHintColors != showHintColors ||
        oldDelegate.hintColor != hintColor;
  }
}
