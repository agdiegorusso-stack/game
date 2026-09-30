import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voce_linkedin/main.dart';
import 'package:voce_linkedin/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final saved = <String, String>{};
  setUp(() {
    saved.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Device.channel, (call) async {
          if (call.method == 'read') return saved[call.arguments['key']];
          if (call.method == 'write')
            saved[call.arguments['key']] = call.arguments['value'];
          return null;
        });
  });
  testWidgets('Avvio vuoto e navigazione senza dati inventati', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VoceApp());
    await tester.pumpAndSettle();
    expect(find.text('La tua coda parte da qui'), findsOneWidget);
    expect(find.text('MODALITÀ LOCALE'), findsOneWidget);
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    expect(find.text('Aggiungi post'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Di cosa vuoi parlare?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Importazione conserva testo e autore dopo riavvio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VoceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Autore (facoltativo)'),
      'Autore test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Testo completo del post'),
      'Un software per infermieri deve partire dalle attività concrete.',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();
    expect(find.text('Autore test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const VoceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    expect(find.text('Autore test'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [360.0, 430.0]) {
    testWidgets('Navigazione senza overflow su schermo $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: capture, child: const VoceApp()));
      await tester.pumpAndSettle();
      for (final entry in {'Risposte': 'risposte', 'Studio': 'studio', 'Radar': 'radar', 'Profilo': 'profilo'}.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Schermata ${entry.key}, larghezza $width');
        if (width == 430) {
          await tester.runAsync(() async {
            final boundary = capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build-report/${entry.value}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
