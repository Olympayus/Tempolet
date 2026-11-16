import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/ui/app_titlebar.dart';

/// Native→Flutter channel the runner uses to report the hovered title bar
/// button (`windows/runner/flutter_window.cpp`).
const String kTitlebarChannelName = 'tempolet/titlebar';

/// Maps the channel's `button` argument to a [TitlebarHover].
///
/// The runner sends `min`, `max`, `close` or null; anything else is treated as
/// "no button" so a future native value cannot crash the title bar.
TitlebarHover titlebarHoverFromNative(Object? button) => switch (button) {
  'min' => TitlebarHover.min,
  'max' => TitlebarHover.max,
  'close' => TitlebarHover.close,
  _ => TitlebarHover.none,
};

/// Receives native title bar hover notifications.
///
/// The runner owns hit-testing (it must, to keep Snap previews working), so the
/// Flutter side only listens: `hover` carries the button under the pointer and
/// the shell repaints the title bar from it.
class TitlebarChannel {
  TitlebarChannel([this._channel = const MethodChannel(kTitlebarChannelName)]);

  final MethodChannel _channel;

  /// Button currently under the native pointer; [TitlebarHover.none] while the
  /// pointer is elsewhere.
  final ValueNotifier<TitlebarHover> hover = ValueNotifier(TitlebarHover.none);

  bool _initialized = false;

  /// Starts listening for `hover` calls. Safe to call more than once.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'hover') return;
    final arguments = call.arguments;
    final button = arguments is Map ? arguments['button'] : null;
    hover.value = titlebarHoverFromNative(button);
  }

  void dispose() {
    if (_initialized) {
      _channel.setMethodCallHandler(null);
      _initialized = false;
    }
    hover.dispose();
  }
}
