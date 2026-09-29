import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoro_forge/domain/models.dart';
import 'package:zoro_forge/src/app.dart';

// Read-only fixture: renders the real DojoScreen without mocking its layout,
// scrollable, disclosure, or catalog. No database or GPS is required here.
class _DojoStore extends ChangeNotifier implements AppStore {
  @override final Catalog catalog;
  _DojoStore(this.catalog);
  @override List<Workout> get history => [];
  @override Workout? get draft => null;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _scrollToFooter(WidgetTester tester) async {
  final list = find.byKey(const PageStorageKey('sword-page'));
  final scrollable = find.descendant(of: list, matching: find.byType(Scrollable)).first;
  for (var n = 0; n < 45; n++) {
    await tester.drag(list, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Scrolling into the Dojo footer must not cast a saved scroll offset to bool.');
    expect(find.byType(ErrorWidget), findsNothing);
    final state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent - 1) return;
  }
  fail('Footer was not reached after 45 short scrolls.');
}

void main() {
  late Catalog catalog;
  setUpAll(() => catalog = Catalog.decode(File('assets/catalog.json').readAsStringSync()));

  for (final spec in [
    (width: 360.0, height: 800.0, scale: 1.0),
    (width: 320.0, height: 700.0, scale: 1.3),
    (width: 412.0, height: 900.0, scale: 1.0),
  ]) {
    testWidgets('Dojo footer scroll ${spec.width.toInt()}', (tester) async {
      tester.view.physicalSize = Size(spec.width, spec.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _DojoStore(catalog);
      final bucket = PageStorageBucket();
      final visible = ValueNotifier<bool>(true);
      final boundaryKey = GlobalKey();
      addTearDown(store.dispose);
      addTearDown(visible.dispose);
      await tester.pumpWidget(AppScope(store: store, child: MaterialApp(
        theme: forgeTheme,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(spec.scale)), child: child!),
        home: Scaffold(
          appBar: AppBar(title: const Text('ZORO FORGE')),
          body: RepaintBoundary(key: boundaryKey, child: PageStorage(bucket: bucket,
            child: ValueListenableBuilder<bool>(valueListenable: visible,
              builder: (context, show, _) => show ? const DojoScreen() : const Center(child: Text('Altra scheda'))))),
        ),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Persist a genuine scroll-offset double before the disclosure is built.
      // This is the state the old version shares accidentally with the tile.
      final context = tester.element(find.byKey(const PageStorageKey('sword-page')));
      bucket.writeState(context, 64.0);
      await _scrollToFooter(tester);
      final title = find.text('Il percorso verso le tre spade');
      expect(title, findsOneWidget);
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Una spada: fondamentali.'), findsOneWidget);
      final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
      expect(tile.key, isA<PageStorageKey<String>>());
      final tileContext = tester.element(find.byType(ExpansionTile));
      expect(bucket.readState(tileContext), isTrue);
      final listContext = tester.element(find.byKey(const PageStorageKey('sword-page')));
      expect(bucket.readState(listContext), isA<double>());
      // Destroy/recreate the page in the same bucket, as when changing tabs.
      visible.value = false;
      await tester.pumpAndSettle();
      visible.value = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollToFooter(tester);
      expect(find.textContaining('Una spada: fondamentali.'), findsOneWidget);
      // Close and reopen; neither operation may corrupt the scroll offset.
      await tester.ensureVisible(find.text('Il percorso verso le tre spade'));
      await tester.tap(find.text('Il percorso verso le tre spade'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final end = find.text('Apri tutta la videoteca');
      await tester.ensureVisible(end);
      await tester.pumpAndSettle();
      expect(end.hitTestable(), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      if (spec.width == 360) {
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build-report/dojo-footer-fixed.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('Every disclosure has a distinct scoped storage key', () {
    for (final name in ['dojo_screen.dart', 'progress_screen.dart', 'settings_screen.dart', 'video_screen.dart']) {
      final source = File('lib/src/$name').readAsStringSync();
      final tiles = RegExp(r'\bExpansionTile\(').allMatches(source).length;
      final keyed = RegExp(r'\bExpansionTile\(\s*key:\s*(?:const\s+)?PageStorageKey<String>').allMatches(source).length;
      expect(keyed, tiles, reason: '$name has an unkeyed expanding item.');
    }
  });
}
