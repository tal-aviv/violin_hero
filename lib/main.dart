import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class ViolinHeroApp extends StatelessWidget {
  const ViolinHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Violin Hero',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FF),
      ),
      home: const ViolinGameScreen(),
    );
  }
}

class ViolinGameScreen extends StatefulWidget {
  const ViolinGameScreen({super.key});

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

  static const List<LearningStage> _stages = [
    LearningStage(
      title: 'Stage 1: Learn D/Re String',
      activeStringIndices: [1],
      mode: StageMode.learnSingleString,
    ),
    LearningStage(
      title: 'Stage 2: Learn A/La String',
      activeStringIndices: [2],
      mode: StageMode.learnSingleString,
    ),
    LearningStage(
      title: 'Stage 3: Mix D/Re + A/La',
      activeStringIndices: [1, 2],
      mode: StageMode.mixedStrings,
    ),
    LearningStage(
      title: 'Stage 4: Learn E/Mi String',
      activeStringIndices: [3],
      mode: StageMode.learnSingleString,
    ),
    LearningStage(
      title: 'Stage 5: Mix D/Re + A/La + E/Mi',
      activeStringIndices: [1, 2, 3],
      mode: StageMode.mixedStrings,
    ),
    LearningStage(
      title: 'Stage 6: Learn G/Sol String',
      activeStringIndices: [0],
      mode: StageMode.learnSingleString,
    ),
    LearningStage(
      title: 'Stage 7: Mix All Strings',
      activeStringIndices: [0, 1, 2, 3],
      mode: StageMode.mixedStrings,
    ),
  ];
  static const int _mixStageRequiredCorrect = 10;

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

  late GameNote _currentNote;
  int _stageIndex = 0;
  int _stageCorrectCount = 0;
  FeedbackState _feedbackState = FeedbackState.idle;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    unawaited(_audioPlayer.setPlayerMode(PlayerMode.lowLatency));
    _currentNote = _pickRandomNoteFromCurrentStage();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  LearningStage get _currentStage => _stages[_stageIndex];

  List<GameNote> get _activeNotesForCurrentStage => _allNotes
      .where((note) => _currentStage.activeStringIndices.contains(note.stringIndex))
      .toList();

  GameNote _pickRandomNoteFromCurrentStage({GameNote? excluding}) {
    final activeNotes = _activeNotesForCurrentStage;
    if (activeNotes.isEmpty) return _allNotes.first;
    final options = excluding == null
        ? activeNotes
        : activeNotes.where((note) => note.id != excluding.id).toList();
    if (options.isEmpty) return activeNotes.first;
    return options[_random.nextInt(options.length)];
  }

  void _advanceToNextStage() {
    if (_stageIndex >= _stages.length - 1) return;
    _stageIndex++;
    _stageCorrectCount = 0;
  }

  void _checkForStageCompletion() {
    if (_currentStage.mode == StageMode.learnSingleString) {
      final allStageNotesMastered = _activeNotesForCurrentStage.every(
        (note) => _mastered[note.id] ?? false,
      );
      if (allStageNotesMastered) {
        _advanceToNextStage();
      }
      return;
    }

    if (_stageCorrectCount >= _mixStageRequiredCorrect) {
      _advanceToNextStage();
    }
  }

  Future<void> _onFingerPlacement(_FingerPlacement placement) async {
    if (_isTransitioning) return;
    final noteId = _currentNote.id;
    final hintWasHidden = (_mastered[noteId] ?? false) && (_hideHintForNote[noteId] ?? false);

    final isCorrect =
        placement.stringIndex == _currentNote.stringIndex &&
        placement.fingerNumber == _currentNote.fingerNumber;

    if (isCorrect) {
      setState(() {
        _feedbackState = FeedbackState.correct;
        _stageCorrectCount++;
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

        _checkForStageCompletion();
        _isTransitioning = true;
      });

      await _playNoteTone(_currentNote);
      await Future<void>.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;
      setState(() {
        _currentNote = _pickRandomNoteFromCurrentStage(excluding: _currentNote);
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

  bool _isMastered(String noteId) => _mastered[noteId] ?? false;

  bool get _showHintColors {
    final noteId = _currentNote.id;
    final isMastered = _mastered[noteId] ?? false;
    final hideHint = _hideHintForNote[noteId] ?? false;
    return !isMastered || !hideHint;
  }

  String get _stageLabel {
    if (_currentStage.mode == StageMode.mixedStrings) {
      return '${_currentStage.title}  ($_stageCorrectCount/$_mixStageRequiredCorrect)';
    }
    return _currentStage.title;
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
    const durationMs = 500;
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

    const amplitude = 0.43;
    const attackSamples = 2400;
    const releaseSamples = 3900;
    const lowPassMix = 0.9;
    const bowNoiseAmount = 0.003;
    const formant1Hz = 1650.0;
    const formant2Hz = 2450.0;
    var lowPassState = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      var env = 1.0;
      if (i < attackSamples) {
        env = i / attackSamples;
      } else if (i > sampleCount - releaseSamples) {
        env = (sampleCount - i) / releaseSamples;
      }
      final baseFreq = frequencyHz;
      final harmonic = sin(2 * pi * baseFreq * t) * 0.77 +
          sin(2 * pi * baseFreq * 2 * t) * 0.145 +
          sin(2 * pi * baseFreq * 3 * t) * 0.052 +
          sin(2 * pi * baseFreq * 4 * t) * 0.018;

      final formant = sin(2 * pi * formant1Hz * t) * 0.005 +
          sin(2 * pi * formant2Hz * t) * 0.0026;

      final bowNoise = sin(2 * pi * 1137.0 * t);
      final raw = harmonic + formant + bowNoise * bowNoiseAmount * env;

      // One-pole smoothing keeps the bright tone but removes buzzy edges.
      lowPassState = lowPassState * lowPassMix + raw * (1 - lowPassMix);
      final drive = lowPassState * 1.25;
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

class _MusicStaffCard extends StatelessWidget {
  const _MusicStaffCard({
    required this.note,
    required this.feedbackState,
    required this.showHintColors,
    required this.hintColor,
  });

  final GameNote note;
  final FeedbackState feedbackState;
  final bool showHintColors;
  final Color hintColor;

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
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleTap(details.localPosition, size),
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
  });

  final int staffStep;
  final bool showSharp;
  final Color noteColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..strokeWidth = 2;
    const lines = 5;
    // Keep staff lines slightly tighter so a canonical treble clef
    // can extend above and below within the available card height.
    final spacing = min(16.0, size.height / (lines + 3.2));
    final staffTopY = (size.height - spacing * (lines - 1)) / 2;

    final staffLeftX = 20.0;
    final staffRightX = size.width - 20;
    final staffWidth = staffRightX - staffLeftX;

    for (int i = 0; i < lines; i++) {
      final y = staffTopY + i * spacing;
      canvas.drawLine(Offset(staffLeftX, y), Offset(staffRightX, y), linePaint);
    }

    final staffBottomY = staffTopY + (lines - 1) * spacing;
    // Canonical printed G-clef proportions relative to a 5-line staff:
    // about one staff-space above line 1 and one staff-space below line 5.
    final clefTopTarget = staffTopY - spacing * 1.0;
    final clefBottomTarget = staffBottomY + spacing * 2.8;
    final targetClefHeight = clefBottomTarget - clefTopTarget;
    const clefStyle = TextStyle(
      color: Color(0xFF111111),
      fontSize: 100,
      fontWeight: FontWeight.w400,
    );
    final clefText = TextPainter(
      text: TextSpan(text: '𝄞', style: clefStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseClefScale = targetClefHeight / max(1.0, clefText.height);
    final maxClefWidth = staffWidth * 0.62;
    final clefScale = min(baseClefScale, maxClefWidth / max(1.0, clefText.width));
    final clefX = staffLeftX + 2;
    final clefY = clefTopTarget;
    canvas.save();
    canvas.translate(clefX, clefY);
    canvas.scale(clefScale, clefScale);
    clefText.paint(canvas, Offset.zero);
    canvas.restore();
    final clefRightX = clefX + clefText.width * clefScale;

    final bottomLineY = staffBottomY;
    final noteY = bottomLineY - staffStep * (spacing / 2);

    final notePaint = Paint()..color = noteColor;
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

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(noteX, noteY),
        width: noteHeadWidth,
        height: noteHeadHeight,
      ),
      notePaint,
    );

    final stemLength = spacing * 3.5;
    final stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = max(2.0, spacing * 0.22);
    final staffMiddleY = (staffTopY + staffBottomY) / 2;
    final stemGoesDownOnLeft = noteY < staffMiddleY;
    if (stemGoesDownOnLeft) {
      final stemX = noteX - noteHeadWidth * 0.38;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY + stemLength),
        stemPaint,
      );
    } else {
      final stemX = noteX + noteHeadWidth * 0.38;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY - stemLength),
        stemPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) {
    return oldDelegate.staffStep != staffStep ||
        oldDelegate.showSharp != showSharp ||
        oldDelegate.noteColor != noteColor;
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
