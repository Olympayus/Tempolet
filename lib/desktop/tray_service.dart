import 'package:flutter/foundation.dart';
// tray_manager 0.8 moved to the nativeapi Menu API; its root library no longer
// re-exports the 0.5.x facade. The facade still ships in src/ and is the only
// API with onClick handlers, so v0.1.0 uses it through implementation imports
// (migrate to the native API in v0.2.0).
// ignore: implementation_imports
import 'package:tray_manager/src/menu.dart' show Menu, MenuItem;
// ignore: implementation_imports
import 'package:tray_manager/src/tray_listener.dart' show TrayListener;
// ignore: implementation_imports
import 'package:tray_manager/src/tray_manager.dart' show TrayManager;

/// Minimal system tray: show the main window or quit.
class TrayService {
  final TrayManager _tray = TrayManager.instance;

  Future<void> initialize({
    required VoidCallback onShow,
    required VoidCallback onQuit,
  }) async {
    await _tray.setToolTip('Tempolet');
    await _tray.setIcon('assets/tray_icon.ico');
    await _tray.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示主窗口', onClick: (_) => onShow()),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出', onClick: (_) => onQuit()),
        ],
      ),
    );
    _tray.addListener(_TrayListener(onShow: onShow));
  }

  Future<void> setTooltip(String text) => _tray.setToolTip(text);

  Future<void> dispose() => _tray.destroy();
}

class _TrayListener extends TrayListener {
  _TrayListener({required this.onShow});

  final VoidCallback onShow;

  @override
  void onTrayIconMouseDown() => onShow();

  @override
  void onTrayIconMouseUp() => onShow();
}
