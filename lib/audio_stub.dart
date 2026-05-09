/// Non-web stub for [playDataUrlOnWeb].
///
/// On native targets the audio path uses `package:audioplayers` directly,
/// so this helper should never be reached at runtime. It exists only so
/// the conditional import in `main.dart` resolves to a real symbol when
/// `dart:js_interop` is unavailable.
library;

void playDataUrlOnWeb(String dataUrl, double volume) {
  // Intentionally empty — never invoked on non-web platforms.
}
