part of 'main.dart';

class _MusicStaffCard extends StatelessWidget {
  const _MusicStaffCard({
    required this.note,
    required this.feedbackState,
    required this.showHintColors,
    required this.hintColor,
    this.duration = NoteDuration.quarter,
  });

  /// `null` when the current slot is a rest. The painter then draws the
  /// rest glyph indicated by `duration.spec.restGlyph` instead of a
  /// pitched note head.
  final GameNote? note;
  final FeedbackState feedbackState;
  final bool showHintColors;
  final Color hintColor;
  final NoteDuration duration;

  @override
  Widget build(BuildContext context) {
    final isRest = duration.spec.isRest;
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
                // For rests, staffStep is unused — the painter routes to
                // the rest-glyph path. We pass 4 (middle line) just so
                // the field has a sensible value.
                staffStep: note?.staffStep ?? 4,
                showSharp:
                    !isRest && (note?.letterLabel.contains('#') ?? false),
                // Rests render in a neutral dark color regardless of
                // hint state — a rest doesn't belong to a string/finger.
                noteColor: isRest
                    ? const Color(0xFF111111)
                    : (showHintColors ? hintColor : const Color(0xFF111111)),
                durationSpec: duration.spec,
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
    this.showNoteName = true,
  });

  final GameNote note;
  final bool showHintColors;

  /// `false` at Level 3 of the adaptive system — the card is hidden
  /// entirely (rendered as transparent space of the same size) so the
  /// player has to identify the note from its staff position alone.
  /// Keeping the slot reserved instead of collapsing it prevents the
  /// layout below from jumping each time the player advances through
  /// notes at different mastery levels.
  ///
  /// Briefly toggled back to `true` on `FeedbackState.correct` so the
  /// student sees the answer alongside the audio confirmation, then
  /// flips back to `false` on the next slot.
  final bool showNoteName;

  @override
  Widget build(BuildContext context) {
    if (!showNoteName) {
      // Reserve the slot but render nothing — the card vanishes until
      // a correct placement reveals the note name.
      return const SizedBox(width: 108, height: 108);
    }
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
  const _FingerPlacement({
    required this.fingerNumber,
    required this.stringIndex,
    this.lowSecondVariant = false,
  });

  final int fingerNumber;
  final int stringIndex;

  /// `true` only when [fingerNumber] is 2 and the player tapped the
  /// upper half of the finger-2 region (the low-2 spot, closer to
  /// finger 1). Used by the correctness check for low-2 notes such as
  /// C natural.
  final bool lowSecondVariant;
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
  /// Semitones above the open string for the "low 2" finger placement —
  /// the spot used for natural notes like C on the A string or F on the
  /// D string. A half step below the regular (high) 2nd finger.
  static const int _lowSecondSemitones = 3;
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

  /// Y-coordinate of the "low 2" finger spot — between finger 1 and the
  /// regular (high) 2nd finger. The placement that natural C or natural
  /// F want on a real violin.
  static double yForLowSecondFingerOnScreen(Size size) {
    final top = topPadding;
    final bottom = size.height - bottomPadding;
    final mm = _distanceFromNutForSemitone(_lowSecondSemitones) *
        stoppedFingerSpacingScale;
    final y = top + mmToLogicalPx(mm);
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
    final y2Low = yForLowSecondFingerOnScreen(size);
    final y2 = yForFingerOnScreen(fingerNumber: 2, size: size);
    final y3 = yForFingerOnScreen(fingerNumber: 3, size: size);
    final yOpen = yForFingerOnScreen(fingerNumber: 0, size: size);

    final int fingerNumber;
    bool lowSecondVariant = false;
    if (clampedY < (y1 + y2) / 2) {
      fingerNumber = 1;
    } else if (clampedY < (y2 + y3) / 2) {
      fingerNumber = 2;
      // Within the finger-2 region, the upper half (closer to finger 1)
      // is the low-2 sub-zone; the lower half is high-2. Splitting only
      // inside the finger-2 region keeps the boundaries with finger 1
      // and finger 3 unchanged from the previous behavior.
      lowSecondVariant = clampedY < (y2Low + y2) / 2;
    } else if (clampedY < (y3 + yOpen) / 2) {
      fingerNumber = 3;
    } else {
      fingerNumber = 0;
    }
    final snappedY = (fingerNumber == 2 && lowSecondVariant)
        ? y2Low
        : yForFingerOnScreen(fingerNumber: fingerNumber, size: size);

    return _ResolvedPlacement(
      placement: _FingerPlacement(
        fingerNumber: fingerNumber,
        stringIndex: stringIndex,
        lowSecondVariant: lowSecondVariant,
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
    required this.onPlacement,
    this.targetLowSecondFinger = false,
  });

  final double neckHeight;
  final double neckWidth;
  final int targetFingerNumber;
  final int targetStringIndex;
  final bool showHintColors;
  final Color hintColor;
  final ValueChanged<_FingerPlacement> onPlacement;
  final bool targetLowSecondFinger;

  @override
  State<_VerticalViolinNeckCard> createState() => _VerticalViolinNeckCardState();
}

class _VerticalViolinNeckCardState extends State<_VerticalViolinNeckCard> {
  Offset? _marker;
  int? _selectedString;
  int? _selectedFinger;
  bool _selectedLowSecond = false;

  void _handleTap(Offset localPosition, Size size) {
    final resolved = _ViolinFingerGeometry.resolveFromTouch(localPosition, size);
    setState(() {
      _marker = resolved.marker;
      _selectedString = resolved.placement.stringIndex;
      _selectedFinger = resolved.placement.fingerNumber;
      _selectedLowSecond = resolved.placement.lowSecondVariant;
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
                    selectedFinger: _selectedFinger,
                    selectedLowSecond: _selectedLowSecond,
                    targetFingerNumber: widget.targetFingerNumber,
                    targetStringIndex: widget.targetStringIndex,
                    showHintColors: widget.showHintColors,
                    hintColor: widget.hintColor,
                    targetLowSecondFinger: widget.targetLowSecondFinger,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
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
    required this.durationSpec,
  });

  final int staffStep;
  final bool showSharp;
  final Color noteColor;
  final NoteDurationSpec durationSpec;

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

    // Treble (G) clef rendered from the bundled Bravura SMuFL font
    // (gClef = U+E050), matching the rest glyphs for consistent
    // engraving. SMuFL anchors the clef's baseline (y = 0) on the
    // G line — the 2nd staff line from the bottom — and uses 1000
    // units/em = 4 staff spaces. So a font size of 4 × spacing with
    // the baseline on the G line reproduces standard placement: the
    // spiral curls around the G line, the tail hangs below the staff,
    // and the flourish rises above it.
    final clefText = TextPainter(
      text: TextSpan(
        text: '\u{E050}',
        style: TextStyle(
          color: const Color(0xFF111111),
          fontFamily: 'Bravura',
          fontSize: spacing * 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final clefBaselineDist =
        clefText.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final clefX = staffLeftX + 2;
    final clefY = gLineY - clefBaselineDist;
    clefText.paint(canvas, Offset(clefX, clefY));
    final clefRightX = clefX + clefText.width;

    final bottomLineY = staffBottomY;

    // Rest slots: draw the Unicode rest glyph centered horizontally on
    // the staff and aligned to its conventional vertical position. Skip
    // the entire note-head / sharp / stem / flag pipeline below.
    if (durationSpec.isRest) {
      _paintRest(
        canvas: canvas,
        clefRightX: clefRightX,
        staffRightX: staffRightX,
        staffTopY: staffTopY,
        staffBottomY: staffBottomY,
        spacing: spacing,
      );
      return;
    }

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
    if (durationSpec.hasOpenHead) {
      canvas.drawOval(noteHeadRect, noteStrokePaint);
    } else {
      canvas.drawOval(noteHeadRect, noteFillPaint);
    }

    // Augmentation dot for dotted rhythms. Sits to the right of the note
    // head; nudged into the adjacent space when the head is on a staff
    // line so it doesn't visually merge with the line itself.
    if (durationSpec.isDotted) {
      final dotRadius = max(2.0, spacing * 0.18);
      final dotX = noteX + noteHeadWidth * 0.5 + spacing * 0.45;
      final isOnLine = staffStep.isEven;
      final dotY = isOnLine ? noteY - spacing * 0.5 : noteY;
      canvas.drawCircle(Offset(dotX, dotY), dotRadius, noteFillPaint);
    }

    if (!durationSpec.hasStem) {
      // Whole notes have no stem — drawing is complete after the head.
      return;
    }

    final stemLength = spacing * 3.5;
    final stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = max(2.0, spacing * 0.22);
    final staffMiddleY = (staffTopY + staffBottomY) / 2;
    final stemGoesDownOnLeft = noteY < staffMiddleY;
    final rx = noteHeadWidth * 0.5;
    // Open heads attach the stem at the edge of the oval; filled heads
    // hide the stem's anchor inside the fill.
    final attachXOffset =
        durationSpec.hasOpenHead ? rx : noteHeadWidth * 0.43;
    final flagCount = durationSpec.flagCount;
    if (stemGoesDownOnLeft) {
      final stemX = noteX - attachXOffset;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY + stemLength),
        stemPaint,
      );
      if (flagCount >= 1) {
        _drawFlagsDownStem(
          canvas: canvas,
          stemX: stemX,
          tipY: noteY + stemLength,
          spacing: spacing,
          flagCount: flagCount,
        );
      }
    } else {
      final stemX = noteX + attachXOffset;
      canvas.drawLine(
        Offset(stemX, noteY),
        Offset(stemX, noteY - stemLength),
        stemPaint,
      );
      if (flagCount >= 1) {
        _drawFlagsUpStem(
          canvas: canvas,
          stemX: stemX,
          tipY: noteY - stemLength,
          spacing: spacing,
          flagCount: flagCount,
        );
      }
    }
  }

  /// Draws one or more flags on a stem that points downward (note head
  /// above the stem tip). [flagCount] determines how many flags are
  /// stacked — 1 = eighth, 2 = sixteenth, etc. — each subsequent flag
  /// nudges upward by ~0.7 staff spaces along the stem.
  void _drawFlagsDownStem({
    required Canvas canvas,
    required double stemX,
    required double tipY,
    required double spacing,
    required int flagCount,
  }) {
    final flagPaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < flagCount; i++) {
      final flagTipY = tipY - spacing * 0.7 * i;
      final flagPath = Path()
        ..moveTo(stemX, flagTipY)
        ..cubicTo(
          stemX + spacing * 0.16,
          flagTipY - spacing * 0.20,
          stemX + spacing * 0.96,
          flagTipY - spacing * 0.52,
          stemX + spacing * 0.70,
          flagTipY - spacing * 1.16,
        )
        ..cubicTo(
          stemX + spacing * 0.52,
          flagTipY - spacing * 0.90,
          stemX + spacing * 0.22,
          flagTipY - spacing * 0.56,
          stemX,
          flagTipY - spacing * 0.36,
        )
        ..close();
      canvas.drawPath(flagPath, flagPaint);
    }
  }

  /// Draws one or more flags on a stem that points upward.
  void _drawFlagsUpStem({
    required Canvas canvas,
    required double stemX,
    required double tipY,
    required double spacing,
    required int flagCount,
  }) {
    final flagPaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < flagCount; i++) {
      final flagTipY = tipY + spacing * 0.7 * i;
      final flagPath = Path()
        ..moveTo(stemX, flagTipY)
        ..cubicTo(
          stemX + spacing * 0.14,
          flagTipY + spacing * 0.20,
          stemX + spacing * 0.98,
          flagTipY + spacing * 0.52,
          stemX + spacing * 0.70,
          flagTipY + spacing * 1.16,
        )
        ..cubicTo(
          stemX + spacing * 0.52,
          flagTipY + spacing * 0.90,
          stemX + spacing * 0.22,
          flagTipY + spacing * 0.56,
          stemX,
          flagTipY + spacing * 0.36,
        )
        ..close();
      canvas.drawPath(flagPath, flagPaint);
    }
  }

  /// Paints the rest glyph for the current `durationSpec`, plus an
  /// augmentation dot for dotted rests.
  ///
  /// Rests are rendered from the bundled **Bravura** SMuFL music font
  /// (see `pubspec.yaml` / `fonts/Bravura.otf`) — the same reference
  /// font professional engraving uses — so each rest is an authentic
  /// glyph rather than a hand-drawn approximation. Earlier attempts
  /// drew the rests as `Canvas` paths because no system font on the
  /// target platforms covers the Unicode Musical-Symbols rests
  /// (U+1D13B–F); Bravura provides them at the SMuFL private-use code
  /// points instead.
  ///
  /// Positioning uses SMuFL conventions: glyph metrics are 1000 units
  /// per em = 4 staff spaces, and the glyph baseline (y = 0) sits on
  /// the MIDDLE staff line. Drawing each glyph with its baseline on
  /// the middle line therefore reproduces standard placement:
  ///   • quarter / eighth / sixteenth — straddle the middle line;
  ///   • half rest — sits on the middle line;
  ///   • whole rest — hangs from the 4th line (one space above the
  ///     middle), so its baseline is raised by one staff space.
  void _paintRest({
    required Canvas canvas,
    required double clefRightX,
    required double staffRightX,
    required double staffTopY,
    required double staffBottomY,
    required double spacing,
  }) {
    if (!durationSpec.isRest) return;

    final staffMidY = (staffTopY + staffBottomY) / 2;
    final restCenterX = (clefRightX + staffRightX) / 2;

    // Map the internal Unicode rest code point to the corresponding
    // Bravura SMuFL glyph, and pick the baseline anchor.
    String? glyph;
    var baselineY = staffMidY;
    switch (durationSpec.restGlyph) {
      case '\u{1D13B}': // whole rest → restWhole, hangs from line 4
        glyph = '\u{E4E3}';
        baselineY = staffMidY - spacing;
        break;
      case '\u{1D13C}': // half rest → restHalf, sits on the middle line
        glyph = '\u{E4E4}';
        break;
      case '\u{1D13D}': // quarter rest → restQuarter
        glyph = '\u{E4E5}';
        break;
      case '\u{1D13E}': // eighth rest → rest8th
        glyph = '\u{E4E6}';
        break;
      case '\u{1D13F}': // sixteenth rest → rest16th
        glyph = '\u{E4E7}';
        break;
    }
    if (glyph == null) return;

    // 1 em (1000 SMuFL units) spans 4 staff spaces, so a font size of
    // 4 × spacing maps one staff space to `spacing` logical pixels.
    final restText = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: spacing * 4,
          color: noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Place the glyph's baseline on the chosen staff line and center
    // it horizontally in the space after the clef.
    final baselineDist =
        restText.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final glyphX = restCenterX - restText.width / 2;
    final glyphY = baselineY - baselineDist;
    restText.paint(canvas, Offset(glyphX, glyphY));

    if (durationSpec.isDotted) {
      final dotRadius = max(2.0, spacing * 0.18);
      final dotX = restCenterX + restText.width / 2 + spacing * 0.35;
      final dotY = staffMidY;
      canvas.drawCircle(
        Offset(dotX, dotY),
        dotRadius,
        Paint()..color = noteColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) {
    return oldDelegate.staffStep != staffStep ||
        oldDelegate.showSharp != showSharp ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.durationSpec != durationSpec;
  }
}

class _VerticalViolinNeckPainter extends CustomPainter {
  _VerticalViolinNeckPainter({
    required this.marker,
    required this.selectedString,
    required this.selectedFinger,
    required this.selectedLowSecond,
    required this.targetFingerNumber,
    required this.targetStringIndex,
    required this.showHintColors,
    required this.hintColor,
    this.targetLowSecondFinger = false,
  });

  final Offset? marker;
  final int? selectedString;
  final int? selectedFinger;
  final bool selectedLowSecond;
  final int targetFingerNumber;
  final int targetStringIndex;
  final bool showHintColors;
  final Color hintColor;
  final bool targetLowSecondFinger;
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
      final targetY = (targetFingerNumber == 2 && targetLowSecondFinger)
          ? _ViolinFingerGeometry.yForLowSecondFingerOnScreen(size)
          : _ViolinFingerGeometry.yForFingerOnScreen(
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
      // Green when the placement matches the target note, red otherwise —
      // the same correctness rule the learning screens use (right string,
      // right finger, and low-2 sub-zone when the target demands it). This
      // works for every note on every string.
      final isCorrect = selectedString == targetStringIndex &&
          selectedFinger == targetFingerNumber &&
          (!targetLowSecondFinger || selectedLowSecond);
      final markerPaint = Paint()
        ..color = isCorrect ? const Color(0xFF00C853) : const Color(0xFFFF7043);
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
        oldDelegate.selectedFinger != selectedFinger ||
        oldDelegate.selectedLowSecond != selectedLowSecond ||
        oldDelegate.targetFingerNumber != targetFingerNumber ||
        oldDelegate.targetStringIndex != targetStringIndex ||
        oldDelegate.showHintColors != showHintColors ||
        oldDelegate.hintColor != hintColor ||
        oldDelegate.targetLowSecondFinger != targetLowSecondFinger;
  }
}
