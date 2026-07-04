part of 'main.dart';

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

