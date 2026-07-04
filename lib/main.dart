import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import: pulls in the real JS interop helper when compiling
// for the web, and a no-op stub otherwise. This keeps `dart:js_interop`
// out of native builds entirely.
import 'audio_stub.dart' if (dart.library.js_interop) 'audio_web.dart';

part 'models.dart';
part 'persistence.dart';
part 'content.dart';
part 'auth.dart';
part 'screens.dart';
part 'painters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ViolinHeroApp());
}
