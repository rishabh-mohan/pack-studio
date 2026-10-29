import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/pack_colors_screen.dart';
import 'package:pack_studio/pack_storage.dart';
import 'package:pack_studio/theme.dart';

Future<void> settleIo(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 160; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 8 &&
        (until?.call() ??
            find.byType(CircularProgressIndicator).evaluate().isEmpty)) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a pack palette saves, survives reopen, and leaves other packs alone',
    (tester) async {
      if (const bool.fromEnvironment('RENDER_REVIEW')) {
        const fontPath = String.fromEnvironment('REVIEW_FONT');
        if (fontPath.isNotEmpty) {
          await tester.runAsync(() async {
            final bytes = await File(fontPath).readAsBytes();
            await (FontLoader('Roboto')..addFont(Future.value(bytes.buffer.asByteData()))).load();
            await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
          });
        }
      }
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late Directory tmp;
      late PackStorage storage;
      late PackEntry pack, other;
      late String otherBefore;
      await tester.runAsync(() async {
        tmp = await Directory.systemTemp.createTemp('pack_colors');
        storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
        pack = await storage.createFromTemplate('Ocean adventure');
        other = await storage.createFromTemplate('Another pack');
        otherBefore = await storage.read(other, 'pack.json');
        final manifest = jsonDecode(
          await storage.read(pack, 'pack.json'),
        ) as Map<String, dynamic>;
        manifest['authorNote'] = 'Keep me';
        manifest['colorScheme'] = {
          'preset': 'peach',
          'customExtension': 42,
          'colors': {'futureRole': '#112233'},
        };
        await storage.write(pack, 'pack.json', jsonEncode(manifest));
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        try {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        } on FileSystemException {
          /* Windows may briefly retain a file handle. */
        }
      });
      const captureKey = ValueKey('color-scheme-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const ValueKey('section:Color scheme'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PackColorsScreen(pack: pack, storage: storage),
                    ),
                  ),
                  child: const Text('Edit colors'),
                ),
              ),
            ),
          ),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byKey(const ValueKey('section:Color scheme')));
      await settleIo(tester);
      await tester.tap(find.byKey(const ValueKey('palette:ocean')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PackColorPreview>(find.byType(PackColorPreview))
            .scheme
            .preset,
        'ocean',
      );
      if (const bool.fromEnvironment('RENDER_REVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build').create(recursive: true);
          await File('build/pack-color-scheme.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final accent = find.byKey(const ValueKey('hex:accent'));
      await tester.ensureVisible(accent);
      await tester.enterText(accent, '#12');
      await tester.pump(const Duration(seconds: 1));
      await settleIo(tester);
      expect(find.text('Use a color such as #367EB3'), findsOneWidget);
      var saved = jsonDecode(
        (await tester.runAsync(() => storage.read(pack, 'pack.json')))!,
      ) as Map;
      expect((saved['colorScheme'] as Map)['preset'], 'ocean');
      expect(
        ((saved['colorScheme'] as Map)['colors'] as Map).containsKey('accent'),
        isFalse,
      );

      await tester.enterText(accent, '#334455');
      await tester.pump();
      expect(find.text('Use a color such as #367EB3'), findsNothing);
      // Navigate immediately: the pending autosave must finish before the route closes.
      await tester.tap(find.byType(BackButton));
      await settleIo(
        tester,
        until: () => find.byType(PackColorsScreen).evaluate().isEmpty,
      );
      saved = jsonDecode(
        (await tester.runAsync(() => storage.read(pack, 'pack.json')))!,
      ) as Map;
      expect(saved['authorNote'], 'Keep me');
      expect((saved['colorScheme'] as Map)['customExtension'], 42);
      expect((saved['colorScheme'] as Map)['colors'], {
        'futureRole': '#112233',
        'accent': '#334455',
      });
      expect(
        await tester.runAsync(() => storage.read(other, 'pack.json')),
        otherBefore,
      );

      await tester.tap(find.byKey(const ValueKey('section:Color scheme')));
      await settleIo(tester);
      expect(
        tester
            .widget<PackColorPreview>(find.byType(PackColorPreview))
            .scheme
            .color('accent'),
        0xFF334455,
      );
      await tester.tap(find.byKey(const ValueKey('palette:forest')));
      await tester.tap(find.byType(BackButton));
      await settleIo(
        tester,
        until: () => find.byType(PackColorsScreen).evaluate().isEmpty,
      );
      saved = jsonDecode(
        (await tester.runAsync(() => storage.read(pack, 'pack.json')))!,
      ) as Map;
      expect((saved['colorScheme'] as Map)['preset'], 'forest');
      expect((saved['colorScheme'] as Map)['colors'], {
        'futureRole': '#112233',
      });
      expect(tester.takeException(), isNull);
    },
  );
}
