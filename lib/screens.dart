part of 'main.dart';

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
    if (session != null) {
      unawaited(_HeroProgressStore.loadAndMergeRemote(session.username));
    }
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
      await _HeroProgressStore.loadAndMergeRemote(session.username);
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
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final isLandscape = mq.size.width > mq.size.height;
        if (!isLandscape) return child!;
        final portraitSize = Size(mq.size.height, mq.size.width);
        return MediaQuery(
          data: mq.copyWith(size: portraitSize),
          child: RotatedBox(
            quarterTurns: -1,
            child: SizedBox(
              width: portraitSize.width,
              height: portraitSize.height,
              child: child,
            ),
          ),
        );
      },
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
    this.isDraft = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? footer;

  /// When true, the card shows a small "DRAFT" pill next to the title.
  /// Used by the admin-only library so the admin user can tell at a
  /// glance which songs are still hidden from regular players.
  final bool isDraft;

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isDraft) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE0B2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFB8C00),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'DRAFT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE65100),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
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
    // Filter the library by visibility — admin-only songs are hidden
    // from regular users, but admin accounts see them with a DRAFT
    // badge so they're easy to spot.
    final adminSession = isAdminUser(session);
    final visibleSongs = kSongLibrary
        .where(
          (song) =>
              song.visibility == SongVisibility.public || adminSession,
        )
        .toList(growable: false);

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
                for (int i = 0; i < visibleSongs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ModuleCard(
                    title: visibleSongs[i].title,
                    icon: visibleSongs[i].icon,
                    color: visibleSongs[i].color,
                    isDraft:
                        visibleSongs[i].visibility == SongVisibility.admin,
                    footer: _ProgressStarsRow(
                      filledCount: _displayStarsFromSectionTotal(
                        progress.songSectionStars[visibleSongs[i].id] ?? 0,
                      ),
                      color: visibleSongs[i].color,
                    ),
                    onTap: () {
                      final song = visibleSongs[i];
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SongLearningScreen(
                            song: song,
                            session: session,
                            onLogout: onLogout,
                            onProfileUpdated: onProfileUpdated,
                          ),
                        ),
                      );
                    },
                  ),
                ],
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

class _AudioPool {
  _AudioPool();

  static const int size = 4;
  final Map<String, String> _dataUrlCache = {};

  final List<AudioPlayer> _nativePlayers = [];
  int _nativeIndex = 0;

  void init() {
    if (!kIsWeb) {
      for (int i = 0; i < size; i++) {
        _nativePlayers.add(AudioPlayer());
      }
    }
  }

  Future<void> play(Uint8List wavBytes, {double volume = 0.85, String? cacheKey}) async {
    if (kIsWeb) {
      _playWeb(wavBytes, volume: volume, cacheKey: cacheKey);
    } else {
      await _playNative(wavBytes, volume: volume);
    }
  }

  void _playWeb(Uint8List wavBytes, {double volume = 0.85, String? cacheKey}) {
    final key = cacheKey ?? '${wavBytes.length}_${wavBytes.hashCode}';
    final dataUrl = _dataUrlCache.putIfAbsent(key, () {
      final b64 = base64Encode(wavBytes);
      return 'data:audio/wav;base64,$b64';
    });
    playDataUrlOnWeb(dataUrl, volume);
  }

  Future<void> _playNative(Uint8List wavBytes, {double volume = 0.85}) async {
    final player = _nativePlayers[_nativeIndex];
    _nativeIndex = (_nativeIndex + 1) % size;
    try {
      await player.play(
        BytesSource(wavBytes, mimeType: 'audio/wav'),
        volume: volume,
      );
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  void dispose() {
    for (final p in _nativePlayers) {
      p.dispose();
    }
    _nativePlayers.clear();
    _dataUrlCache.clear();
  }
}

class _ViolinGameScreenState extends State<ViolinGameScreen>
    with _AdaptiveNoteLearning<ViolinGameScreen> {
  @override
  List<GameNote> get adaptiveNotePool => _allNotes;

  final Random _random = Random();

  // Free play exposes every note in [kGameNotePool] except the low-2
  // `C5_A` (C natural only appears in song material). Derived from the
  // shared pool so the note set can't drift from Learn Songs.
  static final List<GameNote> _allNotes = kGameNotePool
      .where((note) => note.id != 'C5_A')
      .toList(growable: false);

  // Adaptive per-note state maps (_consecutiveCorrect, _mastered, hide
  // flags, mistake counters) and their hydrate/persist helpers come from
  // the shared [_AdaptiveNoteLearning] mixin, keyed by [adaptiveNotePool].
  static const int _mistakesBeforeHintReturns = 2;
  static const int _relearnCorrectToHideHintAgain = 2;
  static const int _correctToHideNoteName = 3;
  static const int _relearnCorrectToHideNoteNameAgain = 2;
  static const int _mistakesBeforeNoteNameReturns = 2;
  late final _AudioPool _audioPool;
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
    _audioPool = _AudioPool()..init();
    _activeStringIndices = widget.activeStringIndices.toSet().toList()..sort();
    _currentNote = _pickRandomNoteFromSelection();
    _hydrateAdaptiveStatesFromStore();
  }

  @override
  void dispose() {
    _audioPool.dispose();
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
    final nameWasHidden =
        (_nameMastered[noteId] ?? false) && (_hideNoteNameForNote[noteId] ?? false);
    final alreadyMastered = _mastered[noteId] ?? false;

    final isCorrect =
        placement.stringIndex == _currentNote.stringIndex &&
        placement.fingerNumber == _currentNote.fingerNumber &&
        (!_currentNote.lowSecondFinger || placement.lowSecondVariant);
    final stringIndex = _currentNote.stringIndex;
    _stringAttempts[stringIndex] = (_stringAttempts[stringIndex] ?? 0) + 1;

    if (isCorrect) {
      var justMastered = false;
      setState(() {
        _feedbackState = FeedbackState.correct;
        _consecutiveCorrect[noteId] = (_consecutiveCorrect[noteId] ?? 0) + 1;
        if (hintWasHidden) {
          _consecutiveCorrectAtLevel2[noteId] =
              (_consecutiveCorrectAtLevel2[noteId] ?? 0) + 1;
        } else {
          _consecutiveCorrectAtLevel2[noteId] = 0;
        }

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
        // Level 2 → 3 / 2.5 → 3: graduate the note name out once the
        // player has built a sufficient streak *while already at
        // Level 2* (color hint hidden).
        if (hintWasHidden &&
            !(_nameMastered[noteId] ?? false) &&
            (_consecutiveCorrectAtLevel2[noteId] ?? 0) >= _correctToHideNoteName) {
          _nameMastered[noteId] = true;
          _hideNoteNameForNote[noteId] = true;
          _mistakesWithoutNoteName[noteId] = 0;
        } else if ((_nameMastered[noteId] ?? false) &&
            !nameWasHidden &&
            hintWasHidden &&
            (_consecutiveCorrectAtLevel2[noteId] ?? 0) >=
                _relearnCorrectToHideNoteNameAgain) {
          _hideNoteNameForNote[noteId] = true;
          _mistakesWithoutNoteName[noteId] = 0;
        } else if (nameWasHidden) {
          _mistakesWithoutNoteName[noteId] = 0;
        }
        _isTransitioning = true;
        _mistakeChargedForCurrentNote = false;
      });
      _persistAdaptiveStateForNote(noteId);

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
        _consecutiveCorrectAtLevel2[noteId] = 0;
        // Cascade one level at a time — Level 3 → 2 happens before
        // any color hint can come back.
        if (nameWasHidden) {
          final nextMistakeCount = (_mistakesWithoutNoteName[noteId] ?? 0) + 1;
          _mistakesWithoutNoteName[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeNoteNameReturns) {
            _hideNoteNameForNote[noteId] = false;
            _mistakesWithoutNoteName[noteId] = 0;
          }
        } else if (hintWasHidden) {
          final nextMistakeCount = (_mistakesWithoutHint[noteId] ?? 0) + 1;
          _mistakesWithoutHint[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeHintReturns) {
            _hideHintForNote[noteId] = false;
            _mistakesWithoutHint[noteId] = 0;
          }
        }
      });
      _persistAdaptiveStateForNote(noteId);
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

  /// `true` when the solfège card should display the note name. False
  /// only at Level 3, except during the brief "correct" feedback
  /// window where we briefly reveal the name as confirmation.
  bool get _showNoteNameForCurrentNote {
    final noteId = _currentNote.id;
    final isNameMastered = _nameMastered[noteId] ?? false;
    final hideName = _hideNoteNameForNote[noteId] ?? false;
    if (!isNameMastered || !hideName) return true;
    return _feedbackState == FeedbackState.correct;
  }

  Future<void> _playNoteTone(GameNote note) async {
    final toneBytes =
        _toneCache.putIfAbsent(note.id, () => _buildViolinLikeWav(note.frequencyHz));
    await _audioPool.play(toneBytes, cacheKey: note.id);
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
                          showNoteName: _showNoteNameForCurrentNote,
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
                      targetLowSecondFinger: _currentNote.lowSecondFinger,
                      showHintColors: _showHintColors,
                      hintColor: _currentNote.hintColor,
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

class _SongLearningScreenState extends State<SongLearningScreen>
    with _AdaptiveNoteLearning<SongLearningScreen> {
  @override
  List<GameNote> get adaptiveNotePool => _songNotePool;

  static const double _sectionStarAccuracyThreshold = 0.85;
  // Learn Songs exposes every note in [kGameNotePool] except the G-string
  // notes (no current song descends that low). Derived from the shared
  // pool so the note set can't drift from Learn Notes.
  static final List<GameNote> _songNotePool = kGameNotePool
      .where((note) => note.stringIndex != 0)
      .toList(growable: false);

  // ── Adaptive hint system ────────────────────────────────────────
  // Per-note progression has three levels, each progressively harder:
  //
  //   Level 1 — full hints  (color note head + colored neck indicator
  //                          + colored solfège card)
  //   Level 2 — name only   (no color anywhere; solfège card visible
  //                          in neutral grey)
  //   Level 3 — staff only  (no color, no solfège shown until the
  //                          player places correctly — then the
  //                          solfège card briefly reveals as positive
  //                          confirmation alongside the audio)
  //
  // Progression: 3 consecutive correct plays at the current level
  // graduate the note up. A wrong play resets the streak counter and,
  // if it accumulates [_mistakesBeforeHintReturns] (or, for Level 3,
  // [_mistakesBeforeNoteNameReturns]) misses, drops the note one level
  // down so the help comes back. Re-mastery uses the lower thresholds
  // [_relearnCorrectToHideHintAgain] / [_relearnCorrectToHideNoteNameAgain]
  // — once a player has *been* at a level, getting back is faster.
  static const int _mistakesBeforeHintReturns = 2;
  static const int _relearnCorrectToHideHintAgain = 2;
  static const int _correctToHideNoteName = 3;
  static const int _relearnCorrectToHideNoteNameAgain = 2;
  static const int _mistakesBeforeNoteNameReturns = 2;
  // Adaptive per-note state maps and their hydrate/persist helpers come
  // from the shared [_AdaptiveNoteLearning] mixin, keyed by
  // [adaptiveNotePool] (= [_songNotePool] here).

  late final _AudioPool _audioPool;
  final Map<String, Uint8List> _toneCache = {};
  late SongDefinition _selectedSong;
  int _songIndex = 0;
  int _mistakesThisRun = 0;
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
    _audioPool = _AudioPool()..init();
    _selectedSong = widget.song;
    _songNotes = _selectedSong.noteIds
        .map<GameNote?>((id) => id.isEmpty ? null : _noteById(id))
        .toList(growable: false);
    _hydrateAdaptiveStatesFromStore();
    // If the song happens to begin with a rest, the player can't act
    // on it — schedule the silent auto-advance after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAutoAdvanceIfRest();
    });
  }

  @override
  void dispose() {
    _audioPool.dispose();
    super.dispose();
  }

  /// O(1) id → note lookup, built once from [_songNotePool]. Replaces a
  /// per-call linear scan.
  static final Map<String, GameNote> _songNotePoolById = {
    for (final note in _songNotePool) note.id: note,
  };

  GameNote _noteById(String id) => _songNotePoolById[id]!;

  /// Per-slot resolved notes, computed once in [initState] — the selected
  /// song never changes for a screen instance, so there's no need to
  /// rebuild this list (and re-run a lookup per note) on every access.
  /// Rest slots map to `null` — there's no pitched note associated with a
  /// rest. Indexing parallels [SongDefinition.noteDurations].
  late final List<GameNote?> _songNotes;

  /// `null` while the current slot is a rest. UI code should branch on
  /// this — the violin neck is disabled, the hint card is hidden, and
  /// the staff card draws a rest glyph instead of a note head.
  GameNote? get _currentNote => _songNotes[_songIndex];

  NoteDuration get _currentNoteDuration =>
      _selectedSong.noteDurations[_songIndex];

  int get _currentNoteDurationMs => noteDurationMs(_currentNoteDuration);

  /// `true` when the current slot is a rest. Centralized so the audio,
  /// hit-test, and rendering branches all check the same condition.
  bool get _isCurrentRest => _currentNoteDuration.spec.isRest;

  /// What the violin neck should render. During a rest there's no target
  /// to aim at, so instead of dimming/recoloring the board we keep the
  /// most recently shown pitched note frozen in place — the fingerboard
  /// doesn't change at all when a rest begins; taps are simply ignored
  /// (see the `IgnorePointer` in the rest branch) until the rest elapses
  /// and the next note loads. Returns `null` only if the song opens on a
  /// rest, in which case the board renders neutral.
  GameNote? get _neckDisplayNote {
    if (!_isCurrentRest) return _currentNote;
    for (var i = _songIndex - 1; i >= 0; i--) {
      final note = _songNotes[i];
      if (note != null) return note;
    }
    return null;
  }

  bool _showHintFor(String noteId) {
    final isMastered = _mastered[noteId] ?? false;
    final hideHint = _hideHintForNote[noteId] ?? false;
    return !isMastered || !hideHint;
  }

  /// `true` when the solfège card should display the note name. False
  /// only at Level 3, with one exception: while the player is being
  /// shown positive feedback for a correct placement we briefly reveal
  /// the name as a learning confirmation alongside the audio.
  bool _showNoteNameFor(String noteId) {
    final isNameMastered = _nameMastered[noteId] ?? false;
    final hideName = _hideNoteNameForNote[noteId] ?? false;
    if (!isNameMastered || !hideName) return true;
    return _feedbackState == FeedbackState.correct;
  }

  bool get _notesVisibleInUi {
    final note = _currentNote;
    if (note == null) {
      // During a rest there's no pitched note to "play by heart"; the
      // staff still shows the rest glyph so the player keeps their place.
      return true;
    }
    return !_isByHeartMode || _byHeartHintNoteId == note.id;
  }

  bool get _showHintColors {
    final note = _currentNote;
    if (note == null) return false;
    return _notesVisibleInUi && _showHintFor(note.id);
  }

  bool get _showNoteNameForCurrentNote {
    final note = _currentNote;
    if (note == null) return false;
    if (!_notesVisibleInUi) return false;
    return _showNoteNameFor(note.id);
  }

  /// Auto-advances the song through any rest slots without requiring
  /// player input. Called from [initState] (covers songs that start on
  /// a rest), after every successful note advance, and after a
  /// play-mode reset. Safe to call when the current slot is *not* a
  /// rest — it's a no-op in that case.
  void _scheduleAutoAdvanceIfRest() {
    if (!mounted || !_isCurrentRest || _isTransitioning) return;
    setState(() {
      _isTransitioning = true;
    });
    final restDurationMs = _currentNoteDurationMs;
    final indexAtSchedule = _songIndex;
    Future<void>.delayed(Duration(milliseconds: restDurationMs), () {
      if (!mounted) return;
      // Bail if state shifted under us (mode toggle, song reset, etc.).
      if (_songIndex != indexAtSchedule) return;
      _completeRestAdvance();
    });
  }

  /// Silent counterpart to the post-correct-tap advancement: bumps the
  /// song index forward (or completes the song) without awarding stars
  /// or playing audio. Triggers [_scheduleAutoAdvanceIfRest] again so
  /// consecutive rests chain through cleanly.
  void _completeRestAdvance() {
    if (!mounted) return;
    final lastIndex = _songNotes.length - 1;
    final wasFinalSlot = _songIndex >= lastIndex;
    if (wasFinalSlot) {
      // The song's final slot is a trailing rest (e.g. a closing
      // "quarter + quarter rest" bar). The player has already played
      // the last pitched note, so this is a genuine finish — run the
      // full completion flow (celebration + stars), exactly as if the
      // song had ended on a note. Without this the song would silently
      // loop back to the start and play through again.
      setState(() {
        _songIndex = 0;
        _feedbackState = FeedbackState.idle;
        _isTransitioning = false;
      });
      unawaited(_finishSong());
      return;
    }
    setState(() {
      _songIndex++;
      _feedbackState = FeedbackState.idle;
      _isTransitioning = false;
    });
    _scheduleAutoAdvanceIfRest();
  }

  /// Shared song-completion flow: tallies accuracy, awards stars, logs
  /// the completion, optionally promotes to "play by heart", and shows
  /// the celebration overlay. Called both when the player finishes on a
  /// pitched note and when the song's final slot is a trailing rest.
  ///
  /// Callers are expected to have already reset `_songIndex` to 0; the
  /// run counters (`_mistakesThisRun`, `_wrongChargedNotesThisRun`) must
  /// still be intact so accuracy and the perfect-run check are correct —
  /// this method resets them once it's done reading them.
  Future<void> _finishSong() async {
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
    // The song just snapped back to slot 0 — if that's a rest, kick
    // off the auto-advance so the player isn't stuck staring at it.
    _scheduleAutoAdvanceIfRest();
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
    // Rests don't accept input — the slot auto-advances on its own
    // timer. Ignore stray taps so the player can rest their hand.
    if (_isCurrentRest) return;
    final note = _currentNote;
    if (note == null) return; // Defensive: rest already handled above.
    final noteId = note.id;
    final hintWasHidden = (_mastered[noteId] ?? false) && (_hideHintForNote[noteId] ?? false);
    final nameWasHidden =
        (_nameMastered[noteId] ?? false) && (_hideNoteNameForNote[noteId] ?? false);
    final noteVisibleInUi = !_isByHeartMode || _byHeartHintNoteId == noteId;
    final hintVisibleNow = noteVisibleInUi && _showHintFor(noteId);

    final isCorrect =
        placement.stringIndex == note.stringIndex &&
        placement.fingerNumber == note.fingerNumber &&
        // Low-2 notes (e.g. C natural on the A string) must be played
        // with the 2nd finger close to the 1st finger. High-2 targets
        // (C#, F#) accept either sub-zone for backward compatibility.
        (!note.lowSecondFinger || placement.lowSecondVariant);

    if (isCorrect) {
      setState(() {
        _feedbackState = FeedbackState.correct;
        if (_isByHeartMode) {
          _byHeartHintNoteId = null;
          _byHeartMistakesOnCurrentNote = 0;
        }
        _consecutiveCorrect[noteId] = (_consecutiveCorrect[noteId] ?? 0) + 1;
        // The Level 2 → 3 graduation only counts plays the player
        // entered with the color hint already hidden — this enforces
        // the "3 more correct *at Level 2*" gate independent of the
        // total streak, and resets cleanly whenever the player drops
        // back to Level 1.5 (hint visible again).
        if (hintWasHidden) {
          _consecutiveCorrectAtLevel2[noteId] =
              (_consecutiveCorrectAtLevel2[noteId] ?? 0) + 1;
        } else {
          _consecutiveCorrectAtLevel2[noteId] = 0;
        }
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
        // Level 2 → 3: initial graduation hides the solfège card.
        // Level 2.5 → 3: re-mastery uses the lower threshold once the
        // note has *previously* been at Level 3.
        if (hintWasHidden &&
            !(_nameMastered[noteId] ?? false) &&
            (_consecutiveCorrectAtLevel2[noteId] ?? 0) >= _correctToHideNoteName) {
          _nameMastered[noteId] = true;
          _hideNoteNameForNote[noteId] = true;
          _mistakesWithoutNoteName[noteId] = 0;
        } else if ((_nameMastered[noteId] ?? false) &&
            !nameWasHidden &&
            hintWasHidden &&
            (_consecutiveCorrectAtLevel2[noteId] ?? 0) >=
                _relearnCorrectToHideNoteNameAgain) {
          _hideNoteNameForNote[noteId] = true;
          _mistakesWithoutNoteName[noteId] = 0;
        } else if (nameWasHidden) {
          _mistakesWithoutNoteName[noteId] = 0;
        }
        _isTransitioning = true;
        _mistakeChargedForCurrentSongNote = false;
      });
      _persistAdaptiveStateForNote(noteId);

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
          stringIndex: note.stringIndex,
          songId: _selectedSong.id,
          byHeartMode: _isByHeartMode,
          hintUsed: hintVisibleNow,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': note.fingerNumber,
          },
        ),
      );

      final noteDurationMs = _currentNoteDurationMs;
      await _playNoteTone(note, durationMs: noteDurationMs);
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
      // The new slot may be a rest — chain the silent auto-advance.
      // Skipped on song completion: the celebration overlay handles
      // that path on its own.
      if (!songCompleted) {
        _scheduleAutoAdvanceIfRest();
      }
      if (songCompleted) {
        await _finishSong();
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
        _consecutiveCorrectAtLevel2[noteId] = 0;
        // Mistake handling cascades one level at a time so that a
        // single wrong play never demotes the note past two stages.
        // Level 3 (name hidden) → Level 2 first; only future mistakes
        // at Level 2 can take the hint color back.
        if (nameWasHidden) {
          final nextMistakeCount = (_mistakesWithoutNoteName[noteId] ?? 0) + 1;
          _mistakesWithoutNoteName[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeNoteNameReturns) {
            _hideNoteNameForNote[noteId] = false;
            _mistakesWithoutNoteName[noteId] = 0;
          }
        } else if (hintWasHidden) {
          final nextMistakeCount = (_mistakesWithoutHint[noteId] ?? 0) + 1;
          _mistakesWithoutHint[noteId] = nextMistakeCount;
          if (nextMistakeCount >= _mistakesBeforeHintReturns) {
            _hideHintForNote[noteId] = false;
            _mistakesWithoutHint[noteId] = 0;
          }
        }
      });
      _persistAdaptiveStateForNote(noteId);
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
          stringIndex: note.stringIndex,
          songId: _selectedSong.id,
          byHeartMode: _isByHeartMode,
          hintUsed: hintVisibleNow,
          metadata: {
            'fingerNumber': placement.fingerNumber,
            'targetFinger': note.fingerNumber,
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
    await _audioPool.play(toneBytes, cacheKey: cacheKey);
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
    // Scale the attack/release ramps with the note's duration so the
    // envelope doesn't swallow the body of short notes. For quarter
    // notes and longer the result is identical to the original
    // (capped at 5200 attack / 6800 release samples ≈ 118 / 154 ms);
    // for eighths and sixteenths the ramps shorten proportionally so
    // the note actually rings audibly between attack and release
    // instead of fading to silence the moment it finishes ramping in.
    // Effect: less staccato feel and a smaller perceived gap between
    // adjacent short notes.
    final attackSamples = min(5200, (sampleCount * 0.20).round());
    final releaseSamples = min(6800, (sampleCount * 0.25).round());
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
                                  hintColor: _currentNote?.hintColor ??
                                      const Color(0xFF111111),
                                  duration: _currentNoteDuration,
                                ),
                                const SizedBox(height: 8),
                                // Solfege hint card only makes sense for
                                // pitched slots — there's no syllable to
                                // sing during a rest. Use a same-height
                                // placeholder so the layout doesn't jump.
                                if (_currentNote != null)
                                  _NoteHintCard(
                                    note: _currentNote!,
                                    showHintColors: _showHintColors,
                                    showNoteName: _showNoteNameForCurrentNote,
                                  )
                                else
                                  const SizedBox(height: 108),
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
                        // While the current slot is a rest the neck
                        // ignores taps but is left visually unchanged —
                        // the most recently shown note stays frozen in
                        // place (no dim, no recolor). The auto-advance
                        // timer takes the slot to the next note, which
                        // becomes playable once the rest elapses.
                        child: _isCurrentRest
                            ? IgnorePointer(
                                child: _VerticalViolinNeckCard(
                                  key: ValueKey(
                                    '${_selectedSong.id}_rest_after_'
                                    '${_neckDisplayNote?.id ?? 'start'}',
                                  ),
                                  neckHeight: neckHeight,
                                  neckWidth: neckWidth,
                                  targetFingerNumber:
                                      _neckDisplayNote?.fingerNumber ?? 0,
                                  targetStringIndex:
                                      _neckDisplayNote?.stringIndex ?? 0,
                                  targetLowSecondFinger:
                                      _neckDisplayNote?.lowSecondFinger ?? false,
                                  showHintColors:
                                      _neckDisplayNote != null && _showHintColors,
                                  hintColor: _neckDisplayNote?.hintColor ??
                                      const Color(0xFF111111),
                                  onPlacement: _onFingerPlacement,
                                ),
                              )
                            : _VerticalViolinNeckCard(
                                key: ValueKey(
                                  '${_selectedSong.id}_${_songIndex}_${_currentNote!.id}',
                                ),
                                neckHeight: neckHeight,
                                neckWidth: neckWidth,
                                targetFingerNumber: _currentNote!.fingerNumber,
                                targetStringIndex: _currentNote!.stringIndex,
                                targetLowSecondFinger:
                                    _currentNote!.lowSecondFinger,
                                showHintColors: _showHintColors,
                                hintColor: _currentNote!.hintColor,
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

