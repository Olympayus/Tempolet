import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_titlebar.dart';
import 'package:tempolet/desktop/titlebar_channel.dart';

Widget _app(Widget child) => MaterialApp(home: Column(children: [child]));

void _noop() {}

Widget _titlebar({
  bool maximized = false,
  TitlebarHover hover = TitlebarHover.none,
}) {
  return AppTitlebar(
    maximized: maximized,
    hover: hover,
    onMinimize: _noop,
    onMaximizeRestore: _noop,
    onClose: _noop,
  );
}

void main() {
  testWidgets('titlebar is 32 high with 46x32 buttons and red close hover', (
    tester,
  ) async {
    // MaterialApp's home receives tight full-screen constraints, so a Column
    // gives the bar the loose height it has at the top of the app shell.
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AppTitlebar(
              maximized: false,
              hover: TitlebarHover.close,
              onMinimize: () {},
              onMaximizeRestore: () {},
              onClose: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppTitlebar)).height, 32);
    expect(
      tester.getSize(find.byKey(const ValueKey('titlebar-close'))),
      const Size(46, 32),
    );
    final close = tester.widget<Container>(
      find.byKey(const ValueKey('titlebar-close')),
    );
    expect((close.decoration as BoxDecoration).color, const Color(0xFFC42B1C));
  });

  testWidgets('all three buttons are 46x32', (tester) async {
    await tester.pumpWidget(_app(_titlebar()));

    for (final key in const [
      'titlebar-min',
      'titlebar-max',
      'titlebar-close',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))),
        const Size(46, 32),
        reason: key,
      );
    }
  });

  testWidgets('nav background, bottom hairline and 12px app name at x=14', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_titlebar()));

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('titlebar-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.light.nav);
    expect(
      decoration.border,
      Border(bottom: BorderSide(color: AppPalette.light.line)),
    );

    final name = tester.widget<Text>(find.text('Tempolet'));
    expect(name.style?.fontSize, 12);
    expect(name.style?.color, AppPalette.light.sub);
    expect(tester.getRect(find.text('Tempolet')).left, 14);
  });

  testWidgets('hovered button uses a 6% fill', (tester) async {
    await tester.pumpWidget(_app(_titlebar(hover: TitlebarHover.min)));

    final min = tester.widget<Container>(
      find.byKey(const ValueKey('titlebar-min')),
    );
    expect((min.decoration as BoxDecoration).color, const Color(0x0F000000));
    final max = tester.widget<Container>(
      find.byKey(const ValueKey('titlebar-max')),
    );
    expect((max.decoration as BoxDecoration).color, Colors.transparent);
  });

  testWidgets('close hover paints a white icon, other close states do not', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_titlebar(hover: TitlebarHover.close)));
    final hovered = tester.widget<Icon>(find.byIcon(LucideIcons.x));
    expect(hovered.color, Colors.white);

    await tester.pumpWidget(_app(_titlebar()));
    final idle = tester.widget<Icon>(find.byIcon(LucideIcons.x));
    expect(idle.color, AppPalette.light.ink);
  });

  testWidgets('maximize button shows the restore glyph when maximized', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_titlebar()));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('titlebar-max')),
        matching: find.byIcon(LucideIcons.square),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(_app(_titlebar(maximized: true)));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('titlebar-max')),
        matching: find.byIcon(LucideIcons.copy),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TitlebarChannel maps native hover calls', (tester) async {
    final channel = TitlebarChannel();
    channel.initialize();
    addTearDown(channel.dispose);

    Future<void> send(Object? button) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        kTitlebarChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('hover', {'button': button}),
        ),
        (_) {},
      );
    }

    await send('min');
    expect(channel.hover.value, TitlebarHover.min);
    await send('max');
    expect(channel.hover.value, TitlebarHover.max);
    await send('close');
    expect(channel.hover.value, TitlebarHover.close);
    await send(null);
    expect(channel.hover.value, TitlebarHover.none);
    await send('unexpected');
    expect(channel.hover.value, TitlebarHover.none);
  });
}
