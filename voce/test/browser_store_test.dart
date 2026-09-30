import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voce_linkedin/domain.dart';
import 'package:voce_linkedin/main.dart';
import 'package:voce_linkedin/platform_services.dart';
import 'package:voce_linkedin/store.dart';

class BrowserApi extends Api {
  final calls = <String>[];
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  BrowserApi() { base = 'https://voce.example.test'; token = 'test'; }
  @override
  Future<Json> call(String path, {Json? data}) async {
    calls.add(path);
    if (path == '/v1/status') return {
      'mode': 'browser', 'radar_supported': true, 'ai': true,
      'browser': {'state': 'partial', 'fresh': true, 'enabled': true},
    };
    if (path == '/v1/inbox') return {'items': [{
      'id': 'browser:comment', 'source': 'linkedin_browser',
      'author': 'Autore test', 'text': 'Come controlli i dati?',
      'fetched_at': now, 'done': false,
      'draft': {'text': 'Verifico la fonte prima di usarli.'},
    }]};
    if (path == '/v1/radar') return {'items': [{
      'id': 'browser:post', 'source': 'linkedin_browser',
      'author': 'Autore feed', 'text': 'Software sanitario e verifica dei dati.',
      'fetched_at': now, 'draft': {'text': 'Quale controllo fate alla fonte?'},
    }]};
    return {'ok': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final saved = <String, String>{};
  setUp(() {
    saved.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Device.channel, (call) async {
      if (call.method == 'write') saved[call.arguments['key']] = call.arguments['value'];
      return null;
    });
  });
  test('Sincronizzazione browser conserva bozze, dati manuali e stato gestito', () async {
    final api = BrowserApi();
    final store = AppStore(api: api);
    addTearDown(store.dispose);
    store.comments.add({'id': 'manual-comment', 'source': 'manual'});
    store.posts.add({'id': 'manual-post', 'source': 'manual'});
    await store.refresh();
    await store.refresh();
    expect(store.comments.length, 2);
    expect(store.posts.length, 2);
    expect(store.comments.last['draft']['text'], 'Verifico la fonte prima di usarli.');
    expect(store.posts.last['draft']['text'], 'Quale controllo fate alla fonte?');
    final prepared = await store.preparedDraft(store.posts.last, 'comment');
    prepared['text'] = 'Modifica personale';
    expect((await store.preparedDraft(store.posts.last, 'comment'))['text'], 'Modifica personale');
    store.posts.last['text'] = 'Il post è stato modificato';
    store.posts.last['draft'] = {'text': 'Nuova bozza sul contenuto aggiornato'};
    expect((await store.preparedDraft(store.posts.last, 'comment'))['text'], 'Nuova bozza sul contenuto aggiornato');
    expect(store.drafts.length, 1);
    await store.mark(store.comments.last, true);
    expect(api.calls, contains('/v1/inbox/update'));
    final archive = jsonDecode(saved['workspace']!);
    expect(archive['comments'].last['done'], true);
    store.comments.last['fetched_at'] = api.now - 172801;
    store.posts.last['fetched_at'] = api.now - 172801;
    store.purge();
    expect(store.comments.single['id'], 'manual-comment');
    expect(store.posts.single['id'], 'manual-post');
  });
  testWidgets('La raccolta parziale e il blocco sono visibili', (tester) async {
    final store = AppStore(api: BrowserApi());
    addTearDown(store.dispose);
    store.status = {'browser': {'state': 'partial', 'fresh': true, 'enabled': true}};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrowserStatus(store: store))));
    expect(find.text('Raccolta con copertura parziale'), findsOneWidget);
    store.status = {'browser': {'state': 'blocked', 'fresh': false, 'enabled': true}};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrowserStatus(key: UniqueKey(), store: store))));
    expect(find.text('LinkedIn richiede una verifica'), findsOneWidget);
    expect(find.textContaining('non comunica da tempo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
