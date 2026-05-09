/// Web-only audio playback helper.
///
/// This file imports `dart:js_interop`, which is only available when
/// compiling for the web. It must therefore never be imported directly:
/// callers should use the conditional import in `main.dart` so that
/// non-web targets pull in `audio_stub.dart` instead.
library;

import 'dart:js_interop';

@JS('Audio')
extension type _JSAudio._(JSObject _) implements JSObject {
  external factory _JSAudio([String src]);
  external set volume(num value);
  external JSPromise<JSAny?> play();
}

/// Plays a `data:audio/...` URL on the browser's HTML5 Audio element at
/// the given [volume] (0.0 – 1.0). Errors are swallowed so a failed
/// playback never bubbles up to the UI layer.
void playDataUrlOnWeb(String dataUrl, double volume) {
  try {
    final audio = _JSAudio(dataUrl);
    audio.volume = volume;
    audio.play().toDart.catchError((_) => null);
  } catch (_) {
    // Audio playback is best-effort; ignore failures.
  }
}
